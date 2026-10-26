# OC Training Log Technical Architecture

**Status:** Development foundation  
**Last updated:** 2026-09-14

## 1. Architectural goals

- Make result entry reliable and fast on iPhone.
- Keep programming, results, and benchmarks structured enough for search and PR calculation.
- Allow coaches to import human-authored programming in bulk while requiring review before publication.
- Enforce gym, track, and role access on the server.
- Start simple without blocking future Kilo integration, additional gyms, or tracks.

## 2. Selected MVP stack and system shape

### Platform choices

- Member client: Swift and SwiftUI, targeting iOS 17 or later
- Admin client: TypeScript, React, and Next.js App Router
- Backend platform: Supabase managed PostgreSQL, Auth, and private Storage
- API and server execution: authenticated Next.js Route Handlers deployed to Vercel
- Scheduled work: secured Vercel Cron triggers backed by idempotent database jobs
- Push: direct Apple Push Notification service using token-based authentication
- Error monitoring: Sentry with sensitive-field filtering
- Continuous integration: GitHub Actions

These services are replaceable boundaries, not locations for core product rules. Result validation, PR comparison, authorization decisions, parsing rules, and reminder eligibility live in tested application/domain modules or versioned PostgreSQL policies and functions.

### Member client

A native iOS application using Swift and SwiftUI. The MVP targets iOS 17 or later and uses Keychain, LocalAuthentication, UserNotifications, URL-based deep links, and lightweight local persistence. Face ID or Touch ID gates an existing session locally; it does not replace server authentication.

Primary modules:

- Authentication and onboarding
- Home and assignment resolution
- Today's Workout and result entry
- Workout History and search
- Personal Records and percentage calculations
- Profile, track membership, and reminder settings
- Local drafts and synchronization

### Admin client

A responsive TypeScript application using Next.js App Router. Desktop web is primary, but core workflows must remain usable on mobile. Server Components may call domain services directly; browser interactions and the iOS client use authenticated Route Handlers.

Primary modules:

- Track overview
- Programming import, parse, review, preview, edit, and publish
- Invitations and share links
- Track member directory
- Member workout history and PRs

### Backend and API

Supabase provides PostgreSQL, email/password identity, and private object storage. An explicit TypeScript domain/service layer and authenticated Route Handlers provide:

- Identity, email verification, and authorization
- Gyms, tracks, memberships, invitations, and share links
- Programming documents, parsing jobs, workouts, blocks, and movements
- Workout logs, movement results, notes, and PR materialization
- Reminder schedules, device tokens, and push-delivery jobs
- File-object storage for uploaded source documents

The iOS and browser clients use publishable credentials only. Supabase service-role credentials are restricted to server execution. Row-level security and least-privilege grants provide defense in depth even when requests normally pass through the API. Core schema and business behavior remain standard PostgreSQL and portable TypeScript wherever practical.

### Repository boundaries

The initial repository shape is:

```text
apps/
  admin-web/       Next.js admin UI and HTTP route adapters
  ios/             SwiftUI member application
packages/
  domain/          framework-independent TypeScript business rules
  contracts/       API schemas and generated OpenAPI artifacts
  test-fixtures/   representative SP and GP inputs and expected results
supabase/
  migrations/      schema, grants, RLS policies, and database functions
  tests/           database authorization and constraint tests
  seed.sql          deterministic local development data
docs/
```

Route Handlers remain thin adapters: authenticate, validate the contract, call a domain service, and translate the result to HTTP. They must not become the only place a business rule is expressed.

## 3. Authentication and authorization

- Email/password account creation with mandatory email verification
- Secure session tokens stored in iOS Keychain
- Face ID or Touch ID local unlock for returning users where available; passkeys are post-MVP
- Minimum age attestation of 13+
- Roles: `member` and combined `admin`
- Server-side authorization by gym membership and track membership
- Track-specific invitation tokens and share links
- Existing accounts accepting an invitation add a membership rather than creating a duplicate identity

Supabase Auth JWTs identify callers. Every private request must enforce gym, role, and track authorization in the service layer and through tested PostgreSQL grants/RLS policies. Authorization tests must include both allow and deny cases for anonymous users, members in each track, departed members, and admins from another gym.

