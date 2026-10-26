import { programmingImportDraftSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { getAdminRequestContext } from "../../../../../../lib/admin/authorization";

export async function PATCH(
  request: Request,
  context: { params: Promise<{ importId: string }> },
): Promise<Response> {
  const admin = await getAdminRequestContext();
  if (!admin) return jsonError(401, "unauthorized");
  const { importId } = await context.params;
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonError(400, "invalid_json");
  }
  const parsed = programmingImportDraftSchema.safeParse(
    (body as { draft?: unknown })?.draft,
  );
  if (!parsed.success) return jsonError(400, "invalid_programming_draft");

  const { data, error } = await admin.supabase
    .from("program_imports")
    .update({ parsed_payload: parsed.data })
    .eq("id", importId)
    .eq("parse_status", "review")
    .select("id")
    .maybeSingle();
  if (error) return jsonError(500, "draft_save_failed");
  if (!data) return jsonError(404, "import_not_found");
  return NextResponse.json({ saved: true });
}

function jsonError(status: number, error: string) {
  return NextResponse.json({ error }, { status });
}
