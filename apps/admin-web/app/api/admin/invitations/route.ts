import { invitationActionSchema } from "@oc-training-log/contracts";
import { NextResponse } from "next/server";
import { getAdminRequestContext } from "../../../../lib/admin/authorization";
import { createJoinToken, joinUrl } from "../../../../lib/invitations/tokens";

export async function POST(request: Request): Promise<Response> {
  const admin = await getAdminRequestContext();
  if (!admin) return jsonError(401, "unauthorized");
  const parsed = invitationActionSchema.safeParse(await safeJson(request));
  if (!parsed.success) return jsonError(400, "invalid_invitation_request");

  const { data: track } = await admin.supabase
    .from("training_tracks")
    .select("id, name")
    .eq("gym_id", admin.gymId)
    .eq("code", parsed.data.trackCode)
    .eq("status", "active")
    .maybeSingle();
  if (!track) return jsonError(404, "track_not_found");

  if (parsed.data.kind === "share") {
    const now = new Date().toISOString();
    const { error: disableError } = await admin.supabase
      .from("share_links")
      .update({ enabled: false, disabled_at: now })
      .eq("track_id", track.id)
      .eq("enabled", true);
    if (disableError) return jsonError(500, "share_link_failed");

    const token = createJoinToken();
    const { data, error } = await admin.supabase
      .from("share_links")
      .insert({
        track_id: track.id,
        created_by: admin.userId,
        token_hash: token.tokenHash,
        token_hint: token.tokenHint,
      })
      .select("id, created_at")
      .single();
    if (error || !data) return jsonError(500, "share_link_failed");
    return NextResponse.json({
      shareLink: {
        id: data.id,
        trackCode: parsed.data.trackCode,
        trackName: track.name,
        tokenHint: token.tokenHint,
        createdAt: data.created_at,
        url: joinUrl(request.url, token.rawToken),
      },
    });
  }

  const emails = [...new Set(parsed.data.emails)];
  const { data: existing } = await admin.supabase
    .from("invitations")
    .select("id, email, send_count")
    .eq("track_id", track.id)
    .is("accepted_at", null)
    .is("revoked_at", null)
    .in("email", emails);
  const existingMap = new Map(
    (existing ?? []).map((item) => [String(item.email), item]),
  );
  const invitations = [];

  for (const email of emails) {
    const token = createJoinToken();
    const sentAt = new Date();
    const expiresAt = new Date(sentAt.getTime() + 7 * 24 * 60 * 60 * 1000);
    const current = existingMap.get(email);
    const mutation = current
      ? admin.supabase
          .from("invitations")
          .update({
            token_hash: token.tokenHash,
            expires_at: expiresAt.toISOString(),
            last_sent_at: sentAt.toISOString(),
            send_count: current.send_count + 1,
          })
          .eq("id", current.id)
          .select("id")
          .single()
      : admin.supabase
          .from("invitations")
          .insert({
            track_id: track.id,
            email,
            token_hash: token.tokenHash,
            created_by: admin.userId,
            expires_at: expiresAt.toISOString(),
            last_sent_at: sentAt.toISOString(),
          })
          .select("id")
          .single();
    const { data, error } = await mutation;
    if (error || !data) return jsonError(500, "invitation_save_failed");
    invitations.push({
      id: data.id,
      email,
      trackCode: parsed.data.trackCode,
      trackName: track.name,
      expiresAt: expiresAt.toISOString(),
      url: joinUrl(request.url, token.rawToken),
    });
  }

  return NextResponse.json({ invitations }, { status: 201 });
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
