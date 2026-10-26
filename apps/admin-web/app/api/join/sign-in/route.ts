import { signInFromInvitationSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../../lib/supabase/server";

export async function POST(request: Request): Promise<Response> {
  const parsed = signInFromInvitationSchema.safeParse(await safeJson(request));
  if (!parsed.success) return jsonError(400, "invalid_sign_in");
  const supabase = await createSupabaseServerClient();
  const { error: signInError } = await supabase.auth.signInWithPassword({
    email: parsed.data.email,
    password: parsed.data.password,
  });
  if (signInError) return jsonError(401, "invalid_credentials");

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
  if (error) {
    await supabase.auth.signOut();
    if (error.message.includes("email_mismatch"))
      return jsonError(403, "invitation_email_mismatch");
    return jsonError(400, "invitation_unavailable");
  }
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
