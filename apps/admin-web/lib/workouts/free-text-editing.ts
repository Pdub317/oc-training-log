import {
  editFreeTextWorkoutResponseSchema,
  type EditFreeTextWorkoutRequest,
  type EditFreeTextWorkoutResponse,
} from "@oc-training-log/contracts";
import {
  InvalidWorkoutEditError,
  WorkoutEditConflictError,
  WorkoutEditDataError,
  WorkoutEditDeniedError,
} from "./editing";

export interface FreeTextWorkoutEditingRepository {
  edit(request: EditFreeTextWorkoutRequest): Promise<unknown>;
}

export async function editFreeTextWorkout(
  request: EditFreeTextWorkoutRequest,
  repository: FreeTextWorkoutEditingRepository,
): Promise<EditFreeTextWorkoutResponse> {
  const parsed = editFreeTextWorkoutResponseSchema.safeParse(
    await repository.edit(request),
  );
  if (!parsed.success) {
    throw new WorkoutEditDataError("Free-text edit response was invalid.", {
      cause: parsed.error,
    });
  }
  return parsed.data;
}

export {
  InvalidWorkoutEditError,
  WorkoutEditConflictError,
  WorkoutEditDataError,
  WorkoutEditDeniedError,
};
