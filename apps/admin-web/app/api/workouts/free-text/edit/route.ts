import { editFreeTextWorkoutRequestSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../../../lib/supabase/server";
import {
  editFreeTextWorkout,
  InvalidWorkoutEditError,
  WorkoutEditConflictError,
  WorkoutEditDataError,
  WorkoutEditDeniedError,
  type FreeTextWorkoutEditingRepository,
} from "../../../../../lib/workouts/free-text-editing";
import { SupabaseFreeTextWorkoutEditingRepository } from "../../../../../lib/workouts/supabase-free-text-editing-repository";

type Dependencies = {
  getRepository(
    request: Request,
  ): Promise<FreeTextWorkoutEditingRepository | null>;
};

export function createEditFreeTextWorkoutHandler(dependencies: Dependencies) {
  return async function PATCH(request: Request): Promise<Response> {
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return jsonError(400, "invalid_workout_edit");
    }
    const parsed = editFreeTextWorkoutRequestSchema.safeParse(body);
    if (!parsed.success) return jsonError(400, "invalid_workout_edit");
    const repository = await dependencies.getRepository(request);
    if (!repository) return jsonError(401, "unauthorized");
    try {
      return NextResponse.json(
        await editFreeTextWorkout(parsed.data, repository),
        { headers: noStoreHeaders },
      );
    } catch (error) {
      if (error instanceof WorkoutEditDeniedError)
        return jsonError(403, "workout_edit_denied");
      if (error instanceof InvalidWorkoutEditError)
        return jsonError(400, "invalid_workout_edit");
      if (error instanceof WorkoutEditConflictError)
        return jsonError(409, "workout_edit_conflict");
      if (error instanceof WorkoutEditDataError)
        return jsonError(500, "workout_edit_unavailable");
      return jsonError(500, "workout_edit_unavailable");
    }
  };
}

export const PATCH = createEditFreeTextWorkoutHandler({
  async getRepository(request) {
    const token = request.headers
      .get("authorization")
      ?.match(/^Bearer ([^\s]+)$/i)?.[1];
    const client = await createSupabaseServerClient(token);
    const { data, error } = await client.auth.getClaims(token);
    if (error || typeof data?.claims?.sub !== "string") return null;
    return new SupabaseFreeTextWorkoutEditingRepository(client);
  },
});

const noStoreHeaders = { "Cache-Control": "no-store" } as const;
function jsonError(status: number, error: string): Response {
  return NextResponse.json({ error }, { status, headers: noStoreHeaders });
}
