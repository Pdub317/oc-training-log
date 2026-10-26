import { resendInvitationSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { getAdminRequestContext } from "../../../../../../lib/admin/authorization";
import {
  createJoinToken,
  joinUrl,
} from "../../../../../../lib/invitations/tokens";

export async function POST(
  request: Request,
  context: { params: Promise<{ invitationId: string }> },
) {
  const admin = await getAdminRequestContext();
  if (!admin) return jsonError(401, "unauthorized");
  if (!resendInvitationSchema.safeParse(await safeJson(request)).success) {
    return jsonError(400, "invalid_invitation_request");
  }
  const { invitationId } = await context.params;
  const { data: invitation } = await admin.supabase
    .from("invitations")
    .select("id, email, send_count, track_id, training_tracks(code, name)")
    .eq("id", invitationId)
    .is("accepted_at", null)
    .is("revoked_at", null)
    .maybeSingle();
  if (!invitation) return jsonError(404, "invitation_not_found");

  const token = createJoinToken();
  const sentAt = new Date();
  const expiresAt = new Date(sentAt.getTime() + 7 * 24 * 60 * 60 * 1000);
  const { error } = await admin.supabase
    .from("invitations")
    .update({
      token_hash: token.tokenHash,
      expires_at: expiresAt.toISOString(),
      last_sent_at: sentAt.toISOString(),
      send_count: invitation.send_count + 1,
    })
    .eq("id", invitation.id);
  if (error) return jsonError(500, "invitation_save_failed");
  const track = Array.isArray(invitation.training_tracks)
    ? invitation.training_tracks[0]
    : invitation.training_tracks;
  return NextResponse.json({
    invitation: {
      id: invitation.id,
      email: invitation.email,
      trackCode: track?.code,
      trackName: track?.name,
      expiresAt: expiresAt.toISOString(),
      url: joinUrl(request.url, token.rawToken),
    },
  });
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
