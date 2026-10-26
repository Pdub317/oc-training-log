import { describe, expect, it } from "vitest";
import type { WorkoutEditingRepository } from "../../../../lib/workouts/editing";
import { WorkoutEditConflictError } from "../../../../lib/workouts/editing";
import { createEditWorkoutHandler } from "./route";

const body = {
  workoutLogId: "10000000-0000-4000-8000-000000000001",
  expectedUpdatedAt: "2026-09-02T18:30:00.000Z",
  notes: "Corrected",
  results: [
    {
      resultSchema: "weighted_fixed_reps",
      prescribedMovementId: "00000000-0000-0000-0000-000000001312",
      weightLb: 90.5,
    },
  ],
};

describe("PATCH /api/workouts/edit", () => {
  it("validates and returns the updated version", async () => {
    const repository: WorkoutEditingRepository = {
      async edit(request) {
        return {
          state: "updated",
          workoutLogId: request.workoutLogId,
          updatedAt: "2026-09-02T18:31:00.000Z",
        };
      },
    };
    const response = await createEditWorkoutHandler({
      async getRepository() {
        return repository;
      },
    })(
      new Request("http://localhost/api/workouts/edit", {
        method: "PATCH",
        body: JSON.stringify(body),
      }),
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toMatchObject({ state: "updated" });
  });

  it("rejects invalid input and maps stale versions", async () => {
    const invalid = await createEditWorkoutHandler({
      async getRepository() {
        return null;
      },
    })(
      new Request("http://localhost/api/workouts/edit", {
        method: "PATCH",
        body: JSON.stringify({
          ...body,
          results: [{ ...body.results[0], weightLb: 0 }],
        }),
      }),
    );
    expect(invalid.status).toBe(400);

    const conflict = await createEditWorkoutHandler({
      async getRepository() {
        return {
          async edit() {
            throw new WorkoutEditConflictError();
          },
        };
      },
    })(
      new Request("http://localhost/api/workouts/edit", {
        method: "PATCH",
        body: JSON.stringify(body),
      }),
    );
    expect(conflict.status).toBe(409);
  });
});
