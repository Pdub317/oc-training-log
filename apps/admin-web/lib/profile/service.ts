import {
  memberProfileSchema,
  type MemberProfile,
  type UpdateMemberProfile,
} from "@oc-training-log/contracts";

export interface MemberProfileRepository {
  get(userId: string): Promise<unknown | null>;
  update(userId: string, input: UpdateMemberProfile): Promise<unknown | null>;
  leaveTrack(userId: string, trackId: string): Promise<boolean>;
}

export class MemberProfileDataError extends Error {}
export class TrackMembershipNotFoundError extends Error {}

export async function getMemberProfile(
  userId: string,
  repository: MemberProfileRepository,
): Promise<MemberProfile> {
  const value = await repository.get(userId);
  return parseProfile(value);
}

export async function updateMemberProfile(
  userId: string,
  input: UpdateMemberProfile,
  repository: MemberProfileRepository,
): Promise<MemberProfile> {
  if (!isValidTimeZone(input.timeZone)) {
    throw new MemberProfileDataError("The member time zone is invalid.");
  }
  const value = await repository.update(userId, input);
  return parseProfile(value);
}

export async function leaveMemberTrack(
  userId: string,
  trackId: string,
  repository: MemberProfileRepository,
): Promise<MemberProfile> {
  if (!(await repository.leaveTrack(userId, trackId))) {
    throw new TrackMembershipNotFoundError();
  }
  return getMemberProfile(userId, repository);
}

function parseProfile(value: unknown | null): MemberProfile {
  const parsed = memberProfileSchema.safeParse(value);
  if (!parsed.success) {
    throw new MemberProfileDataError("Invalid member profile.", {
      cause: parsed.error,
    });
  }
  return parsed.data;
}

function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone }).format();
    return true;
  } catch {
    return false;
  }
}
