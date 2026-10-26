import { createPrivateKey, sign, type KeyObject } from "node:crypto";
import {
  connect,
  constants as http2Constants,
  type IncomingHttpHeaders,
} from "node:http2";
import { deviceRegistrationSchema } from "@oc-training-log/contracts";
import {
  createWorkoutReminderNotification,
  type ReminderSendResult,
  type WorkoutReminderNotification,
} from "./worker";

export type APNsConfiguration = {
  teamId: string;
  keyId: string;
  bundleId: string;
  privateKey: string;
};

type APNsTransportRequest = {
  origin: string;
  path: string;
  headers: Record<string, string>;
  body: string;
};

type APNsTransportResponse = {
  status: number;
  headers: IncomingHttpHeaders;
  body: string;
};

export interface APNsTransport {
  send(request: APNsTransportRequest): Promise<APNsTransportResponse>;
}

export function loadAPNsConfiguration(
  environment: Readonly<Record<string, string | undefined>>,
): APNsConfiguration | null {
  const values = [
    environment.APNS_TEAM_ID,
    environment.APNS_KEY_ID,
    environment.APNS_BUNDLE_ID,
    environment.APNS_PRIVATE_KEY,
  ];
  if (values.every((value) => !value)) return null;
  if (values.some((value) => !value)) {
    throw new Error("APNs configuration is incomplete.");
  }

  const configuration = {
    teamId: environment.APNS_TEAM_ID!,
    keyId: environment.APNS_KEY_ID!,
    bundleId: environment.APNS_BUNDLE_ID!,
    privateKey: environment.APNS_PRIVATE_KEY!.replaceAll("\\n", "\n"),
  };
  validateConfiguration(configuration);
  return configuration;
}

export function createAPNsProviderToken(
  configuration: APNsConfiguration,
  issuedAt: Date,
): string {
  const seconds = Math.floor(issuedAt.getTime() / 1_000);
  if (!Number.isFinite(seconds)) throw new Error("Invalid APNs token time.");
  const header = encodeJSON({ alg: "ES256", kid: configuration.keyId });
  const claims = encodeJSON({ iss: configuration.teamId, iat: seconds });
  const input = `${header}.${claims}`;
  const signature = sign("sha256", Buffer.from(input), {
    key: parsePrivateKey(configuration.privateKey),
    dsaEncoding: "ieee-p1363",
  }).toString("base64url");
  return `${input}.${signature}`;
}

export class APNsClient {
  private readonly key: KeyObject;
  private cachedToken: { value: string; issuedAtMs: number } | null = null;

  constructor(
    private readonly configuration: APNsConfiguration,
    private readonly transport: APNsTransport = new NodeHTTP2APNsTransport(),
    private readonly now: () => Date = () => new Date(),
  ) {
    validateConfiguration(configuration);
    this.key = parsePrivateKey(configuration.privateKey);
  }

  async sendWorkoutReminder(input: {
    environment: "sandbox" | "production";
    deviceToken: string;
    workoutDate: string;
  }): Promise<ReminderSendResult> {
    const tokenResult = deviceRegistrationSchema.safeParse({
      platform: "ios",
      environment: input.environment,
      token: input.deviceToken,
    });
    if (!tokenResult.success) {
      return { outcome: "invalid_device", reason: "BadDeviceToken" };
    }

    const payload = createWorkoutReminderNotification(input.workoutDate);
    const body = JSON.stringify(payload satisfies WorkoutReminderNotification);
    if (Buffer.byteLength(body) > 4_096) {
      return { outcome: "terminal", reason: "PayloadTooLarge" };
    }

    const response = await this.transport.send({
      origin:
        input.environment === "sandbox"
          ? "https://api.sandbox.push.apple.com"
          : "https://api.push.apple.com",
      path: `/3/device/${input.deviceToken}`,
      headers: {
        authorization: `bearer ${this.providerToken()}`,
        "apns-topic": this.configuration.bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
        "apns-expiration": "0",
        "content-type": "application/json",
      },
      body,
    });

    const providerId = headerValue(response.headers["apns-id"]);
    if (response.status === 200) {
      return { outcome: "sent", providerId };
    }

    const reason = responseReason(response.body);
    if (
      reason === "BadDeviceToken" ||
      reason === "DeviceTokenNotForTopic" ||
      reason === "ExpiredToken" ||
      reason === "Unregistered"
    ) {
      return { outcome: "invalid_device", reason };
    }
    if ([429, 500, 503].includes(response.status)) {
      return { outcome: "retryable", reason };
    }
    return { outcome: "terminal", reason };
  }

