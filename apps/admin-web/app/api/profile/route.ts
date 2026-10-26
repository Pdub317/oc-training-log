import { updateMemberProfileSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { extractBearerToken } from "../today/route";
import { createSupabaseServerClient } from "../../../lib/supabase/server";
import {
  getMemberProfile,
  MemberProfileDataError,
  updateMemberProfile,
  type MemberProfileRepository,
} from "../../../lib/profile/service";
import { SupabaseMemberProfileRepository } from "../../../lib/profile/supabase-repository";

type Context = { userId: string; repository: MemberProfileRepository };
type Dependencies = { getContext(request: Request): Promise<Context | null> };

export function createProfileHandlers(dependencies: Dependencies) {
  return {
    async GET(request: Request): Promise<Response> {
      const context = await safeContext(dependencies, request);
      if (!context) return jsonError(401, "unauthorized");
      try {
        return json(await getMemberProfile(context.userId, context.repository));
      } catch {
        return jsonError(500, "profile_unavailable");
      }
    },

    async PATCH(request: Request): Promise<Response> {
      const parsed = updateMemberProfileSchema.safeParse(
        await safeJson(request),
      );
      if (!parsed.success) return jsonError(400, "invalid_profile");
      const context = await safeContext(dependencies, request);
      if (!context) return jsonError(401, "unauthorized");
      try {
        return json(
          await updateMemberProfile(
            context.userId,
            parsed.data,
            context.repository,
          ),
        );
      } catch (error) {
        return jsonError(
          error instanceof MemberProfileDataError ? 400 : 500,
          error instanceof MemberProfileDataError
            ? "invalid_profile"
            : "profile_unavailable",
        );
      }
    },
  };
}

const handlers = createProfileHandlers({ getContext: requestContext });
export const GET = handlers.GET;
export const PATCH = handlers.PATCH;

async function requestContext(request: Request): Promise<Context | null> {
  const token = extractBearerToken(request.headers.get("authorization"));
  const client = await createSupabaseServerClient(token ?? undefined);
  const auth = await client.auth.getClaims(token ?? undefined);
  const userId = auth.data?.claims?.sub;
  if (auth.error || typeof userId !== "string") return null;
  return { userId, repository: new SupabaseMemberProfileRepository(client) };
}

async function safeContext(dependencies: Dependencies, request: Request) {
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
