import { describe, expect, it } from "vitest";
import { deviceRegistrationSchema } from "./device-registration";

const token = "ab".repeat(32);

describe("deviceRegistrationSchema", () => {
  it("accepts a normalized APNs token without changing it", () => {
    expect(
      deviceRegistrationSchema.parse({
        platform: "ios",
        environment: "sandbox",
        token,
      }),
    ).toEqual({ platform: "ios", environment: "sandbox", token });
  });

  it("rejects malformed tokens and unsupported platforms", () => {
    expect(
      deviceRegistrationSchema.safeParse({
        platform: "ios",
        environment: "sandbox",
        token: "not-a-token",
      }).success,
    ).toBe(false);
    expect(
      deviceRegistrationSchema.safeParse({
        platform: "android",
        environment: "sandbox",
        token,
      }).success,
    ).toBe(false);
  });
});