The admin app uses server-managed, HTTP-only Supabase session cookies refreshed by the Next.js request proxy. Rendering the admin dashboard additionally requires an active `admin` gym membership. The iOS client stores its refreshable session in an app-namespaced Keychain service. Only the Supabase URL and publishable key may enter either client; the service-role key remains server-only.

The iOS local-unlock gate is independent of Supabase session refresh. A member-ID-namespaced device preference defaults off and requires successful Apple LocalAuthentication before enabling. The system device-owner policy supports biometrics with device-passcode recovery. A restored protected session delays creation of member screens until unlock; subsequent locks retain the view tree and drafts behind an opaque, noninteractive, accessibility-hidden privacy cover. Background transitions relock and invalidate pending authentication results. Notification routing waits for unlock. Tokens and biometric data are never stored in the preference.

Password management uses a separate Supabase Swift client with locked in-memory storage and automatic token refresh disabled. It never shares the member Keychain namespace or auth event observer. Current-password changes sign in that temporary client, compare the returned identity to the active member, then update the password. Recovery calls the provider's password-reset email endpoint, verifies an email OTP of type `recovery`, and updates only after obtaining a valid recovery session. A verified temporary session is retained for password-validation retries and explicitly cleared after success or dismissal, even if provider sign-out fails. The recovery email template uses `{{ .Token }}` instead of a redirect; no recovery token enters app URLs, browser cookies, or workout routing.

## 4. Core data model

### Identity and organization

- `users`: id, first_name, last_name, email, email_verified_at, time_zone nullable, created_at, updated_at
- `gyms`: id, name, timezone, created_at, updated_at
- `gym_memberships`: user_id, gym_id, role, status, joined_at, updated_at
- `training_tracks`: id, gym_id, name, code, status, created_at, updated_at
- `track_memberships`: user_id, track_id, status, joined_at, left_at, updated_at
- `invitations`: id, track_id, email, token_hash, expires_at, accepted_at
- `share_links`: id, track_id, token_hash, enabled, created_at

Invitation secrets are 256-bit random values generated only in authenticated server execution. PostgreSQL retains SHA-256 hashes rather than recoverable tokens. Email invitations have one open row per track/address, expire seven days after creation or refresh, and rotate their secret on refresh. Each track has at most one enabled reusable link; replacement disables the prior row. A security-definer public resolver hashes the presented token and returns only minimal gym/track context for valid, unaccepted, unrevoked, unexpired invitations or enabled reusable links. Invitation tables themselves have no anonymous access and are restricted to same-gym administrators by RLS.

The initial M7 admin slice creates secure invitation URLs and supports copy/open-email handoff locally without contacting recipients. Production outbound delivery remains behind a server-only provider integration so local or test actions cannot accidentally email real members.

The registration route checks token/email compatibility before calling Supabase Auth, sends first/last name and explicit age, Terms, and Privacy acknowledgements as identity metadata, and requires the configured email-confirmation flow. The auth-user synchronization trigger records acknowledgement timestamps without trusting the browser to create memberships. After verification, or after an existing verified account signs in, `accept_join_token` rehashes and locks the token, rechecks its validity and email restriction, requires all acknowledgements, and upserts active gym and exact-track memberships in one transaction. It consumes an email invitation but leaves a reusable link active. An invalid, expired, revoked, disabled, mismatched, unverified, or already-consumed request creates no membership.

The authenticated Profile API returns only the caller's private account and active gym/track membership summary. Profile edits synchronize first/last name with authentication metadata and store a validated IANA time zone. A security-definer leave function locks and changes only the caller's selected active track membership to `left`; it does not delete the account, gym membership, workout logs, results, or PR history. The iOS client puts two confirmations in front of that action and directs rejoining through invitations rather than an editable track selector.

### Programming

- `program_imports`: id, track_id, created_by, source_type, source_file_name, raw_text, parsed_payload, parse_status, published_at, created_at, updated_at
- `programming_days`: id, track_id, workout_date, title, coach_notes, status, published_at, created_at, updated_at
- `workout_blocks`: id, programming_day_id, type, title, instructions, display_order, created_at, updated_at
- `prescribed_movements`: id, block_id, movement_id nullable, display_name, prescription_text, coach_notes, substitutions, result_schema, display_order, created_at, updated_at
- `movements`: id, canonical_name, aliases, default_result_schema, created_at, updated_at

