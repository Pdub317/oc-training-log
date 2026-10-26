import { describe, expect, it } from "vitest";
import { reminderSettingsSchema } from "./reminders";

describe("reminder settings contract", () => {
  it("accepts distinct ISO weekdays with separate local times", () => {
    expect(
      reminderSettingsSchema.safeParse({
        timeZone: "America/Los_Angeles",
        schedules: [
          { weekday: 1, localTime: "18:15" },
          { weekday: 3, localTime: "19:30" },
        ],
      }).success,
    ).toBe(true);
  });

  it("rejects duplicate weekdays and malformed times", () => {
    expect(
      reminderSettingsSchema.safeParse({
        timeZone: "America/Los_Angeles",
        schedules: [
          { weekday: 1, localTime: "18:15" },
          { weekday: 1, localTime: "18:45" },
        ],
      }).success,
    ).toBe(false);
    expect(
      reminderSettingsSchema.safeParse({
        timeZone: "America/Los_Angeles",
        schedules: [{ weekday: 7, localTime: "25:00" }],
      }).success,
    ).toBe(false);
  });
});
