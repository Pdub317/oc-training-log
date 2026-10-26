import { describe, expect, it } from "vitest";
import type { FreeTextWorkoutRepository } from "../../../../lib/workouts/free-text";
import { WorkoutCompletionConflictError } from "../../../../lib/workouts/free-text";
import { createFreeTextWorkoutHandler } from "./route";

const body = {
  clientRequestId: "10000000-0000-4000-8000-000000000001",
  trackCode: "GP",
  workoutDate: "2026-09-02",
  title: "Trail run",
  notes: "Ran easy for 30 minutes.",
} as const;

describe("POST /api/workouts/free-text", () => {
  it("validates and returns the completed workout", async () => {
    let received: unknown;
    const repository: FreeTextWorkoutRepository = {
      async complete(request) {
        received = request;
        return {
          state: "completed",
          workoutLogId: "20000000-0000-4000-8000-000000000001",
          completedAt: "2026-09-02T18:30:00.000Z",
          replayed: false,
          results: [],
          personalRecords: [],
        };
      },
    };
    const response = await createFreeTextWorkoutHandler({
      async getRepository() {
        return repository;
      },
    })(request(body));

    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({
      state: "completed",
      results: [],
    });
    expect(received).toEqual(body);
  });

  it("rejects empty details before authentication", async () => {
    let repositoryRequested = false;
    const response = await createFreeTextWorkoutHandler({
      async getRepository() {
        repositoryRequested = true;
        return null;
      },
    })(request({ ...body, notes: "   " }));

    expect(response.status).toBe(400);
    expect(repositoryRequested).toBe(false);
  });

  it("requires authentication and maps same-day conflicts", async () => {
    const unauthorized = await createFreeTextWorkoutHandler({
      async getRepository() {
        return null;
      },
    })(request(body));
    expect(unauthorized.status).toBe(401);

    const conflict = await createFreeTextWorkoutHandler({
      async getRepository() {
        return {
          async complete() {
            throw new WorkoutCompletionConflictError();
          },
        };
      },
    })(request(body));
    expect(conflict.status).toBe(409);
    await expect(conflict.json()).resolves.toEqual({
      error: "completion_conflict",
    });
  });
});

function request(value: unknown): Request {
  return new Request("http://localhost/api/workouts/free-text", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(value),
  });
}
