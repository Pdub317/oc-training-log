import {
  programmingImportDraftSchema,
  trackCodeSchema,
} from "@oc-training-log/contracts";
import { parseProgrammingSource } from "@oc-training-log/domain";
import { NextResponse } from "next/server";
import { getAdminRequestContext } from "../../../../../lib/admin/authorization";
import {
  extractProgrammingSource,
  UnsupportedProgrammingFileError,
} from "../../../../../lib/programming/source-extraction";

export const runtime = "nodejs";

export async function POST(request: Request): Promise<Response> {
  const context = await getAdminRequestContext();
  if (!context) return jsonError(401, "unauthorized");

  let form: FormData;
  try {
    form = await request.formData();
  } catch {
    return jsonError(400, "invalid_form");
  }

  const trackCode = trackCodeSchema.safeParse(form.get("trackCode"));
  const defaultYear = Number(form.get("defaultYear"));
  if (
    !trackCode.success ||
    !Number.isInteger(defaultYear) ||
    defaultYear < 2020 ||
    defaultYear > 2100
  ) {
    return jsonError(400, "invalid_import_settings");
  }

  const fileValue = form.get("file");
  const file = fileValue instanceof File ? fileValue : null;
  let source;
  try {
    source = await extractProgrammingSource({
      pastedText: String(form.get("pastedText") ?? ""),
      file,
    });
  } catch (error) {
    if (error instanceof UnsupportedProgrammingFileError) {
      return jsonError(400, error.message);
    }
    return jsonError(400, "file_read_failed");
  }

  const { data: track } = await context.supabase
    .from("training_tracks")
    .select("id")
    .eq("gym_id", context.gymId)
    .eq("code", trackCode.data)
    .eq("status", "active")
    .maybeSingle();
  if (!track) return jsonError(404, "track_not_found");

  const draft = parseProgrammingSource({
    sourceText: source.sourceText,
    trackCode: trackCode.data,
    defaultYear,
  });
  if (draft.days.length === 0) {
    return NextResponse.json(
      { error: "no_dates_found", draft },
      { status: 422 },
    );
  }

  if (!programmingImportDraftSchema.safeParse(draft).success) {
    return jsonError(422, "invalid_parsed_draft");
  }

  const { data: created, error } = await context.supabase
    .from("program_imports")
    .insert({
      track_id: track.id,
      created_by: context.userId,
      source_type: source.sourceType,
      source_file_name: source.sourceFileName,
      raw_text: source.sourceText,
      parsed_payload: draft,
    })
    .select("id")
    .single();
  if (error || !created) return jsonError(500, "import_save_failed");

  return NextResponse.json({ importId: created.id, draft }, { status: 201 });
}

function jsonError(status: number, error: string) {
  return NextResponse.json({ error }, { status });
}
