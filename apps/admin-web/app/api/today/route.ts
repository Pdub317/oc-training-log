import { trackCodeSchema, workoutDateSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../lib/supabase/server";
import {
  getToday,
  TodayDataError,
  TrackAccessDeniedError,
  type Clock,
  type TodayRepository,
} from "../../../lib/today/service";
import { SupabaseTodayRepository } from "../../../lib/today/supabase-repository";

type RequestContext = {
  userId: string;
  repository: TodayRepository;
};

type TodayHandlerDependencies = {
  getRequestContext(request: Request): Promise<RequestContext | null>;
  clock?: Clock;
};

export function createTodayHandler(dependencies: TodayHandlerDependencies) {
  return async function GET(request: Request): Promise<Response> {
    const searchParams = new URL(request.url).searchParams;
    const trackResult = trackCodeSchema.safeParse(searchParams.get("track"));

    if (!trackResult.success) {
      return jsonError(400, "invalid_track");
    }

    const requestedDate = searchParams.get("date");
    const dateResult = requestedDate
      ? workoutDateSchema.safeParse(requestedDate)
      : null;
    if (dateResult && !dateResult.success) {
      return jsonError(400, "invalid_date");
    }

    let context: RequestContext | null;
    try {
      context = await dependencies.getRequestContext(request);
    } catch {
      return jsonError(500, "today_unavailable");
    }

    if (!context) {
      return jsonError(401, "unauthorized");
    }

    try {
      const response = await getToday(
        {
          userId: context.userId,
          trackCode: trackResult.data,
          workoutDate: dateResult?.data,
        },
        { repository: context.repository, clock: dependencies.clock },
      );

      return NextResponse.json(response, { headers: noStoreHeaders });
    } catch (error) {
      if (error instanceof TrackAccessDeniedError) {
        return jsonError(403, "track_access_denied");
      }

      if (error instanceof TodayDataError) {
        return jsonError(500, "today_unavailable");
      }

      return jsonError(500, "today_unavailable");
    }
  };
}

export const GET = createTodayHandler({
  async getRequestContext(request) {
    const accessToken = extractBearerToken(
      request.headers.get("authorization"),
    );
    const client = await createSupabaseServerClient(accessToken ?? undefined);
    const { data, error } = await client.auth.getClaims(
      accessToken ?? undefined,
    );
    const userId = data?.claims?.sub;

    if (error || typeof userId !== "string" || userId.length === 0) {
      return null;
    }

    return {
      userId,
      repository: new SupabaseTodayRepository(client),
    };
  },
});

export function extractBearerToken(
  authorization: string | null,
): string | null {
  const match = authorization?.match(/^Bearer ([^\s]+)$/i);
  return match?.[1] ?? null;
}

const noStoreHeaders = { "Cache-Control": "no-store" } as const;

function jsonError(status: number, error: string): Response {
  return NextResponse.json({ error }, { status, headers: noStoreHeaders });
}
