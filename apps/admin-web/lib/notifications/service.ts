import {
  deviceRegistrationResponseSchema,
  type DeviceRegistration,
  type DeviceRegistrationResponse,
} from "@oc-training-log/contracts";

export interface DeviceRegistrationRepository {
  register(userId: string, device: DeviceRegistration): Promise<void>;
  disable(userId: string, device: DeviceRegistration): Promise<void>;
}

export async function registerDevice(
  userId: string,
  device: DeviceRegistration,
  repository: DeviceRegistrationRepository,
): Promise<DeviceRegistrationResponse> {
  await repository.register(userId, device);
  return deviceRegistrationResponseSchema.parse({ registered: true });
}

export async function disableDevice(
  userId: string,
  device: DeviceRegistration,
  repository: DeviceRegistrationRepository,
): Promise<DeviceRegistrationResponse> {
  await repository.disable(userId, device);
  return deviceRegistrationResponseSchema.parse({ registered: true });
}
