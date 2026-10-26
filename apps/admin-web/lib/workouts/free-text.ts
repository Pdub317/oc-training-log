import {
  freeTextWorkoutResponseSchema,
  type FreeTextWorkoutRequest,
  type FreeTextWorkoutResponse,
} from "@oc-training-log/contracts";
import {
  InvalidWorkoutCompletionError,
  WorkoutCompletionConflictError,
  WorkoutCompletionDataError,
  WorkoutCompletionDeniedError,
} from "./completion";

export interface FreeTextWorkoutRepository {
  complete(request: FreeTextWorkoutRequest): Promise<unknown>;
}

export async function completeFreeTextWorkout(
  request: FreeTextWorkoutRequest,
  repository: FreeTextWorkoutRepository,
): Promise<FreeTextWorkoutResponse> {
  const parsed = freeTextWorkoutResponseSchema.safeParse(
    await repository.complete(request),
  );
  if (!parsed.success) {
    throw new WorkoutCompletionDataError("Free-text completion was invalid.", {
      cause: parsed.error,
    });
  }
  return parsed.data;
}

export {
  InvalidWorkoutCompletionError,
  WorkoutCompletionConflictError,
  WorkoutCompletionDataError,
  WorkoutCompletionDeniedError,
};
