import { z } from "zod";

export const reminderWeekdaySchema = z.number().int().min(1).max(7);
export const reminderLocalTimeSchema = z
  .string()
  .regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/);

const reminderScheduleSchema = z
  .object({
    weekday: reminderWeekdaySchema,
    localTime: reminderLocalTimeSchema,
  })
  .strict();

export const reminderSettingsSchema = z
  .object({
    timeZone: z.string().trim().min(1).max(100),
    schedules: z.array(reminderScheduleSchema).max(7),
  })
  .strict()
  .superRefine((value, context) => {
    if (
      new Set(value.schedules.map(({ weekday }) => weekday)).size !==
      value.schedules.length
    ) {
      context.addIssue({
        code: "custom",
        message: "A weekday may appear only once.",
        path: ["schedules"],
      });
    }
  });

export const updateReminderSettingsSchema = reminderSettingsSchema;

export type ReminderSettings = z.infer<typeof reminderSettingsSchema>;
export type UpdateReminderSettings = z.infer<
  typeof updateReminderSettingsSchema
>;
