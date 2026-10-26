import { deviceRegistrationSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { extractBearerToken } from "../../today/route";
import {
  disableDevice,
  registerDevice,
  type DeviceRegistrationRepository,
} from "../../../../lib/notifications/service";
import { SupabaseDeviceRegistrationRepository } from "../../../../lib/notifications/supabase-repository";
import { createSupabaseServerClient } from "../../../../lib/supabase/server";

type Context = { userId: string; repository: DeviceRegistrationRepository };
type Dependencies = { getContext(request: Request): Promise<Context | null> };

export function createDeviceRegistrationHandlers(dependencies: Dependencies) {
  async function perform(request: Request, action: "register" | "disable") {
    const parsed = deviceRegistrationSchema.safeParse(await safeJson(request));
    if (!parsed.success) return jsonError(400, "invalid_device_registration");
    const context = await resolveContext(dependencies, request);
    if (!context) return jsonError(401, "unauthorized");
    try {
      return json(
        action === "register"
          ? await registerDevice(
              context.userId,
              parsed.data,
              context.repository,
            )
          : await disableDevice(
              context.userId,
              parsed.data,
              context.repository,
            ),
      );
    } catch {
      return jsonError(500, "device_registration_unavailable");
    }
  }

  return {
    POST: (request: Request) => perform(request, "register"),
    DELETE: (request: Request) => perform(request, "disable"),
  };
}

const handlers = createDeviceRegistrationHandlers({
  getContext: requestContext,
});
export const POST = handlers.POST;
export const DELETE = handlers.DELETE;

async function requestContext(request: Request): Promise<Context | null> {
  const token = extractBearerToken(request.headers.get("authorization"));
  const client = await createSupabaseServerClient(token ?? undefined);
  const auth = await client.auth.getClaims(token ?? undefined);
  const userId = auth.data?.claims?.sub;
  if (auth.error || typeof userId !== "string") return null;
  return {
    userId,
    repository: new SupabaseDeviceRegistrationRepository(client),
  };
}

async function resolveContext(dependencies: Dependencies, request: Request) {
  try {
    return await dependencies.getContext(request);
  } catch {
    return null;
  }
}

async function safeJson(request: Request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

function json(value: unknown): Response {
  return NextResponse.json(value, { headers: { "Cache-Control": "no-store" } });
}

function jsonError(status: number, error: string): Response {
  return NextResponse.json(
    { error },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}
