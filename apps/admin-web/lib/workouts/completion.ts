import {
  completeWorkoutResponseSchema,
  type CompleteWorkoutRequest,
  type CompleteWorkoutResponse,
} from "@oc-training-log/contracts";

export interface WorkoutCompletionRepository {
  complete(request: CompleteWorkoutRequest): Promise<unknown>;
}

export class WorkoutCompletionDeniedError extends Error {}
export class InvalidWorkoutCompletionError extends Error {}
export class WorkoutCompletionConflictError extends Error {}
export class WorkoutCompletionDataError extends Error {}

export async function completeWorkout(
  request: CompleteWorkoutRequest,
  repository: WorkoutCompletionRepository,
): Promise<CompleteWorkoutResponse> {
  const response = await repository.complete(request);
  const parsed = completeWorkoutResponseSchema.safeParse(response);

  if (!parsed.success) {
    throw new WorkoutCompletionDataError(
      "Workout completion did not match the public contract.",
      { cause: parsed.error },
    );
  }

  return parsed.data;
}
