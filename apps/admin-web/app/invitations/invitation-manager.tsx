"use client";

import type { FormEvent } from "react";
import { useState } from "react";

type Track = { id: string; code: string; name: string };
type Invitation = {
  id: string;
  email: string;
  trackCode: string;
  trackName: string;
  expiresAt: string;
  acceptedAt: string | null;
  revokedAt: string | null;
  lastSentAt: string;
  sendCount: number;
};
type ShareLink = {
  id: string;
  trackCode: string;
  trackName: string;
  tokenHint: string;
  createdAt: string;
};
type ReadyLink = {
  id: string;
  email?: string;
  trackCode: string;
  trackName: string;
  expiresAt?: string;
  url: string;
};

export function InvitationManager({
  tracks,
  initialInvitations,
  initialShareLinks,
}: {
  tracks: Track[];
  initialInvitations: Invitation[];
  initialShareLinks: ShareLink[];
}) {
  const [invitations, setInvitations] = useState(initialInvitations);
  const [shareLinks, setShareLinks] = useState(initialShareLinks);
  const [readyLinks, setReadyLinks] = useState<ReadyLink[]>([]);
  const [busy, setBusy] = useState("");
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  async function createInvitations(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const emails = String(form.get("emails") ?? "")
      .split(/[\s,;]+/)
      .map((email) => email.trim())
      .filter(Boolean);
    setBusy("email");
    setError("");
    setNotice("");
    const response = await fetch("/api/admin/invitations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        kind: "email",
        trackCode: form.get("trackCode"),
        emails,
      }),
    });
    const body = (await response.json()) as {
      invitations?: ReadyLink[];
      error?: string;
    };
    setBusy("");
    if (!response.ok || !body.invitations) {
      setError("Check the email addresses and try again.");
      return;
    }
    setReadyLinks(body.invitations);
    const now = new Date().toISOString();
    setInvitations((current) => [
      ...body.invitations!.map((item) => ({
        id: item.id,
        email: item.email!,
        trackCode: item.trackCode,
        trackName: item.trackName,
        expiresAt: item.expiresAt!,
        acceptedAt: null,
        revokedAt: null,
        lastSentAt: now,
        sendCount:
          (current.find((old) => old.id === item.id)?.sendCount ?? 0) + 1,
      })),
      ...current.filter(
        (old) => !body.invitations!.some((item) => item.id === old.id),
      ),
    ]);
    setNotice(
      `${body.invitations.length} invitation ${body.invitations.length === 1 ? "link is" : "links are"} ready.`,
    );
    event.currentTarget.reset();
  }

  async function createShareLink(trackCode: string) {
    setBusy(`share-${trackCode}`);
    setError("");
    setNotice("");
    const response = await fetch("/api/admin/invitations", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ kind: "share", trackCode }),
    });
    const body = (await response.json()) as {
      shareLink?: ReadyLink & { tokenHint: string; createdAt: string };
    };
    setBusy("");
    if (!response.ok || !body.shareLink) {
      setError("The reusable link could not be generated.");
      return;
    }
    const link = body.shareLink;
    setReadyLinks([link]);
    setShareLinks((current) => [
      {
        id: link.id,
        trackCode: link.trackCode,
        trackName: link.trackName,
        tokenHint: link.tokenHint,
        createdAt: link.createdAt,
      },
      ...current.filter((old) => old.trackCode !== trackCode),
    ]);
    setNotice(
      `${trackCode} reusable link created. Copy it now; only its secure hash is retained.`,
    );
  }

  async function resend(invitation: Invitation) {
    setBusy(`resend-${invitation.id}`);
    setError("");
    setNotice("");
    const response = await fetch(
      `/api/admin/invitations/${invitation.id}/resend`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ kind: "resend" }),
      },
    );
    const body = (await response.json()) as { invitation?: ReadyLink };
    setBusy("");
    if (!response.ok || !body.invitation) {
      setError("The invitation could not be refreshed.");
      return;
    }
    setReadyLinks([body.invitation]);
    setInvitations((current) =>
      current.map((item) =>
        item.id === invitation.id
          ? {
              ...item,
              expiresAt: body.invitation!.expiresAt!,
              lastSentAt: new Date().toISOString(),
              sendCount: item.sendCount + 1,
            }
          : item,
      ),
    );
    setNotice("A fresh seven-day invitation link is ready.");
  }

  async function disable(link: ShareLink) {
    if (!window.confirm(`Disable the ${link.trackCode} reusable signup link?`))
      return;
    setBusy(`disable-${link.id}`);
    setError("");
    const response = await fetch(`/api/admin/share-links/${link.id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ kind: "disable" }),
    });
    setBusy("");
    if (!response.ok) {
      setError("The reusable link could not be disabled.");
      return;
    }
    setShareLinks((current) => current.filter((item) => item.id !== link.id));
    setNotice(`${link.trackCode} reusable link disabled.`);
  }

  async function copy(value: string) {
    await navigator.clipboard.writeText(value);
    setNotice("Link copied.");
  }

  return (
    <>
      <section className="panel">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Specific people</p>
            <h2>Email invitations</h2>
          </div>
          <p>
            Create track-specific, seven-day links for one or more email
            addresses.
          </p>
        </div>
        <form className="invite-form" onSubmit={createInvitations}>
          <label>
            Training track
            <select name="trackCode">
              {tracks.map((track) => (
                <option key={track.id} value={track.code}>
                  {track.name} ({track.code})
                </option>
              ))}
            </select>
          </label>
          <label>
            Email addresses
            <textarea
              name="emails"
              rows={4}
              required
              placeholder="athlete@example.com, parent@example.com"
            />
            <small>
              Separate multiple addresses with commas, spaces, or new lines.
            </small>
          </label>
          <button
            className="primary-button"
            disabled={busy === "email"}
            type="submit"
          >
            {busy === "email" ? "Creating…" : "Create invitation links"}
          </button>
        </form>
      </section>

      {readyLinks.length ? (
        <section className="panel ready-links">
          <div className="section-heading">
            <div>
              <p className="eyebrow">Copy now</p>
              <h2>New links</h2>
            </div>
            <p>
              For security, the complete link is shown only when created or
              refreshed.
            </p>
          </div>
          {readyLinks.map((link) => (
            <div className="ready-link" key={link.id}>
              <div>
                <strong>
                  {link.email ?? `${link.trackName} reusable link`}
                </strong>
                <span>
                  {link.trackCode}
                  {link.expiresAt
                    ? ` · expires ${formatDate(link.expiresAt)}`
                    : " · no expiration"}
                </span>
              </div>
              <div>
                <button
                  className="secondary-button"
                  type="button"
                  onClick={() => copy(link.url)}
                >
                  Copy link
                </button>
                {link.email ? (
                  <a
                    className="secondary-button"
                    href={`mailto:${encodeURIComponent(link.email)}?subject=${encodeURIComponent(`Your ${link.trackName} training log invitation`)}&body=${encodeURIComponent(`Join OC Gym Bend’s ${link.trackName} training log:\n\n${link.url}\n\nThis invitation expires in seven days.`)}`}
                  >
                    Open email
                  </a>
                ) : null}
              </div>
            </div>
          ))}
        </section>
      ) : null}

      {error ? (
        <p className="form-error page-message" role="alert">
          {error}
        </p>
      ) : notice ? (
        <p className="success-banner page-message" role="status">
          {notice}
        </p>
      ) : null}

      <section className="panel">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Reusable access</p>
            <h2>Track signup links</h2>
          </div>
          <p>
            These links do not expire. Disable and replace one if it is shared
            too broadly.
          </p>
        </div>
        <div className="share-link-grid">
          {tracks.map((track) => {
            const link = shareLinks.find(
              (item) => item.trackCode === track.code,
            );
            return (
              <article className="share-link-card" key={track.id}>
                <span className="track-code">{track.code}</span>
                <div>
                  <h3>{track.name}</h3>
                  {link ? (
                    <p>
                      Active link ending in <strong>…{link.tokenHint}</strong>
                      <br />
                      Created {formatDate(link.createdAt)}
                    </p>
                  ) : (
                    <p>No reusable signup link is active.</p>
                  )}
                </div>
                <div>
                  {link ? (
                    <>
                      <button
                        className="secondary-button"
                        disabled={busy === `disable-${link.id}`}
                        onClick={() => disable(link)}
                        type="button"
                      >
                        Disable
                      </button>
                      <button
                        className="primary-button"
                        disabled={busy === `share-${track.code}`}
                        onClick={() => createShareLink(track.code)}
                        type="button"
                      >
                        Replace
                      </button>
                    </>
                  ) : (
                    <button
                      className="primary-button"
                      disabled={busy === `share-${track.code}`}
                      onClick={() => createShareLink(track.code)}
                      type="button"
                    >
                      Generate link
                    </button>
                  )}
                </div>
              </article>
            );
          })}
        </div>
      </section>

      <section className="panel">
        <div className="section-heading">
          <div>
            <p className="eyebrow">Status</p>
            <h2>Email invitation history</h2>
          </div>
          <p>Refreshing a pending invitation invalidates its previous link.</p>
        </div>
        {invitations.length ? (
          <div className="invitation-list">
            {invitations.map((invitation) => {
              const state = invitation.acceptedAt
                ? "Accepted"
                : invitation.revokedAt
                  ? "Revoked"
                  : new Date(invitation.expiresAt) <= new Date()
                    ? "Expired"
                    : "Pending";
              return (
                <article className="invitation-row" key={invitation.id}>
                  <span className="track-pill">{invitation.trackCode}</span>
                  <div>
                    <strong>{invitation.email}</strong>
                    <small>
                      {invitation.trackName} · {state} · {invitation.sendCount}{" "}
                      {invitation.sendCount === 1 ? "link" : "links"} created
                    </small>
                  </div>
                  <time dateTime={invitation.expiresAt}>
                    {state === "Pending"
                      ? `Expires ${formatDate(invitation.expiresAt)}`
                      : state}
                  </time>
                  {!invitation.acceptedAt && !invitation.revokedAt ? (
                    <button
                      className="secondary-button"
                      disabled={busy === `resend-${invitation.id}`}
                      onClick={() => resend(invitation)}
                      type="button"
                    >
                      Refresh link
                    </button>
                  ) : null}
                </article>
              );
            })}
          </div>
        ) : (
          <div className="empty-state">
            <h3>No email invitations yet</h3>
            <p>Created invitations will appear here.</p>
          </div>
        )}
      </section>
    </>
  );
}

function formatDate(value: string) {
  return new Intl.DateTimeFormat("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  }).format(new Date(value));
}
