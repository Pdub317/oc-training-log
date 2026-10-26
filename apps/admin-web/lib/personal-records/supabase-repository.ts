import type { TrackCode } from "@oc-training-log/contracts";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  PersonalRecordsDataError,
  type PersonalRecordsRepository,
} from "./service";

type Track = { id: string; code: TrackCode; name: string };
type Benchmark = {
  id: string;
  label: string;
  result_schema: string;
  comparison_direction: "higher" | "lower";
};
type RecordRow = {
  id: string;
  benchmark_id: string;
  movement_result_id: string;
  value: number | string;
  unit: string;
  achieved_at: string;
};
type ResultRow = {
  id: string;
  workout_log_id: string;
  completed_reps: number | null;
};

export class SupabasePersonalRecordsRepository
  implements PersonalRecordsRepository
{
  constructor(private readonly client: SupabaseClient) {}

  async list(userId: string, trackCode: TrackCode): Promise<unknown | null> {
    const track = await this.findTrack(userId, trackCode);
    if (!track) return null;
    const data = await this.load(track, userId);
    return {
      track,
      benchmarks: data.benchmarks.map((benchmark) => ({
        benchmarkId: benchmark.id,
        label: benchmark.label,
        resultSchema: benchmark.result_schema,
        comparisonDirection: benchmark.comparison_direction,
        currentBests: currentBests(benchmark, data.records, data.resultMap),
      })),
    };
  }

  async detail(
    userId: string,
    trackCode: TrackCode,
    benchmarkId: string,
  ): Promise<unknown | null> {
    const track = await this.findTrack(userId, trackCode);
    if (!track) return null;
    const data = await this.load(track, userId, benchmarkId);
    const benchmark = data.benchmarks[0];
    if (!benchmark) return null;
    const bests = currentBests(benchmark, data.records, data.resultMap);
    const bestIds = new Set(bests.map((best) => best.personalRecordId));
    const logIds = [
      ...new Set([...data.resultMap.values()].map((row) => row.workout_log_id)),
    ];
    const logs = logIds.length
      ? await this.client
          .from("workout_logs")
          .select("id, workout_date, programming_day_id, free_text_title")
          .in("id", logIds)
      : { data: [], error: null };
    assertSucceeded(logs.error);
    const dayIds = (logs.data ?? [])
      .map((log) => log.programming_day_id)
      .filter(Boolean);
    const days = dayIds.length
      ? await this.client
          .from("programming_days")
          .select("id, title")
          .in("id", dayIds)
      : { data: [], error: null };
    assertSucceeded(days.error);
    const dayMap = new Map((days.data ?? []).map((day) => [day.id, day.title]));
    const logMap = new Map((logs.data ?? []).map((log) => [log.id, log]));
    return {
      track,
      benchmark: {
        benchmarkId: benchmark.id,
        label: benchmark.label,
        resultSchema: benchmark.result_schema,
        comparisonDirection: benchmark.comparison_direction,
        currentBests: bests,
      },
      history: data.records.map((record) => {
        const result = data.resultMap.get(record.movement_result_id)!;
        const log = logMap.get(result.workout_log_id)!;
        return {
          ...score(record, benchmark, data.resultMap),
          workoutLogId: log.id,
          workoutDate: log.workout_date,
          workoutTitle: log.programming_day_id
            ? dayMap.get(log.programming_day_id)
            : log.free_text_title,
          isCurrentBest: bestIds.has(record.id),
        };
      }),
    };
  }

  private async findTrack(
    userId: string,
    code: TrackCode,
  ): Promise<Track | null> {
    const memberships = await this.client
      .from("track_memberships")
      .select("track_id")
      .eq("user_id", userId)
      .eq("status", "active");
    assertSucceeded(memberships.error);
    const ids = (memberships.data ?? []).map((row) => row.track_id);
    if (!ids.length) return null;
    const track = await this.client
      .from("training_tracks")
      .select("id, code, name")
      .eq("code", code)
      .eq("status", "active")
      .in("id", ids)
      .maybeSingle();
    assertSucceeded(track.error);
    return track.data as Track | null;
  }

  private async load(track: Track, userId: string, benchmarkId?: string) {
    let query = this.client
      .from("benchmarks")
      .select("id, label, result_schema, comparison_direction")
      .eq("track_id", track.id)
      .order("label");
    if (benchmarkId) query = query.eq("id", benchmarkId);
    const benchmarks = await query;
    assertSucceeded(benchmarks.error);
    const values = (benchmarks.data ?? []) as Benchmark[];
    const ids = values.map((benchmark) => benchmark.id);
    const records = ids.length
      ? await this.client
          .from("personal_records")
          .select(
            "id, benchmark_id, movement_result_id, value, unit, achieved_at",
          )
          .eq("user_id", userId)
          .in("benchmark_id", ids)
          .order("achieved_at", { ascending: false })
      : { data: [], error: null };
    assertSucceeded(records.error);
    const recordRows = (records.data ?? []) as RecordRow[];
    const resultIds = recordRows.map((record) => record.movement_result_id);
    const results = resultIds.length
      ? await this.client
          .from("movement_results")
          .select("id, workout_log_id, completed_reps")
          .in("id", resultIds)
      : { data: [], error: null };
    assertSucceeded(results.error);
    return {
      benchmarks: values,
      records: recordRows,
      resultMap: new Map(
        ((results.data ?? []) as ResultRow[]).map((result) => [
          result.id,
          result,
        ]),
      ),
    };
  }
}

function currentBests(
  benchmark: Benchmark,
  records: RecordRow[],
  resultMap: Map<string, ResultRow>,
) {
  const selected = new Map<string, RecordRow>();
  for (const record of records.filter(
    (row) => row.benchmark_id === benchmark.id,
  )) {
    const result = resultMap.get(record.movement_result_id);
    if (!result) continue;
    const key =
      benchmark.result_schema === "weighted_variable_reps"
        ? `${record.unit}:${result.completed_reps}`
        : record.unit;
    const prior = selected.get(key);
    if (
      !prior ||
      (benchmark.comparison_direction === "higher"
        ? Number(record.value) > Number(prior.value)
        : Number(record.value) < Number(prior.value))
    ) {
      selected.set(key, record);
    }
  }
  return [...selected.values()].map((record) =>
    score(record, benchmark, resultMap),
  );
}

function score(
  record: RecordRow,
  benchmark: Benchmark,
  resultMap: Map<string, ResultRow>,
) {
  return {
    personalRecordId: record.id,
    value: Number(record.value),
    unit: record.unit,
    completedReps:
      benchmark.result_schema === "weighted_variable_reps"
        ? Number(resultMap.get(record.movement_result_id)?.completed_reps)
        : null,
    achievedAt: record.achieved_at,
  };
}

function assertSucceeded(
  error: { message: string } | null,
): asserts error is null {
  if (error)
    throw new PersonalRecordsDataError("Unable to load personal records.", {
      cause: error,
    });
}
