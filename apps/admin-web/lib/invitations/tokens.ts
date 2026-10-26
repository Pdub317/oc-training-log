import { createHash, randomBytes } from "node:crypto";

export function createJoinToken() {
  const rawToken = randomBytes(32).toString("base64url");
  return {
    rawToken,
    tokenHash: hashJoinToken(rawToken),
    tokenHint: rawToken.slice(-6),
  };
}

export function hashJoinToken(rawToken: string) {
  return createHash("sha256").update(rawToken, "utf8").digest("hex");
}

export function joinUrl(requestUrl: string, rawToken: string) {
  return `${new URL(requestUrl).origin}/join?token=${encodeURIComponent(rawToken)}`;
}
