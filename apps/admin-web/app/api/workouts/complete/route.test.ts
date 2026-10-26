import { describe, expect, it } from "vitest";
import {
  InvalidWorkoutCompletionError,
  WorkoutCompletionConflictError,
  WorkoutCompletionDeniedError,
  type WorkoutCompletionRepository,
} from "../../../../lib/workouts/completion";
import { createCompleteWorkoutHandler } from "./route";

const validBody = {
  clientRequestId: "10000000-0000-4000-8000-000000000001",
  trackCode: "GP",
  programmingDayId: "00000000-0000-0000-0000-000000000822",
  workoutDate: "2026-09-02",
  notes: null,
  results: [
    {
      resultSchema: "weighted_fixed_reps",
      prescribedMovementId: "00000000-0000-0000-0000-000000001312",
      weightLb: 53.5,
    },
  ],
} as const;

const validResponse = {
  state: "completed",
  workoutLogId: "20000000-0000-4000-8000-000000000001",
  completedAt: "2026-09-02T18:30:00.000Z",
  replayed: false,
  results: [
    {
      resultSchema: "weighted_fixed_reps",
      movementResultId: "30000000-0000-4000-8000-000000000001",
      prescribedMovementId: "00000000-0000-0000-0000-000000001312",
      weightLb: 53.5,
    },
  ],
  personalRecords: [],
} as const;

describe("POST /api/workouts/complete", () => {
  it("rejects invalid entries before authentication or database work", async () => {
    let contextRequested = false;
    const handler = createCompleteWorkoutHandler({
      async getRequestContext() {
        contextRequested = true;
        return null;
      },
    });

    const response = await handler(
      request({
        ...validBody,
        results: [{ ...validBody.results[0], weightLb: 0 }],
      }),
    );

    expect(response.status).toBe(400);
    expect(contextRequested).toBe(false);
  });

  it("requires authentication", async () => {
    const handler = createCompleteWorkoutHandler({
      async getRequestContext() {
        return null;
      },
    });
    const response = await handler(request(validBody));
    expect(response.status).toBe(401);
    expect(response.headers.get("Cache-Control")).toBe("no-store");
  });

  it("returns a contract-validated completion", async () => {
    let received: unknown;
    const handler = createCompleteWorkoutHandler({
      async getRequestContext() {
        return {
          repository: {
            async complete(input) {
              received = input;
              return validResponse;
            },
          },
        };
      },
    });
    const response = await handler(request(validBody));
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual(validResponse);
    expect(received).toEqual(validBody);
  });

  it.each([
    [new WorkoutCompletionDeniedError(), 403, "workout_access_denied"],
    [new InvalidWorkoutCompletionError(), 400, "invalid_completion"],
    [new WorkoutCompletionConflictError(), 409, "completion_conflict"],
  ])("maps a safe domain error", async (error, status, code) => {
    const handler = createCompleteWorkoutHandler({
      async getRequestContext() {
        return { repository: failingRepository(error) };
      },
    });
    const response = await handler(request(validBody));
    expect(response.status).toBe(status);
    await expect(response.json()).resolves.toEqual({ error: code });
  });

  it("does not expose unexpected database details", async () => {
    const handler = createCompleteWorkoutHandler({
      async getRequestContext() {
        return {
          repository: failingRepository(
            new Error("private database row and token"),
          ),
        };
      },
    });
    const response = await handler(request(validBody));
    expect(response.status).toBe(500);
    expect(JSON.stringify(await response.json())).not.toContain("private");
  });
});

function request(body: unknown): Request {
  return new Request("http://localhost/api/workouts/complete", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
}

function failingRepository(error: Error): WorkoutCompletionRepository {
  return {
    async complete() {
      throw error;
    },
  };
}
