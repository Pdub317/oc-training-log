export type ReminderDeliveryStatus = "pending" | "suppressed_logged";

export type ReminderDeliveryClaim = {
  deliveryId: string;
  status: ReminderDeliveryStatus;
  workoutDate: string;
  intendedAt: string;
  environment: "sandbox" | "production";
  deviceToken: string;
};

export type ReminderDeliveryAttempt = {
  deliveryId: string;
  workoutDate: string;
  environment: "sandbox" | "production";
  deviceToken: string;
  attemptCount: number;
};

export type ReminderSendResult =
  | { outcome: "sent"; providerId: string | null }
  | { outcome: "invalid_device"; reason: string }
  | { outcome: "retryable"; reason: string }
  | { outcome: "terminal"; reason: string };

export interface ReminderDeliveryRepository {
  claim(windowStart: Date, windowEnd: Date): Promise<ReminderDeliveryClaim[]>;
}

export interface ReminderAttemptRepository {
  claimAttempts(now: Date): Promise<ReminderDeliveryAttempt[]>;
  recordAttempt(
    attempt: ReminderDeliveryAttempt,
    result: ReminderSendResult,
    nextAttemptAt: Date | null,
  ): Promise<void>;
}

export interface ReminderSender {
  sendWorkoutReminder(
    input: ReminderDeliveryAttempt,
  ): Promise<ReminderSendResult>;
}

export type ReminderWorkerResult = {
  claimed: number;
  pendingDelivery: number;
  suppressedLogged: number;
};

export type ReminderDispatchResult = {
  attempted: number;
  sent: number;
  retryScheduled: number;
  invalidDevices: number;
  terminalFailures: number;
};

export type ReminderCycleResult = ReminderWorkerResult &
  ReminderDispatchResult & { deliveryEnabled: boolean };

export type WorkoutReminderNotification = {
  aps: {
    alert: { title: string; body: string };
    sound: "default";
  };
  workoutDate: string;
  deepLink: string;
};

export function createWorkoutReminderNotification(
  workoutDate: string,
): WorkoutReminderNotification {
  return {
    aps: {
      alert: {
        title: "Log your training results",
        body: "Open OC Training Log to record today's workout.",
      },
      sound: "default",
    },
    workoutDate,
    deepLink: `octraininglog://log?date=${encodeURIComponent(workoutDate)}`,
  };
}

export async function prepareDueReminderDeliveries(
  repository: ReminderDeliveryRepository,
  now: Date,
  windowMinutes = 5,
): Promise<ReminderWorkerResult> {
  if (
    !Number.isInteger(windowMinutes) ||
    windowMinutes < 1 ||
    windowMinutes > 15 ||
    Number.isNaN(now.getTime())
  ) {
    throw new Error("Invalid reminder worker window.");
  }
  const windowStart = new Date(now.getTime() - windowMinutes * 60_000);
  const claims = await repository.claim(windowStart, now);
  return {
    claimed: claims.length,
    pendingDelivery: claims.filter(({ status }) => status === "pending").length,
    suppressedLogged: claims.filter(
      ({ status }) => status === "suppressed_logged",
    ).length,
  };
}

export async function dispatchDueReminderDeliveries(
  repository: ReminderAttemptRepository,
  sender: ReminderSender,
  now: Date,
  random: () => number = Math.random,
): Promise<ReminderDispatchResult> {
  if (Number.isNaN(now.getTime())) {
    throw new Error("Invalid reminder dispatch time.");
  }
  const attempts = await repository.claimAttempts(now);
  const summary: ReminderDispatchResult = {
    attempted: attempts.length,
    sent: 0,
    retryScheduled: 0,
    invalidDevices: 0,
    terminalFailures: 0,
  };

  for (const attempt of attempts) {
    let result: ReminderSendResult;
    try {
      result = await sender.sendWorkoutReminder(attempt);
    } catch {
      result = { outcome: "retryable", reason: "TransportUnavailable" };
    }

    const nextAttemptAt =
      result.outcome === "retryable"
        ? retryTime(attempt.attemptCount, now, random)
        : null;
    await repository.recordAttempt(attempt, result, nextAttemptAt);
    switch (result.outcome) {
      case "sent":
        summary.sent += 1;
        break;
      case "invalid_device":
        summary.invalidDevices += 1;
        break;
      case "terminal":
        summary.terminalFailures += 1;
        break;
      case "retryable":
        if (attempt.attemptCount < 3) summary.retryScheduled += 1;
        else summary.terminalFailures += 1;
        break;
    }
  }
  return summary;
}

export async function runReminderCycle(
  repository: ReminderDeliveryRepository & ReminderAttemptRepository,
  sender: ReminderSender | null,
  now: Date,
  random: () => number = Math.random,
): Promise<ReminderCycleResult> {
  const prepared = await prepareDueReminderDeliveries(repository, now);
  const dispatched = sender
    ? await dispatchDueReminderDeliveries(repository, sender, now, random)
    : {
        attempted: 0,
        sent: 0,
        retryScheduled: 0,
        invalidDevices: 0,
        terminalFailures: 0,
      };
  return { ...prepared, ...dispatched, deliveryEnabled: sender !== null };
}

function retryTime(
  attemptCount: number,
  now: Date,
  random: () => number,
): Date | null {
  if (attemptCount >= 3) return null;
  const baseMinutes = attemptCount === 1 ? 15 : 30;
  const sample = random();
  const jitterSeconds = Number.isFinite(sample)
    ? Math.floor(Math.min(Math.max(sample, 0), 0.999_999) * 60)
    : 0;
  return new Date(now.getTime() + baseMinutes * 60_000 + jitterSeconds * 1_000);
}
