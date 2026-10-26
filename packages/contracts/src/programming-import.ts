import { z } from "zod";
import { trackCodeSchema, workoutBlockTypeSchema } from "./today";

export const programmingResultSchemaType = z.enum([
  "weighted_fixed_reps",
  "weighted_variable_reps",
  "height_or_distance",
  "for_time",
  "max_repetitions",
  "calories_or_distance",
  "rounds_and_reps",
  "notes_only",
]);

const confidenceSchema = z.enum(["high", "medium", "low"]);
const safeText = (maximum: number) => z.string().trim().min(1).max(maximum);

export const importedMovementDraftSchema = z
  .object({
    id: z.string().min(1).max(100),
    displayName: safeText(200),
    prescriptionText: safeText(2000),
    coachNotes: z.string().max(2000),
    optionGroupKey: z.string().trim().min(1).max(100).nullable().optional(),
    optionGroupLabel: z.string().trim().min(1).max(200).nullable().optional(),
    resultSchema: programmingResultSchemaType,
    confidence: confidenceSchema,
    requiresReview: z.boolean(),
    warnings: z.array(z.string().max(500)).max(20),
  })
  .strict()
  .superRefine((movement, context) => {
    if (
      (movement.optionGroupKey == null) !==
      (movement.optionGroupLabel == null)
    ) {
      context.addIssue({
        code: "custom",
        message: "Option group key and label must be supplied together",
        path: ["optionGroupKey"],
      });
    }
    if (movement.optionGroupKey && movement.resultSchema === "notes_only") {
      context.addIssue({
        code: "custom",
        message: "Selectable options must have a scored result format",
        path: ["resultSchema"],
      });
    }
  });

export const importedBlockDraftSchema = z
  .object({
    id: z.string().min(1).max(100),
    type: workoutBlockTypeSchema,
    title: safeText(200),
    instructions: z.string().max(5000),
    confidence: confidenceSchema,
    warnings: z.array(z.string().max(500)).max(20),
    movements: z.array(importedMovementDraftSchema).min(1).max(100),
  })
  .strict();

export const importedDayDraftSchema = z
  .object({
    id: z.string().min(1).max(100),
    workoutDate: z.iso.date(),
    title: safeText(200),
    coachNotes: z.string().max(5000),
    isClosed: z.boolean().optional(),
    sourceExcerpt: z.string().max(100_000),
    confidence: confidenceSchema,
    warnings: z.array(z.string().max(500)).max(50),
    blocks: z.array(importedBlockDraftSchema).max(30),
  })
  .strict()
  .superRefine((day, context) => {
    if (day.isClosed && day.blocks.length > 0) {
      context.addIssue({
        code: "custom",
        message: "Closed days cannot contain workout blocks",
        path: ["blocks"],
      });
    }
    if (!day.isClosed && day.blocks.length === 0) {
      context.addIssue({
        code: "custom",
        message: "Workout days require at least one block",
        path: ["blocks"],
      });
    }
  });

export const programmingImportDraftSchema = z
  .object({
    trackCode: trackCodeSchema,
    sourceText: z.string().min(1).max(1_000_000),
    days: z.array(importedDayDraftSchema).min(1).max(62),
    warnings: z.array(z.string().max(500)).max(100),
  })
  .strict();

export const publishProgrammingImportRequestSchema = z
  .object({ draft: programmingImportDraftSchema })
  .strict();

export type ProgrammingImportDraft = z.infer<
  typeof programmingImportDraftSchema
>;
export type ImportedDayDraft = z.infer<typeof importedDayDraftSchema>;
export type ImportedBlockDraft = z.infer<typeof importedBlockDraftSchema>;
export type ImportedMovementDraft = z.infer<typeof importedMovementDraftSchema>;
export type ProgrammingResultSchemaType = z.infer<
  typeof programmingResultSchemaType
>;
