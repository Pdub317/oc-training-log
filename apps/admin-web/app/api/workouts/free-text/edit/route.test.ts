import { describe, expect, it } from "vitest";
import {
  WorkoutEditConflictError,
  type FreeTextWorkoutEditingRepository,
} from "../../../../../lib/workouts/free-text-editing";
import { createEditFreeTextWorkoutHandler } from "./route";

const body = {
  workoutLogId: "20000000-0000-4000-8000-000000000001",
  expectedUpdatedAt: "2026-09-02T18:30:00.000Z",
  title: "Updated trail run",
  notes: "Ran easy for 35 minutes.",
};

describe("PATCH /api/workouts/free-text/edit", () => {
  it("validates and returns an optimistic free-text edit", async () => {
    let received: unknown;
    const repository: FreeTextWorkoutEditingRepository = {
      async edit(request) {
        received = request;
        return {
          state: "updated",
          workoutLogId: request.workoutLogId,
          updatedAt: "2026-09-02T18:31:00.000Z",
        };
      },
    };
    const response = await createEditFreeTextWorkoutHandler({
      async getRepository() {
        return repository;
      },
    })(request(body));
    expect(response.status).toBe(200);
    expect(received).toEqual(body);
  });

  it("rejects empty details before authentication and maps stale versions", async () => {
    let repositoryRequested = false;
    const invalid = await createEditFreeTextWorkoutHandler({
      async getRepository() {
        repositoryRequested = true;
        return null;
      },
    })(request({ ...body, notes: "   " }));
    expect(invalid.status).toBe(400);
    expect(repositoryRequested).toBe(false);

    const conflict = await createEditFreeTextWorkoutHandler({
      async getRepository() {
        return {
          async edit() {
            throw new WorkoutEditConflictError();
          },
        };
      },
    })(request(body));
    expect(conflict.status).toBe(409);
  });
});

function request(value: unknown): Request {
  return new Request("http://localhost/api/workouts/free-text/edit", {
    method: "PATCH",
    body: JSON.stringify(value),
  });
}