  private providerToken(): string {
    const now = this.now();
    const nowMs = now.getTime();
    if (!Number.isFinite(nowMs)) throw new Error("Invalid APNs token time.");
    if (
      this.cachedToken &&
      nowMs >= this.cachedToken.issuedAtMs &&
      nowMs - this.cachedToken.issuedAtMs < 50 * 60 * 1_000
    ) {
      return this.cachedToken.value;
    }

    const seconds = Math.floor(nowMs / 1_000);
    const header = encodeJSON({ alg: "ES256", kid: this.configuration.keyId });
    const claims = encodeJSON({ iss: this.configuration.teamId, iat: seconds });
    const input = `${header}.${claims}`;
    const signature = sign("sha256", Buffer.from(input), {
      key: this.key,
      dsaEncoding: "ieee-p1363",
    }).toString("base64url");
    const value = `${input}.${signature}`;
    this.cachedToken = { value, issuedAtMs: nowMs };
    return value;
  }
}

class NodeHTTP2APNsTransport implements APNsTransport {
  async send(request: APNsTransportRequest): Promise<APNsTransportResponse> {
    return new Promise((resolve, reject) => {
      const session = connect(request.origin);
      let responseHeaders: IncomingHttpHeaders = {};
      let responseBody = "";
      let settled = false;
      const finish = (result?: APNsTransportResponse, error?: Error): void => {
        if (settled) return;
        settled = true;
        session.close();
        if (error) reject(new Error("APNs transport unavailable."));
        else resolve(result!);
      };
      const stream = session.request({
        ":method": "POST",
        ":path": request.path,
        ...request.headers,
      });
      stream.setEncoding("utf8");
      stream.setTimeout(10_000, () => {
        stream.close(http2Constants.NGHTTP2_CANCEL);
        finish(undefined, new Error("timeout"));
      });
      stream.on("response", (headers) => {
        responseHeaders = headers;
      });
      stream.on("data", (chunk: string) => {
        if (responseBody.length < 16_384) responseBody += chunk;
      });
      stream.on("end", () => {
        finish({
          status: Number(responseHeaders[":status"] ?? 0),
          headers: responseHeaders,
          body: responseBody,
        });
      });
      stream.on("error", () => finish(undefined, new Error("stream")));
      session.on("error", () => finish(undefined, new Error("session")));
      stream.end(request.body);
    });
  }
}

function validateConfiguration(configuration: APNsConfiguration): void {
  if (
    !/^[A-Z0-9]{10}$/.test(configuration.teamId) ||
    !/^[A-Z0-9]{10}$/.test(configuration.keyId) ||
    !/^[A-Za-z0-9.-]{3,255}$/.test(configuration.bundleId)
  ) {
    throw new Error("APNs configuration is invalid.");
  }
  parsePrivateKey(configuration.privateKey);
}

function parsePrivateKey(value: string): KeyObject {
  try {
    const key = createPrivateKey(value);
    if (
      key.asymmetricKeyType !== "ec" ||
      key.asymmetricKeyDetails?.namedCurve !== "prime256v1"
    ) {
      throw new Error("wrong key type");
    }
    return key;
  } catch {
    throw new Error("APNs configuration is invalid.");
  }
}

function encodeJSON(value: unknown): string {
  return Buffer.from(JSON.stringify(value)).toString("base64url");
}

function headerValue(value: string | string[] | undefined): string | null {
  if (Array.isArray(value)) return value[0] ?? null;
  return value ?? null;
}

function responseReason(body: string): string {
  try {
    const value = JSON.parse(body) as { reason?: unknown };
    return typeof value.reason === "string" ? value.reason : "Unknown";
  } catch {
    return "Unknown";
  }
}