Publishing should enforce a unique active programming day per track and date.

The admin import route accepts paste, text/Markdown, Word `.docx`, Excel `.xlsx`, CSV, and TSV sources up to 5 MB. It extracts text in server execution, normalizes spreadsheet cells into source order, and runs the framework-independent parser. The private database row retains the extracted source and editable JSON review draft under track-admin RLS; the original binary is discarded after extraction for MVP. The parser recognizes multi-date source sections and case-insensitive workout blocks, preserves unfamiliar content, and proposes a result schema with high, medium, or low confidence. Ambiguous proposals retain a blocking `requiresReview` marker until the admin confirms or changes the result input.

Publication calls one security-definer PostgreSQL function through the authenticated admin session. The function rechecks track administration, track identity, dates, block types, nonempty prescriptions, read-only Warm-up/Recovery rules, duplicate dates, and unresolved review markers. It archives an existing published version for each corrected track/date, then creates the replacement days, blocks, and prescriptions and marks the import published in one transaction. Archived rows and their identifiers remain available to historical workout logs.

Programming statuses are `draft`, `published`, and `archived`. Members may select only published days for an active track membership; gym admins may manage all programming only within their gym. Child block and prescription policies inherit that day-level authorization. The shared movement catalog is readable by active gym members and writable only through trusted server operations for the initial slice. A prescription may retain a nullable canonical movement link because imported or coach-authored text must remain publishable and reviewable even before movement mapping is complete; `display_name` and `prescription_text` are always required.

### Today response boundary

The initial authenticated Today response is a strict `published | no_programming` union. Both variants contain the member-local workout date, IANA time zone, and authorized track identity. A published response contains one programming day with blocks and prescribed movements in strictly increasing coach-defined display order. Only the stable block and result-schema categories are normalized; `prescription_text` remains authoritative so percentages, tempo, equipment, sets, reps, load, duration, rest, and unusual coach notation are preserved exactly.

Warm-up and recovery movements must use the `notes_only` result schema. A no-programming response explicitly permits a free-text workout. Draft or archived programming, unsupported track codes, privileged credentials, and unknown fields are not valid member responses.

`GET /api/today?track=SP|GP` authenticates either an iOS Bearer session token or the web session cookie, requires an active membership in the requested track, and resolves the workout date from the server clock in the member's valid stored IANA time zone. The active gym time zone is the fallback when the member setting is absent or invalid. The endpoint does not accept a client-supplied date, loads only published programming, orders blocks and movements by their stored display order, validates the assembled response against the shared contract, and disables response caching.

### Results and records

- `workout_logs`: id, user_id, programming_day_id, workout_date, status, client_request_id, completion_payload, notes, completed_at, created_at, updated_at
- `movement_results`: id, workout_log_id, prescribed_movement_id, movement_id nullable, result_schema, schema-specific nullable value columns for weight, reps, duration, measurements, calories/distance, and rounds plus residual reps, created_at, updated_at; database constraints require exactly the fields belonging to the stored result schema
- `benchmarks`: id, track_id, movement_id, label, result_schema, comparison_direction, metadata; metadata includes comparison dimensions such as fixed or completed rep count
- `personal_records`: id, user_id, benchmark_id, movement_result_id, value, unit, achieved_at, created_at

Do not discard historical PR rows when a new best occurs. The latest best is derived or materialized separately.

`POST /api/workouts/complete` accepts every MVP result schema. Each submitted result is a strict schema-discriminated value: fixed weight requires weight; variable weight requires weight and positive whole completed reps; max repetitions requires only positive whole completed reps; time requires positive whole milliseconds; height/distance requires a positive numeric measurement plus `in`, `ft`, `m`, `yd`, or `mi`; calories/distance requires a positive numeric result plus `cal`, `m`, `km`, `ft`, `yd`, or `mi`; and rounds/reps requires nonnegative whole rounds and residual reps that are not both zero. The operation verifies active gym and track memberships, requires exactly one schema-matching result for every scoreable prescription, permits an empty result array only when the day has no scoreable prescriptions, and writes the workout log and movement results in one transaction. Members may read only their own logs and results and cannot insert either table directly.

