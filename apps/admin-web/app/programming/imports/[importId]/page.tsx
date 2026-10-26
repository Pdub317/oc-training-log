import { programmingImportDraftSchema } from "@oc-training-log/contracts";
import Link from "next/link";
import { notFound } from "next/navigation";
import { requireAdmin } from "../../../../lib/admin/authorization";
import { ProgrammingReview } from "./programming-review";

export const dynamic = "force-dynamic";

export default async function ProgrammingImportPage({
  params,
}: {
  params: Promise<{ importId: string }>;
}) {
  const admin = await requireAdmin();
  const { importId } = await params;
  const { data: item, error } = await admin.supabase
    .from("program_imports")
    .select("id, source_file_name, source_type, parse_status, parsed_payload")
    .eq("id", importId)
    .maybeSingle();
  if (error) {
    return (
      <ReviewUnavailable message="The saved draft could not be loaded. Please refresh and try again." />
    );
  }
  if (!item) notFound();
  const draft = programmingImportDraftSchema.safeParse(item.parsed_payload);
  if (!draft.success) {
    return (
      <ReviewUnavailable message="This saved draft contains programming that could not be opened for review. Your source is still saved. Return to programming and import a corrected copy, or ask for help recovering this draft." />
    );
  }

  return (
    <main className="shell programming-review-shell">
      <header className="masthead compact-masthead">
        <div>
          <p className="eyebrow">{draft.data.trackCode} programming · Review</p>
          <h1>{item.source_file_name || "Pasted programming"}</h1>
        </div>
        <Link className="text-button" href="/programming">
          Back to programming
        </Link>
      </header>
      <ProgrammingReview
        importId={item.id}
        initialDraft={draft.data}
        published={item.parse_status === "published"}
        sourceLabel={item.source_type}
      />
    </main>
  );
}

function ReviewUnavailable({ message }: { message: string }) {
  return (
    <main className="shell">
      <h1>Programming review unavailable</h1>
      <p role="alert">{message}</p>
      <Link href="/programming">Back to programming</Link>
    </main>
  );
}
