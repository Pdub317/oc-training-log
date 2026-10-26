import { z } from "zod";

export * from "./today";
export * from "./workout-completion";
export * from "./workout-edit";
export * from "./history";
export * from "./personal-records";
export * from "./free-text-workout";
export * from "./programming-import";
export * from "./invitations";
export * from "./member-profile";
export * from "./reminders";
export * from "./device-registration";

export const healthResponseSchema = z
  .object({
    status: z.literal("ok"),
  })
  .strict();

export type HealthResponse = z.infer<typeof healthResponseSchema>;

export const emailSignInSchema = z
  .object({
    email: z.string().trim().toLowerCase().email(),
    password: z.string().min(1),
  })
  .strict();

export type EmailSignIn = z.infer<typeof emailSignInSchema>;
