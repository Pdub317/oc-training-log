import { z } from "zod";
import { trackCodeSchema } from "./today";

const databaseUuidSchema = z
  .string()
  .regex(
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i,
    "Invalid identifier",
  );

export const weightPoundsSchema = z.number().finite().positive().max(100_000);

export const completedRepsSchema = z.number().int().positive().max(100_000);
export const durationMillisecondsSchema = z
  .number()
  .int()
  .positive()
  .max(359_999_999);
export const measurementValueSchema = z
  .number()
  .finite()
  .positive()
  .max(1_000_000);
export const measurementUnitSchema = z.enum(["in", "ft", "m", "yd", "mi"]);
export const activityResultUnitSchema = z.enum([
  "cal",
  "m",
  "km",
  "ft",
  "yd",
  "mi",
]);
export const activityResultValueSchema = z
  .number()
  .finite()
  .positive()
  .max(1_000_000);
export const completedRoundsSchema = z
  .number()
  .int()
  .nonnegative()
  .max(100_000);
export const residualRepsSchema = z.number().int().nonnegative().max(99_999);

export const workoutResultSchema = z.discriminatedUnion("resultSchema", [
  z
    .object({
      resultSchema: z.literal("weighted_fixed_reps"),
      prescribedMovementId: databaseUuidSchema,
      weightLb: weightPoundsSchema,
    })
    .strict(),
  z
    .object({
      resultSchema: z.literal("weighted_variable_reps"),
      prescribedMovementId: databaseUuidSchema,
      weightLb: weightPoundsSchema,
      completedReps: completedRepsSchema,
    })
    .strict(),
  z
    .object({
      resultSchema: z.literal("max_repetitions"),
      prescribedMovementId: databaseUuidSchema,
      completedReps: completedRepsSchema,
    })
    .strict(),
  z
    .object({
      resultSchema: z.literal("for_time"),
      prescribedMovementId: databaseUuidSchema,
      durationMs: durationMillisecondsSchema,
    })
    .strict(),
  z
    .object({
      resultSchema: z.literal("height_or_distance"),
      prescribedMovementId: databaseUuidSchema,
      measurementValue: measurementValueSchema,
      measurementUnit: measurementUnitSchema,
    })
    .strict(),
  z
    .object({
      resultSchema: z.literal("calories_or_distance"),
      prescribedMovementId: databaseUuidSchema,
      resultValue: activityResultValueSchema,
      resultUnit: activityResultUnitSchema,
    })
    .strict(),
  z
    .object({
      resultSchema: z.literal("rounds_and_reps"),
      prescribedMovementId: databaseUuidSchema,
      completedRounds: completedRoundsSchema,
      residualReps: residualRepsSchema,
    })
    .strict()
    .refine((result) => result.completedRounds > 0 || result.residualReps > 0, {
      message: "Rounds and reps cannot both be zero",
    }),
]);

export const completeWorkoutRequestSchema = z
  .object({
    clientRequestId: databaseUuidSchema,
    trackCode: trackCodeSchema,
    programmingDayId: databaseUuidSchema,
    workoutDate: z.iso.date(),
    notes: z.string().max(5_000).nullable(),
    results: z.array(workoutResultSchema).max(100),
  })
  .strict()
  .superRefine((request, context) => {
    const seen = new Set<string>();
    request.results.forEach((result, index) => {
      if (seen.has(result.prescribedMovementId)) {
        context.addIssue({
          code: "custom",
          message: "Each prescribed movement may be submitted only once",
          path: ["results", index, "prescribedMovementId"],
        });
      }
      seen.add(result.prescribedMovementId);
    });
  });

