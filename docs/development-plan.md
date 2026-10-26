# OC Training Log Development Plan

**Status:** Approved for implementation  
**Last updated:** 2026-09-12  
**Planning assumption:** One primary developer, with focused gym-owner review at decision and pilot gates

## Delivery strategy

Build a thin, production-shaped vertical slice before expanding feature breadth:

1. An admin signs in and creates one structured strength workout.
2. The admin explicitly publishes it to one track and date.
3. An authorized member sees it on iPhone.
4. The member records and completes one fixed-rep weighted result.
5. The workout appears in History and establishes the first eligible PR.

This slice uses real migrations, authentication, authorization, persistence, and automated tests. Import parsing, reminders, and visual polish follow after the core loop is proven.

## Cost guardrails

- Use local and free service tiers during foundation work where their terms permit it.
- Enable paid Supabase and Vercel production plans for the TestFlight pilot.
- Start with Sentry's single-developer free plan and upgrade only when collaboration or volume requires it.
- Set provider spend alerts and caps before accepting external users.
- Do not purchase enterprise compliance tiers without a documented requirement.
- Keep the initial infrastructure target below $100 per month, excluding the Apple Developer membership, domain, legal review, and development labor.

## Milestones

### M0 — Implementation decisions

**Status:** Complete for scaffolding

Completed:

- selected the application, backend, hosting, push, monitoring, and CI stack;
- established local, staging, and production separation;
- resolved Face ID, dumbbell-load, and variable-rep PR behavior;
- established structural-versus-plausibility validation behavior;
- established deterministic parser confidence and publication gates;
- added representative monthly GP and SP parser fixtures from supplied programming;
- kept hurdle PR scoring disabled until the gym defines the test.

Remaining pilot gates:

- gym-approved plausibility-warning thresholds;
- standardized hurdle measurement if automatic hurdle PRs are desired;
- APNs retry and terminal-failure limits;
- privacy, retention, youth-consent, and legal approval.

### M1 — Development foundation

**Status:** In progress; repository, admin, iOS, and local-backend scaffolds created on 2026-08-31

**Target:** Reproducible local workspace with build and test automation

Deliverables:

- repository directories and workspace tooling;
- Next.js admin shell;
- SwiftUI iOS shell;
- local Supabase configuration, first migration, and deterministic seeds;
- shared domain and API-contract packages;
- GitHub Actions checks;
- environment-variable templates and secret-handling documentation;
- Sentry wiring with privacy-safe defaults.

Exit criteria:

- a new developer can follow the README and start the local system;
- admin and iOS applications build;
- the database resets and reseeds deterministically;
- automated checks pass without production credentials;
- no privileged secret is present in client code or committed files.

### M2 — Identity and track authorization

**Status:** In progress; foundational schema, deterministic local identities, RLS policies, 12 authorization tests, protected admin sign-in, and Keychain-backed iOS sessions created on 2026-09-01

**Target:** Verified users can access only the correct gym and track

Deliverables:

- email/password registration, verification, sign-in, and sign-out;
- Keychain-backed iOS session storage;
- users, gyms, gym memberships, tracks, and track memberships;
- seeded OC Gym Bend, SP, GP, and initial admin;
- API authentication middleware;
- grants and RLS policies with allow/deny tests.

Exit criteria:

- anonymous access to private data fails;
- SP and GP members cannot read each other's data;
- departed members lose track access;
- an admin can access only their gym;
- verification and session failure states are handled in both clients.

### M3 — First end-to-end vertical slice

**Status:** Completed on 2026-09-02. The vertical slice now includes published programming, authenticated Today retrieval, fixed-rep entry, atomic idempotent completion, explicit benchmark matching, first-PR creation, and a private iOS Workouts history that reloads persisted results.

**Target:** Publish a workout, log a result, and establish a PR

Deliverables:

- manual programming-day and strength-block creation;
- one active published workout per track/date constraint;
- authenticated Today endpoint and iOS screen;
- fixed-rep weighted result entry that preserves positive decimal pound values;
- completion, History entry, and first PR creation;
- tests for publish uniqueness, validation, authorization, idempotency, and PR direction.

Exit criteria:

- the five-step delivery-strategy flow succeeds on a physical or simulated iPhone;
- retrying a completion request creates no duplicate workout, result, or PR;
- a GP member never receives SP programming and vice versa;
- the completed workout and PR survive a fresh application launch.

### M4 — Complete result entry and offline reliability

**Status:** Completed on 2026-09-02. Every MVP result format, notes-only completion, and free-text day now supports strict entry, private persistence, member-isolated autosave, exact stable-request offline queueing, retry, visible conflict handling, History, and optimistic editing. Programmed-result edits rebuild PR history; free-text edits preserve exact details and never manufacture scores or PRs.

Add all MVP result schemas, workout notes, free-text days, local drafts, offline completion queueing, idempotent synchronization, editing, and visible conflict handling.

### M5 — Programming import and publication

**Status:** Completed on 2026-09-03. The responsive admin now exposes Add Programming from the dashboard and each track, accepts paste plus text/Markdown, Word, Excel, CSV, and TSV sources, parses multi-date drafts with confidence and blocking review markers, preserves source text beside editable dates/blocks/items, supports draft saving and a member preview, and publishes explicitly through one track-authorized transaction. Corrected dates archive rather than overwrite the prior published version.

