import type { DeviceRegistration } from "@oc-training-log/contracts";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { DeviceRegistrationRepository } from "./service";

export class SupabaseDeviceRegistrationRepository
  implements DeviceRegistrationRepository
{
  constructor(private readonly client: SupabaseClient) {}

  async register(_userId: string, device: DeviceRegistration): Promise<void> {
    const result = await this.client.rpc(
      "register_device_token",
      parameters(device),
    );
    if (result.error)
      throw new Error("Unable to register device.", { cause: result.error });
  }

  async disable(_userId: string, device: DeviceRegistration): Promise<void> {
    const result = await this.client.rpc(
      "disable_device_token",
      parameters(device),
    );
    if (result.error)
      throw new Error("Unable to disable device.", { cause: result.error });
  }
}

function parameters(device: DeviceRegistration) {
  return {
    p_platform: device.platform,
    p_environment: device.environment,
    p_token: device.token,
  };
}
