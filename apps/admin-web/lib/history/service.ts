import {
  historyResponseSchema,
  type HistoryResponse,
  type HistoryRequest,
  type HistoryWorkout,
  type TrackCode,
} from "@oc-training-log/contracts";

export type HistoryTrack = { id: string; code: TrackCode; name: string };

export interface HistoryRepository {
  findActiveTrack(
    userId: string,
    trackCode: TrackCode,
  ): Promise<HistoryTrack | null>;
  findCompletedWorkouts(
    userId: string,
    trackId: string,
    request: Omit<HistoryRequest, "trackCode">,
  ): Promise<{ workouts: HistoryWorkout[]; nextCursor: string | null }>;
}

export class HistoryAccessDeniedError extends Error {}
export class HistoryDataError extends Error {}

export async function getHistory(
  input: { userId: string } & HistoryRequest,
  repository: HistoryRepository,
): Promise<HistoryResponse> {
  const track = await repository.findActiveTrack(input.userId, input.trackCode);
  if (!track) throw new HistoryAccessDeniedError();

  const page = await repository.findCompletedWorkouts(input.userId, track.id, {
    workoutLogId: input.workoutLogId,
    query: input.query,
    fromDate: input.fromDate,
    personalRecordsOnly: input.personalRecordsOnly,
    cursor: input.cursor,
  });
  const response = {
    track,
    workouts: page.workouts,
    nextCursor: page.nextCursor,
  };
  const parsed = historyResponseSchema.safeParse(response);
  if (!parsed.success) {
    throw new HistoryDataError("History did not match the public contract.", {
      cause: parsed.error,
    });
  }
  return parsed.data;
}