The iOS client generates one stable request identifier per programming day and reuses it after a network failure. The database also enforces one workout log per member and programming day. A retry whose normalized day, track, date, notes, and results match returns the original completion; a changed retry returns an explicit conflict and never silently replaces the stored values. Notes-only days complete at the day level with optional workout notes; read-only warm-up and recovery movements never render score controls or create movement-result rows.

When the endpoint is unavailable, iOS stores the already validated, schema-specific completion request in a lightweight local queue namespaced by authenticated member and programming day. The queue contains no access token or credential. Queued inputs are locked, and app reload or manual refresh retries the exact stored request using the current authenticated session. Confirmed completion deletes both the queue item and its draft. An explicit server conflict changes the item to a persistent conflict state, stops automatic retries, retains the local draft, and requires the later conflict-resolution workflow.

The Workouts tab surfaces persistent conflicts separately from History. Resolution compares the current server workout with the queued iPhone request, including notes and schema-formatted results. “Keep currently saved version” removes the local queue item and draft after confirmation. “Use results from this iPhone” is enabled only when the current History version is available and submits that version through the optimistic edit transaction; confirmation is required, and a second stale-version conflict leaves both copies intact for another refresh.

Each prescribed movement has an optional, admin-confirmed `benchmark_id`. A database constraint requires the linked benchmark to match the programming track, canonical movement, and result schema. Only linked results enter PR evaluation; ordinary working weights never become records by text inference. The first valid linked result creates a historical PR row, and later results append a row only when they improve according to the benchmark direction. Completion responses include any PR rows created for their movement results.

`GET /api/history?track=SP|GP` requires an active membership in the requested track and returns the caller's completed workouts in reverse chronological cursor pages. An optional validated `workout` identifier performs an exact lookup and cannot be combined with list filters; ownership and active track access are still enforced. The strict response contains the programming title, date, completion timestamp, edit version, member notes, prescribed-movement identifiers, all schema-specific scored results, block context, and PR indicators. The iOS Workouts tab renders persisted results, opens a full workout-detail screen, and provides prefilled schema-specific editing controls. A successful edit reloads History; a stale edit remains open with a specific conflict message.

`PATCH /api/workouts/edit` accepts the owned workout-log identifier, the exact `updated_at` version returned by History, optional notes, and the same strict schema-specific result variants as completion. The database locks the workout, rechecks active gym and track access, rejects stale versions, requires an exact result for every scoreable prescription, replaces results atomically, and rebuilds that member's historical PR rows from all retained raw results. This supports MVP editing without silently losing a concurrent update or leaving a corrected result attached to stale PR history.

`PATCH /api/workouts/free-text/edit` applies the same ownership, active-membership, row-lock, and expected-`updated_at` checks to a free-text title and non-empty workout details. It preserves the details exactly, trims only the display title, and updates the stored completion payload so later replay/conflict comparisons use the accepted version.

History search, local-date cutoffs, and PR-session filtering run inside an authenticated database function that rechecks active gym and track membership before selecting workout identifiers. Matching is case-insensitive across titles, member notes, movement names, prescriptions, and stored result values. Results use a stable workout-date/completion-time/identifier order and return 50 workouts plus a lookahead identifier; the public response exposes only the last displayed workout identifier as an opaque cursor. The iOS screen requests additional pages explicitly and de-duplicates identifiers while merging them.

The responsive admin member directory is rendered server-side from the administrator's HTTP-only session. It lists active member/track memberships inside the administrator's gym and links to a read-only member detail with the latest 50 workouts, stored notes and typed results, PR indicators, and PR progression for the selected track. Row-level policies permit reads only when `private.can_admin_user` confirms an active administrator and target member share a gym; member writes remain unchanged, and administrators from other gyms receive no rows.

