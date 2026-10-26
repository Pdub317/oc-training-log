import { editWorkoutRequestSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../../lib/supabase/server";
import {
  editWorkout,
  InvalidWorkoutEditError,
  WorkoutEditConflictError,
  WorkoutEditDataError,
  WorkoutEditDeniedError,
  type WorkoutEditingRepository,
} from "../../../../lib/workouts/editing";
import { SupabaseWorkoutEditingRepository } from "../../../../lib/workouts/supabase-editing-repository";

type Dependencies = {
  getRepository(request: Request): Promise<WorkoutEditingRepository | null>;
};

export function createEditWorkoutHandler(dependencies: Dependencies) {
  return async function PATCH(request: Request): Promise<Response> {
    let body: unknown;
    try {
      body = await request.json();
    } catch {
      return jsonError(400, "invalid_workout_edit");
    }
    const parsed = editWorkoutRequestSchema.safeParse(body);
    if (!parsed.success) return jsonError(400, "invalid_workout_edit");

    const repository = await dependencies.getRepository(request);
    if (!repository) return jsonError(401, "unauthorized");
    try {
      return NextResponse.json(await editWorkout(parsed.data, repository), {
        headers: noStoreHeaders,
      });
    } catch (error) {
      if (error instanceof WorkoutEditDeniedError) {
        return jsonError(403, "workout_edit_denied");
      }
      if (error instanceof InvalidWorkoutEditError) {
        return jsonError(400, "invalid_workout_edit");
      }
      if (error instanceof WorkoutEditConflictError) {
        return jsonError(409, "workout_edit_conflict");
      }
      if (error instanceof WorkoutEditDataError) {
        return jsonError(500, "workout_edit_unavailable");
      }
      return jsonError(500, "workout_edit_unavailable");
    }
  };
}

export const PATCH = createEditWorkoutHandler({
  async getRepository(request) {
    const token = request.headers
      .get("authorization")
      ?.match(/^Bearer ([^\s]+)$/i)?.[1];
    const client = await createSupabaseServerClient(token);
    const { data, error } = await client.auth.getClaims(token);
    if (error || typeof data?.claims?.sub !== "string") return null;
    return new SupabaseWorkoutEditingRepository(client);
  },
});

const noStoreHeaders = { "Cache-Control": "no-store" } as const;
function jsonError(status: number, error: string): Response {
  return NextResponse.json({ error }, { status, headers: noStoreHeaders });
}
