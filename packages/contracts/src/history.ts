import { z } from "zod";
import { weightPoundsSchema } from "./workout-completion";
import {
  activityResultUnitSchema,
  activityResultValueSchema,
  completedRoundsSchema,
  durationMillisecondsSchema,
  measurementUnitSchema,
  measurementValueSchema,
  residualRepsSchema,
} from "./workout-completion";
import { trackCodeSchema, workoutBlockTypeSchema } from "./today";

const databaseIdentifierSchema = z
  .string()
  .regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);

const historyMovementBase = {
  movementResultId: databaseIdentifierSchema,
  prescribedMovementId: databaseIdentifierSchema,
  name: z.string().trim().min(1).max(200),
  prescriptionText: z.string().trim().min(1).max(2_000),
  blockType: workoutBlockTypeSchema,
  isPersonalRecord: z.boolean(),
} as const;

export const historyMovementSchema = z.discriminatedUnion("resultSchema", [
  z
    .object({
      ...historyMovementBase,
      resultSchema: z.literal("weighted_fixed_reps"),
      weightLb: weightPoundsSchema,
    })
    .strict(),
  z
    .object({
      ...historyMovementBase,
      resultSchema: z.literal("weighted_variable_reps"),
      weightLb: weightPoundsSchema,
      completedReps: z.number().int().positive().max(100_000),
    })
    .strict(),
  z
    .object({
      ...historyMovementBase,
      resultSchema: z.literal("max_repetitions"),
      completedReps: z.number().int().positive().max(100_000),
    })
    .strict(),
  z
    .object({
      ...historyMovementBase,
      resultSchema: z.literal("for_time"),
      durationMs: durationMillisecondsSchema,
    })
    .strict(),
  z
    .object({
      ...historyMovementBase,
      resultSchema: z.literal("height_or_distance"),
      measurementValue: measurementValueSchema,
      measurementUnit: measurementUnitSchema,
    })
    .strict(),
  z
    .object({
      ...historyMovementBase,
      resultSchema: z.literal("calories_or_distance"),
      resultValue: activityResultValueSchema,
      resultUnit: activityResultUnitSchema,
    })
    .strict(),
  z
    .object({
      ...historyMovementBase,
      resultSchema: z.literal("rounds_and_reps"),
      completedRounds: completedRoundsSchema,
      residualReps: residualRepsSchema,
    })
    .strict(),
]);

export const historyWorkoutSchema = z
  .object({
    workoutLogId: databaseIdentifierSchema,
    programmingDayId: databaseIdentifierSchema.nullable(),
    workoutDate: z.iso.date(),
    completedAt: z.iso.datetime({ offset: true }),
    updatedAt: z.iso.datetime({ offset: true }),
    title: z.string().trim().min(1).max(200),
    notes: z.string().max(5_000).nullable(),
    hasPersonalRecord: z.boolean(),
    movements: z.array(historyMovementSchema).max(100),
  })
  .strict();

export const historyResponseSchema = z
  .object({
    track: z
      .object({
        id: databaseIdentifierSchema,
        code: trackCodeSchema,
        name: z.string().trim().min(1).max(200),
      })
      .strict(),
    workouts: z.array(historyWorkoutSchema).max(100),
    nextCursor: databaseIdentifierSchema.nullable(),
  })
  .strict();

export const historyRequestSchema = z
  .object({
    trackCode: trackCodeSchema,
    workoutLogId: databaseIdentifierSchema.optional(),
    query: z.string().trim().min(1).max(100).optional(),
    fromDate: z.iso.date().optional(),
    personalRecordsOnly: z.boolean(),
    cursor: databaseIdentifierSchema.optional(),
  })
  .strict()
  .refine(
    (request) =>
      !request.workoutLogId ||
      (!request.query &&
        !request.fromDate &&
        !request.personalRecordsOnly &&
        !request.cursor),
    { message: "A workout lookup cannot be combined with list filters" },
  );

export type HistoryResponse = z.infer<typeof historyResponseSchema>;
export type HistoryWorkout = z.infer<typeof historyWorkoutSchema>;
export type HistoryMovement = z.infer<typeof historyMovementSchema>;
export type HistoryRequest = z.infer<typeof historyRequestSchema>;