`GET /api/personal-records?track=SP|GP` returns the authorized track's benchmark catalog with the member's current bests. Supplying a validated `benchmark` identifier returns the append-only PR progression with source workout identifiers, dates, and titles. Selecting an event sends its identifier through the exact authorized History lookup and opens the shared full-workout detail experience. The server derives current bests using each benchmark's comparison direction and keeps weighted variable-rep records partitioned by completed rep count. Canonical values remain in their stored units; the iOS client formats them for display and derives 50–95% pound tables by rounding each percentage to the nearest whole pound.

### Notifications

`GET /api/reminders` returns only the authenticated member's selected weekday/local-time pairs and effective IANA time zone. `PUT /api/reminders` validates distinct ISO weekdays `1...7`, strict 24-hour `HH:MM` values, at most seven rows, and a real IANA time zone before calling an authenticated database replacement function. The transaction updates the member time zone, removes the prior schedule, and inserts the complete new selection; an empty selection disables reminders by leaving no enabled rows. Direct member inserts and updates are denied. Profile time-zone changes propagate to existing schedule rows.

Reminder preferences store scheduling intent separately from delivery capability. The iOS client reads the system permission without prompting, requests alert, badge, and sound access only after an explicit member action, and exposes the iPhone Settings recovery path after denial. After permission is granted, the app obtains an APNs token and sends it to `POST /api/notifications/devices`; sign-out calls `DELETE /api/notifications/devices` before ending the session.

The client requests the current token from APNs on each authorized app launch and keeps it only in memory for the active session; it never caches the token in local persistence. The authenticated registration functions validate normalized APNs tokens, keep the raw token unreadable to member roles, retain a SHA-256 lookup hash, and idempotently bind a physical token to only the latest signed-in member. Registration never writes a token to application logs or returns it in a response. The server token remains necessary for the APNs worker and is disabled on sign-out. Scheduled delivery and retry remain separate slices.

Reminder payloads carry the strict workout date and `octraininglog://log?date=YYYY-MM-DD`. The iOS router validates this contract, retains a pending destination across authentication, selects Home, and requests that date for each active track. `GET /api/today` continues to resolve the member-local date by default, but accepts a validated `date` for this authenticated Log Results flow. The API rechecks active track access and reports whether the member already has a log for that track/date so stale notification taps open a locked completed state instead of a duplicate form.

- `reminder_schedules`: user_id, weekday, local_time, timezone, enabled
- `device_tokens`: user_id, platform, token, enabled
- `notification_deliveries`: schedule_id, intended_at, status, provider_id

## 5. Result schemas

The prescribed movement determines the UI and validation schema. Initial schemas:

- Weighted fixed reps: weight; prescribed reps are contextual
- Weighted variable reps: weight and completed reps required
- Height/distance: numeric measurement and unit
- For time: duration, lower value wins
- Max repetitions: completed reps, higher value wins
- Calories/distance: positive numeric result plus `cal`, `m`, `km`, `ft`, `yd`, or `mi`; direction defined by the benchmark
- Rounds and reps: nonnegative completed rounds and residual reps, not both zero
- Completion or notes-only: day-level completion and optional workout notes without a competitive movement score

Selectable workout alternatives form a group around independently prescribed options. The result schema belongs to each option and is derived from the requested outcome, not its equipment or modality. Completion accepts results only for selected options, requires at least one selection in a required group, and allows multiple selections. A Gym Closed programming day is a visible, non-loggable day state rather than a notes-only workout.

Calories are compared only with calories. Activity distance values normalize to meters for PR comparison while preserving the entered value and unit. Rounds-plus-reps use `completed_rounds * 100000 + residual_reps` as an internal comparison key; the residual-rep constraint keeps this equivalent to comparing rounds first and residual reps second.

Weights accept positive decimal pound values up to the structural maximum and are stored without application rounding. Dumbbell benchmark load is canonicalized per hand and displayed as `lb each`. Duration is normalized to milliseconds and accepts hours, minutes, seconds, and tenths. Structural validation failures are blocked. Configurable plausibility limits require confirmation but never silently alter input; gym-approved threshold values are a pilot gate.

## 6. PR calculation

On result save:

1. Resolve a benchmark by track, movement, and relevant comparison metadata, including completed rep count for variable-rep weighted benchmarks.
2. Validate and normalize the score.
3. Compare it with the athlete's current best using the benchmark direction.
4. If no prior score exists or the score improves it, create a new historical PR row.
5. Recompute the current-best projection.

