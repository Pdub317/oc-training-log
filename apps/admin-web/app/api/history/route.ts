import { historyRequestSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import {
  getHistory,
  HistoryAccessDeniedError,
  HistoryDataError,
  type HistoryRepository,
} from "../../../lib/history/service";
import { SupabaseHistoryRepository } from "../../../lib/history/supabase-repository";
import { createSupabaseServerClient } from "../../../lib/supabase/server";

type RequestContext = { userId: string; repository: HistoryRepository };
type Dependencies = {
  getRequestContext(request: Request): Promise<RequestContext | null>;
};

export function createHistoryHandler(dependencies: Dependencies) {
  return async function GET(request: Request): Promise<Response> {
    const parameters = new URL(request.url).searchParams;
    const parsed = historyRequestSchema.safeParse({
      trackCode: parameters.get("track"),
      workoutLogId: parameters.get("workout") || undefined,
      query: parameters.get("query") || undefined,
      fromDate: parameters.get("from") || undefined,
      personalRecordsOnly: parameters.get("pr") === "true",
      cursor: parameters.get("cursor") || undefined,
    });
    if (!parsed.success) return jsonError(400, "invalid_history_query");

    let context: RequestContext | null;
    try {
      context = await dependencies.getRequestContext(request);
    } catch {
      return jsonError(500, "history_unavailable");
    }
    if (!context) return jsonError(401, "unauthorized");

    try {
      return NextResponse.json(
        await getHistory(
          { userId: context.userId, ...parsed.data },
          context.repository,
        ),
        { headers: noStoreHeaders },
      );
    } catch (error) {
      if (error instanceof HistoryAccessDeniedError) {
        return jsonError(403, "track_access_denied");
      }
      if (error instanceof HistoryDataError) {
        return jsonError(500, "history_unavailable");
      }
      return jsonError(500, "history_unavailable");
    }
  };
}

export const GET = createHistoryHandler({
  async getRequestContext(request) {
    const token = request.headers
      .get("authorization")
      ?.match(/^Bearer ([^\s]+)$/i)?.[1];
    const client = await createSupabaseServerClient(token);
    const { data, error } = await client.auth.getClaims(token);
    const userId = data?.claims?.sub;
    if (error || typeof userId !== "string") return null;
    return { userId, repository: new SupabaseHistoryRepository(client) };
  },
});

const noStoreHeaders = { "Cache-Control": "no-store" } as const;
function jsonError(status: number, error: string): Response {
  return NextResponse.json({ error }, { status, headers: noStoreHeaders });
}
