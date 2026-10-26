import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "../../../lib/supabase/server";

export const dynamic = "force-dynamic";

export default async function CompleteJoinPage({
  searchParams,
}: {
  searchParams: Promise<{ token?: string }>;
}) {
  const { token } = await searchParams;
  if (!token || token.length > 200) redirect("/join");
  const supabase = await createSupabaseServerClient();
  const { data: claims } = await supabase.auth.getClaims();
  if (!claims?.claims?.sub)
    redirect(`/join?token=${encodeURIComponent(token)}&mode=signin`);
  const { data, error } = await supabase.rpc("accept_join_token", {
    raw_token: token,
  });
  const membership = data?.[0];
  return (
    <main className="join-shell">
      <section className="join-card">
        <p className="eyebrow">OC Gym Bend</p>
        {error || !membership ? (
          <>
            <h1>Unable to join.</h1>
            <p className="join-intro">
              The invitation is no longer available. Ask a coach to refresh it.
            </p>
          </>
        ) : (
          <>
            <span className="join-track-code">{membership.track_code}</span>
            <h1>You’re in.</h1>
            <p className="join-intro">
              Your account is now connected to{" "}
              <strong>{membership.gym_name}</strong> ·{" "}
              <strong>{membership.track_name}</strong>.
            </p>
            <div className="next-step-card">
              <strong>Open the iPhone app</strong>
              <p>
                Sign in with this verified email and password to see your track
                programming.
              </p>
            </div>
          </>
        )}
      </section>
    </main>
  );
}
