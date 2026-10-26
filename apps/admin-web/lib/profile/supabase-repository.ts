import type { UpdateMemberProfile } from "@oc-training-log/contracts";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  MemberProfileDataError,
  type MemberProfileRepository,
} from "./service";

type UserRow = {
  id: string;
  first_name: string;
  last_name: string;
  email: string;
  email_verified_at: string | null;
  time_zone: string | null;
};

export class SupabaseMemberProfileRepository
  implements MemberProfileRepository
{
  constructor(private readonly client: SupabaseClient) {}

  async get(userId: string): Promise<unknown | null> {
    const user = await this.client
      .from("users")
      .select("id, first_name, last_name, email, email_verified_at, time_zone")
      .eq("id", userId)
      .maybeSingle();
    assertSucceeded(user.error, "member account");
    if (!user.data) return null;

    const gymMemberships = await this.client
      .from("gym_memberships")
      .select("gym_id")
      .eq("user_id", userId)
      .eq("status", "active");
    assertSucceeded(gymMemberships.error, "gym memberships");
    const gymIds = (gymMemberships.data ?? []).map((row) => row.gym_id);
    const gyms = gymIds.length
      ? await this.client.from("gyms").select("id, name").in("id", gymIds)
      : { data: [], error: null };
    assertSucceeded(gyms.error, "gyms");
    const gymRows = gyms.data ?? [];
    const gymNames = new Map(gymRows.map((gym) => [gym.id, gym.name]));

    const memberships = await this.client
      .from("track_memberships")
      .select("track_id, joined_at")
      .eq("user_id", userId)
      .eq("status", "active");
    assertSucceeded(memberships.error, "track memberships");
    const membershipRows = memberships.data ?? [];
    const joinedAt = new Map(
      membershipRows.map((membership) => [
        membership.track_id,
        membership.joined_at,
      ]),
    );
    const trackIds = membershipRows.map((row) => row.track_id);
    const tracks = trackIds.length
      ? await this.client
          .from("training_tracks")
          .select("id, gym_id, code, name")
          .eq("status", "active")
          .in("id", trackIds)
          .order("name")
      : { data: [], error: null };
    assertSucceeded(tracks.error, "training tracks");

    return shapeProfile(
      user.data as UserRow,
      gymRows,
      (tracks.data ?? []).map((track) => ({
        ...track,
        gymName: gymNames.get(track.gym_id),
        joinedAt: joinedAt.get(track.id),
      })),
    );
  }

  async update(
    userId: string,
    input: UpdateMemberProfile,
  ): Promise<unknown | null> {
    const update = await this.client.rpc("update_member_profile", {
      p_first_name: input.firstName,
      p_last_name: input.lastName,
      p_time_zone: input.timeZone,
    });
    assertSucceeded(update.error, "member profile");
    return this.get(userId);
  }

  async leaveTrack(_userId: string, trackId: string): Promise<boolean> {
    const result = await this.client.rpc("leave_training_track", {
      target_track_id: trackId,
    });
    if (result.error?.message.includes("active_track_membership_required")) {
      return false;
    }
    assertSucceeded(result.error, "leave track");
    return Array.isArray(result.data) && result.data.length === 1;
  }
}

function shapeProfile(
  user: UserRow,
  gyms: { id: string; name: string }[],
  tracks: {
    id: string;
    gym_id: string;
    code: string;
    name: string;
    gymName: string | undefined;
    joinedAt: string | undefined;
  }[],
) {
  return {
    member: {
      id: user.id,
      firstName: user.first_name,
      lastName: user.last_name,
      email: user.email,
      emailVerified: user.email_verified_at !== null,
      timeZone: user.time_zone,
    },
    gyms: gyms.map((gym) => ({ id: gym.id, name: gym.name })),
    tracks: tracks.map((track) => ({
      id: track.id,
      gymId: track.gym_id,
      gymName: track.gymName,
      code: track.code,
      name: track.name,
      joinedAt: track.joinedAt,
    })),
  };
}

function assertSucceeded(
  error: { message: string } | null,
  operation: string,
): asserts error is null {
  if (error) {
    throw new MemberProfileDataError(`Unable to load ${operation}.`, {
      cause: error,
    });
  }
}
