import { timingSafeEqual } from "node:crypto";
import { NextResponse } from "next/server";
import {
  APNsClient,
  loadAPNsConfiguration,
} from "../../../../lib/reminders/apns";
import { runReminderCycle } from "../../../../lib/reminders/worker";
import { SupabaseReminderDeliveryRepository } from "../../../../lib/reminders/supabase-worker-repository";
import { createSupabaseServiceClient } from "../../../../lib/supabase/service";

type Dependencies = {
  secret(): string | undefined;
  now(): Date;
  run(now: Date): Promise<unknown>;
};

export function createReminderCronHandler(dependencies: Dependencies) {
  return async function GET(request: Request): Promise<Response> {
    if (
      !authorized(request.headers.get("authorization"), dependencies.secret())
    ) {
      return json({ error: "unauthorized" }, 401);
    }
    try {
      return json(await dependencies.run(dependencies.now()), 200);
    } catch {
      return json({ error: "reminder_worker_unavailable" }, 500);
    }
  };
}

export const GET = createReminderCronHandler({
  secret: () => process.env.CRON_SECRET,
  now: () => new Date(),
  async run(now) {
    const repository = new SupabaseReminderDeliveryRepository(
      createSupabaseServiceClient(),
    );
    return runReminderCycle(repository, configuredAPNsSender(), now);
  },
});

let cachedAPNsSender: APNsClient | null | undefined;

function configuredAPNsSender(): APNsClient | null {
  if (cachedAPNsSender !== undefined) return cachedAPNsSender;
  const configuration = loadAPNsConfiguration(process.env);
  cachedAPNsSender = configuration ? new APNsClient(configuration) : null;
  return cachedAPNsSender;
}

function authorized(
  header: string | null,
  secret: string | undefined,
): boolean {
  if (!secret || secret.length < 16 || !header?.startsWith("Bearer "))
    return false;
  const supplied = Buffer.from(header.slice(7));
  const expected = Buffer.from(secret);
  return (
    supplied.length === expected.length && timingSafeEqual(supplied, expected)
  );
}

function json(value: unknown, status: number): Response {
  return NextResponse.json(value, {
    status,
    headers: { "Cache-Control": "no-store" },
  });
}
