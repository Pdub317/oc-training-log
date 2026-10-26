import Link from "next/link";
import { requireAdmin } from "../../lib/admin/authorization";
import { signOut } from "../login/actions";
import { InvitationManager } from "./invitation-manager";

export const dynamic = "force-dynamic";

export default async function InvitationsPage() {
  const admin = await requireAdmin();
  const { data: tracks } = await admin.supabase
    .from("training_tracks")
    .select("id, code, name")
    .eq("gym_id", admin.gymId)
    .eq("status", "active")
    .order("code");
  const trackIds = (tracks ?? []).map((track) => track.id);
  const [{ data: invitations }, { data: shareLinks }] = await Promise.all([
    trackIds.length
      ? admin.supabase
          .from("invitations")
          .select(
            "id, track_id, email, expires_at, accepted_at, revoked_at, last_sent_at, send_count",
          )
          .in("track_id", trackIds)
          .order("last_sent_at", { ascending: false })
          .limit(100)
      : Promise.resolve({ data: [] }),
    trackIds.length
      ? admin.supabase
          .from("share_links")
          .select("id, track_id, token_hint, enabled, created_at")
          .in("track_id", trackIds)
          .eq("enabled", true)
      : Promise.resolve({ data: [] }),
  ]);
  const trackMap = new Map((tracks ?? []).map((track) => [track.id, track]));

  return (
    <main className="shell">
      <header className="masthead compact-masthead">
        <div>
          <p className="eyebrow">OC Gym Bend · Admin</p>
          <h1>Invitations</h1>
        </div>
        <div className="masthead-actions">
          <Link className="text-button" href="/">
            Dashboard
          </Link>
          <form action={signOut}>
            <button className="text-button" type="submit">
              Sign out
            </button>
          </form>
        </div>
      </header>
      <InvitationManager
        tracks={(tracks ?? []).map((track) => ({
          id: track.id,
          code: String(track.code),
          name: track.name,
        }))}
        initialInvitations={(invitations ?? []).map((invitation) => ({
          id: invitation.id,
          email: String(invitation.email),
          trackCode: String(trackMap.get(invitation.track_id)?.code ?? ""),
          trackName: trackMap.get(invitation.track_id)?.name ?? "Unknown track",
          expiresAt: invitation.expires_at,
          acceptedAt: invitation.accepted_at,
          revokedAt: invitation.revoked_at,
          lastSentAt: invitation.last_sent_at,
          sendCount: invitation.send_count,
        }))}
        initialShareLinks={(shareLinks ?? []).map((shareLink) => ({
          id: shareLink.id,
          trackCode: String(trackMap.get(shareLink.track_id)?.code ?? ""),
          trackName: trackMap.get(shareLink.track_id)?.name ?? "Unknown track",
          tokenHint: shareLink.token_hint,
          createdAt: shareLink.created_at,
        }))}
      />
    </main>
  );
}
