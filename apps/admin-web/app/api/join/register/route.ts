import { registerFromInvitationSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { createSupabaseServerClient } from "../../../../lib/supabase/server";

export async function POST(request: Request): Promise<Response> {
  const parsed = registerFromInvitationSchema.safeParse(
    await safeJson(request),
  );
  if (!parsed.success) return jsonError(400, "invalid_registration");
  const supabase = await createSupabaseServerClient();
  const { data: tokenAllowed, error: tokenError } = await supabase.rpc(
    "can_register_join_token",
    { raw_token: parsed.data.token, candidate_email: parsed.data.email },
  );
  if (tokenError || !tokenAllowed)
    return jsonError(403, "invitation_email_mismatch");

  const origin = new URL(request.url).origin;
  const next = `/join/complete?token=${encodeURIComponent(parsed.data.token)}`;
  const { data, error } = await supabase.auth.signUp({
    email: parsed.data.email,
    password: parsed.data.password,
    options: {
      emailRedirectTo: `${origin}/auth/callback?next=${encodeURIComponent(next)}`,
      data: {
        first_name: parsed.data.firstName,
        last_name: parsed.data.lastName,
        age_13_attested: true,
        terms_accepted: true,
        privacy_accepted: true,
      },
    },
  });
  if (error) return jsonError(400, "registration_failed");
  if (data.user?.identities?.length === 0)
    return jsonError(409, "account_exists");

  if (data.session) {
    const accepted = await supabase.rpc("accept_join_token", {
      raw_token: parsed.data.token,
    });
    if (accepted.error)
      return jsonError(400, mapAcceptanceError(accepted.error.message));
    return NextResponse.json({
      state: "joined",
      membership: accepted.data?.[0],
    });
  }
  return NextResponse.json(
    { state: "verification_required", email: parsed.data.email },
    { status: 201 },
  );
}

async function safeJson(request: Request) {
  try {
    return await request.json();
  } catch {
    return null;
  }
}
function mapAcceptanceError(message: string) {
  if (message.includes("email_mismatch")) return "invitation_email_mismatch";
  if (message.includes("verified_email")) return "verification_required";
  return "invitation_unavailable";
}
function jsonError(status: number, error: string) {
  return NextResponse.json({ error }, { status });
}