Only successful completed results are used. Unsuccessful attempts may be written in notes but do not become scored results.

Variable-rep weighted records compare only with results at the same completed rep count. Hurdle-jump results are notes-only until a standardized scoring rule is approved.

## 7. Programming ingestion

Supported sources: paste, plain text, Word document, and spreadsheet. A single import may contain an entire month and multiple dates, but each import is assigned to exactly one track.

Pipeline:

1. Upload or paste source.
2. Extract text and date boundaries.
3. Recognize block headings and aliases such as Strength, Accessory, WOD, Recovery, WU, J, S, A, and F.
4. Split block text into prescribed movement candidates.
5. Infer result schemas from language such as `For time`, `1 rep max`, `4x6`, percentages, duration, distance, or calories.
6. Flag ambiguity and show the source beside the parsed draft.
7. Admin edits, previews, and explicitly publishes.

The parser assists authoring; it is never the final authority. Low-confidence content remains reviewable text rather than being dropped.

An explicitly `n/a` labeled block is treated as intentionally absent and is not added to the draft. A present but empty block is retained so the review flow can require the admin to fill or remove it.

Within Strength blocks, deterministic candidate splitting may create separate prescribed movements when a source line has a clear second set-and-rep prescription or an explicit between-set exercise clause. The original source excerpt remains unchanged, and inferred weighted cards retain their review requirement until confirmed. Non-scoreable circuits are not split into synthetic score fields.

Parsing confidence is deterministic and explainable:

- `recognized`: required date, block, movement mapping, and result schema are present without conflict;
- `review`: the content is preserved but one or more interpretations require admin confirmation;
- `blocking`: track/date conflicts, duplicate active dates, or unresolved required score fields prevent publication.

Every import requires admin review and explicit publication regardless of confidence. An admin may intentionally mark preserved content as unscored text.

## 8. Local drafts and synchronization

Programmed and free-text workout logs share the same private `workout_logs` boundary. Every log stores its owning track directly. A programmed log references a programming day and has no free-text title; a free-text log has a required title and no programming-day reference. The database enforces one log per member, track, and local workout date. The authenticated free-text completion endpoint verifies active gym and track membership, refuses creation when published programming exists, and uses the same stable-request replay and conflict semantics as programmed completion. History reads both shapes without manufacturing movement results for free-text entries.

- The iOS client autosaves in-progress workout values after each change in app-local persistence. Programmed drafts are keyed by authenticated member and programming day; free-text drafts are keyed by authenticated member, track, and local workout date, so drafts cannot appear in another signed-in member's session.
- Drafts preserve the member's exact entry strings and notes. Restoration discards entries for movement identifiers that are no longer present in the published programming, without rewriting the remaining values.
- A stable client-generated completion request identifier is saved with the draft before the first submission. Failed submissions retain the draft and identifier for a safe retry; the draft is deleted only after the server confirms completion.
- Restore drafts after app termination or brief network loss.
- Queue a completed log when offline and synchronize when connectivity returns.
- Use stable client-generated identifiers for idempotent retries.
- For MVP, latest user edit may win, with a visible conflict prompt if both local and server copies changed.

## 9. Reminders

- Schedule one local-time reminder per selected weekday, with optional apply-time-to-all convenience.
- Adjust automatically for daylight-saving transitions.
- Before sending, verify that the day's workout is not already logged.
- Deep-link notification taps to that date's Log Results screen.
- If notification permission is denied, do not send notifications and explain how to enable them in Settings.
- Kilo attendance events are a future trigger behind a provider interface.

A secured Vercel Cron endpoint runs on a short UTC interval and claims due reminder jobs using an idempotency key. Eligibility is recalculated immediately before delivery. The worker sends directly to APNs with token-based authentication, records the provider response, disables invalid device tokens, and never logs the raw token. A failed first attempt is retried after fifteen minutes plus up to fifty-nine seconds of jitter; a failed second attempt is retried after thirty minutes plus the same jitter; a transient third failure becomes terminal.

