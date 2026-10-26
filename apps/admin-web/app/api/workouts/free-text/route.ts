import { freeTextWorkoutRequestSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../../lib/supabase/server";
import {
  completeFreeTextWorkout,
  InvalidWorkoutCompletionError,
  WorkoutCompletionConflictError,
  WorkoutCompletionDataError,
  WorkoutCompletionDeniedError,
  type FreeTextWorkoutRepository,
} from "../../../../lib/workouts/free-text";
import { SupabaseFreeTextWorkoutRepository } from "../../../../lib/workouts/supabase-free-text-repository";

type Dependencies = {
  getRepository(request: Request): Promise<FreeTextWorkoutRepository | null>;
};

export function createFreeTextWorkoutHandler(dependencies: Dependencies) {
  return async function POST(request: Request): Promise<Response> {
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return jsonError(400, "invalid_completion");
    }
    const parsed = freeTextWorkoutRequestSchema.safeParse(body);
    if (!parsed.success) return jsonError(400, "invalid_completion");
    const repository = await dependencies.getRepository(request);
    if (!repository) return jsonError(401, "unauthorized");
    try {
      return NextResponse.json(
        await completeFreeTextWorkout(parsed.data, repository),
        { headers: noStoreHeaders },
      );
    } catch (error) {
      if (error instanceof WorkoutCompletionDeniedError)
        return jsonError(403, "workout_access_denied");
      if (error instanceof InvalidWorkoutCompletionError)
        return jsonError(400, "invalid_completion");
      if (error instanceof WorkoutCompletionConflictError)
        return jsonError(409, "completion_conflict");
      if (error instanceof WorkoutCompletionDataError)
        return jsonError(500, "completion_unavailable");
      return jsonError(500, "completion_unavailable");
    }
  };
}

export const POST = createFreeTextWorkoutHandler({
  async getRepository(request) {
    const token = request.headers
      .get("authorization")
      ?.match(/^Bearer ([^\s]+)$/i)?.[1];
    const client = await createSupabaseServerClient(token);
    const { data, error } = await client.auth.getClaims(token);
    if (error || typeof data?.claims?.sub !== "string") return null;
    return new SupabaseFreeTextWorkoutRepository(client);
  },
});

const noStoreHeaders = { "Cache-Control": "no-store" } as const;
function jsonError(status: number, error: string): Response {
  return NextResponse.json({ error }, { status, headers: noStoreHeaders });
}
