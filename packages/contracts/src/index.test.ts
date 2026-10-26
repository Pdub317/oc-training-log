import { describe, expect, it } from "vitest";
import { emailSignInSchema, healthResponseSchema } from "./index";

describe("health response contract", () => {
  it("accepts only the public readiness shape", () => {
    expect(healthResponseSchema.parse({ status: "ok" })).toEqual({
      status: "ok",
    });
    expect(() =>
      healthResponseSchema.parse({ status: "ok", databaseUrl: "private" }),
    ).toThrow();
  });
});

describe("email sign-in contract", () => {
  it("normalizes an email address without changing the password", () => {
    expect(
      emailSignInSchema.parse({
        email: "  COACH@OCGYMBEND.COM ",
        password: " keep spaces ",
      }),
    ).toEqual({
      email: "coach@ocgymbend.com",
      password: " keep spaces ",
    });
  });

  it("rejects malformed or unexpected input", () => {
    expect(() =>
      emailSignInSchema.parse({ email: "not-an-email", password: "secret" }),
    ).toThrow();
    expect(() =>
      emailSignInSchema.parse({
        email: "coach@ocgymbend.com",
        password: "secret",
        serviceRoleKey: "must-not-cross-the-client-boundary",
      }),
    ).toThrow();
  });
});
