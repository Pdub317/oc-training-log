import { describe, expect, it } from "vitest";
import {
  acceptInvitationSchema,
  invitationActionSchema,
  registerFromInvitationSchema,
} from "./invitations";

describe("invitationActionSchema", () => {
  it("normalizes and validates a bounded email batch", () => {
    expect(
      invitationActionSchema.parse({
        kind: "email",
        trackCode: "SP",
        emails: [" ATHLETE@EXAMPLE.COM "],
      }),
    ).toEqual({
      kind: "email",
      trackCode: "SP",
      emails: ["athlete@example.com"],
    });
  });

  it("rejects malformed addresses", () => {
    expect(
      invitationActionSchema.safeParse({
        kind: "email",
        trackCode: "GP",
        emails: ["not-email"],
      }).success,
    ).toBe(false);
  });

  it("requires every registration acknowledgement and matching passwords", () => {
    const base = {
      token: "a".repeat(32),
      firstName: "Avery",
      lastName: "Athlete",
      email: "avery@example.com",
      password: "Password1234!",
      passwordConfirmation: "Password1234!",
      age13Attested: true,
      termsAccepted: true,
      privacyAccepted: true,
    } as const;
    expect(registerFromInvitationSchema.safeParse(base).success).toBe(true);
    expect(
      registerFromInvitationSchema.safeParse({
        ...base,
        password: "12345678901",
        passwordConfirmation: "12345678901",
      }).success,
    ).toBe(false);
    expect(
      registerFromInvitationSchema.safeParse({
        ...base,
        password: " 1234567890 ",
        passwordConfirmation: " 1234567890 ",
      }).data?.password,
    ).toBe(" 1234567890 ");
    expect(
      registerFromInvitationSchema.safeParse({
        ...base,
        passwordConfirmation: "different",
      }).success,
    ).toBe(false);
    expect(
      registerFromInvitationSchema.safeParse({ ...base, age13Attested: false })
        .success,
    ).toBe(false);
  });

  it("requires acknowledgements when a signed-in member accepts", () => {
    const accepted = {
      token: "a".repeat(32),
      age13Attested: true,
      termsAccepted: true,
      privacyAccepted: true,
    } as const;
    expect(acceptInvitationSchema.safeParse(accepted).success).toBe(true);
    expect(
      acceptInvitationSchema.safeParse({
        ...accepted,
        privacyAccepted: false,
      }).success,
    ).toBe(false);
  });
});