export const completeWorkoutResponseSchema = z
  .object({
    state: z.literal("completed"),
    workoutLogId: databaseUuidSchema,
    completedAt: z.iso.datetime({ offset: true }),
    replayed: z.boolean(),
    results: z.array(
      z.discriminatedUnion("resultSchema", [
        z
          .object({
            resultSchema: z.literal("weighted_fixed_reps"),
            movementResultId: databaseUuidSchema,
            prescribedMovementId: databaseUuidSchema,
            weightLb: weightPoundsSchema,
          })
          .strict(),
        z
          .object({
            resultSchema: z.literal("calories_or_distance"),
            movementResultId: databaseUuidSchema,
            prescribedMovementId: databaseUuidSchema,
            resultValue: activityResultValueSchema,
            resultUnit: activityResultUnitSchema,
          })
          .strict(),
        z
          .object({
            resultSchema: z.literal("rounds_and_reps"),
            movementResultId: databaseUuidSchema,
            prescribedMovementId: databaseUuidSchema,
            completedRounds: completedRoundsSchema,
            residualReps: residualRepsSchema,
          })
          .strict(),
        z
          .object({
            resultSchema: z.literal("weighted_variable_reps"),
            movementResultId: databaseUuidSchema,
            prescribedMovementId: databaseUuidSchema,
            weightLb: weightPoundsSchema,
            completedReps: completedRepsSchema,
          })
          .strict(),
        z
          .object({
            resultSchema: z.literal("max_repetitions"),
            movementResultId: databaseUuidSchema,
            prescribedMovementId: databaseUuidSchema,
            completedReps: completedRepsSchema,
          })
          .strict(),
        z
          .object({
            resultSchema: z.literal("for_time"),
            movementResultId: databaseUuidSchema,
            prescribedMovementId: databaseUuidSchema,
            durationMs: durationMillisecondsSchema,
          })
          .strict(),
        z
          .object({
            resultSchema: z.literal("height_or_distance"),
            movementResultId: databaseUuidSchema,
            prescribedMovementId: databaseUuidSchema,
            measurementValue: measurementValueSchema,
            measurementUnit: measurementUnitSchema,
          })
          .strict(),
      ]),
    ),
    personalRecords: z.array(
      z.discriminatedUnion("unit", [
        z
          .object({
            personalRecordId: databaseUuidSchema,
            benchmarkId: databaseUuidSchema,
            benchmarkLabel: z.string().trim().min(1).max(200),
            movementResultId: databaseUuidSchema,
            value: weightPoundsSchema,
            unit: z.literal("lb"),
            achievedAt: z.iso.datetime({ offset: true }),
          })
          .strict(),
        z
          .object({
            personalRecordId: databaseUuidSchema,
            benchmarkId: databaseUuidSchema,
            benchmarkLabel: z.string().trim().min(1).max(200),
            movementResultId: databaseUuidSchema,
            value: durationMillisecondsSchema,
            unit: z.literal("ms"),
            achievedAt: z.iso.datetime({ offset: true }),
          })
          .strict(),
        z
          .object({
            personalRecordId: databaseUuidSchema,
            benchmarkId: databaseUuidSchema,
            benchmarkLabel: z.string().trim().min(1).max(200),
            movementResultId: databaseUuidSchema,
            value: measurementValueSchema,
            unit: z.literal("in"),
            achievedAt: z.iso.datetime({ offset: true }),
          })
          .strict(),
        z
          .object({
            personalRecordId: databaseUuidSchema,
            benchmarkId: databaseUuidSchema,
            benchmarkLabel: z.string().trim().min(1).max(200),
            movementResultId: databaseUuidSchema,
            value: completedRepsSchema,
            unit: z.literal("reps"),
            achievedAt: z.iso.datetime({ offset: true }),
          })
          .strict(),
        z
          .object({
            personalRecordId: databaseUuidSchema,
            benchmarkId: databaseUuidSchema,
            benchmarkLabel: z.string().trim().min(1).max(200),
            movementResultId: databaseUuidSchema,
            value: z.number().finite().positive().max(10_000_099_999),
            unit: z.enum(["cal", "m", "rounds_reps"]),
            achievedAt: z.iso.datetime({ offset: true }),
          })
          .strict(),
      ]),
    ),
  })
  .strict();

export type CompleteWorkoutRequest = z.infer<
  typeof completeWorkoutRequestSchema
>;
export type CompleteWorkoutResponse = z.infer<
  typeof completeWorkoutResponseSchema
>;
