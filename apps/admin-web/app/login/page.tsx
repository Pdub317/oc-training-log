import { redirect } from "next/navigation";
import { createSupabaseServerClient } from "../../lib/supabase/server";
import { signIn } from "./actions";

export const dynamic = "force-dynamic";

type LoginPageProps = {
  searchParams: Promise<{ error?: string }>;
};

export default async function LoginPage({ searchParams }: LoginPageProps) {
  const supabase = await createSupabaseServerClient();
  const { data } = await supabase.auth.getClaims();

  if (data?.claims) {
    redirect("/");
  }

  const { error } = await searchParams;

  return (
    <main className="auth-shell">
      <section aria-labelledby="sign-in-heading" className="auth-panel">
        <p className="eyebrow">OC Gym Bend</p>
        <h1 id="sign-in-heading">Admin sign in</h1>
        <p className="auth-intro">
          Use your authorized coaching or gym administration account.
        </p>

        {error ? (
          <p className="form-error" role="alert">
            {error === "invalid-input"
              ? "Enter a valid email address and password."
              : error === "not-authorized"
                ? "This account does not have active administrator access."
                : "We could not sign you in with those credentials."}
          </p>
        ) : null}

        <form action={signIn} className="auth-form">
          <label>
            Email
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
              autoComplete="current-password"
              name="password"
              required
              type="password"
            />
          </label>
          <button type="submit">Sign in</button>
        </form>
      </section>
    </main>
  );
}
