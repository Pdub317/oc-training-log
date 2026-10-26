import { describe, expect, it } from "vitest";
import {
  leaveTrackSchema,
  memberProfileSchema,
  updateMemberProfileSchema,
} from "./member-profile";

const profile = {
  member: {
    id: "00000000-0000-4000-8000-000000000003",
    firstName: "Jamie",
    lastName: "Member",
    email: "jamie@example.com",
    emailVerified: true,
    timeZone: "America/Los_Angeles",
  },
  gyms: [
    {
      id: "00000000-0000-4000-8000-000000000100",
      name: "OC Gym Bend",
    },
  ],
  tracks: [
    {
      id: "00000000-0000-4000-8000-000000000202",
      gymId: "00000000-0000-4000-8000-000000000100",
      gymName: "OC Gym Bend",
      code: "GP",
      name: "General Population",
      joinedAt: "2026-09-03T20:00:00.000Z",
    },
  ],
} as const;

describe("member profile contracts", () => {
  it("accepts a private account and active membership summary", () => {
    expect(memberProfileSchema.parse(profile)).toEqual(profile);
  });

  it("normalizes editable names and requires a time zone", () => {
    expect(
      updateMemberProfileSchema.parse({
        firstName: " Jamie ",
        lastName: " Member ",
        timeZone: "America/Los_Angeles",
      }),
    ).toEqual({
      firstName: "Jamie",
      lastName: "Member",
      timeZone: "America/Los_Angeles",
    });
  });

  it("requires an explicit destructive-action confirmation", () => {
    expect(
      leaveTrackSchema.safeParse({
        trackId: profile.tracks[0].id,
        confirmation: "leave_track",
      }).success,
    ).toBe(true);
    expect(
      leaveTrackSchema.safeParse({
        trackId: profile.tracks[0].id,
        confirmation: "yes",
      }).success,
    ).toBe(false);
  });
});
