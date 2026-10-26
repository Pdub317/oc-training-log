import type { EditFreeTextWorkoutRequest } from "@oc-training-log/contracts";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  InvalidWorkoutEditError,
  WorkoutEditConflictError,
  WorkoutEditDataError,
  WorkoutEditDeniedError,
  type FreeTextWorkoutEditingRepository,
} from "./free-text-editing";

export class SupabaseFreeTextWorkoutEditingRepository
  implements FreeTextWorkoutEditingRepository
{
  constructor(private readonly client: SupabaseClient) {}

  async edit(request: EditFreeTextWorkoutRequest): Promise<unknown> {
    const { data, error } = await this.client.rpc("edit_free_text_workout", {
      p_workout_log_id: request.workoutLogId,
      p_expected_updated_at: request.expectedUpdatedAt,
      p_title: request.title,
      p_notes: request.notes,
    });
    if (!error) return data;
    if (error.message.includes("workout_edit_denied")) {
      throw new WorkoutEditDeniedError();
    }
    if (error.message.includes("workout_edit_conflict")) {
      throw new WorkoutEditConflictError();
    }
    if (error.message.includes("invalid_workout_edit")) {
      throw new InvalidWorkoutEditError();
    }
    throw new WorkoutEditDataError("Unable to edit free-text workout.", {
      cause: error,
    });
  }
}
