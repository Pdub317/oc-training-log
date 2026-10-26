import Link from "next/link";
import { notFound } from "next/navigation";
import { requireAdmin } from "../../../lib/admin/authorization";
import { loadAdminMemberDetail } from "../../../lib/admin/member-data";
import { signOut } from "../../login/actions";

export const dynamic = "force-dynamic";

type MemberDetailPageProps = {
  params: Promise<{ memberId: string }>;
  searchParams: Promise<{ track?: string }>;
};

export default async function MemberDetailPage({
  params,
  searchParams,
}: MemberDetailPageProps) {
  const [{ memberId }, { track }] = await Promise.all([params, searchParams]);
  if (!/^[0-9a-f-]{36}$/i.test(memberId)) notFound();
  const { supabase, gymId } = await requireAdmin();
  const detail = await loadAdminMemberDetail(supabase, gymId, memberId, track);
  if (!detail) notFound();

  return (
    <main className="shell">
      <header className="masthead compact-masthead">
        <div>
          <p className="eyebrow">OC Gym Bend</p>
          <h1>Training Log Admin</h1>
        </div>
        <form action={signOut}>
          <button className="text-button" type="submit">
            Sign out
          </button>
        </form>
      </header>

      <nav aria-label="Breadcrumb" className="breadcrumb">
        <Link href="/">Dashboard</Link>
        <span aria-hidden="true">/</span>
        <Link href={`/members?track=${detail.selectedTrack.code}`}>
          Members
        </Link>
        <span aria-hidden="true">/</span>
        <span>
          {detail.member.firstName} {detail.member.lastName}
        </span>
      </nav>

      <section className="member-hero">
        <span aria-hidden="true" className="avatar avatar-large">
          {detail.member.firstName.slice(0, 1)}
          {detail.member.lastName.slice(0, 1)}
        </span>
        <div>
          <p className="eyebrow">Member progress</p>
          <h2>
            {detail.member.firstName} {detail.member.lastName}
          </h2>
          <p>{detail.member.email}</p>
        </div>
      </section>

      {detail.tracks.length > 1 ? (
        <nav
          aria-label="Select member track"
          className="filter-row member-track-filter"
        >
          {detail.tracks.map((item) => (
            <Link
              className={
                detail.selectedTrack.code === item.code
                  ? "filter-chip active"
                  : "filter-chip"
              }
              href={`/members/${detail.member.id}?track=${item.code}`}
              key={item.id}
            >
              {item.code} · {item.name}
            </Link>
          ))}
        </nav>
      ) : null}

      <div className="detail-grid">
        <section
          aria-labelledby="history-heading"
          className="panel detail-panel"
        >
          <div className="section-heading">
            <div>
              <p className="eyebrow">{detail.selectedTrack.code}</p>
              <h2 id="history-heading">Workout history</h2>
            </div>
            <p>Latest 50 completed workouts</p>
          </div>
          {detail.workouts.length ? (
            <div className="workout-list">
              {detail.workouts.map((workout) => (
                <article className="workout-card" key={workout.id}>
                  <div className="workout-heading">
                    <div>
                      <time dateTime={workout.date}>
                        {formatDate(workout.date)}
                      </time>
                      <h3>{workout.title}</h3>
                    </div>
                    {workout.results.some((result) => result.isPR) ? (
                      <span className="pr-badge">PR</span>
                    ) : null}
                  </div>
                  {workout.results.length ? (
                    <dl className="result-list">
                      {workout.results.map((result) => (
                        <div key={result.id}>
                          <dt>{result.name}</dt>
                          <dd>
                            {result.value}
                            {result.isPR ? " · PR" : ""}
                          </dd>
                          <p>{result.prescription}</p>
                        </div>
                      ))}
                    </dl>
                  ) : null}
                  {workout.notes ? (
                    <p className="workout-notes">
                      <strong>Notes:</strong> {workout.notes}
                    </p>
                  ) : null}
                </article>
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <h3>No workouts yet</h3>
              <p>Completed workouts will appear here.</p>
            </div>
          )}
        </section>

        <section
          aria-labelledby="records-heading"
          className="panel detail-panel"
        >
          <div className="section-heading">
            <div>
              <p className="eyebrow">Progress</p>
              <h2 id="records-heading">Personal records</h2>
            </div>
            <p>Read-only PR progression</p>
          </div>
          {detail.personalRecords.length ? (
            <div className="record-list">
              {detail.personalRecords.map((record) => (
                <article className="record-row" key={record.id}>
                  <div>
                    <h3>{record.benchmarkLabel}</h3>
                    <time dateTime={record.achievedAt}>
                      {formatDate(record.achievedAt)}
                    </time>
                  </div>
                  <strong>{record.value}</strong>
                </article>
              ))}
            </div>
          ) : (
            <div className="empty-state">
              <h3>No personal records yet</h3>
              <p>Benchmark results will appear here as they are recorded.</p>
            </div>
          )}
        </section>
      </div>
    </main>
  );
}

function formatDate(value: string) {
  const dateOnly = value.slice(0, 10);
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
    timeZone: "UTC",
  }).format(new Date(`${dateOnly}T00:00:00Z`));
}
