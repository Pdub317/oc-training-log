import { describe, expect, it } from "vitest";
import type { MemberProfileRepository } from "../../../../../lib/profile/service";
import { createLeaveTrackHandler } from "./route";

const trackId = "00000000-0000-4000-8000-000000000202";

function repository(active = true): MemberProfileRepository {
  return {
    async get() {
      return {
        member: {
          id: "00000000-0000-4000-8000-000000000003",
          firstName: "Jamie",
          lastName: "Member",
          email: "jamie@example.com",
          emailVerified: true,
          timeZone: "America/Los_Angeles",
        },
        gyms: [],
        tracks: [],
      };
    },
    async update() {
      return null;
    },
    async leaveTrack() {
      return active;
    },
  };
}

describe("POST /api/profile/tracks/leave", () => {
  it("requires explicit confirmation and returns the refreshed profile", async () => {
    const handler = createLeaveTrackHandler({
      async getContext() {
        return { userId: "member", repository: repository() };
      },
    });
    const response = await handler(
      new Request("http://localhost/api/profile/tracks/leave", {
        method: "POST",
        body: JSON.stringify({ trackId, confirmation: "leave_track" }),
      }),
    );
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ tracks: [] });
    expect(
      (
        await handler(
          new Request("http://localhost/api/profile/tracks/leave", {
            method: "POST",
            body: JSON.stringify({ trackId, confirmation: "yes" }),
          }),
        )
      ).status,
    ).toBe(400);
  });

  it("does not disclose another or already-left membership", async () => {
    const handler = createLeaveTrackHandler({
      async getContext() {
        return { userId: "member", repository: repository(false) };
      },
    });
    const response = await handler(
      new Request("http://localhost/api/profile/tracks/leave", {
        method: "POST",
        body: JSON.stringify({ trackId, confirmation: "leave_track" }),
      }),
    );
    expect(response.status).toBe(409);
    await expect(response.json()).resolves.toEqual({
      error: "track_membership_inactive",
    });
  });
});
