"use client";

import type { FormEvent } from "react";
import { useState } from "react";

type Mode = "register" | "signin";

export function JoinForm({
  token,
  trackName,
  signedIn,
  defaultMode,
}: {
  token: string;
  trackName: string;
  signedIn: boolean;
  defaultMode: Mode;
}) {
  const [mode, setMode] = useState<Mode>(defaultMode);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState<"verification" | "joined" | null>(
    null,
  );

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError("");
    const form = new FormData(event.currentTarget);
    const body: Record<string, unknown> = {
      token,
      email: form.get("email"),
      password: form.get("password"),
      age13Attested: form.get("age13Attested") === "on",
      termsAccepted: form.get("termsAccepted") === "on",
      privacyAccepted: form.get("privacyAccepted") === "on",
    };
    if (mode === "register") {
      body.firstName = form.get("firstName");
      body.lastName = form.get("lastName");
      body.passwordConfirmation = form.get("passwordConfirmation");
    }
    const response = await fetch(
      `/api/join/${mode === "register" ? "register" : "sign-in"}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      },
    );
    const result = (await response.json()) as {
      state?: string;
      error?: string;
    };
    setBusy(false);
    if (!response.ok) {
      const messages: Record<string, string> = {
        account_exists:
          "An account already uses that email. Choose “I already have an account.”",
        invitation_email_mismatch:
          "Use the email address this invitation was sent to.",
        invalid_credentials:
          "That email and password combination was not recognized.",
        invalid_registration:
          "Complete every field, use matching passwords of at least twelve characters, and confirm each acknowledgement.",
        invalid_sign_in:
          "Enter your email and password and confirm each acknowledgement.",
      };
      setError(
        messages[result.error ?? ""] ??
          "We could not complete this request. The link may no longer be available.",
      );
      return;
    }
    setSuccess(result.state === "joined" ? "joined" : "verification");
  }

  async function acceptSignedIn(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError("");
    const form = new FormData(event.currentTarget);
    const response = await fetch("/api/join/accept", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        token,
        age13Attested: form.get("age13Attested") === "on",
        termsAccepted: form.get("termsAccepted") === "on",
        privacyAccepted: form.get("privacyAccepted") === "on",
      }),
    });
    setBusy(false);
    if (!response.ok) {
      setError(
        "This signed-in account cannot use the invitation. Sign out and use the invited email instead.",
      );
      return;
    }
    setSuccess("joined");
  }

  if (success === "verification")
    return (
      <div className="join-success">
        <h2>Check your email</h2>
        <p>
          Use the verification message from OC Training Log. After verification,
          this invitation will finish connecting your {trackName} membership.
        </p>
      </div>
    );
  if (success === "joined")
    return (
      <div className="join-success">
        <h2>You’re in.</h2>
        <p>
          Your account is connected to {trackName}. Open the OC Training Log
          iPhone app and sign in with the same email and password.
        </p>
      </div>
    );

  return (
    <div className="join-form-wrap">
      {signedIn ? (
        <div className="signed-in-join">
          <p>You already have a signed-in account in this browser.</p>
          <form onSubmit={acceptSignedIn}>
            <fieldset className="acknowledgements">
              <legend>Required confirmations</legend>
              <label>
                <input name="age13Attested" required type="checkbox" /> I
                confirm I am at least 13 years old.
              </label>
              <label>
                <input name="termsAccepted" required type="checkbox" /> I accept
                the Terms of Use.
              </label>
              <label>
                <input name="privacyAccepted" required type="checkbox" /> I
                acknowledge the Privacy Notice.
              </label>
            </fieldset>
            <button className="primary-button" disabled={busy} type="submit">
              {busy ? "Please wait…" : `Join ${trackName}`}
            </button>
          </form>
        </div>
      ) : null}
      <div className="join-mode-switch">
        <button
          className={mode === "register" ? "active" : ""}
          onClick={() => {
            setMode("register");
            setError("");
          }}
          type="button"
        >
          Create account
        </button>
        <button
          className={mode === "signin" ? "active" : ""}
          onClick={() => {
            setMode("signin");
            setError("");
          }}
          type="button"
        >
          I already have an account
        </button>
      </div>
      <form className="join-form" onSubmit={submit}>
        {mode === "register" ? (
          <div className="name-fields">
            <label>
              First name
              <input autoComplete="given-name" name="firstName" required />
            </label>
            <label>
              Last name
              <input autoComplete="family-name" name="lastName" required />
            </label>
          </div>
        ) : null}
        <label>
          Email address
          <input
            autoComplete="email"
            inputMode="email"
            name="email"
            required
            type="email"
          />
        </label>
        <label>
          Password
          <input
            autoComplete={
              mode === "register" ? "new-password" : "current-password"
            }
            minLength={mode === "register" ? 12 : 1}
            name="password"
            required
            type="password"
          />
        </label>
        {mode === "register" ? (
          <label>
            Confirm password
            <input
              autoComplete="new-password"
              minLength={12}
              name="passwordConfirmation"
              required
              type="password"
            />
          </label>
        ) : null}
        <fieldset className="acknowledgements">
          <legend>Required confirmations</legend>
          <label>
            <input name="age13Attested" required type="checkbox" /> I confirm I
            am at least 13 years old.
          </label>
          <label>
            <input name="termsAccepted" required type="checkbox" /> I accept the
            Terms of Use.
          </label>
          <label>
            <input name="privacyAccepted" required type="checkbox" /> I
            acknowledge the Privacy Notice.
          </label>
        </fieldset>
        {error ? (
          <p className="form-error" role="alert">
            {error}
          </p>
        ) : null}
        <button className="primary-button" disabled={busy} type="submit">
          {busy
            ? "Please wait…"
            : mode === "register"
              ? "Create account"
              : `Sign in and join ${trackName}`}
        </button>
      </form>
    </div>
  );
}
