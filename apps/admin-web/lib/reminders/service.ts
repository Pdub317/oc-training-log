import {
  reminderSettingsSchema,
  type ReminderSettings,
  type UpdateReminderSettings,
} from "@oc-training-log/contracts";

export interface ReminderSettingsRepository {
  get(userId: string): Promise<unknown | null>;
  replace(
    userId: string,
    input: UpdateReminderSettings,
  ): Promise<unknown | null>;
}

export class ReminderSettingsDataError extends Error {}

export async function getReminderSettings(
  userId: string,
  repository: ReminderSettingsRepository,
): Promise<ReminderSettings> {
  return parse(await repository.get(userId));
}

export async function updateReminderSettings(
  userId: string,
  input: UpdateReminderSettings,
  repository: ReminderSettingsRepository,
): Promise<ReminderSettings> {
  if (!isValidTimeZone(input.timeZone)) {
    throw new ReminderSettingsDataError("Invalid reminder time zone.");
  }
  return parse(await repository.replace(userId, input));
}

function parse(value: unknown | null): ReminderSettings {
  const parsed = reminderSettingsSchema.safeParse(value);
  if (!parsed.success) {
    throw new ReminderSettingsDataError("Invalid reminder settings.", {
      cause: parsed.error,
    });
  }
  return parsed.data;
}

function isValidTimeZone(timeZone: string): boolean {
  try {
    new Intl.DateTimeFormat("en-US", { timeZone }).format();
    return true;
  } catch {
    return false;
  }
}
