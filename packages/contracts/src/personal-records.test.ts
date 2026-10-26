import { describe, expect, it } from "vitest";
import { personalRecordDetailResponseSchema } from "./personal-records";

describe("personal record contracts", () => {
  it("keeps variable-rep comparison dimensions explicit", () => {
    const response = {
      track: {
        id: "00000000-0000-0000-0000-000000000202",
        code: "GP",
        name: "GP",
      },
      benchmark: {
        benchmarkId: "10000000-0000-4000-8000-000000000001",
        label: "Deficit bench press",
        resultSchema: "weighted_variable_reps",
        comparisonDirection: "higher",
        currentBests: [
          {
            personalRecordId: "20000000-0000-4000-8000-000000000001",
            value: 185,
            unit: "lb",
            completedReps: 3,
            achievedAt: "2026-09-02T18:30:00.000Z",
          },
        ],
      },
      history: [
        {
          personalRecordId: "20000000-0000-4000-8000-000000000001",
          value: 185,
          unit: "lb",
          completedReps: 3,
          achievedAt: "2026-09-02T18:30:00.000Z",
          workoutLogId: "30000000-0000-4000-8000-000000000001",
          workoutDate: "2026-09-02",
          workoutTitle: "Max effort upper",
          isCurrentBest: true,
        },
      ],
    } as const;
    expect(personalRecordDetailResponseSchema.parse(response)).toEqual(
      response,
    );
  });
});
