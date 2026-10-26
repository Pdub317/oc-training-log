import { disableShareLinkSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { getAdminRequestContext } from "../../../../../lib/admin/authorization";

export async function PATCH(
  request: Request,
  context: { params: Promise<{ shareLinkId: string }> },
) {
  const admin = await getAdminRequestContext();
  if (!admin) return jsonError(401, "unauthorized");
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    body = null;
  }
  if (!disableShareLinkSchema.safeParse(body).success)
    return jsonError(400, "invalid_share_link_request");
  const { shareLinkId } = await context.params;
  const { data, error } = await admin.supabase
    .from("share_links")
    .update({ enabled: false, disabled_at: new Date().toISOString() })
    .eq("id", shareLinkId)
    .eq("enabled", true)
    .select("id")
    .maybeSingle();
  if (error) return jsonError(500, "share_link_failed");
  if (!data) return jsonError(404, "share_link_not_found");
  return NextResponse.json({ disabled: true });
}

function jsonError(status: number, error: string) {
  return NextResponse.json({ error }, { status });
}
