import { leaveTrackSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../../../lib/supabase/server";
import {
  leaveMemberTrack,
  TrackMembershipNotFoundError,
  type MemberProfileRepository,
} from "../../../../../lib/profile/service";
import { SupabaseMemberProfileRepository } from "../../../../../lib/profile/supabase-repository";
import { extractBearerToken } from "../../../today/route";

export function createLeaveTrackHandler(dependencies: {
  getContext(request: Request): Promise<{
    userId: string;
    repository: MemberProfileRepository;
  } | null>;
}) {
  return async function POST(request: Request): Promise<Response> {
    const parsed = leaveTrackSchema.safeParse(await safeJson(request));
    if (!parsed.success) return jsonError(400, "invalid_leave_request");
    let context;
    try {
      context = await dependencies.getContext(request);
    } catch {
      return jsonError(500, "profile_unavailable");
    }
    if (!context) return jsonError(401, "unauthorized");
    try {
      const profile = await leaveMemberTrack(
        context.userId,
        parsed.data.trackId,
        context.repository,
      );
      return NextResponse.json(profile, {
        headers: { "Cache-Control": "no-store" },
      });
    } catch (error) {
      return jsonError(
        error instanceof TrackMembershipNotFoundError ? 409 : 500,
        error instanceof TrackMembershipNotFoundError
          ? "track_membership_inactive"
          : "profile_unavailable",
      );
    }
  };
}

export const POST = createLeaveTrackHandler({
  async getContext(request) {
    const token = extractBearerToken(request.headers.get("authorization"));
    const client = await createSupabaseServerClient(token ?? undefined);
    const auth = await client.auth.getClaims(token ?? undefined);
    const userId = auth.data?.claims?.sub;
    if (auth.error || typeof userId !== "string") return null;
    return {
      userId,
      repository: new SupabaseMemberProfileRepository(client),
    };
  },
});

async function safeJson(request: Request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}

function jsonError(status: number, error: string): Response {
  return NextResponse.json(
    { error },
    { status, headers: { "Cache-Control": "no-store" } },
  );
}
