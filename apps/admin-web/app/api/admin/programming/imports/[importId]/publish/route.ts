import { publishProgrammingImportRequestSchema } from "@oc-training-log/contracts";
import { programmingDraftBlockingIssues } from "@oc-training-log/domain";
import { NextResponse } from "next/server";
import { getAdminRequestContext } from "../../../../../../../lib/admin/authorization";

export async function POST(
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
  const parsed = publishProgrammingImportRequestSchema.safeParse(body);
  if (!parsed.success) return jsonError(400, "invalid_programming_draft");
  const issues = programmingDraftBlockingIssues(parsed.data.draft);
  if (issues.length) {
    return NextResponse.json(
      { error: "review_required", issues },
      { status: 409 },
    );
  }

  const { data, error } = await admin.supabase.rpc("publish_program_import", {
    target_import_id: importId,
    draft: parsed.data.draft,
  });
  if (error) {
    if (error.message.includes("already_published")) {
      return jsonError(409, "already_published");
    }
    return jsonError(400, "publication_failed");
  }
  return NextResponse.json(data);
}

function jsonError(status: number, error: string) {
  return NextResponse.json({ error }, { status });
}
