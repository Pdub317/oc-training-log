import { z } from "zod";
import { workoutResultSchema } from "./workout-completion";

const databaseUuidSchema = z.string().uuid();

export const editWorkoutRequestSchema = z
  .object({
    workoutLogId: databaseUuidSchema,
    expectedUpdatedAt: z.iso.datetime({ offset: true }),
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

export const editWorkoutResponseSchema = z
  .object({
    state: z.literal("updated"),
    workoutLogId: databaseUuidSchema,
    updatedAt: z.iso.datetime({ offset: true }),
  })
  .strict();

export type EditWorkoutRequest = z.infer<typeof editWorkoutRequestSchema>;
export type EditWorkoutResponse = z.infer<typeof editWorkoutResponseSchema>;
