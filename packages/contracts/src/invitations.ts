import { z } from "zod";
import { trackCodeSchema } from "./today";

export const createEmailInvitationsSchema = z
  .object({
    kind: z.literal("email"),
    trackCode: trackCodeSchema,
    emails: z
      .array(z.string().trim().toLowerCase().email().max(320))
      .min(1)
      .max(50),
  })
  .strict();

export const createShareLinkSchema = z
  .object({ kind: z.literal("share"), trackCode: trackCodeSchema })
  .strict();

export const invitationActionSchema = z.discriminatedUnion("kind", [
  createEmailInvitationsSchema,
  createShareLinkSchema,
]);

export const resendInvitationSchema = z
  .object({ kind: z.literal("resend") })
  .strict();

export const disableShareLinkSchema = z
  .object({ kind: z.literal("disable") })
  .strict();

export type InvitationAction = z.infer<typeof invitationActionSchema>;

const joinTokenSchema = z.string().min(20).max(200);

export const registerFromInvitationSchema = z
  .object({
    token: joinTokenSchema,
    firstName: z.string().trim().min(1).max(100),
    lastName: z.string().trim().min(1).max(100),
    email: z.string().trim().toLowerCase().email().max(320),
    password: z.string().min(12).max(128),
    passwordConfirmation: z.string().min(12).max(128),
    age13Attested: z.literal(true),
    termsAccepted: z.literal(true),
    privacyAccepted: z.literal(true),
  })
  .strict()
  .superRefine((input, context) => {
    if (input.password !== input.passwordConfirmation) {
      context.addIssue({
        code: "custom",
        message: "Passwords must match.",
        path: ["passwordConfirmation"],
      });
    }
  });

export const signInFromInvitationSchema = z
  .object({
    token: joinTokenSchema,
    email: z.string().trim().toLowerCase().email().max(320),
    password: z.string().min(1).max(128),
    age13Attested: z.literal(true),
    termsAccepted: z.literal(true),
    privacyAccepted: z.literal(true),
  })
  .strict();

export const acceptInvitationSchema = z
  .object({
    token: joinTokenSchema,
    age13Attested: z.literal(true),
    termsAccepted: z.literal(true),
    privacyAccepted: z.literal(true),
  })
  .strict();
