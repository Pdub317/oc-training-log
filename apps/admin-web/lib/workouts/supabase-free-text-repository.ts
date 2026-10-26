import type { FreeTextWorkoutRequest } from "@oc-training-log/contracts";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  InvalidWorkoutCompletionError,
  WorkoutCompletionConflictError,
  WorkoutCompletionDataError,
  WorkoutCompletionDeniedError,
  type FreeTextWorkoutRepository,
} from "./free-text";

export class SupabaseFreeTextWorkoutRepository
  implements FreeTextWorkoutRepository
{
  constructor(private readonly client: SupabaseClient) {}

  async complete(request: FreeTextWorkoutRequest): Promise<unknown> {
    const { data, error } = await this.client.rpc(
      "complete_free_text_workout",
      {
        p_client_request_id: request.clientRequestId,
        p_track_code: request.trackCode,
        p_workout_date: request.workoutDate,
        p_title: request.title,
        p_notes: request.notes,
      },
    );
    if (!error && typeof data === "object" && data !== null) {
      return { ...data, personalRecords: [] };
    }
    if (error?.message.includes("workout_not_authorized")) {
      throw new WorkoutCompletionDeniedError();
    }
    if (
      error?.message.includes("completion_conflict") ||
      error?.message.includes("programming_available")
    ) {
      throw new WorkoutCompletionConflictError();
    }
    if (error?.message.includes("invalid_completion")) {
      throw new InvalidWorkoutCompletionError();
    }
    throw new WorkoutCompletionDataError("Unable to save free-text workout.", {
      cause: error,
    });
  }
}
