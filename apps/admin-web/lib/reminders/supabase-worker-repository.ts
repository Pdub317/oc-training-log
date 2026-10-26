import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  ReminderDeliveryClaim,
  ReminderDeliveryRepository,
  ReminderDeliveryStatus,
  ReminderDeliveryAttempt,
  ReminderAttemptRepository,
  ReminderSendResult,
} from "./worker";

export class SupabaseReminderDeliveryRepository
  implements ReminderDeliveryRepository, ReminderAttemptRepository
{
  constructor(private readonly client: SupabaseClient) {}

  async claim(
    windowStart: Date,
    windowEnd: Date,
  ): Promise<ReminderDeliveryClaim[]> {
    const result = await this.client.rpc("claim_due_reminder_deliveries", {
      p_window_start: windowStart.toISOString(),
      p_window_end: windowEnd.toISOString(),
    });
    if (result.error) throw new Error("Unable to claim reminder deliveries.");
    return (result.data ?? []).map((row: Record<string, unknown>) => ({
      deliveryId: String(row.delivery_id),
      status: row.status as ReminderDeliveryStatus,
      workoutDate: String(row.workout_date),
      intendedAt: String(row.intended_at),
      environment: row.environment as "sandbox" | "production",
      deviceToken: String(row.device_token),
    }));
  }

  async claimAttempts(now: Date): Promise<ReminderDeliveryAttempt[]> {
    const result = await this.client.rpc("claim_reminder_delivery_attempts", {
      p_now: now.toISOString(),
    });
    if (result.error) throw new Error("Unable to claim reminder attempts.");
    return (result.data ?? []).map((row: Record<string, unknown>) => ({
      deliveryId: String(row.delivery_id),
      workoutDate: String(row.workout_date),
      environment: row.environment as "sandbox" | "production",
      deviceToken: String(row.device_token),
      attemptCount: Number(row.attempt_count),
    }));
  }

  async recordAttempt(
    attempt: ReminderDeliveryAttempt,
    result: ReminderSendResult,
    nextAttemptAt: Date | null,
  ): Promise<void> {
    const providerId = result.outcome === "sent" ? result.providerId : null;
    const providerReason = result.outcome === "sent" ? null : result.reason;
    const response = await this.client.rpc("record_reminder_delivery_result", {
      p_delivery_id: attempt.deliveryId,
      p_outcome: result.outcome,
      p_provider_id: providerId,
      p_provider_reason: providerReason,
      p_next_attempt_at: nextAttemptAt?.toISOString() ?? null,
    });
    if (response.error) throw new Error("Unable to record reminder attempt.");
  }
}
