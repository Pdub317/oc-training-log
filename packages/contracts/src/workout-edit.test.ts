import { describe, expect, it } from "vitest";
import {
  editWorkoutRequestSchema,
  editWorkoutResponseSchema,
} from "./workout-edit";

describe("workout edit contracts", () => {
  it("accepts an exact-version schema-specific edit", () => {
    const parsed = editWorkoutRequestSchema.parse({
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
    });
    expect(parsed.results).toHaveLength(1);
  });

  it("rejects duplicate movements and validates the response version", () => {
    const result = {
      resultSchema: "max_repetitions" as const,
      prescribedMovementId: "00000000-0000-0000-0000-000000001312",
      completedReps: 10,
    };
    expect(
      editWorkoutRequestSchema.safeParse({
        workoutLogId: "10000000-0000-4000-8000-000000000001",
        expectedUpdatedAt: "2026-09-02T18:30:00.000Z",
        notes: null,
        results: [result, result],
      }).success,
    ).toBe(false);
    expect(
      editWorkoutResponseSchema.parse({
        state: "updated",
        workoutLogId: "10000000-0000-4000-8000-000000000001",
        updatedAt: "2026-09-02T18:31:00.000Z",
      }).state,
    ).toBe("updated");
  });
});
