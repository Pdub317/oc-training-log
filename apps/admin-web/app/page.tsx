import { TRACKS } from "@oc-training-log/domain";
import Link from "next/link";
import { requireAdmin } from "../lib/admin/authorization";
import { loadAdminMemberDirectory } from "../lib/admin/member-data";
import { signOut } from "./login/actions";

export const dynamic = "force-dynamic";

export default async function HomePage() {
  const { supabase, gymId } = await requireAdmin();
  const members = await loadAdminMemberDirectory(supabase, gymId);

  return (
    <main className="shell">
      <header className="masthead">
        <div>
          <p className="eyebrow">OC Gym Bend</p>
          <h1>Training Log Admin</h1>
        </div>
        <div className="masthead-actions">
          <span className="status">Authenticated admin</span>
          <Link className="primary-button compact-button" href="/programming">
            Add programming
          </Link>
          <Link className="text-button" href="/invitations">
            Manage invitations
          </Link>
          <form action={signOut}>
            <button className="text-button" type="submit">
              Sign out
            </button>
          </form>
        </div>
      </header>

      <section aria-labelledby="tracks-heading" className="panel">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Initial workspace</p>
            <h2 id="tracks-heading">Training tracks</h2>
          </div>
          <div className="section-heading-actions">
            <p>Member data and programming remain isolated by track.</p>
            <Link className="text-link" href="/programming">
              Manage all programming →
            </Link>
          </div>
        </div>

        <div className="track-grid">
          {TRACKS.map((track) => (
            <Link
              className="track-card track-card-link"
              href={`/members?track=${track.code}`}
              key={track.code}
            >
              <span aria-hidden="true" className="track-code">
                {track.code}
              </span>
              <div>
                <h3>{track.name}</h3>
                <p>
                  {
                    members.filter((member) => member.trackCode === track.code)
                      .length
                  }{" "}
                  active members · View roster
                </p>
              </div>
            </Link>
          ))}
        </div>
      </section>
    </main>
  );
}
