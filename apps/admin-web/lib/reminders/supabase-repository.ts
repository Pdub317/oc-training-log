import type { UpdateReminderSettings } from "@oc-training-log/contracts";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  ReminderSettingsDataError,
  type ReminderSettingsRepository,
} from "./service";

export class SupabaseReminderSettingsRepository
  implements ReminderSettingsRepository
{
  constructor(private readonly client: SupabaseClient) {}

  async get(userId: string): Promise<unknown | null> {
    const user = await this.client
      .from("users")
      .select("time_zone")
      .eq("id", userId)
      .maybeSingle();
    assertSucceeded(user.error);
    if (!user.data) return null;

    let timeZone = user.data.time_zone as string | null;
    if (!timeZone) {
      const memberships = await this.client
        .from("gym_memberships")
        .select("gym_id")
        .eq("user_id", userId)
        .eq("status", "active")
        .limit(1);
      assertSucceeded(memberships.error);
      const gymId = memberships.data?.[0]?.gym_id;
      if (gymId) {
        const gym = await this.client
          .from("gyms")
          .select("timezone")
          .eq("id", gymId)
          .maybeSingle();
        assertSucceeded(gym.error);
        timeZone = gym.data?.timezone ?? null;
      }
    }
    if (!timeZone) return null;

    const schedules = await this.client
      .from("reminder_schedules")
      .select("weekday, local_time")
      .eq("user_id", userId)
      .eq("enabled", true)
      .order("weekday");
    assertSucceeded(schedules.error);
    return {
      timeZone,
      schedules: (schedules.data ?? []).map((schedule) => ({
        weekday: schedule.weekday,
        localTime: String(schedule.local_time).slice(0, 5),
      })),
    };
  }

  async replace(
    userId: string,
    input: UpdateReminderSettings,
  ): Promise<unknown | null> {
    const result = await this.client.rpc("replace_reminder_schedules", {
      p_time_zone: input.timeZone,
      p_schedules: input.schedules,
    });
    assertSucceeded(result.error);
    return this.get(userId);
  }
}

function assertSucceeded(
  error: { message: string } | null,
): asserts error is null {
  if (error) {
    throw new ReminderSettingsDataError("Unable to load reminder settings.", {
      cause: error,
    });
  }
}
