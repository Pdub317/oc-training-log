import { z } from "zod";
import { completeWorkoutResponseSchema } from "./workout-completion";
import { editWorkoutResponseSchema } from "./workout-edit";
import { trackCodeSchema } from "./today";

export const freeTextWorkoutRequestSchema = z
  .object({
    clientRequestId: z.string().uuid(),
    trackCode: trackCodeSchema,
    workoutDate: z.iso.date(),
    title: z.string().trim().min(1).max(200),
    notes: z
      .string()
      .max(5_000)
      .refine((value) => value.trim().length > 0),
  })
  .strict();

export const freeTextWorkoutResponseSchema = completeWorkoutResponseSchema;

export const editFreeTextWorkoutRequestSchema = z
  .object({
    workoutLogId: z.string().uuid(),
    expectedUpdatedAt: z.iso.datetime({ offset: true }),
    title: z.string().trim().min(1).max(200),
    notes: z
      .string()
      .max(5_000)
      .refine((value) => value.trim().length > 0),
  })
  .strict();

export const editFreeTextWorkoutResponseSchema = editWorkoutResponseSchema;

export type FreeTextWorkoutRequest = z.infer<
  typeof freeTextWorkoutRequestSchema
>;
export type FreeTextWorkoutResponse = z.infer<
  typeof freeTextWorkoutResponseSchema
>;
export type EditFreeTextWorkoutRequest = z.infer<
  typeof editFreeTextWorkoutRequestSchema
>;
export type EditFreeTextWorkoutResponse = z.infer<
  typeof editFreeTextWorkoutResponseSchema
>;
