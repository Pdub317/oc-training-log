import { z } from "zod";

export const trackCodeSchema = z.enum(["SP", "GP"]);
export const workoutDateSchema = z.iso.date();

export const todayTrackSchema = z
  .object({
    id: z.guid(),
    code: trackCodeSchema,
    name: z.string().trim().min(1).max(200),
  })
  .strict();

export const workoutBlockTypeSchema = z.enum([
  "warm_up",
  "jumps",
  "strength",
  "accessory",
  "wod",
  "finisher",
  "recovery",
  "other",
]);

export const resultSchemaTypeSchema = z.enum([
  "weighted_fixed_reps",
  "weighted_variable_reps",
  "height_or_distance",
  "for_time",
  "max_repetitions",
  "calories_or_distance",
  "rounds_and_reps",
  "notes_only",
]);

export const todayMovementSchema = z
  .object({
    id: z.guid(),
    movementId: z.guid().nullable(),
    name: z.string().trim().min(1).max(200),
    prescriptionText: z.string().trim().min(1).max(2_000),
    coachNotes: z.string().trim().min(1).max(2_000).nullable(),
    substitutions: z.array(z.string().trim().min(1).max(500)).max(20),
    optionGroupKey: z.string().trim().min(1).max(100).nullable().optional(),
    optionGroupLabel: z.string().trim().min(1).max(200).nullable().optional(),
    resultSchema: resultSchemaTypeSchema,
    displayOrder: z.number().int().nonnegative(),
  })
  .strict();

export const todayWorkoutBlockSchema = z
  .object({
    id: z.guid(),
    type: workoutBlockTypeSchema,
    title: z.string().trim().min(1).max(200),
    instructions: z.string().trim().min(1).max(5_000).nullable(),
    displayOrder: z.number().int().nonnegative(),
    movements: z.array(todayMovementSchema).max(100),
  })
  .strict()
  .superRefine((block, context) => {
    addOrderingIssues(block.movements, context, "movements");

    if (block.type === "warm_up" || block.type === "recovery") {
      block.movements.forEach((movement, index) => {
        if (movement.resultSchema !== "notes_only") {
          context.addIssue({
            code: "custom",
            message: `${block.type} movements must be read-only`,
            path: ["movements", index, "resultSchema"],
          });
        }
      });
    }
  });

const todayResponseBase = {
  workoutDate: workoutDateSchema,
  timeZone: z.string().trim().min(1).max(100),
  track: todayTrackSchema,
  isCompleted: z.boolean(),
} as const;

export const publishedTodayResponseSchema = z
  .object({
    ...todayResponseBase,
    state: z.literal("published"),
    programmingDay: z
      .object({
        id: z.guid(),
        title: z.string().trim().min(1).max(200),
        coachNotes: z.string().trim().min(1).max(5_000).nullable(),
        blocks: z.array(todayWorkoutBlockSchema).max(50),
      })
      .strict(),
  })
  .strict()
  .superRefine((response, context) => {
    addOrderingIssues(response.programmingDay.blocks, context, [
      "programmingDay",
      "blocks",
    ]);
  });

export const noProgrammingTodayResponseSchema = z
  .object({
    ...todayResponseBase,
    state: z.literal("no_programming"),
    canCreateFreeText: z.literal(true),
  })
  .strict();

export const closedTodayResponseSchema = z
  .object({
    ...todayResponseBase,
    state: z.literal("closed"),
    isCompleted: z.literal(false),
    programmingDay: z
      .object({
        id: z.guid(),
        title: z.string().trim().min(1).max(200),
        coachNotes: z.string().trim().min(1).max(5_000).nullable(),
      })
      .strict(),
  })
  .strict();

export const todayResponseSchema = z.discriminatedUnion("state", [
  publishedTodayResponseSchema,
  closedTodayResponseSchema,
  noProgrammingTodayResponseSchema,
]);

export type TrackCode = z.infer<typeof trackCodeSchema>;
export type WorkoutBlockType = z.infer<typeof workoutBlockTypeSchema>;
export type ResultSchemaType = z.infer<typeof resultSchemaTypeSchema>;
export type TodayMovement = z.infer<typeof todayMovementSchema>;
export type TodayWorkoutBlock = z.infer<typeof todayWorkoutBlockSchema>;
export type PublishedTodayResponse = z.infer<
  typeof publishedTodayResponseSchema
>;
export type NoProgrammingTodayResponse = z.infer<
  typeof noProgrammingTodayResponseSchema
>;
export type ClosedTodayResponse = z.infer<typeof closedTodayResponseSchema>;
export type TodayResponse = z.infer<typeof todayResponseSchema>;

type OrderedItem = { displayOrder: number };

function addOrderingIssues(
  items: readonly OrderedItem[],
  context: z.RefinementCtx,
  path: string | (string | number)[],
) {
  const basePath = Array.isArray(path) ? path : [path];

  items.forEach((item, index) => {
    if (index > 0 && item.displayOrder <= items[index - 1]!.displayOrder) {
      context.addIssue({
        code: "custom",
        message: "displayOrder values must be strictly increasing",
        path: [...basePath, index, "displayOrder"],
      });
    }
  });
}