Add paste, text, Word, and spreadsheet ingestion; multi-date parsing; confidence categories; source comparison; draft correction; member preview; and explicit publication.

### M6 — History, search, and Personal Records

**Status:** Completed on 2026-09-03. The iOS History screen provides server-backed case-insensitive search across workout and movement content, local-calendar 30-day, 90-day, one-year, and all-date filters, a PR-workouts-only filter, and cursor-based 50-workout pagination. Every query rechecks active track access. The member PR tab lists the authorized benchmark catalog, searches by benchmark, shows current bests and empty states, preserves separate variable-rep bests, opens PR progression history, calculates 50–95% pound tables, and navigates each PR event to its exact full source workout. The responsive admin directory filters active members by track and opens a same-gym, read-only workout-history and PR-progression detail.

Add History and PR search, record detail/history, workout links, percentage tables, PR-session filtering, and admin read-only member drill-down.

### M7 — Invitations, profile, and reminders

**Status:** In progress as of 2026-09-03. The Invitations workspace supports multi-address track-specific email-link creation, seven-day token rotation, one reusable link per track with disable/replace behavior, hash-only storage, and minimal public resolution. Valid links provide new-account and existing-account onboarding; registration enforces the invited email where applicable, matching passwords, age 13+, Terms, Privacy, email verification, and atomic gym/exact-track activation. The iOS Profile provides private account/membership display, name and IANA-time-zone editing, sign-out, and a dual-confirmation leave-track correction that preserves gym membership and historical data. Authenticated reminder preferences support any weekday selection, separate local times, apply-time-to-all, and atomic replacement/off behavior. The app requests notification permission only after explanatory context, shows the iPhone Settings recovery path after denial, privately registers APNs device tokens, and disables the current token before sign-out. A secured five-minute worker now prepares due reminders with IANA local-time resolution, active-membership/device checks, logged-date suppression, private audit rows, and idempotent claims. APNs transmission, bounded retries, and notification deep links were implemented on 2026-09-08. Optional per-account iPhone local unlock with device-passcode recovery, background privacy protection, and deferred notification navigation was added on 2026-09-12. Native password change and email-code recovery were added on 2026-09-12, with isolated temporary sessions and matching twelve-character registration validation. Production recovery still requires provider template/SMTP setup. Real outbound invitation email delivery and legal data entry points remain.

Add email invitations and reusable links, profile and leave-track flows, local biometric unlock, reminder settings, APNs delivery, suppression, retries, and deep links.

### M8 — Pilot and release readiness

Complete accessibility, security, privacy/legal, deletion/export, retention, analytics, TestFlight, coach validation, member pilot, and App Store preparation.

## First implementation backlog

Work in this order. A ticket is complete only when its tests and documentation are included.

1. Create the repository directories and root workspace commands.
2. Initialize the Next.js admin application with TypeScript and strict checks.
3. Initialize the SwiftUI iOS application targeting iOS 17 or later.
4. Initialize the local Supabase project and secret-safe environment templates.
5. Add the first migration for users, gym, memberships, and tracks.
6. Add grants, RLS policies, and database allow/deny tests.
7. Add deterministic seeds for OC Gym Bend, SP, GP, and development identities.
8. Add the TypeScript domain and API-contract packages.
9. Add health/readiness checks without exposing environment details.
10. Add GitHub Actions for web, domain, database, and iOS checks.
11. Implement verified authentication and session handling.
12. Implement the initial track-authorized `Today` contract and endpoint. Completed on 2026-09-01 with member-local date resolution, strict response validation, track denial, and explicit no-programming behavior.
13. Implement fixed-rep weighted entry and workout completion. Completed on 2026-09-02 with positive decimal-weight validation and no application rounding, member-only result storage, stable retry identifiers, semantic conflict protection, an authenticated completion endpoint, and iOS saved/error states.

Milestone 6 is complete: History cards open full workout details; programmed and free-text editing use optimistic concurrency; PR history rebuilds after corrections; offline conflicts have explicit side-by-side resolution; server-backed History supports search, date/PR filters, and pagination; member PRs support search, detail, percentages, progression, and source-workout navigation; and administrators have same-gym, read-only member History and PR drill-down. M7 is underway; next configure production recovery delivery and implement outbound invitation delivery, then complete legal data entry points with approved content.

## Definition of done

Every implementation change must:

- preserve SP and GP isolation;
- include tests for affected business and authorization rules;
- include a forward migration for persisted schema changes;
- keep timestamps in UTC and render member schedules locally;
- avoid logging private content or credentials;
- update the product specification and version history when behavior changes;
- update the decision log for consequential tradeoffs;
- remain usable and accessible on the target iPhone or responsive admin layout.

## Review cadence

- At the end of M1: verify setup, builds, migrations, and cost controls.
- At the end of M2: review the authorization test matrix before adding member data.
- At the end of M3: demo the complete vertical slice to the gym owner.
- Before M5: collect representative monthly source files for both tracks.
- Before TestFlight: close every M0 pilot gate and complete privacy/legal review.
