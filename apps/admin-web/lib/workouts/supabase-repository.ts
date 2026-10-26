import type { CompleteWorkoutRequest } from "@oc-training-log/contracts";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  InvalidWorkoutCompletionError,
  WorkoutCompletionConflictError,
  WorkoutCompletionDataError,
  WorkoutCompletionDeniedError,
  type WorkoutCompletionRepository,
} from "./completion";

export class SupabaseWorkoutCompletionRepository
  implements WorkoutCompletionRepository
{
  constructor(private readonly client: SupabaseClient) {}

  async complete(request: CompleteWorkoutRequest): Promise<unknown> {
    const { data, error } = await this.client.rpc("complete_workout", {
      p_client_request_id: request.clientRequestId,
      p_track_code: request.trackCode,
      p_programming_day_id: request.programmingDayId,
      p_workout_date: request.workoutDate,
      p_notes: request.notes,
      p_results: request.results,
    });

    if (!error) return this.attachPersonalRecords(data);
    if (error.message.includes("workout_not_authorized")) {
      throw new WorkoutCompletionDeniedError();
    }
    if (error.message.includes("completion_conflict")) {
      throw new WorkoutCompletionConflictError();
    }
    if (
      error.message.includes("invalid_completion") ||
      error.message.includes("unsupported_result_schema")
    ) {
      throw new InvalidWorkoutCompletionError();
    }
    throw new WorkoutCompletionDataError("Unable to complete workout.", {
      cause: error,
    });
  }

  private async attachPersonalRecords(data: unknown): Promise<unknown> {
    if (!isRecord(data) || !Array.isArray(data.results)) {
      return data;
    }

    const movementResultIds = data.results
      .filter(isRecord)
      .map((result) => result.movementResultId)
      .filter((id): id is string => typeof id === "string");
    if (movementResultIds.length === 0) {
      return { ...data, personalRecords: [] };
    }

    const recordResult = await this.client
      .from("personal_records")
      .select("id, benchmark_id, movement_result_id, value, unit, achieved_at")
      .in("movement_result_id", movementResultIds);
    if (recordResult.error) {
      throw new WorkoutCompletionDataError("Unable to load personal records.", {
        cause: recordResult.error,
      });
    }

    const records = recordResult.data ?? [];
    const benchmarkIds = records.map((record) => record.benchmark_id);
    const benchmarkResult = await this.client
      .from("benchmarks")
      .select("id, label")
      .in("id", benchmarkIds);
    if (benchmarkResult.error) {
      throw new WorkoutCompletionDataError("Unable to load benchmarks.", {
        cause: benchmarkResult.error,
      });
    }

    const labels = new Map(
      (benchmarkResult.data ?? []).map((benchmark) => [
        benchmark.id,
        benchmark.label,
      ]),
    );

    return {
      ...data,
      personalRecords: records.map((record) => ({
        personalRecordId: record.id,
        benchmarkId: record.benchmark_id,
        benchmarkLabel: labels.get(record.benchmark_id) ?? "Personal record",
        movementResultId: record.movement_result_id,
        value: Number(record.value),
        unit: record.unit,
        achievedAt: record.achieved_at,
      })),
    };
  }
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
