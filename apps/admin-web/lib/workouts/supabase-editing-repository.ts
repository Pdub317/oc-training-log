import type { EditWorkoutRequest } from "@oc-training-log/contracts";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  InvalidWorkoutEditError,
  WorkoutEditConflictError,
  WorkoutEditDataError,
  WorkoutEditDeniedError,
  type WorkoutEditingRepository,
} from "./editing";

export class SupabaseWorkoutEditingRepository
  implements WorkoutEditingRepository
{
  constructor(private readonly client: SupabaseClient) {}

  async edit(request: EditWorkoutRequest): Promise<unknown> {
    const { data, error } = await this.client.rpc("edit_workout", {
      p_workout_log_id: request.workoutLogId,
      p_expected_updated_at: request.expectedUpdatedAt,
      p_notes: request.notes,
      p_results: request.results,
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
    throw new WorkoutEditDataError("Unable to edit workout.", { cause: error });
  }
}
