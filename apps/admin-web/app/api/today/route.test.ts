import { describe, expect, it } from "vitest";
import type { TodayRepository } from "../../../lib/today/service";
import { TodayDataError } from "../../../lib/today/service";
import { createTodayHandler, extractBearerToken } from "./route";

const authorizedTrack = {
  id: "00000000-0000-0000-0000-000000000201",
  code: "SP" as const,
  name: "Sports Performance",
  memberTimeZone: "America/Los_Angeles",
  gymTimeZone: "America/Los_Angeles",
};

describe("GET /api/today", () => {
  it("accepts the iOS Bearer-token header format without accepting malformed values", () => {
    expect(extractBearerToken("Bearer member.jwt.token")).toBe(
      "member.jwt.token",
    );
    expect(extractBearerToken("bearer member.jwt.token")).toBe(
      "member.jwt.token",
    );
    expect(extractBearerToken("Basic credentials")).toBeNull();
    expect(extractBearerToken("Bearer token with spaces")).toBeNull();
  });

  it("requires a valid supported track", async () => {
    let contextRequested = false;
    const handler = createTodayHandler({
      async getRequestContext() {
        contextRequested = true;
        return null;
      },
    });

    const response = await handler(request("UNASSIGNED"));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: "invalid_track" });
    expect(contextRequested).toBe(false);
  });

  it("rejects anonymous requests", async () => {
    const handler = createTodayHandler({
      async getRequestContext() {
        return null;
      },
    });

    const response = await handler(request("SP"));

    expect(response.status).toBe(401);
    await expect(response.json()).resolves.toEqual({ error: "unauthorized" });
    expect(response.headers.get("Cache-Control")).toBe("no-store");
  });

  it("rejects malformed requested dates before authentication", async () => {
    let contextRequested = false;
    const handler = createTodayHandler({
      async getRequestContext() {
        contextRequested = true;
        return null;
      },
    });

    const response = await handler(request("SP", "September-8"));

    expect(response.status).toBe(400);
    await expect(response.json()).resolves.toEqual({ error: "invalid_date" });
    expect(contextRequested).toBe(false);
  });

  it("denies members who do not have the requested track", async () => {
    const handler = createTodayHandler({
      async getRequestContext() {
        return { userId: "member-1", repository: repository(null) };
      },
    });

    const response = await handler(request("GP"));

    expect(response.status).toBe(403);
    await expect(response.json()).resolves.toEqual({
      error: "track_access_denied",
    });
  });

  it("returns a contract-validated no-programming response", async () => {
    const handler = createTodayHandler({
      async getRequestContext() {
        return {
          userId: "member-1",
          repository: repository(authorizedTrack),
        };
      },
      clock: { now: () => new Date("2026-07-26T18:00:00.000Z") },
    });

    const response = await handler(request("SP"));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      state: "no_programming",
      workoutDate: "2026-07-26",
      track: { code: "SP" },
      canCreateFreeText: true,
      isCompleted: false,
    });
  });

  it("returns an authorized explicitly requested date", async () => {
    const repo = repository(authorizedTrack);
    let loadedDate: string | undefined;
    repo.findPublishedProgramming = async (_trackId, workoutDate) => {
      loadedDate = workoutDate;
      return null;
    };
    const handler = createTodayHandler({
      async getRequestContext() {
        return { userId: "member-1", repository: repo };
      },
    });

    const response = await handler(request("SP", "2026-07-14"));

    expect(response.status).toBe(200);
    expect(loadedDate).toBe("2026-07-14");
  });

  it("does not expose repository errors or private details", async () => {
    const failingRepository = repository(authorizedTrack);
    failingRepository.findPublishedProgramming = async () => {
      throw new TodayDataError("database detail: private-row-id");
    };
    const handler = createTodayHandler({
      async getRequestContext() {
        return { userId: "member-1", repository: failingRepository };
      },
    });

    const response = await handler(request("SP"));

    expect(response.status).toBe(500);
    expect(JSON.stringify(await response.json())).not.toContain(
      "private-row-id",
    );
  });

  it("does not expose authentication-provider failures", async () => {
    const handler = createTodayHandler({
      async getRequestContext() {
        throw new Error("provider detail: private-token");
      },
    });

    const response = await handler(request("SP"));

    expect(response.status).toBe(500);
    await expect(response.json()).resolves.toEqual({
      error: "today_unavailable",
    });
  });
});

function request(track: string, date?: string): Request {
  const suffix = date ? `&date=${date}` : "";
  return new Request(`http://localhost/api/today?track=${track}${suffix}`);
}

function repository(track: typeof authorizedTrack | null): TodayRepository {
  return {
    async findActiveTrack() {
      return track;
    },
    async findPublishedProgramming() {
      return null;
    },
    async hasCompletedWorkout() {
      return false;
    },
  };
}
