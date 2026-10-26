import { describe, expect, it } from "vitest";
import { getSupabasePublicConfig, getSupabaseServiceConfig } from "./config";

describe("Supabase public configuration", () => {
  it("returns only browser-safe values", () => {
    expect(
      getSupabasePublicConfig({
        NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY: " publishable-key ",
        NEXT_PUBLIC_SUPABASE_URL: " http://127.0.0.1:54321 ",
        SUPABASE_SERVICE_ROLE_KEY: "server-secret",
      }),
    ).toEqual({
      publishableKey: "publishable-key",
      url: "http://127.0.0.1:54321",
    });
  });

  it("fails with the missing value names", () => {
    expect(() => getSupabasePublicConfig({})).toThrow(
      "NEXT_PUBLIC_SUPABASE_URL, NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
    );
  });
});

describe("Supabase service configuration", () => {
  it("requires and returns server-only credentials", () => {
    expect(
      getSupabaseServiceConfig({
        NEXT_PUBLIC_SUPABASE_URL: " http://127.0.0.1:54321 ",
        SUPABASE_SERVICE_ROLE_KEY: " service-secret ",
      }),
    ).toEqual({
      url: "http://127.0.0.1:54321",
      serviceRoleKey: "service-secret",
    });
    expect(() => getSupabaseServiceConfig({})).toThrow(
      "NEXT_PUBLIC_SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY",
    );
  });
});
