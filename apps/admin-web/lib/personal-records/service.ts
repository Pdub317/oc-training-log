import {
  personalRecordDetailResponseSchema,
  personalRecordListResponseSchema,
  type PersonalRecordDetailResponse,
  type PersonalRecordListResponse,
  type TrackCode,
} from "@oc-training-log/contracts";

export interface PersonalRecordsRepository {
  list(userId: string, trackCode: TrackCode): Promise<unknown | null>;
  detail(
    userId: string,
    trackCode: TrackCode,
    benchmarkId: string,
  ): Promise<unknown | null>;
}

export class PersonalRecordsAccessDeniedError extends Error {}
export class PersonalRecordsDataError extends Error {}

export async function listPersonalRecords(
  input: { userId: string; trackCode: TrackCode },
  repository: PersonalRecordsRepository,
): Promise<PersonalRecordListResponse> {
  const value = await repository.list(input.userId, input.trackCode);
  if (!value) throw new PersonalRecordsAccessDeniedError();
  const parsed = personalRecordListResponseSchema.safeParse(value);
  if (!parsed.success)
    throw new PersonalRecordsDataError("Invalid PR list.", {
      cause: parsed.error,
    });
  return parsed.data;
}

export async function getPersonalRecordDetail(
  input: { userId: string; trackCode: TrackCode; benchmarkId: string },
  repository: PersonalRecordsRepository,
): Promise<PersonalRecordDetailResponse> {
  const value = await repository.detail(
    input.userId,
    input.trackCode,
    input.benchmarkId,
  );
  if (!value) throw new PersonalRecordsAccessDeniedError();
  const parsed = personalRecordDetailResponseSchema.safeParse(value);
  if (!parsed.success)
    throw new PersonalRecordsDataError("Invalid PR detail.", {
      cause: parsed.error,
    });
  return parsed.data;
}
