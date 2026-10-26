import Link from "next/link";
import { requireAdmin } from "../../lib/admin/authorization";
import { signOut } from "../login/actions";

export const dynamic = "force-dynamic";

export default async function ProgrammingPage({
  searchParams,
}: {
  searchParams: Promise<{ published?: string }>;
}) {
  const admin = await requireAdmin();
  const { published } = await searchParams;
  const { data: tracks } = await admin.supabase
    .from("training_tracks")
    .select("id, code, name")
    .eq("gym_id", admin.gymId)
    .eq("status", "active")
    .order("code");
  const trackIds = (tracks ?? []).map((track) => track.id);
  const [{ data: imports }, { data: days }] = await Promise.all([
    trackIds.length
      ? admin.supabase
          .from("program_imports")
          .select(
            "id, track_id, source_type, source_file_name, parse_status, created_at",
          )
          .in("track_id", trackIds)
          .order("created_at", { ascending: false })
          .limit(20)
      : Promise.resolve({ data: [] }),
    trackIds.length
      ? admin.supabase
          .from("programming_days")
          .select("track_id, workout_date")
          .in("track_id", trackIds)
          .eq("status", "published")
          .gte("workout_date", new Date().toISOString().slice(0, 10))
      : Promise.resolve({ data: [] }),
  ]);
  const trackMap = new Map((tracks ?? []).map((track) => [track.id, track]));

  return (
    <main className="shell">
      <header className="masthead compact-masthead">
        <div>
          <p className="eyebrow">OC Gym Bend · Admin</p>
          <h1>Programming</h1>
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

      {published ? (
        <p className="success-banner" role="status">
          Published {published} programming {published === "1" ? "day" : "days"}
          . Members can now see them on their track.
        </p>
      ) : null}

      <section className="panel" aria-labelledby="add-programming-heading">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Start here</p>
            <h2 id="add-programming-heading">Add programming</h2>
          </div>
          <p>
            Choose the track first. Nothing reaches members until you review and
            publish it.
          </p>
        </div>
        <div className="track-grid">
          {(tracks ?? []).map((track) => {
            const upcoming = (days ?? []).filter(
              (day) => day.track_id === track.id,
            ).length;
            return (
              <Link
                className="track-card track-card-link"
                href={`/programming/new?track=${track.code}`}
                key={track.id}
              >
                <span className="track-code" aria-hidden="true">
                  {track.code}
                </span>
                <div>
                  <h3>Add {track.name}</h3>
                  <p>
                    {upcoming} upcoming published{" "}
                    {upcoming === 1 ? "day" : "days"}
                  </p>
                </div>
              </Link>
            );
          })}
        </div>
      </section>

      <section className="panel" aria-labelledby="imports-heading">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Saved work</p>
            <h2 id="imports-heading">Recent imports</h2>
          </div>
          <p>Open a review draft where you left off.</p>
        </div>
        {(imports ?? []).length ? (
          <div className="import-list">
            {(imports ?? []).map((item) => {
              const track = trackMap.get(item.track_id);
              return (
                <Link
                  className="import-row"
                  href={`/programming/imports/${item.id}`}
                  key={item.id}
                >
                  <span className="track-pill">{track?.code ?? "—"}</span>
                  <span>
                    <strong>
                      {item.source_file_name || "Pasted programming"}
                    </strong>
                    <small>
                      {item.source_type} ·{" "}
                      {new Date(item.created_at).toLocaleString()}
                    </small>
                  </span>
                  <span className={`review-status ${item.parse_status}`}>
                    {item.parse_status}
                  </span>
                  <span aria-hidden="true">→</span>
                </Link>
              );
            })}
          </div>
        ) : (
          <div className="empty-state">
            <h3>No imports yet</h3>
            <p>Your saved programming drafts will appear here.</p>
          </div>
        )}
      </section>
    </main>
  );
}
