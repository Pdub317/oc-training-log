import { z } from "zod";

export const pushEnvironmentSchema = z.enum(["sandbox", "production"]);

export const deviceRegistrationSchema = z
  .object({
    platform: z.literal("ios"),
    environment: pushEnvironmentSchema,
    token: z.string().regex(/^[a-f0-9]{64,200}$/),
  })
  .strict();

export const deviceRegistrationResponseSchema = z
  .object({ registered: z.literal(true) })
  .strict();

export type DeviceRegistration = z.infer<typeof deviceRegistrationSchema>;
export type DeviceRegistrationResponse = z.infer<
  typeof deviceRegistrationResponseSchema
>;
