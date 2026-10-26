import Link from "next/link";
import { requireAdmin } from "../../../lib/admin/authorization";
import { NewProgrammingImportForm } from "./new-programming-import-form";

export const dynamic = "force-dynamic";

export default async function NewProgrammingPage({
  searchParams,
}: {
  searchParams: Promise<{ track?: string }>;
}) {
  await requireAdmin();
  const { track } = await searchParams;
  const initialTrack = track === "SP" ? "SP" : "GP";
  return (
    <main className="shell">
      <header className="masthead compact-masthead">
        <div>
          <p className="eyebrow">Add programming</p>
          <h1>Bring in a workout plan</h1>
        </div>
        <Link className="text-button" href="/programming">
          Back to programming
        </Link>
      </header>
      <NewProgrammingImportForm initialTrack={initialTrack} />
    </main>
  );
}
