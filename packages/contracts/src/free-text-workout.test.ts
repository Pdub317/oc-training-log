import { describe, expect, it } from "vitest";
import {
  editFreeTextWorkoutRequestSchema,
  freeTextWorkoutRequestSchema,
} from "./free-text-workout";

describe("free-text workout contract", () => {
  it("accepts a titled workout with meaningful details", () => {
    const parsed = freeTextWorkoutRequestSchema.parse({
      clientRequestId: "10000000-0000-4000-8000-000000000001",
      trackCode: "GP",
      workoutDate: "2026-10-01",
      title: " Trail run ",
      notes: "  Ran easy for 30 minutes.\n",
    });
    expect(parsed.title).toBe("Trail run");
    expect(parsed.notes).toBe("  Ran easy for 30 minutes.\n");
  });

  it("rejects an empty workout description", () => {
    expect(
      freeTextWorkoutRequestSchema.safeParse({
        clientRequestId: "10000000-0000-4000-8000-000000000001",
        trackCode: "GP",
        workoutDate: "2026-10-01",
        title: "Trail run",
        notes: "   ",
      }).success,
    ).toBe(false);
  });

  it("validates free-text edits while preserving exact details", () => {
    const parsed = editFreeTextWorkoutRequestSchema.parse({
      workoutLogId: "20000000-0000-4000-8000-000000000001",
      expectedUpdatedAt: "2026-09-02T18:30:00.000Z",
      title: " Updated trail run ",
      notes: "  Exact updated details\n",
    });
    expect(parsed.title).toBe("Updated trail run");
    expect(parsed.notes).toBe("  Exact updated details\n");
  });
});
