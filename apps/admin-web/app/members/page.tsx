import Link from "next/link";
import { requireAdmin } from "../../lib/admin/authorization";
import { loadAdminMemberDirectory } from "../../lib/admin/member-data";
import { signOut } from "../login/actions";

export const dynamic = "force-dynamic";

type MembersPageProps = {
  searchParams: Promise<{ track?: string }>;
};

export default async function MembersPage({ searchParams }: MembersPageProps) {
  const { supabase, gymId } = await requireAdmin();
  const members = await loadAdminMemberDirectory(supabase, gymId);
  const { track } = await searchParams;
  const selectedTrack =
    track && members.some((member) => member.trackCode === track)
      ? track
      : undefined;
  const visibleMembers = selectedTrack
    ? members.filter((member) => member.trackCode === selectedTrack)
    : members;
  const tracks = [
    ...new Map(
      members.map((member) => [
        member.trackCode,
        {
          code: member.trackCode,
          name: member.trackName,
        },
      ]),
    ).values(),
  ];

  return (
    <main className="shell">
      <AdminHeader />
      <nav aria-label="Breadcrumb" className="breadcrumb">
        <Link href="/">Dashboard</Link>
        <span aria-hidden="true">/</span>
        <span>Members</span>
      </nav>

      <section aria-labelledby="members-heading" className="panel">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Member directory</p>
            <h2 id="members-heading">Active members</h2>
          </div>
          <p>Select a member to review workout history and personal records.</p>
        </div>

        <nav aria-label="Filter members by track" className="filter-row">
          <Link
            className={!selectedTrack ? "filter-chip active" : "filter-chip"}
            href="/members"
          >
            All tracks
          </Link>
          {tracks.map((item) => (
            <Link
              className={
                selectedTrack === item.code
                  ? "filter-chip active"
                  : "filter-chip"
              }
              href={`/members?track=${item.code}`}
              key={item.code}
            >
              {item.code} · {item.name}
            </Link>
          ))}
        </nav>

        {visibleMembers.length ? (
          <div className="member-list">
            {visibleMembers.map((member) => (
              <Link
                className="member-row"
                href={`/members/${member.memberId}?track=${member.trackCode}`}
                key={`${member.memberId}:${member.trackId}`}
              >
                <span aria-hidden="true" className="avatar">
                  {member.firstName.slice(0, 1)}
                  {member.lastName.slice(0, 1)}
                </span>
                <span className="member-identity">
                  <strong>
                    {member.firstName} {member.lastName}
                  </strong>
                  <span>{member.email}</span>
                </span>
                <span className="track-pill">{member.trackCode}</span>
                <span aria-hidden="true" className="row-arrow">
                  →
                </span>
              </Link>
            ))}
          </div>
        ) : (
          <div className="empty-state">
            <h3>No active members</h3>
            <p>
              Members will appear here after joining an active training track.
            </p>
          </div>
        )}
      </section>
    </main>
  );
}

function AdminHeader() {
  return (
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
  );
}
