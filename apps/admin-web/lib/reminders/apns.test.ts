import { generateKeyPairSync } from "node:crypto";
import { describe, expect, it } from "vitest";
import {
  APNsClient,
  createAPNsProviderToken,
  loadAPNsConfiguration,
  type APNsConfiguration,
  type APNsTransport,
} from "./apns";

const privateKey = generateKeyPairSync("ec", { namedCurve: "P-256" })
  .privateKey.export({ type: "pkcs8", format: "pem" })
  .toString();

const configuration: APNsConfiguration = {
  teamId: "TEAMID1234",
  keyId: "KEYID12345",
  bundleId: "com.ocgymbend.traininglog",
  privateKey,
};

describe("APNs delivery boundary", () => {
  it("stays disabled with no credentials and rejects partial configuration", () => {
    expect(loadAPNsConfiguration({})).toBeNull();
    expect(() => loadAPNsConfiguration({ APNS_TEAM_ID: "TEAMID1234" })).toThrow(
      "APNs configuration is incomplete",
    );
  });

  it("validates escaped PEM credentials without exposing them", () => {
    const loaded = loadAPNsConfiguration({
      APNS_TEAM_ID: configuration.teamId,
      APNS_KEY_ID: configuration.keyId,
      APNS_BUNDLE_ID: configuration.bundleId,
      APNS_PRIVATE_KEY: privateKey.replaceAll("\n", "\\n"),
    });
    expect(loaded).toEqual(configuration);

    expect(() =>
      loadAPNsConfiguration({
        APNS_TEAM_ID: configuration.teamId,
        APNS_KEY_ID: configuration.keyId,
        APNS_BUNDLE_ID: configuration.bundleId,
        APNS_PRIVATE_KEY: "private-secret-that-must-not-appear",
      }),
    ).toThrow("APNs configuration is invalid");
  });

  it("creates a correctly shaped ES256 provider token", () => {
    const token = createAPNsProviderToken(
      configuration,
      new Date("2026-09-08T12:00:00.000Z"),
    );
    const [header, claims, signature] = token.split(".");
    expect(JSON.parse(Buffer.from(header!, "base64url").toString())).toEqual({
      alg: "ES256",
      kid: configuration.keyId,
    });
    expect(JSON.parse(Buffer.from(claims!, "base64url").toString())).toEqual({
      iss: configuration.teamId,
      iat: 1788868800,
    });
    expect(Buffer.from(signature!, "base64url")).toHaveLength(64);
  });

  it("sends the private date payload to the correct APNs environment", async () => {
    const transport = new StubTransport({
      status: 200,
      headers: { "apns-id": "provider-id" },
      body: "",
    });
    const client = new APNsClient(
      configuration,
      transport,
      () => new Date("2026-09-08T12:00:00.000Z"),
    );

    const result = await client.sendWorkoutReminder({
      environment: "sandbox",
      deviceToken: "ab".repeat(32),
      workoutDate: "2026-09-08",
    });

    expect(result).toEqual({ outcome: "sent", providerId: "provider-id" });
    expect(transport.requests).toHaveLength(1);
    const request = transport.requests[0]!;
    expect(request.origin).toBe("https://api.sandbox.push.apple.com");
    expect(request.path).toBe(`/3/device/${"ab".repeat(32)}`);
    expect(request.headers["apns-topic"]).toBe(configuration.bundleId);
    expect(request.headers["apns-push-type"]).toBe("alert");
    expect(request.headers.authorization).toMatch(
      /^bearer [^.]+\.[^.]+\.[^.]+$/,
    );
    expect(JSON.parse(request.body)).toMatchObject({
      workoutDate: "2026-09-08",
      deepLink: "octraininglog://log?date=2026-09-08",
    });
  });

  it("classifies invalid tokens, transient failures, and terminal failures", async () => {
    const invalid = new APNsClient(
      configuration,
      new StubTransport({
        status: 410,
        headers: {},
        body: JSON.stringify({ reason: "Unregistered" }),
      }),
    );
    await expect(
      invalid.sendWorkoutReminder({
        environment: "production",
        deviceToken: "cd".repeat(32),
        workoutDate: "2026-09-08",
      }),
    ).resolves.toEqual({ outcome: "invalid_device", reason: "Unregistered" });

    const retryable = new APNsClient(
      configuration,
      new StubTransport({
        status: 503,
        headers: {},
        body: JSON.stringify({ reason: "ServiceUnavailable" }),
      }),
    );
    await expect(
      retryable.sendWorkoutReminder({
        environment: "production",
        deviceToken: "ef".repeat(32),
        workoutDate: "2026-09-08",
      }),
    ).resolves.toEqual({
      outcome: "retryable",
      reason: "ServiceUnavailable",
    });

    const terminal = new APNsClient(
      configuration,
      new StubTransport({
        status: 400,
        headers: {},
        body: JSON.stringify({ reason: "PayloadEmpty" }),
      }),
    );
    await expect(
      terminal.sendWorkoutReminder({
        environment: "production",
        deviceToken: "01".repeat(32),
        workoutDate: "2026-09-08",
      }),
    ).resolves.toEqual({ outcome: "terminal", reason: "PayloadEmpty" });
  });

  it("rejects malformed device tokens before opening a connection", async () => {
    const transport = new StubTransport({ status: 200, headers: {}, body: "" });
    const client = new APNsClient(configuration, transport);

    await expect(
      client.sendWorkoutReminder({
        environment: "sandbox",
        deviceToken: "not-a-token",
        workoutDate: "2026-09-08",
      }),
    ).resolves.toEqual({ outcome: "invalid_device", reason: "BadDeviceToken" });
    expect(transport.requests).toEqual([]);
  });
});

type TransportRequest = Parameters<APNsTransport["send"]>[0];
type TransportResponse = Awaited<ReturnType<APNsTransport["send"]>>;

class StubTransport implements APNsTransport {
  requests: TransportRequest[] = [];

  constructor(private readonly response: TransportResponse) {}

  async send(request: TransportRequest): Promise<TransportResponse> {
    this.requests.push(request);
    return this.response;
  }
}
