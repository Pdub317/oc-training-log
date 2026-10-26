import { describe, expect, it } from "vitest";
import type { ReminderSettingsRepository } from "../../../lib/reminders/service";
import { createReminderHandlers } from "./route";

function repository(): ReminderSettingsRepository {
  return {
    async get() {
      return { timeZone: "America/Los_Angeles", schedules: [] };
    },
    async replace(_userId, input) {
      return input;
    },
  };
}

describe("/api/reminders", () => {
  it("returns and replaces only the authenticated member schedule", async () => {
    const handlers = createReminderHandlers({
      async getContext() {
        return { userId: "member", repository: repository() };
      },
    });
    expect(
      await (
        await handlers.GET(new Request("http://localhost/api/reminders"))
      ).json(),
    ).toEqual({ timeZone: "America/Los_Angeles", schedules: [] });
    const response = await handlers.PUT(
      new Request("http://localhost/api/reminders", {
        method: "PUT",
        body: JSON.stringify({
          timeZone: "America/Los_Angeles",
          schedules: [{ weekday: 1, localTime: "18:30" }],
        }),
      }),
    );
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({
      schedules: [{ weekday: 1, localTime: "18:30" }],
    });
  });

  it("rejects invalid schedules before authentication", async () => {
    let checkedAuth = false;
    const handlers = createReminderHandlers({
      async getContext() {
        checkedAuth = true;
        return null;
      },
    });
    const response = await handlers.PUT(
      new Request("http://localhost/api/reminders", {
        method: "PUT",
        body: JSON.stringify({
          timeZone: "America/Los_Angeles",
          schedules: [{ weekday: 1, localTime: "30:00" }],
        }),
      }),
    );
    expect(response.status).toBe(400);
    expect(checkedAuth).toBe(false);
  });
});
