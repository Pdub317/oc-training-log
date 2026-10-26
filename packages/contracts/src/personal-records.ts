import { z } from "zod";
import { trackCodeSchema } from "./today";

const idSchema = z
  .string()
  .regex(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i);
const scoreSchema = z
  .object({
    personalRecordId: idSchema,
    value: z.number().positive(),
    unit: z.enum(["lb", "reps", "ms", "in", "cal", "m", "rounds_reps"]),
    completedReps: z.number().int().positive().max(100_000).nullable(),
    achievedAt: z.iso.datetime({ offset: true }),
  })
  .strict();

const benchmarkSchema = z
  .object({
    benchmarkId: idSchema,
    label: z.string().trim().min(1).max(200),
    resultSchema: z.enum([
      "weighted_fixed_reps",
      "weighted_variable_reps",
      "max_repetitions",
      "for_time",
      "height_or_distance",
      "calories_or_distance",
      "rounds_and_reps",
    ]),
    comparisonDirection: z.enum(["higher", "lower"]),
    currentBests: z.array(scoreSchema).max(100),
  })
  .strict();

const trackSchema = z
  .object({
    id: idSchema,
    code: trackCodeSchema,
    name: z.string().min(1).max(200),
  })
  .strict();

export const personalRecordListResponseSchema = z
  .object({ track: trackSchema, benchmarks: z.array(benchmarkSchema).max(500) })
  .strict();

export const personalRecordDetailResponseSchema = z
  .object({
    track: trackSchema,
    benchmark: benchmarkSchema,
    history: z
      .array(
        scoreSchema.extend({
          workoutLogId: idSchema,
          workoutDate: z.iso.date(),
          workoutTitle: z.string().trim().min(1).max(200),
          isCurrentBest: z.boolean(),
        }),
      )
      .max(500),
  })
  .strict();

export type PersonalRecordListResponse = z.infer<
  typeof personalRecordListResponseSchema
>;
export type PersonalRecordDetailResponse = z.infer<
  typeof personalRecordDetailResponseSchema
>;
