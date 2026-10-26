"use client";

import type { FormEvent } from "react";
import { useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";

const errorMessages: Record<string, string> = {
  empty_source: "Paste programming or choose a file first.",
  file_too_large: "That file is larger than 5 MB.",
  unsupported_file_type:
    "Use a Word (.docx), text, CSV/TSV, or Excel (.xlsx) file.",
  file_read_failed:
    "The file could not be read. Try saving it again or paste the text instead.",
  no_dates_found:
    "No date headings were found. Add a date such as “Tuesday, September 8, 2026.”",
  invalid_parsed_draft:
    "The parsed programming needs correction before it can be reviewed. Check for dates without workouts or unusually long sections, then try again. Your uploaded file has not been changed.",
  import_save_failed: "The draft could not be saved. Please try again.",
};

export function NewProgrammingImportForm({
  initialTrack,
}: {
  initialTrack: "SP" | "GP";
}) {
  const router = useRouter();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      const response = await fetch("/api/admin/programming/imports", {
        method: "POST",
        body: new FormData(event.currentTarget),
      });
      const body = (await response.json()) as {
        error?: string;
        importId?: string;
      };
      if (!response.ok || !body.importId) {
        setError(
          errorMessages[body.error ?? ""] ??
            "The programming could not be imported.",
        );
        return;
      }
      router.push(`/programming/imports/${body.importId}`);
    } catch {
      setError(
        "The programming could not be imported. Check the local server and try again.",
      );
    } finally {
      setBusy(false);
    }
  }

  return (
    <form className="panel programming-source-form" onSubmit={submit}>
      <div className="form-grid two-column-form">
        <label>
          Training track
          <select name="trackCode" defaultValue={initialTrack}>
            <option value="SP">Sports Performance (SP)</option>
            <option value="GP">General Population (GP)</option>
          </select>
        </label>
        <label>
          Year for dates that omit it
          <input
            name="defaultYear"
            type="number"
            min="2020"
            max="2100"
            defaultValue={new Date().getFullYear()}
          />
        </label>
      </div>
      <div className="source-choice">
        <label>
          Paste programming
          <textarea
            name="pastedText"
            rows={16}
            placeholder={`Tuesday, September 8, 2026\n\nWarm-up: ...\nStrength: ...\nWOD: ...`}
          />
        </label>
        <div className="source-divider">
          <span>or</span>
        </div>
        <label className="file-drop">
          Upload a file
          <input
            name="file"
            type="file"
            accept=".docx,.txt,.md,.xlsx,.csv,.tsv,text/plain,application/vnd.openxmlformats-officedocument.wordprocessingml.document,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          />
          <small>Word, text, Excel, CSV, or TSV · up to 5 MB</small>
        </label>
      </div>
      <p className="privacy-note">
        Your source is saved privately for comparison during review. It is never
        published automatically.
      </p>
      {error ? (
        <p className="form-error" role="alert">
          {error}
        </p>
      ) : null}
      <div className="form-actions">
        <Link className="secondary-button" href="/programming">
          Cancel
        </Link>
        <button className="primary-button" disabled={busy} type="submit">
          {busy ? "Reading programming…" : "Parse and review"}
        </button>
      </div>
    </form>
  );
}
