import { updateReminderSettingsSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { extractBearerToken } from "../today/route";
import {
  getReminderSettings,
  ReminderSettingsDataError,
  updateReminderSettings,
  type ReminderSettingsRepository,
} from "../../../lib/reminders/service";
import { SupabaseReminderSettingsRepository } from "../../../lib/reminders/supabase-repository";
import { createSupabaseServerClient } from "../../../lib/supabase/server";

type Context = { userId: string; repository: ReminderSettingsRepository };
type Dependencies = { getContext(request: Request): Promise<Context | null> };

export function createReminderHandlers(dependencies: Dependencies) {
  return {
    async GET(request: Request): Promise<Response> {
      const context = await resolveContext(dependencies, request);
      if (!context) return jsonError(401, "unauthorized");
      try {
        return json(
          await getReminderSettings(context.userId, context.repository),
        );
      } catch {
        return jsonError(500, "reminders_unavailable");
      }
    },
    async PUT(request: Request): Promise<Response> {
      const parsed = updateReminderSettingsSchema.safeParse(
        await safeJson(request),
      );
      if (!parsed.success) return jsonError(400, "invalid_reminders");
      const context = await resolveContext(dependencies, request);
      if (!context) return jsonError(401, "unauthorized");
      try {
        return json(
          await updateReminderSettings(
            context.userId,
            parsed.data,
            context.repository,
          ),
        );
      } catch (error) {
        return jsonError(
          error instanceof ReminderSettingsDataError ? 400 : 500,
          error instanceof ReminderSettingsDataError
            ? "invalid_reminders"
            : "reminders_unavailable",
        );
      }
    },
  };
}

const handlers = createReminderHandlers({ getContext: requestContext });
export const GET = handlers.GET;
export const PUT = handlers.PUT;

async function requestContext(request: Request): Promise<Context | null> {
  const token = extractBearerToken(request.headers.get("authorization"));
  const client = await createSupabaseServerClient(token ?? undefined);
  const auth = await client.auth.getClaims(token ?? undefined);
  const userId = auth.data?.claims?.sub;
  if (auth.error || typeof userId !== "string") return null;
  return {
    userId,
    repository: new SupabaseReminderSettingsRepository(client),
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
