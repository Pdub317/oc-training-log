import { createSupabaseServerClient } from "../../lib/supabase/server";
import { JoinForm } from "./join-form";

export const dynamic = "force-dynamic";

export default async function JoinPage({
  searchParams,
}: {
  searchParams: Promise<{ token?: string; mode?: string }>;
}) {
  const { token, mode } = await searchParams;
  let invitation: {
    join_kind: string;
    gym_name: string;
    track_code: string;
    track_name: string;
    expires_at: string | null;
    invited_email_hint: string | null;
  } | null = null;
  let signedIn = false;
  if (token && token.length <= 200) {
    const supabase = await createSupabaseServerClient();
    const [{ data }, { data: claims }] = await Promise.all([
      supabase.rpc("resolve_join_token", { raw_token: token }),
      supabase.auth.getClaims(),
    ]);
    invitation = data?.[0] ?? null;
    signedIn = Boolean(claims?.claims?.sub);
  }

  return (
    <main className="join-shell">
      <section className="join-card">
        <p className="eyebrow">OC Gym Bend</p>
        {invitation && token ? (
          <>
            <span className="join-track-code">{invitation.track_code}</span>
            <h1>You’re invited.</h1>
            <p className="join-intro">
              Join <strong>{invitation.gym_name}</strong> on the{" "}
              <strong>{invitation.track_name}</strong> training track.
            </p>
            {invitation.invited_email_hint ? (
              <p className="invite-detail">
                This invitation is reserved for{" "}
                <strong>{invitation.invited_email_hint}</strong>.
              </p>
            ) : (
              <p className="invite-detail">
                This is a reusable {invitation.track_name} signup link.
              </p>
            )}
            {invitation.expires_at ? (
              <p className="invite-expiry">
                Valid through{" "}
                {new Intl.DateTimeFormat("en-US", {
                  dateStyle: "long",
                  timeStyle: "short",
                }).format(new Date(invitation.expires_at))}
              </p>
            ) : null}
            <JoinForm
              defaultMode={mode === "signin" ? "signin" : "register"}
              signedIn={signedIn}
              token={token}
              trackName={invitation.track_name}
            />
          </>
        ) : (
          <>
            <h1>Link unavailable.</h1>
            <p className="join-intro">
              This invitation may have expired, been refreshed, or been
              disabled. Ask an OC Gym Bend coach for a new link.
            </p>
          </>
        )}
      </section>
    </main>
  );
}
