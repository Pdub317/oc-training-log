# Local backend

The local backend uses the Supabase CLI pinned in the root JavaScript workspace.

## Prerequisites

- Node.js 24 and pnpm 11
- A Docker-compatible runtime with at least 7 GB of available memory

## Start and inspect

From the repository root:

```sh
pnpm db:start
pnpm db:status
```

Reset the database after migrations or seed changes:

```sh
pnpm db:reset
pnpm db:lint
pnpm db:test
```

Stop local services when finished:

```sh
pnpm db:stop
```

The generated local credentials belong in `.env`, which is ignored by Git. Never place production keys in local configuration or committed files.

The GP development seed includes the five programmed days from August 4–8, 2026, adapted from the user-provided [GP Sample Programming tab](https://docs.google.com/document/d/1ksxoFLpZkoP1o1tSToNJcfs02zcO_aRTKZVhY62jPXM/edit?tab=t.lr0hysmub43u). Sunday, August 9 is intentionally absent so clients exercise the no-programming state. Explicit fixed-load and timed results are structured; content without an explicit score remains notes-only.

The GP development seed also includes the twelve completed days from September 1–15, 2026, adapted from the updated [GP September Programming tab](https://docs.google.com/document/d/1ksxoFLpZkoP1o1tSToNJcfs02zcO_aRTKZVhY62jPXM/edit?tab=t.bvu2tmb0twks). The two closed Sundays are intentionally absent, and the blank September 12 template is not published. Explicit weighted, jump, and timed results are structured; the multi-option September 14 conditioning test remains notes-only because one result schema cannot faithfully represent all of its alternatives.

The SP development seed includes July 23–25, 2026, adapted from the user-provided [Example Programming tab](https://docs.google.com/document/d/1T0MzVk4fpzp1mt2pTcQXrt-PJz-4KR0ttBMS9L-zrBk/edit?tab=t.xf2sc3u3cxze). The user confirmed the year because the source lists only month and day. Clearly prescribed strength loads are structured; jumps, sprints, accessories, and finishers without an explicit result remain notes-only.

## Password recovery configuration

The iOS app uses a six-digit email recovery code, rather than a reset redirect. Local Auth uses `templates/recovery.html`; restart the local Supabase services after changing `config.toml` to apply it. Local emails stay in the local mail viewer.

Before staging or production, copy this template into Supabase Auth's Reset Password email template, configure a verified SMTP sender, and match the repository's twelve-character password minimum, six-digit OTP, and one-hour expiry. Provider delivery/rate-limit failures are surfaced without exposing account existence. Never test against a real member's account; use a dedicated test identity. A password update does not promise immediate invalidation of already-issued access tokens.
