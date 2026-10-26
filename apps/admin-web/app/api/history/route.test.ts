import { describe, expect, it } from "vitest";
import {
  HistoryDataError,
  type HistoryRepository,
} from "../../../lib/history/service";
import { createHistoryHandler } from "./route";

const track = {
  id: "00000000-0000-0000-0000-000000000201",
  code: "SP" as const,
  name: "Sports Performance",
};

describe("GET /api/history", () => {
  it("validates the track before authentication", async () => {
    let requested = false;
    const handler = createHistoryHandler({
      async getRequestContext() {
        requested = true;
        return null;
      },
    });
    const response = await handler(request("OTHER"));
    expect(response.status).toBe(400);
    expect(requested).toBe(false);
  });

  it("requires authentication", async () => {
    const handler = createHistoryHandler({
      async getRequestContext() {
        return null;
      },
    });
    const response = await handler(request("SP"));
    expect(response.status).toBe(401);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
  });

  it("denies a member without the requested track", async () => {
    const handler = createHistoryHandler({
      async getRequestContext() {
        return { userId: "member", repository: repository(null) };
      },
    });
    const response = await handler(request("GP"));
    expect(response.status).toBe(403);
  });

  it("returns contract-validated workout history", async () => {
    const history = repository(track);
    history.findCompletedWorkouts = async () => ({
      workouts: [
        {
          workoutLogId: "10000000-0000-4000-8000-000000000001",
          programmingDayId: "00000000-0000-0000-0000-000000000813",
          workoutDate: "2026-07-25",
          completedAt: "2026-07-25T18:30:00.000Z",
          updatedAt: "2026-07-25T18:30:00.000Z",
          title: "SP Front Squat and Lower Body Strength",
          notes: null,
          hasPersonalRecord: true,
          movements: [
            {
              movementResultId: "20000000-0000-4000-8000-000000000001",
              prescribedMovementId: "00000000-0000-0000-0000-000000001073",
              name: "Front Squat",
              prescriptionText: "5-rep front squat to 12-inch box plus foam",
              blockType: "strength",
              resultSchema: "weighted_fixed_reps",
              weightLb: 315,
              isPersonalRecord: true,
            },
          ],
        },
      ],
      nextCursor: null,
    });
    const handler = createHistoryHandler({
      async getRequestContext() {
        return { userId: "member", repository: history };
      },
    });
    const response = await handler(request("SP"));
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      track: { code: "SP" },
      workouts: [{ hasPersonalRecord: true }],
    });
  });

  it("returns a free-text workout without synthetic movements", async () => {
    const history = repository(track);
    history.findCompletedWorkouts = async () => ({
      workouts: [
        {
          workoutLogId: "10000000-0000-4000-8000-000000000002",
          programmingDayId: null,
          workoutDate: "2026-09-02",
          completedAt: "2026-09-02T18:30:00.000Z",
          updatedAt: "2026-09-02T18:30:00.000Z",
          title: "Trail run",
          notes: "  Ran easy for 30 minutes.\n",
          hasPersonalRecord: false,
          movements: [],
        },
      ],
      nextCursor: null,
    });
    const response = await createHistoryHandler({
      async getRequestContext() {
        return { userId: "member", repository: history };
      },
    })(request("SP"));

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      workouts: [
        {
          programmingDayId: null,
          title: "Trail run",
          notes: "  Ran easy for 30 minutes.\n",
          movements: [],
        },
      ],
    });
  });

  it("forwards validated search, date, PR, and cursor filters", async () => {
    const history = repository(track);
    let received: unknown;
    history.findCompletedWorkouts = async (_userId, _trackId, filters) => {
      received = filters;
      return { workouts: [], nextCursor: null };
    };
    const handler = createHistoryHandler({
      async getRequestContext() {
        return { userId: "member", repository: history };
      },
    });
    const response = await handler(
      new Request(
        "http://localhost/api/history?track=SP&query=deadlift&from=2026-08-01&pr=true&cursor=10000000-0000-4000-8000-000000000001",
      ),
    );

    expect(response.status).toBe(200);
    expect(received).toEqual({
      workoutLogId: undefined,
      query: "deadlift",
      fromDate: "2026-08-01",
      personalRecordsOnly: true,
      cursor: "10000000-0000-4000-8000-000000000001",
    });
  });

  it("forwards an exact source-workout lookup without list filters", async () => {
    const history = repository(track);
    let received: unknown;
    history.findCompletedWorkouts = async (_userId, _trackId, filters) => {
      received = filters;
      return { workouts: [], nextCursor: null };
    };
    const response = await createHistoryHandler({
      async getRequestContext() {
        return { userId: "member", repository: history };
      },
    })(
      new Request(
        "http://localhost/api/history?track=SP&workout=10000000-0000-4000-8000-000000000001",
      ),
    );

    expect(response.status).toBe(200);
    expect(received).toEqual({
      workoutLogId: "10000000-0000-4000-8000-000000000001",
      query: undefined,
      fromDate: undefined,
      personalRecordsOnly: false,
      cursor: undefined,
    });
  });

  it("rejects combining an exact workout lookup with list filters", async () => {
    const response = await createHistoryHandler({
      async getRequestContext() {
        return { userId: "member", repository: repository(track) };
      },
    })(
      new Request(
        "http://localhost/api/history?track=SP&workout=10000000-0000-4000-8000-000000000001&query=squat",
      ),
    );
    expect(response.status).toBe(400);
  });

  it("does not expose private repository failures", async () => {
    const history = repository(track);
    history.findCompletedWorkouts = async () => {
      throw new HistoryDataError("private row detail");
    };
    const handler = createHistoryHandler({
      async getRequestContext() {
        return { userId: "member", repository: history };
      },
    });
    const response = await handler(request("SP"));
    expect(response.status).toBe(500);
    expect(JSON.stringify(await response.json())).not.toContain("private");
  });
});

function request(code: string): Request {
  return new Request(`http://localhost/api/history?track=${code}`);
}

function repository(authorizedTrack: typeof track | null): HistoryRepository {
  return {
    async findActiveTrack() {
      return authorizedTrack;
    },
    async findCompletedWorkouts() {
      return { workouts: [], nextCursor: null };
    },
  };
}
