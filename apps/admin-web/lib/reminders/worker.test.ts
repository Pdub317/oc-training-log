import { describe, expect, it } from "vitest";
import {
  createWorkoutReminderNotification,
  dispatchDueReminderDeliveries,
  prepareDueReminderDeliveries,
  runReminderCycle,
  type ReminderAttemptRepository,
  type ReminderDeliveryAttempt,
  type ReminderDeliveryRepository,
  type ReminderSendResult,
} from "./worker";

describe("prepareDueReminderDeliveries", () => {
  it("builds the date-specific iOS notification navigation contract", () => {
    expect(createWorkoutReminderNotification("2026-09-07")).toEqual({
      aps: {
        alert: {
          title: "Log your training results",
          body: "Open OC Training Log to record today's workout.",
        },
        sound: "default",
      },
      workoutDate: "2026-09-07",
      deepLink: "octraininglog://log?date=2026-09-07",
    });
  });

  it("reports pending and logged-date suppression without exposing tokens", async () => {
    let start: Date | undefined;
    const repository: ReminderDeliveryRepository = {
      async claim(windowStart) {
        start = windowStart;
        return [
          {
            deliveryId: "pending",
            status: "pending",
            workoutDate: "2026-09-07",
            intendedAt: "2026-09-08T01:00:00.000Z",
            environment: "sandbox",
            deviceToken: "ab".repeat(32),
          },
          {
            deliveryId: "suppressed",
            status: "suppressed_logged",
            workoutDate: "2026-09-07",
            intendedAt: "2026-09-08T01:00:00.000Z",
            environment: "sandbox",
            deviceToken: "cd".repeat(32),
          },
        ];
      },
    };
    const result = await prepareDueReminderDeliveries(
      repository,
      new Date("2026-09-08T01:00:00.000Z"),
      5,
    );
    expect(start?.toISOString()).toBe("2026-09-08T00:55:00.000Z");
    expect(result).toEqual({
      claimed: 2,
      pendingDelivery: 1,
      suppressedLogged: 1,
    });
    expect(JSON.stringify(result)).not.toContain("abab");
  });

  it("rejects windows beyond the database safety maximum", async () => {
    const repository: ReminderDeliveryRepository = {
      async claim() {
        return [];
      },
    };
    await expect(
      prepareDueReminderDeliveries(repository, new Date(), 16),
    ).rejects.toThrow("Invalid reminder worker window");
  });

  it("schedules the two approved retries with bounded jitter", async () => {
    const attempts = [attempt("first", 1), attempt("second", 2)];
    const records: Array<{
      deliveryId: string;
      result: ReminderSendResult;
      nextAttemptAt: Date | null;
    }> = [];
    const repository: ReminderAttemptRepository = {
      async claimAttempts() {
        return attempts;
      },
      async recordAttempt(value, result, nextAttemptAt) {
        records.push({ deliveryId: value.deliveryId, result, nextAttemptAt });
      },
    };
    const sender = {
      async sendWorkoutReminder(): Promise<ReminderSendResult> {
        return { outcome: "retryable", reason: "ServiceUnavailable" };
      },
    };
    const now = new Date("2026-09-08T01:00:00.000Z");

    const result = await dispatchDueReminderDeliveries(
      repository,
      sender,
      now,
      () => 0.5,
    );

    expect(
      records.map(({ nextAttemptAt }) => nextAttemptAt?.toISOString()),
    ).toEqual(["2026-09-08T01:15:30.000Z", "2026-09-08T01:30:30.000Z"]);
    expect(result).toEqual({
      attempted: 2,
      sent: 0,
      retryScheduled: 2,
      invalidDevices: 0,
      terminalFailures: 0,
    });
  });

  it("stops after the final attempt and reports only aggregate outcomes", async () => {
    const attempts = [
      attempt("sent", 1),
      attempt("invalid", 1),
      attempt("terminal", 1),
      attempt("exhausted", 3),
    ];
    const outcomes: Record<string, ReminderSendResult> = {
      sent: { outcome: "sent", providerId: "provider-id" },
      invalid: { outcome: "invalid_device", reason: "Unregistered" },
      terminal: { outcome: "terminal", reason: "BadTopic" },
      exhausted: { outcome: "retryable", reason: "ServiceUnavailable" },
    };
    const recorded: Array<{ id: string; next: Date | null }> = [];
    const repository: ReminderAttemptRepository = {
      async claimAttempts() {
        return attempts;
      },
      async recordAttempt(value, _result, nextAttemptAt) {
        recorded.push({ id: value.deliveryId, next: nextAttemptAt });
      },
    };
    const result = await dispatchDueReminderDeliveries(
      repository,
      {
        async sendWorkoutReminder(input) {
          return outcomes[input.deliveryId]!;
        },
      },
      new Date("2026-09-08T01:00:00.000Z"),
    );

    expect(result).toEqual({
      attempted: 4,
      sent: 1,
      retryScheduled: 0,
      invalidDevices: 1,
      terminalFailures: 2,
    });
    expect(recorded.every(({ next }) => next === null)).toBe(true);
    expect(JSON.stringify(result)).not.toContain("provider-id");
    expect(JSON.stringify(result)).not.toContain("abab");
  });

  it("keeps live delivery disabled when no provider is configured", async () => {
    let attemptClaims = 0;
    const repository: ReminderDeliveryRepository & ReminderAttemptRepository = {
      async claim() {
        return [];
      },
      async claimAttempts() {
        attemptClaims += 1;
        return [];
      },
      async recordAttempt() {},
    };

    const result = await runReminderCycle(
      repository,
      null,
      new Date("2026-09-08T01:00:00.000Z"),
    );

    expect(result).toEqual({
      claimed: 0,
      pendingDelivery: 0,
      suppressedLogged: 0,
      attempted: 0,
      sent: 0,
      retryScheduled: 0,
      invalidDevices: 0,
      terminalFailures: 0,
      deliveryEnabled: false,
    });
    expect(attemptClaims).toBe(0);
  });
});

function attempt(
  deliveryId: string,
  attemptCount: number,
): ReminderDeliveryAttempt {
  return {
    deliveryId,
    workoutDate: "2026-09-07",
    environment: "sandbox",
    deviceToken: "ab".repeat(32),
    attemptCount,
  };
}
