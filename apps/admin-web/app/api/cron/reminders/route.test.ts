import { describe, expect, it } from "vitest";
import { createReminderCronHandler } from "./route";

describe("reminder cron", () => {
  it("rejects missing and incorrect secrets without running", async () => {
    let runs = 0;
    const handler = createReminderCronHandler({
      secret: () => "correct-secret-value",
      now: () => new Date(),
      async run() {
        runs += 1;
        return {};
      },
    });
    expect(
      (await handler(new Request("http://localhost/api/cron/reminders")))
        .status,
    ).toBe(401);
    expect(
      (
        await handler(
          new Request("http://localhost/api/cron/reminders", {
            headers: { Authorization: "Bearer incorrect-secret" },
          }),
        )
      ).status,
    ).toBe(401);
    expect(runs).toBe(0);
  });

  it("returns only aggregate preparation and delivery counts", async () => {
    const handler = createReminderCronHandler({
      secret: () => "correct-secret-value",
      now: () => new Date("2026-09-08T01:00:00.000Z"),
      async run(now) {
        expect(now.toISOString()).toBe("2026-09-08T01:00:00.000Z");
        return {
          claimed: 2,
          pendingDelivery: 1,
          suppressedLogged: 1,
          attempted: 1,
          sent: 1,
          retryScheduled: 0,
          invalidDevices: 0,
          terminalFailures: 0,
          deliveryEnabled: true,
        };
      },
    });
    const response = await handler(
      new Request("http://localhost/api/cron/reminders", {
        headers: { Authorization: "Bearer correct-secret-value" },
      }),
    );
    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      claimed: 2,
      pendingDelivery: 1,
      suppressedLogged: 1,
      attempted: 1,
      sent: 1,
      retryScheduled: 0,
      invalidDevices: 0,
      terminalFailures: 0,
      deliveryEnabled: true,
    });
  });
});
