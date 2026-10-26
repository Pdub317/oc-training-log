import { describe, expect, it } from "vitest";
import {
  completeWorkoutRequestSchema,
  completeWorkoutResponseSchema,
} from "./workout-completion";

const request = {
  clientRequestId: "10000000-0000-4000-8000-000000000001",
  trackCode: "GP",
  programmingDayId: "00000000-0000-0000-0000-000000000822",
  workoutDate: "2026-09-02",
  notes: "Felt steady.",
  results: [
    {
      resultSchema: "weighted_fixed_reps",
      prescribedMovementId: "00000000-0000-0000-0000-000000001312",
      weightLb: 53.5,
    },
  ],
} as const;

describe("workout completion contracts", () => {
  it("accepts positive weights and database identifiers", () => {
    expect(completeWorkoutRequestSchema.parse(request)).toEqual(request);
  });

  it("accepts fractional weights without rounding", () => {
    expect(
      completeWorkoutRequestSchema.safeParse({
        ...request,
        results: [{ ...request.results[0], weightLb: 53.25 }],
      }).success,
    ).toBe(true);
  });

  it("rejects duplicate movement results and private extra fields", () => {
    expect(
      completeWorkoutRequestSchema.safeParse({
        ...request,
        results: [request.results[0], request.results[0]],
      }).success,
    ).toBe(false);
    expect(
      completeWorkoutRequestSchema.safeParse({ ...request, userId: "member" })
        .success,
    ).toBe(false);
  });

  it("accepts variable-weight and max-repetition results without coercion", () => {
    expect(
      completeWorkoutRequestSchema.parse({
        ...request,
        results: [
          {
            resultSchema: "weighted_variable_reps",
            prescribedMovementId: "00000000-0000-0000-0000-000000001313",
            weightLb: 225.5,
            completedReps: 7,
          },
          {
            resultSchema: "max_repetitions",
            prescribedMovementId: "00000000-0000-0000-0000-000000001314",
            completedReps: 42,
          },
        ],
      }).results,
    ).toHaveLength(2);
  });

  it("rejects missing reps and result fields from the wrong schema", () => {
    expect(
      completeWorkoutRequestSchema.safeParse({
        ...request,
        results: [
          {
            resultSchema: "weighted_variable_reps",
            prescribedMovementId: "00000000-0000-0000-0000-000000001313",
            weightLb: 225.5,
          },
        ],
      }).success,
    ).toBe(false);
    expect(
      completeWorkoutRequestSchema.safeParse({
        ...request,
        results: [
          {
            resultSchema: "max_repetitions",
            prescribedMovementId: "00000000-0000-0000-0000-000000001314",
            completedReps: 42,
            weightLb: 10,
          },
        ],
      }).success,
    ).toBe(false);
  });

  it("accepts normalized duration and explicit measurement units", () => {
    expect(
      completeWorkoutRequestSchema.parse({
        ...request,
        results: [
          {
            resultSchema: "for_time",
            prescribedMovementId: "00000000-0000-0000-0000-000000001315",
            durationMs: 201_500,
          },
          {
            resultSchema: "height_or_distance",
            prescribedMovementId: "00000000-0000-0000-0000-000000001316",
            measurementValue: 24.25,
            measurementUnit: "in",
          },
        ],
      }).results,
    ).toHaveLength(2);
  });

  it("rejects fractional milliseconds and unsupported measurement units", () => {
    expect(
      completeWorkoutRequestSchema.safeParse({
        ...request,
        results: [
          {
            resultSchema: "for_time",
            prescribedMovementId: "00000000-0000-0000-0000-000000001315",
            durationMs: 201_500.5,
          },
        ],
      }).success,
    ).toBe(false);
    expect(
      completeWorkoutRequestSchema.safeParse({
        ...request,
        results: [
          {
            resultSchema: "height_or_distance",
            prescribedMovementId: "00000000-0000-0000-0000-000000001316",
            measurementValue: 24.25,
            measurementUnit: "cm",
          },
        ],
      }).success,
    ).toBe(false);
  });

  it("accepts calories, distance, rounds plus reps, and notes-only completion", () => {
    const parsed = completeWorkoutRequestSchema.parse({
      ...request,
      results: [
        {
          resultSchema: "calories_or_distance",
          prescribedMovementId: "00000000-0000-0000-0000-000000001317",
          resultValue: 1.25,
          resultUnit: "km",
        },
        {
          resultSchema: "rounds_and_reps",
          prescribedMovementId: "00000000-0000-0000-0000-000000001318",
          completedRounds: 7,
          residualReps: 12,
        },
      ],
    });
    expect(parsed.results).toHaveLength(2);
    expect(
      completeWorkoutRequestSchema.parse({ ...request, results: [] }).results,
    ).toEqual([]);
  });

  it("rejects unsupported activity units and an empty rounds-plus-reps score", () => {
    expect(
      completeWorkoutRequestSchema.safeParse({
        ...request,
        results: [
          {
            resultSchema: "calories_or_distance",
            prescribedMovementId: "00000000-0000-0000-0000-000000001317",
            resultValue: 10,
            resultUnit: "watts",
          },
        ],
      }).success,
    ).toBe(false);
    expect(
      completeWorkoutRequestSchema.safeParse({
        ...request,
        results: [
          {
            resultSchema: "rounds_and_reps",
            prescribedMovementId: "00000000-0000-0000-0000-000000001318",
            completedRounds: 0,
            residualReps: 0,
          },
        ],
      }).success,
    ).toBe(false);
  });

  it("validates the completed response", () => {
    expect(
      completeWorkoutResponseSchema.parse({
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
        personalRecords: [
          {
            personalRecordId: "40000000-0000-4000-8000-000000000001",
            benchmarkId: "50000000-0000-4000-8000-000000000001",
            benchmarkLabel: "5-rep front squat to 12-inch box + foam",
            movementResultId: "30000000-0000-4000-8000-000000000001",
            value: 315,
            unit: "lb",
            achievedAt: "2026-09-02T18:30:00.000Z",
          },
        ],
      }).state,
    ).toBe("completed");
  });

  it("validates remaining saved results and canonical PR units", () => {
    const parsed = completeWorkoutResponseSchema.parse({
      state: "completed",
      workoutLogId: "20000000-0000-4000-8000-000000000001",
      completedAt: "2026-09-02T18:30:00.000Z",
      replayed: false,
      results: [
        {
          resultSchema: "calories_or_distance",
          movementResultId: "30000000-0000-4000-8000-000000000002",
          prescribedMovementId: "00000000-0000-0000-0000-000000001317",
          resultValue: 1.25,
          resultUnit: "km",
        },
        {
          resultSchema: "rounds_and_reps",
          movementResultId: "30000000-0000-4000-8000-000000000003",
          prescribedMovementId: "00000000-0000-0000-0000-000000001318",
          completedRounds: 7,
          residualReps: 12,
        },
      ],
      personalRecords: [
        {
          personalRecordId: "40000000-0000-4000-8000-000000000002",
          benchmarkId: "50000000-0000-4000-8000-000000000002",
          benchmarkLabel: "Distance",
          movementResultId: "30000000-0000-4000-8000-000000000002",
          value: 1250,
          unit: "m",
          achievedAt: "2026-09-02T18:30:00.000Z",
        },
      ],
    });
    expect(parsed.results).toHaveLength(2);
    expect(parsed.personalRecords[0]?.unit).toBe("m");
  });
});
