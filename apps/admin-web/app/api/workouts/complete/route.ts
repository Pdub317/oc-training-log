import { completeWorkoutRequestSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../../lib/supabase/server";
import {
  completeWorkout,
  InvalidWorkoutCompletionError,
  WorkoutCompletionConflictError,
  WorkoutCompletionDataError,
  WorkoutCompletionDeniedError,
  type WorkoutCompletionRepository,
} from "../../../../lib/workouts/completion";
import { SupabaseWorkoutCompletionRepository } from "../../../../lib/workouts/supabase-repository";

type RequestContext = { repository: WorkoutCompletionRepository };
type Dependencies = {
  getRequestContext(request: Request): Promise<RequestContext | null>;
};

export function createCompleteWorkoutHandler(dependencies: Dependencies) {
  return async function POST(request: Request): Promise<Response> {
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return jsonError(400, "invalid_completion");
    }

    const parsed = completeWorkoutRequestSchema.safeParse(body);
    if (!parsed.success) return jsonError(400, "invalid_completion");

    let context: RequestContext | null;
    try {
      context = await dependencies.getRequestContext(request);
    } catch {
      return jsonError(500, "completion_unavailable");
    }
    if (!context) return jsonError(401, "unauthorized");

    try {
      const response = await completeWorkout(parsed.data, context.repository);
      return NextResponse.json(response, { headers: noStoreHeaders });
    } catch (error) {
      if (error instanceof WorkoutCompletionDeniedError) {
        return jsonError(403, "workout_access_denied");
      }
      if (error instanceof InvalidWorkoutCompletionError) {
        return jsonError(400, "invalid_completion");
      }
      if (error instanceof WorkoutCompletionConflictError) {
        return jsonError(409, "completion_conflict");
      }
      if (error instanceof WorkoutCompletionDataError) {
        return jsonError(500, "completion_unavailable");
      }
      return jsonError(500, "completion_unavailable");
    }
  };
}

export const POST = createCompleteWorkoutHandler({
  async getRequestContext(request) {
    const accessToken = extractBearerToken(
      request.headers.get("authorization"),
    );
    const client = await createSupabaseServerClient(accessToken ?? undefined);
    const { data, error } = await client.auth.getClaims(
      accessToken ?? undefined,
    );
    if (error || typeof data?.claims?.sub !== "string") return null;
    return { repository: new SupabaseWorkoutCompletionRepository(client) };
  },
});

function extractBearerToken(authorization: string | null): string | null {
  return authorization?.match(/^Bearer ([^\s]+)$/i)?.[1] ?? null;
}

const noStoreHeaders = { "Cache-Control": "no-store" } as const;
function jsonError(status: number, error: string): Response {
  return NextResponse.json({ error }, { status, headers: noStoreHeaders });
}
