import { describe, expect, it } from "vitest";
import { createJoinToken, hashJoinToken, joinUrl } from "./tokens";

describe("invitation tokens", () => {
  it("creates high-entropy tokens and stores only a deterministic hash", () => {
    const first = createJoinToken();
    const second = createJoinToken();
    expect(first.rawToken).not.toBe(second.rawToken);
    expect(first.tokenHash).toBe(hashJoinToken(first.rawToken));
    expect(first.tokenHash).toMatch(/^[0-9a-f]{64}$/);
  });

  it("builds a URL-safe join link", () => {
    expect(
      joinUrl("http://localhost:3000/api/admin/invitations", "a/b+c"),
    ).toBe("http://localhost:3000/join?token=a%2Fb%2Bc");
  });
});
