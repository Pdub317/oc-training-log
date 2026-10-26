import { describe, expect, it } from "vitest";
import { historyRequestSchema, historyResponseSchema } from "./history";

const response = {
  track: {
    id: "00000000-0000-0000-0000-000000000201",
    code: "SP",
    name: "Sports Performance",
  },
  workouts: [
    {
      workoutLogId: "10000000-0000-4000-8000-000000000001",
      programmingDayId: "00000000-0000-0000-0000-000000000813",
      workoutDate: "2026-07-25",
      completedAt: "2026-07-25T18:30:00.000Z",
      updatedAt: "2026-07-25T18:30:00.000Z",
      title: "SP Front Squat and Lower Body Strength",
      notes: "Strong day.",
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
} as const;

describe("History response contract", () => {
  it("accepts private workout summaries with PR indicators", () => {
    expect(historyResponseSchema.parse(response)).toEqual(response);
  });

  it("rejects unsupported tracks and private extra fields", () => {
    expect(
      historyResponseSchema.safeParse({
        ...response,
        track: { ...response.track, code: "OTHER" },
      }).success,
    ).toBe(false);
    expect(
      historyResponseSchema.safeParse({ ...response, userId: "private" })
        .success,
    ).toBe(false);
  });

  it("accepts an exact workout lookup only without list filters", () => {
    const lookup = {
      trackCode: "SP",
      workoutLogId: "10000000-0000-4000-8000-000000000001",
      personalRecordsOnly: false,
    } as const;
    expect(historyRequestSchema.safeParse(lookup).success).toBe(true);
    expect(
      historyRequestSchema.safeParse({ ...lookup, query: "squat" }).success,
    ).toBe(false);
  });

  it("accepts timed and measured History values", () => {
    const workout = response.workouts[0];
    expect(
      historyResponseSchema.parse({
        ...response,
        workouts: [
          {
            ...workout,
            movements: [
              {
                movementResultId: "20000000-0000-4000-8000-000000000002",
                prescribedMovementId: "00000000-0000-0000-0000-000000001074",
                name: "500 m row",
                prescriptionText: "For time",
                blockType: "wod",
                resultSchema: "for_time",
                durationMs: 101_500,
                isPersonalRecord: true,
              },
              {
                movementResultId: "20000000-0000-4000-8000-000000000003",
                prescribedMovementId: "00000000-0000-0000-0000-000000001075",
                name: "Standing Broad Jump",
                prescriptionText: "Record max distance",
                blockType: "jumps",
                resultSchema: "height_or_distance",
                measurementValue: 6.5,
                measurementUnit: "ft",
                isPersonalRecord: false,
              },
            ],
          },
        ],
      }).workouts[0]?.movements,
    ).toHaveLength(2);
  });

  it("accepts calories or distance and rounds plus reps in History", () => {
    const workout = response.workouts[0];
    const parsed = historyResponseSchema.parse({
      ...response,
      workouts: [
        {
          ...workout,
          movements: [
            {
              movementResultId: "20000000-0000-4000-8000-000000000004",
              prescribedMovementId: "00000000-0000-0000-0000-000000001076",
              name: "Row",
              prescriptionText: "Max distance",
              blockType: "wod",
              resultSchema: "calories_or_distance",
              resultValue: 1.25,
              resultUnit: "km",
              isPersonalRecord: true,
            },
            {
              movementResultId: "20000000-0000-4000-8000-000000000005",
              prescribedMovementId: "00000000-0000-0000-0000-000000001077",
              name: "AMRAP",
              prescriptionText: "As many rounds as possible",
              blockType: "wod",
              resultSchema: "rounds_and_reps",
              completedRounds: 7,
              residualReps: 12,
              isPersonalRecord: false,
            },
          ],
        },
      ],
    });
    expect(parsed.workouts[0]?.movements).toHaveLength(2);
  });
});
