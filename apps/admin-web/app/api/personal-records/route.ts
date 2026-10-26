import { trackCodeSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../lib/supabase/server";
import {
  getPersonalRecordDetail,
  listPersonalRecords,
  PersonalRecordsAccessDeniedError,
  PersonalRecordsDataError,
  type PersonalRecordsRepository,
} from "../../../lib/personal-records/service";
import { SupabasePersonalRecordsRepository } from "../../../lib/personal-records/supabase-repository";

type Context = { userId: string; repository: PersonalRecordsRepository };
type Dependencies = { getContext(request: Request): Promise<Context | null> };

export function createPersonalRecordsHandler(dependencies: Dependencies) {
  return async function GET(request: Request): Promise<Response> {
    const parameters = new URL(request.url).searchParams;
    const track = trackCodeSchema.safeParse(parameters.get("track"));
    const benchmarkId = parameters.get("benchmark");
    if (!track.success || (benchmarkId && !isUuid(benchmarkId))) {
      return jsonError(400, "invalid_personal_records_query");
    }
    const context = await dependencies.getContext(request);
    if (!context) return jsonError(401, "unauthorized");
    try {
      const response = benchmarkId
        ? await getPersonalRecordDetail(
            { userId: context.userId, trackCode: track.data, benchmarkId },
            context.repository,
          )
        : await listPersonalRecords(
            { userId: context.userId, trackCode: track.data },
            context.repository,
          );
      return NextResponse.json(response, { headers: noStoreHeaders });
    } catch (error) {
      if (error instanceof PersonalRecordsAccessDeniedError)
        return jsonError(403, "personal_records_access_denied");
      if (error instanceof PersonalRecordsDataError)
        return jsonError(500, "personal_records_unavailable");
      return jsonError(500, "personal_records_unavailable");
    }
  };
}

export const GET = createPersonalRecordsHandler({
  async getContext(request) {
    const token = request.headers
      .get("authorization")
      ?.match(/^Bearer ([^\s]+)$/i)?.[1];
    const client = await createSupabaseServerClient(token);
    const { data, error } = await client.auth.getClaims(token);
    const userId = data?.claims?.sub;
    if (error || typeof userId !== "string") return null;
    return {
      userId,
      repository: new SupabasePersonalRecordsRepository(client),
    };
  },
});

const noStoreHeaders = { "Cache-Control": "no-store" } as const;
function jsonError(status: number, error: string): Response {
  return NextResponse.json({ error }, { status, headers: noStoreHeaders });
}
function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(
    value,
  );
}
