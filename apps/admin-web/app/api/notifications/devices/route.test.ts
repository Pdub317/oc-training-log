import { describe, expect, it } from "vitest";
import type { DeviceRegistrationRepository } from "../../../../lib/notifications/service";
import { createDeviceRegistrationHandlers } from "./route";

const token = "ab".repeat(32);

describe("/api/notifications/devices", () => {
  it("registers and disables only the authenticated device", async () => {
    const actions: string[] = [];
    const repository: DeviceRegistrationRepository = {
      async register(userId) {
        actions.push(`register:${userId}`);
      },
      async disable(userId) {
        actions.push(`disable:${userId}`);
      },
    };
    const handlers = createDeviceRegistrationHandlers({
      async getContext() {
        return { userId: "member", repository };
      },
    });
    const body = JSON.stringify({
      platform: "ios",
      environment: "sandbox",
      token,
    });
    const post = await handlers.POST(
      new Request("http://localhost/api/notifications/devices", {
        method: "POST",
        body,
      }),
    );
    const remove = await handlers.DELETE(
      new Request("http://localhost/api/notifications/devices", {
        method: "DELETE",
        body,
      }),
    );
    expect(post.status).toBe(200);
    expect(remove.status).toBe(200);
    expect(actions).toEqual(["register:member", "disable:member"]);
  });

  it("rejects malformed tokens before authentication", async () => {
    let checkedAuth = false;
    const handlers = createDeviceRegistrationHandlers({
      async getContext() {
        checkedAuth = true;
        return null;
      },
    });
    const response = await handlers.POST(
      new Request("http://localhost/api/notifications/devices", {
        method: "POST",
        body: JSON.stringify({
          platform: "ios",
          environment: "sandbox",
          token: "bad",
        }),
      }),
    );
    expect(response.status).toBe(400);
    expect(checkedAuth).toBe(false);
  });

  it("requires authentication for a valid registration", async () => {
    const handlers = createDeviceRegistrationHandlers({
      async getContext() {
        return null;
      },
    });
    const response = await handlers.POST(
      new Request("http://localhost/api/notifications/devices", {
        method: "POST",
        body: JSON.stringify({
          platform: "ios",
          environment: "sandbox",
          token,
        }),
      }),
    );
    expect(response.status).toBe(401);
  });
});
