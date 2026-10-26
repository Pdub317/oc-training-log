import type {
  HistoryMovement,
  HistoryRequest,
  HistoryWorkout,
  TrackCode,
  WorkoutBlockType,
} from "@oc-training-log/contracts";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  HistoryDataError,
  type HistoryRepository,
  type HistoryTrack,
} from "./service";

export class SupabaseHistoryRepository implements HistoryRepository {
  constructor(private readonly client: SupabaseClient) {}

  async findActiveTrack(
    userId: string,
    trackCode: TrackCode,
  ): Promise<HistoryTrack | null> {
    const memberships = await this.client
      .from("track_memberships")
      .select("track_id")
      .eq("user_id", userId)
      .eq("status", "active");
    assertSucceeded(memberships.error);
    const ids = (memberships.data ?? []).map((row) => row.track_id);
    if (ids.length === 0) return null;

    const track = await this.client
      .from("training_tracks")
      .select("id, code, name")
      .eq("code", trackCode)
      .eq("status", "active")
      .in("id", ids)
      .maybeSingle();
    assertSucceeded(track.error);
    return track.data as HistoryTrack | null;
  }

  async findCompletedWorkouts(
    userId: string,
    trackId: string,
    request: Omit<HistoryRequest, "trackCode">,
  ): Promise<{ workouts: HistoryWorkout[]; nextCursor: string | null }> {
    const pageSize = 50;
    let logIds: string[];
    let nextCursor: string | null;
    if (request.workoutLogId) {
      logIds = [request.workoutLogId];
      nextCursor = null;
    } else {
      const page = await this.client.rpc("find_history_workout_ids", {
        p_track_id: trackId,
        p_query: request.query ?? null,
        p_from_date: request.fromDate ?? null,
        p_personal_records_only: request.personalRecordsOnly,
        p_cursor_log_id: request.cursor ?? null,
        p_page_size: pageSize,
      });
      assertSucceeded(page.error);
      const pageIds = ((page.data ?? []) as { workout_log_id: string }[]).map(
        (row) => row.workout_log_id,
      );
      const hasNextPage = pageIds.length > pageSize;
      logIds = pageIds.slice(0, pageSize);
      nextCursor = hasNextPage ? (logIds.at(-1) ?? null) : null;
    }
    if (logIds.length === 0) return { workouts: [], nextCursor: null };

    const logs = await this.client
      .from("workout_logs")
      .select(
        "id, programming_day_id, track_id, free_text_title, workout_date, notes, completed_at, updated_at",
      )
      .eq("user_id", userId)
      .eq("track_id", trackId)
      .in("id", logIds);
    assertSucceeded(logs.error);
    if (!logs.data?.length) return { workouts: [], nextCursor: null };
    const logOrder = new Map(logIds.map((id, index) => [id, index]));
    logs.data.sort(
      (left, right) =>
        (logOrder.get(left.id) ?? pageSize) -
        (logOrder.get(right.id) ?? pageSize),
    );

    const dayIds = logs.data
      .map((log) => log.programming_day_id)
      .filter((id): id is string => typeof id === "string");
    const days = await this.client
      .from("programming_days")
      .select("id, title")
      .eq("track_id", trackId)
      .in(
        "id",
        dayIds.length ? dayIds : ["00000000-0000-0000-0000-000000000000"],
      );
    assertSucceeded(days.error);
    const dayMap = new Map((days.data ?? []).map((day) => [day.id, day]));
    const authorizedLogs = logs.data.filter(
      (log) =>
        log.programming_day_id === null || dayMap.has(log.programming_day_id),
    );
    if (authorizedLogs.length === 0) return { workouts: [], nextCursor: null };

    const authorizedDayIds = authorizedLogs
      .map((log) => log.programming_day_id)
      .filter((id): id is string => typeof id === "string");
    const blocks = await this.client
      .from("workout_blocks")
      .select("id, type")
      .in(
        "programming_day_id",
        authorizedDayIds.length
          ? authorizedDayIds
          : ["00000000-0000-0000-0000-000000000000"],
      );
    assertSucceeded(blocks.error);
    const blockMap = new Map(
      (blocks.data ?? []).map((block) => [
        block.id,
        block.type as WorkoutBlockType,
      ]),
    );

    const prescribed = await this.client
      .from("prescribed_movements")
      .select("id, block_id, display_name, prescription_text")
      .in("block_id", [...blockMap.keys()]);
    assertSucceeded(prescribed.error);
    const prescribedMap = new Map(
      (prescribed.data ?? []).map((movement) => [movement.id, movement]),
    );

    const authorizedLogIds = authorizedLogs.map((log) => log.id);
    const results = await this.client
      .from("movement_results")
      .select(
        "id, workout_log_id, prescribed_movement_id, result_schema, weight_lb, completed_reps, duration_ms, measurement_value, measurement_unit, result_value, result_unit, completed_rounds, residual_reps",
      )
      .in("workout_log_id", authorizedLogIds);
    assertSucceeded(results.error);
    const resultIds = (results.data ?? []).map((result) => result.id);
    const records = resultIds.length
      ? await this.client
          .from("personal_records")
          .select("movement_result_id")
          .in("movement_result_id", resultIds)
      : { data: [], error: null };
    assertSucceeded(records.error);
    const recordResultIds = new Set(
      (records.data ?? []).map((record) => record.movement_result_id),
    );

    const workouts = authorizedLogs.map((log) => {
      const movements = (results.data ?? [])
        .filter((result) => result.workout_log_id === log.id)
        .flatMap<HistoryMovement>((result) => {
          const movement = prescribedMap.get(result.prescribed_movement_id);
          const blockType = movement
            ? blockMap.get(movement.block_id)
            : undefined;
          if (!movement || !blockType) return [];
          const base = {
            movementResultId: result.id,
            prescribedMovementId: result.prescribed_movement_id,
            name: movement.display_name,
            prescriptionText: movement.prescription_text,
            blockType,
            isPersonalRecord: recordResultIds.has(result.id),
          };
          if (result.result_schema === "weighted_fixed_reps") {
            return [
              {
                ...base,
                resultSchema: "weighted_fixed_reps",
                weightLb: Number(result.weight_lb),
              },
            ];
          }
          if (result.result_schema === "weighted_variable_reps") {
            return [
              {
                ...base,
                resultSchema: "weighted_variable_reps",
                weightLb: Number(result.weight_lb),
                completedReps: Number(result.completed_reps),
              },
            ];
          }
          if (result.result_schema === "max_repetitions") {
            return [
              {
                ...base,
                resultSchema: "max_repetitions",
                completedReps: Number(result.completed_reps),
              },
            ];
          }
          if (result.result_schema === "for_time") {
            return [
              {
                ...base,
                resultSchema: "for_time",
                durationMs: Number(result.duration_ms),
              },
            ];
          }
          if (result.result_schema === "height_or_distance") {
            if (
              !["in", "ft", "m", "yd", "mi"].includes(result.measurement_unit)
            ) {
              return [];
            }
            return [
              {
                ...base,
                resultSchema: "height_or_distance",
                measurementValue: Number(result.measurement_value),
                measurementUnit: result.measurement_unit as
                  | "in"
                  | "ft"
                  | "m"
                  | "yd"
                  | "mi",
              },
            ];
          }
          if (result.result_schema === "calories_or_distance") {
            if (
              !["cal", "m", "km", "ft", "yd", "mi"].includes(result.result_unit)
            ) {
              return [];
            }
            return [
              {
                ...base,
                resultSchema: "calories_or_distance",
                resultValue: Number(result.result_value),
                resultUnit: result.result_unit as
                  | "cal"
                  | "m"
                  | "km"
                  | "ft"
                  | "yd"
                  | "mi",
              },
            ];
          }
          if (result.result_schema === "rounds_and_reps") {
            return [
              {
                ...base,
                resultSchema: "rounds_and_reps",
                completedRounds: Number(result.completed_rounds),
                residualReps: Number(result.residual_reps),
              },
            ];
          }
          return [];
        });
      const day = log.programming_day_id
        ? dayMap.get(log.programming_day_id)
        : undefined;
      return {
        workoutLogId: log.id,
        programmingDayId: log.programming_day_id,
        workoutDate: log.workout_date,
        completedAt: log.completed_at,
        updatedAt: log.updated_at,
        title: day?.title ?? log.free_text_title ?? "Free-text workout",
        notes: log.notes,
        hasPersonalRecord: movements.some(
          (movement) => movement.isPersonalRecord,
        ),
        movements,
      };
    });
    return { workouts, nextCursor };
  }
}

function assertSucceeded(
  error: { message: string } | null,
): asserts error is null {
  if (error) {
    throw new HistoryDataError("Unable to load workout history.", {
      cause: error,
    });
  }
}
