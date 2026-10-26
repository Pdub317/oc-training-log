import { acceptInvitationSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../../lib/supabase/server";

export async function POST(request: Request): Promise<Response> {
  const parsed = acceptInvitationSchema.safeParse(await safeJson(request));
  if (!parsed.success) return jsonError(400, "invalid_invitation");
  const supabase = await createSupabaseServerClient();
  const { data: claims } = await supabase.auth.getClaims();
  if (!claims?.claims?.sub) return jsonError(401, "authentication_required");
  const { error: metadataError } = await supabase.auth.updateUser({
    data: {
      age_13_attested: true,
      terms_accepted: true,
      privacy_accepted: true,
    },
  });
  if (metadataError) return jsonError(500, "account_update_failed");
  const { data, error } = await supabase.rpc("accept_join_token", {
    raw_token: parsed.data.token,
  });
  if (error)
    return jsonError(
      400,
      error.message.includes("verified_email")
        ? "verification_required"
        : "invitation_unavailable",
    );
  return NextResponse.json({ state: "joined", membership: data?.[0] });
}

async function safeJson(request: Request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}
function jsonError(status: number, error: string) {
  return NextResponse.json({ error }, { status });
}
