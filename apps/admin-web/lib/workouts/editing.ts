import {
  editWorkoutResponseSchema,
  type EditWorkoutRequest,
  type EditWorkoutResponse,
} from "@oc-training-log/contracts";

export interface WorkoutEditingRepository {
  edit(request: EditWorkoutRequest): Promise<unknown>;
}

export class WorkoutEditDeniedError extends Error {}
export class InvalidWorkoutEditError extends Error {}
export class WorkoutEditConflictError extends Error {}
export class WorkoutEditDataError extends Error {}

export async function editWorkout(
  request: EditWorkoutRequest,
  repository: WorkoutEditingRepository,
): Promise<EditWorkoutResponse> {
  const parsed = editWorkoutResponseSchema.safeParse(
    await repository.edit(request),
  );
  if (!parsed.success) {
    throw new WorkoutEditDataError("Workout edit response was invalid.", {
      cause: parsed.error,
    });
  }
  return parsed.data;
}