The reminder cycle invokes `GET /api/cron/reminders` every five minutes with `CRON_SECRET` bearer authentication. Its service-role-only database functions convert the UTC preparation window into each schedule's IANA local time, including daylight-saving rules, and accept preparation windows no longer than fifteen minutes. Preparation requires active gym and track membership plus an enabled device token and writes one candidate per schedule, device, and local workout date. Before every APNs attempt, a second transactional claim suppresses newly completed workout dates, terminates revoked membership/device eligibility, leases at most 100 due rows with row locks, and increments an attempt counter capped at three. The five-minute lease permits recovery if a worker exits before recording the provider result. The endpoint returns aggregate counts only, never device tokens or member identifiers.

The APNs provider adapter uses Node's TLS-backed HTTP/2 client and selects Apple's sandbox or production host from the device-token environment. `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_BUNDLE_ID`, and `APNS_PRIVATE_KEY` are server-only and must be either all absent or all valid; the `.p8` value supports escaped newlines for deployment-secret storage. The adapter validates the P-256 private key, signs ES256 provider JWTs, refreshes them after fifty minutes, caps payloads at 4,096 bytes, and returns only provider IDs and bounded reason classifications. Invalid or unregistered device results are terminal and disable the token. `429` and `5xx` outcomes follow the approved retry schedule; configuration, authentication, and other request failures are terminal. The cron worker creates the adapter only when the full credential set is present, so local and unconfigured environments prepare audit rows without making network requests.

## 10. Environments and delivery

- Local: Supabase CLI services, deterministic seed data, local mail capture, and no production credentials
- Staging: isolated hosted data and credentials used for integration tests and TestFlight validation
- Production: isolated Supabase and Vercel projects with least-privilege credentials and protected deployment controls

Production data is never copied into local or staging environments. Schema, grants, RLS policies, and seed structure are versioned; deployment applies reviewed migrations forward. Pull requests run formatting, static analysis, unit tests, database tests, admin tests, and an iOS build/test job. Production deployment requires all required checks and a successful staging migration.

## 11. Security and privacy baseline

- TLS in transit and encryption at rest
- Least-privilege service credentials and role checks on every private resource
- Hashed invitation/share tokens and passwords managed by the identity provider
- Private uploaded documents with expiring download URLs
- Rate limiting on authentication and public share-link endpoints
- Account deletion and export capabilities before launch
- Minimal operational logging with no workout notes or tokens in application logs
- Formal privacy and legal review before minors use the production service
- No service-role key, APNs signing key, or other privileged secret in either client
- Sentry filtering before transmission; workout notes, tokens, email addresses, and imported source content are excluded by default

## 12. Testing strategy

- Unit tests: parser rules, score normalization, directionality, PR history, percentages, and validation
- API tests: authentication, memberships, invitation expiry, disabled links, authorization, and publish uniqueness
- iOS tests: local draft restore, deep links, completion, editing, reminder settings, and search
- Admin tests: monthly import, ambiguous parse correction, preview/publish, invitations, and member drill-down
- End-to-end fixtures for both tracks using representative programming
- Database tests for grants and RLS allow/deny behavior on every exposed table
- Contract tests ensuring iOS and admin clients receive stable API shapes

## 13. Delivery sequence

1. Schema, authentication, gym and track seeds
2. Admin programming entry and publication
3. Member onboarding and daily-program retrieval
4. Structured results with local drafts
5. History, search, PRs, and percentages
6. Invitations, member drill-down, and scheduled push reminders
7. Privacy hardening, accessibility, telemetry, and release readiness

### Programming review boundary hardening — 2026-09-14

The import endpoint validates parser output against the same contract used by the review page before inserting a draft. Blank Strength/Accessory headings and case-insensitive N/A content produce a notes-only N/A item; other blank headings produce no block. Source text is retained. The review page distinguishes database errors and invalid payloads from missing or inaccessible rows. A local pre-fix draft was recovered by removing its empty block without altering source text, exercises, or publication state.

### Today response mapping correction — 2026-09-14

The Today service explicitly maps repository fields into the public programming-day response. The internal `isClosed` flag selects the closed response variant and is not included in the strict published-workout payload. Regression tests cover both flag values; a local GP request and simulator retry verified published programming loads successfully.
