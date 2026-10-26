import { describe, expect, it } from "vitest";
import type { MemberProfileRepository } from "../../../lib/profile/service";
import { createProfileHandlers } from "./route";

const profile = {
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

function repository(): MemberProfileRepository {
  return {
    async get() {
      return profile;
    },
    async update(_userId, input) {
      return { ...profile, member: { ...profile.member, ...input } };
    },
    async leaveTrack() {
      return true;
    },
  };
}

describe("/api/profile", () => {
  it("returns only the authenticated member profile", async () => {
    const handlers = createProfileHandlers({
      async getContext() {
        return { userId: profile.member.id, repository: repository() };
      },
    });
    const response = await handlers.GET(
      new Request("http://localhost/api/profile"),
    );
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual(profile);
    expect(response.headers.get("cache-control")).toBe("no-store");
  });

  it("updates trimmed names and a valid member time zone", async () => {
    const handlers = createProfileHandlers({
      async getContext() {
        return { userId: profile.member.id, repository: repository() };
      },
    });
    const response = await handlers.PATCH(
      new Request("http://localhost/api/profile", {
        method: "PATCH",
        body: JSON.stringify({
          firstName: " Jamie ",
          lastName: " Athlete ",
          timeZone: "America/New_York",
        }),
      }),
    );
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      member: {
        firstName: "Jamie",
        lastName: "Athlete",
        timeZone: "America/New_York",
      },
    });
  });

  it("rejects malformed data and requires authentication", async () => {
    const handlers = createProfileHandlers({
      async getContext() {
        return null;
      },
    });
    expect(
      (
        await handlers.PATCH(
          new Request("http://localhost/api/profile", {
            method: "PATCH",
            body: JSON.stringify({ firstName: "" }),
          }),
        )
      ).status,
    ).toBe(400);
    expect(
      (await handlers.GET(new Request("http://localhost/api/profile"))).status,
    ).toBe(401);
  });
});
