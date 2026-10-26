# OC Training Log Product Specification

**Document status:** Living product specification  
**Version:** 1.33  
**Last updated:** 2026-09-14  
**Product:** OC Training Log  
**Initial customer:** OC Gym Bend, Bend, Oregon

## Version history

| Version | Date       | Summary                                                                                                                                                        |
| ------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0.1     | 2026-08-03 | Initial vision, member IA, onboarding, Today's Workout, History, PRs, and Profile                                                                              |
| 0.2     | 2026-08-03 | Added tracks, invitations, reminders, admin/programming workflows, and benchmark concepts                                                                      |
| 0.3     | 2026-08-03 | Added result validation, PR rules, search, local drafts, youth scope, and design decisions                                                                     |
| 0.4     | 2026-08-03 | Added admin visuals/prototype decisions, monthly imports, member drill-down, and onboarding details                                                            |
| 0.9     | 2026-08-18 | Reconstructed the living specification and consolidated settled decisions and remaining questions                                                              |
| 1.0     | 2026-08-25 | Added the authoritative 73-item General Population benchmark catalog and resolved its recovery question                                                        |
| 1.1     | 2026-08-31 | Selected the MVP development stack and resolved Face ID, dumbbell-load, variable-rep PR, validation, parser, and reminder implementation rules                 |
| 1.2     | 2026-09-01 | Clarified that member-local workout dates use a stored IANA time zone with the active gym time zone as a fallback                                              |
| 1.3     | 2026-09-02 | Required explicit benchmark linkage before an otherwise scoreable training result may create a personal record                                                 |
| 1.4     | 2026-09-02 | Defined typed completion payloads as schema-specific and required published/submitted result formats to match exactly                                          |
| 1.5     | 2026-09-02 | Defined supported height/distance units and canonical normalization for timed and length-based personal records                                                |
| 1.6     | 2026-09-02 | Defined calories/distance and rounds-plus-reps storage, comparison normalization, and notes-only workout completion                                            |
| 1.7     | 2026-09-02 | Defined member-isolated offline completion queueing, exact-request synchronization, and persistent conflict status                                             |
| 1.8     | 2026-09-02 | Defined optimistic concurrency and full PR-history rebuilding for completed-workout edits                                                                      |
| 1.9     | 2026-09-02 | Defined side-by-side offline conflict comparison and confirmed member resolution choices                                                                       |
| 1.10    | 2026-09-02 | Defined free-text workout ownership, validation, publication precedence, and History representation                                                            |
| 1.11    | 2026-09-02 | Defined optimistic free-text editing and initial History search/date-filter behavior                                                                           |
| 1.12    | 2026-09-02 | Removed the fixed half-pound increment rule so positive fractional weights are accepted and preserved without rounding                                         |
| 1.13    | 2026-09-02 | Defined direct, authorized navigation from each PR-history event to its exact full source workout                                                              |
| 1.14    | 2026-09-03 | Defined same-gym, read-only administrator member drill-down across track-scoped workout history and PR progression                                             |
| 1.15    | 2026-09-03 | Defined the implemented track-bound programming import review, scoring confirmation, preview, draft-save, and transactional publication flow                   |
| 1.16    | 2026-09-03 | Defined secure track invitation creation, seven-day refresh behavior, reusable link replacement, and public link validation                                    |
| 1.17    | 2026-09-03 | Defined invitation-bound registration, verified-email activation, required acknowledgements, and atomic gym/track membership creation                          |
| 1.18    | 2026-09-03 | Defined self-service member profile editing and the history-preserving, dual-confirmation leave-track correction flow                                          |
| 1.19    | 2026-09-03 | Defined authenticated reminder preferences with ISO weekdays, per-day local times, apply-to-all convenience, and atomic replacement                            |
| 1.20    | 2026-09-03 | Added contextual iOS notification permission, private APNs device registration, denied-permission recovery, and sign-out token disabling                       |
| 1.21    | 2026-09-03 | Added secure five-minute reminder claims with local-time/DST resolution, active-membership checks, logged-date suppression, and idempotency                    |
| 1.22    | 2026-09-08 | Added secure date-specific Log Results loading and sign-in-safe notification deep links with completed-workout locking                                         |
| 1.23    | 2026-09-08 | Prepared a credential-gated APNs HTTP/2 provider boundary with private ES256 signing and privacy-safe outcome classification                                   |
| 1.24    | 2026-09-08 | Approved and implemented immediate invalid-token handling plus two jittered reminder retries at fifteen and thirty minutes                                     |
| 1.25    | 2026-09-09 | Added representative GP/SP parser fixtures, SP shorthand recognition, and explicit `n/a` block omission                                                        |
| 1.26    | 2026-09-09 | Defined visible Gym Closed days and prompt-driven multi-select workout alternatives with per-option results                                                    |
| 1.27    | 2026-09-09 | Confirmed that clearly distinct scoreable exercises receive separate member result cards while unscored circuits remain grouped                                |
| 1.28    | 2026-09-09 | Implemented selectable workout alternatives and visible, non-loggable Gym Closed days across admin, member, and database flows                                 |
| 1.29    | 2026-09-12 | Added per-account iPhone local unlock, device-passcode fallback, background privacy protection, and deferred notification navigation                           |
| 1.30    | 2026-09-12 | Added current-password verification, isolated email-code password recovery, and twelve-character registration validation                                       |
| 1.31    | 2026-09-14 | Fixed empty programming headings producing inaccessible review drafts; validate parser output before saving and distinguish review errors from missing imports |
| 1.32    | 2026-09-14 | Strength and Accessory sections with blank or case-insensitive N/A content display unscored N/A to members                                                     |
| 1.33    | 2026-09-14 | Fixed Today response mapping so published workouts load when the internal Gym Closed flag is false                                                             |

## 1. Executive summary

OC Training Log gives OC Gym Bend members a simple place to see their daily programming, record results, review prior training, and understand personal progress. It replaces inconsistent paper notebooks, generic apps, and untracked workouts with a shared structure tailored to the gym's Sports Performance and General Population programs.

The first release consists of a native iOS member application and a responsive web administration application. Coaches publish programming by track; members log structured results; the system automatically detects benchmark PRs. Scheduled push reminders encourage consistent use until class-attendance events can be integrated from Kilo or another gym-management system.

## 2. Problem statement

Young adults in Sports Performance classes do not consistently track their workouts. This prevents the gym owner and coaches from ensuring accountability and demonstrating improvement. Adults training under General Population programming also lack a standardized way to log workouts and monitor progress.

Current member behavior includes paper notebooks, miscellaneous apps or phone notes, inconsistent recording, and no tracking at all. Coaches cannot reliably see historical results or prove the value members receive from their gym fees.

## 3. Proposed solution

Provide a structured training log that:

- delivers the correct daily programming for a member's training track;
- prompts members to log results after their usual class time;
- asks for the appropriate score—weight, reps, time, distance, calories, rounds, or notes—based on programming;
- maintains searchable workout history;
- detects and preserves benchmark PR history;
- calculates training percentages for weighted PRs;
- lets coaches upload, review, and publish programming and inspect member progress.

A future Kilo integration may recognize class attendance and trigger reminders. Scheduled reminders are the MVP fallback.

## 4. Vision, mission, and principles

### Vision

Give athletes one dependable record of what they trained and how they are improving, while giving coaches useful visibility into development.

### Mission

Make logging a workout simple enough that every athlete consistently records results immediately after training.

### Product principles

1. Today's action comes first.
2. Logging must take less effort than finding the workout elsewhere.
3. Coaching language remains recognizable.
4. History is permanent, searchable, and editable by its owner.
5. Progress is understandable without becoming an analytics dashboard.
6. Imported programming is reviewed by a human before members see it.

## 5. Goals and success definition

### User goals

- Know what to train today.
- Record results accurately and quickly.
- Find prior workouts or movement results.
- Know current and historical bests.
- Calculate percentage-based training weights.

### Business goals

- Improve member accountability and logging consistency.
- Help coaches monitor progress.
- Demonstrate strength and performance improvement, especially for young athletes.
- Increase perceived return on gym membership.

### MVP success measures

Initial numeric targets require baseline data, but the product should instrument:

- invited members who activate an account;
- weekly active members;
- assigned workouts with a completed log;
- reminder-to-log conversion;
- median time to complete a log;
- members who view History or PRs;
- programming days published without member-facing correction;
- draft recovery and synchronization failures.

Success means members repeatedly log results, can retrieve historical workouts and specific movements, and can monitor meaningful progress.

## 6. Personas

### Sports Performance member — primary

Young athletes in Sports Performance classes, including members aged 13–17. They need a prompt to log, the day's coach-authored programming, quick structured entry, and clear evidence of improvement.

### General Population member — secondary

Adults following General Population programming. They need consistent logging, searchable history, PRs, and percentage weights based on max lifts.

### Owner/Coach/Admin

The gym owner or a coach who authors programming and manages members. MVP uses one combined staff role. The initial administrator is Sean Wells (`sean@ocgymbend.com`). Staff need to publish programming by track, invite members, see track rosters, and open a member's workout history and PRs.

## 7. MVP scope

### Member iOS application

- Register through a track-specific invitation or share link
- Email/password authentication and email verification
- Face ID convenience after authentication where available
- Home with Today's Workout and Sessions This Week
- View daily track programming and enter structured results
- Free-text entry when no programming is published
- Local autosaved drafts and retry after brief offline use
- Complete and later edit workout logs
- Searchable Workout History with PR-session shortcut/filter
- Searchable Personal Records list and individual record history
- Weighted PR percentage table in record detail
- Profile, track membership display, and leave-track flow
- Scheduled push-reminder settings

### Responsive admin web application

- Initial seeded gym and SP/GP tracks
- Track overview and member counts
- Import a day or month of programming by paste, Word, text, or spreadsheet
- Parse, review, edit, preview, and publish programming
- Invite one or more members by email
- Generate, copy, and disable reusable track-specific links
- Resend an unexpired or replacement invitation
- View SP or GP roster
- Open an active member to see read-only, track-scoped History and PR progression; administrators cannot view members from another gym

### Explicitly post-MVP

- Android member app
- Custom track creation beyond SP and GP
- Granular Owner, Coach, and Admin roles
- Kilo attendance integration
- Advanced coach analytics and reports
- Athlete-specific programming substitutions
- Social features, leaderboards, or messaging
- Full light/dark theme preference, although designs should not preclude it

## 8. Information architecture and navigation

### Member bottom navigation

1. Home
2. Workouts — Workout History
3. PRs — Personal Records
4. More — extensible destinations added later
5. Profile — account and settings

Duplicate Quick Actions are omitted from Home because their destinations already exist in navigation.

### Admin navigation

- Dashboard / Tracks
- Programming
- Members
- Invitations
- Settings

Track context must be visible wherever programming or members are managed.

## 9. Onboarding and account access

### Entry methods

An admin chooses a track and either enters email addresses or creates a reusable link. Both routes are track-specific to avoid incorrect track selection.

### Member registration

Required fields:

- First name
- Last name
- Email address
- Password
- Confirmation that the linked track is correct
- Age confirmation of 13+
- Terms and privacy acceptance

Phone number is not required.

### Flow

1. Member opens the invitation or link.
2. App presents the gym and track, such as `OC Gym Bend · Sports Performance`.
3. Member registers or signs in if the email already has an account.
4. New users verify their email before activation.
5. Member confirms the track with a warning that it cannot be freely changed in Profile.
6. Member optionally enables notifications and configures reminders.
7. Member lands on Home.

Account creation from a link validates the presented token and, for an email invitation, requires the entered email to match before creating an identity. The member supplies matching passwords and confirms age 13+, Terms acceptance, and Privacy acknowledgement. New accounts remain inactive until email verification; verification returns to the same invitation and atomically activates both gym and exact-track membership. Existing verified accounts may sign in and accept the link after providing the same required acknowledgements. Email invitations are then consumed, while reusable links remain valid for other members.

An existing account accepting another link receives an invitation to join that track. A member may leave a track through two confirmation steps. This is the MVP correction path for an incorrect membership.

### Invitation rules

- Email invitations expire after one week.
- Admins can resend invitations.
- Share links are reusable and permanent until an admin disables them.
- No pre-existing gym-member-list match is required.
- Invitation and share-link secrets are shown to an admin only when created or refreshed; only a cryptographic hash and short non-secret hint are retained.
- Refreshing an open email invitation rotates its secret and starts a new seven-day validity window, immediately invalidating the prior URL.
- Creating a replacement reusable link disables the prior link for that track before the new URL becomes active.
- A public link check reveals only the gym, exact track, link kind, expiration when applicable, and a masked invited-email hint. It does not expose invitation records or full email addresses.

## 10. Member Home

Home answers: “What do I need to do today?”

### Required content

- OC Training Log brand and compact track indicator (`SP` or `GP`) in the top-right header
- Greeting and member name
- Primary `Log Results` card showing date, Today's Workout, and track
- `Sessions This Week`, using the member's local calendar week, with logged-day summary and link to the relevant History view
- Appropriate empty, rest-day, loading, and error states

The full “Sports Performance” label should not repeat on every History card. A compact indicator at page level is sufficient.

### No programming state

If the track has no published programming for that date, `Log Results` opens a free-text entry so members can preserve self-directed training. The member supplies a title and non-empty workout details. The entry belongs directly to the member, track, and local workout date; it does not create synthetic programming, movements, scored results, or PRs. A member may have only one workout per track and date. Published programming takes precedence, so a free-text workout cannot be created while programming is published for that track and date. Free-text entries appear in History under their supplied title with their notes preserved exactly.

The default workout date is resolved on the server using the member's stored IANA time zone, including daylight-saving changes. If the member time zone is missing or invalid, the active gym's time zone is used until the client refreshes the member setting. The authenticated client may request a strict calendar date only when opening a date-specific Log Results destination, including a delayed reminder tap; track authorization is rechecked for every request.

## 11. Today's Workout / Log Results

This is the core member workflow.

### Display

- Date and compact track indicator
- Programming blocks in coach-defined order
- Recognized block types such as Warm-up, Jumps, Strength, Accessory, WOD, Finisher, and Recovery
- Prescriptions, coach notes, substitutions, percentages, tempo, and equipment details

Warm-up and Recovery/Cool-down content is read-only and has no completion toggle.

### Structured input

Each scoreable movement displays inputs inferred and confirmed during programming publication:

- Fixed-rep strength: weight used; reps shown from prescription
- Variable-rep max: weight and completed reps required
- Timed effort: duration
- Height or distance: numeric value and unit
- Max reps: positive whole repetitions
- Calories/distance: positive numeric result plus `cal`, `m`, `km`, `ft`, `yd`, or `mi`
- Rounds and reps: nonnegative rounds plus remaining reps, with at least one nonzero value
- Non-scoreable work: day-level completion with optional workout notes/details

A published Gym Closed day is visible to members but cannot be logged. When a workout offers alternatives, the admin may define them as a selectable option group. Members select one or more completed options, and each selected option reveals the result input required by the workout prompt. The equipment does not determine the result schema: for example, both `500m row for time` and `50-calorie bike for time` require a duration, while both `4-minute row for max calories` and `4-minute bike for max calories` require calories. Unselected options create no result.

Clearly distinct scoreable exercises receive separate result cards even when they appear on one source line. For example, Back Squat and Russian Swing each receive their own weight field. Warm-ups and unscored circuits remain grouped. The importer may propose a split only at a clear exercise boundary; the source text remains available and uncertain splits require admin review.

Every workout also supports notes. Configuration details such as band color, chain weight, box/foam setup, specialty bar, or unsuccessful attempts remain optional details/notes unless a later benchmark standard requires them.

### Validation

- Weight accepts positive pound values, including fractional loads, and preserves the submitted value without rounding.
- Time accepts `MM:SS`, `HH:MM:SS`, and tenths of a second, including `03:21:05.5`.
- Height and distance accept inches, feet, meters, yards, or miles. Current jump benchmarks normalize to inches for PR comparison while History preserves the entered value and unit.
- Calories remain distinct from distance. Activity distance normalizes to meters for PR comparison while History preserves the entered value and unit.
- Rounds-plus-reps compare completed rounds first and remaining reps second.
- Variable-rep maxes require completed reps.
- Dumbbell benchmark load is entered and stored per hand and labeled `lb each`.
- Required fields depend on the result schema.
- A submitted result identifies its published result schema and includes only that schema's fields; mismatched or extra score fields are rejected.
- Structurally invalid values are blocked with a clear error.
- Plausible but unusual values trigger a confirmation and are preserved unchanged when confirmed.
- Plausibility thresholds are configurable rather than embedded in the clients; gym approval of initial thresholds is required before pilot.

### Drafts, completion, and editing

- Inputs autosave locally as the member types.
- Drafts survive app closure and brief connectivity loss.
- Member explicitly completes the workout.
- If the completion endpoint is unavailable, the validated request is queued locally for that authenticated member and programming day. Queued fields are locked so the exact request cannot drift before synchronization.
- Pending completions retry after the member app reloads or refreshes. The stable request identifier makes retries idempotent.
- Successful synchronization shows confirmation and any new PRs.
- A server conflict stops automatic retries, remains visible as requiring review, and never overwrites either version.
- Conflict resolution shows the saved and queued versions side by side. Keeping the saved version is the primary choice; replacing it with the iPhone version is available only when the latest server version is loaded. Both choices require confirmation before one version is discarded.
- Completed workouts remain editable without a member-facing audit trail in MVP.
- An edit is accepted only when its expected version still matches the stored workout. Stale edits return a visible conflict instead of overwriting newer data.
- Corrected results trigger a rebuild of the member's benchmark record history from retained raw movement results so current and historical PR indicators remain consistent.

## 12. Workout History

History shows all prior logged workouts in reverse chronological order.

### List behavior

- Search is case-insensitive across workout titles, member notes, movement names, prescriptions, and displayed result values
- Date filters initially offer all dates, the most recent 30 days, 90 days, or one year using the member's local calendar date
- Track-level context rather than a repeated label on every card
- Shortcut/filter for sessions containing a PR, using the yellow PR indicator
- Cards emphasize Jumps (J), Strength (S), and Accessory (A) content
- Warm-up and Finisher content is omitted from card summaries
- Freeform is not shown as a default filter
- Card opens full workout details and editing; free-text title/details use the same stale-version protection as programmed workout edits

### Workout detail

- Date, track, completion state, and programming blocks
- Recorded movement results and notes
- PR badges linked to the relevant Personal Record detail
- Edit action

## 13. Personal Records

The top-level page lists current bests for benchmark movements belonging to the member's track.

### PR list

- Search by benchmark or movement
- Current best value and date
- Useful grouping/filtering based on track catalog
- Empty states for benchmarks without a result
- Selecting a record opens its detail

### PR detail

- Benchmark name and latest best
- Historical list of prior PRs with dates
- Link to the exact full workout where each record occurred; the lookup remains restricted to the signed-in member and selected track
- `History` tab
- `Percentages` tab only for pound-based records

The percentage table uses the latest PR, displays 50% through 95% in 5% steps, and rounds each result to the nearest whole pound.

### Automatic detection

- A published prescription creates or updates a PR only when an admin-confirmed benchmark link identifies the exact track, movement, result schema, and comparison dimensions. Ordinary training loads do not become PRs through name or text inference alone.
- Higher values win for weight, reps, jump height, distance, calories, and other higher-is-better schemas.
- Lower values win for `For Time` efforts.
- Variable-rep weighted benchmarks compare independently within each completed rep count.
- Hurdle-jump entries remain notes-only and do not create PRs until a standardized measurement is approved.
- The first valid benchmark result establishes the first PR.
- Later improvements append PR history; they do not replace prior rows.
- Coach approval is not required for MVP.
- Unsuccessful attempts written in notes do not become records.

## 14. Profile and reminders

### Profile

- First and last name
- Verified email address
- Current gym and track memberships
- Password/security settings
- Face ID preference where supported
- Notification settings
- Member time zone, refreshed from the device when available
- Privacy, terms, data/export/delete entry points
- Sign out
- Leave track, protected by two confirmations

Members cannot directly switch a track selector. Joining another track requires its invitation or share link.

The initial Profile implementation lets an authenticated member view their verified-email status, active gym and track memberships, edit their first and last name, and store a valid IANA time zone. Email is read-only. Leaving a track requires two consecutive destructive confirmations, marks only that membership as left, and preserves the member account, gym relationship, workout history, and PR history. A departed member must use a new invitation or enabled share link to rejoin.

### Password management

Profile > Security includes Change password, requiring the current password and matching new passwords of 12–128 characters. The iOS sign-in screen includes Forgot password: request a recovery email, enter its six-digit code, and set a matching new password. The backend's twelve-character minimum also applies to invitation registration. Password values are never trimmed or normalized.

Acceptance criteria:

- Invalid or mismatched new passwords never reach the password-update operation.
- A current-password change verifies credentials for the exact signed-in member before updating.
- Recovery requests use neutral account-existence wording; invalid, expired, or consumed codes cannot update a password.
- Recovery sessions and reauthentication sessions are temporary, isolated from the member Keychain session, and cleared on completion or dismissal. Recovery alone never opens member screens.
- A successful code verification may retry a rejected password without replaying the consumed code.
- Password fields and recovery codes are cleared after success and dismissal; they are never autosaved or logged.
- The success screen confirms the update and directs the member to use the new password on subsequent sign-in. It does not claim immediate revocation of all existing access tokens.
- Recovery email uses the configured Supabase template and delivery service. Production requires the matching template, six-digit/one-hour OTP settings, password policy, and working SMTP configuration.

### Local unlock

Members may enable Face ID / Touch ID unlock in Profile > Security after successful device authentication. The preference is off by default and applies only to that member on that iPhone. Apple's device passcode is the recovery option when biometrics are unavailable. The app does not collect biometric data or replace server authentication.

Acceptance criteria:

- A restored protected session shows the lock screen before rendering private member screens.
- Backgrounding relocks the session; inactive and background app previews cover private content.
- Canceling or failing authentication keeps the app locked and permits an explicit retry or sign-out.
- Authentication that finishes after backgrounding cannot unlock the app or enable a preference.
- Locking preserves the current workout view and drafts; notification destinations wait until unlock.
- Disabling protection is available only within an unlocked session. Preferences remain isolated when different members use the same iPhone.

### Reminder settings

Members can multi-select Monday through Sunday and set a separate local time for each selected day. `Apply this time to all selected days` reduces repetitive entry.

Reminder preferences use ISO weekday numbers from Monday `1` through Sunday `7`, a `HH:MM` local wall-clock time per selected day, and the member's validated IANA time zone. Saving replaces the member's full schedule atomically; saving no selected days turns reminders off. The settings API does not register a device or imply that notification permission has been granted.

The iOS Profile explains why notifications are useful before the member explicitly requests permission. A grant registers the current APNs token through an authenticated endpoint; a denial sends nothing and presents a direct path to iPhone Settings. The app requests the current token from APNs again after later launches instead of caching it locally. Tokens are private on the server, are reassigned if the same device signs in to a different account, and are disabled before sign-out. Permission and device registration still do not imply that scheduled APNs delivery is active.

Push text: `Log your Training Results`.

Tapping the notification opens `octraininglog://log?date=YYYY-MM-DD` and loads that date's Log Results page. The destination is retained through sign-in when necessary, rejects malformed dates, and reloads only the member's active SP and/or GP tracks. If the workout was completed after the reminder was delivered, the saved state is shown with result entry locked. Members may always open Log Results without a notification.

Rules:

- suppress the reminder if that date is already logged;
- follow the device/member time zone and daylight-saving changes;
- request push permission with explanatory context;
- send nothing if permission is denied and provide a Settings path;
- email fallback is not committed for MVP;
- future Kilo check-in events may replace or supplement schedules.

The server prepares due reminders every five minutes using each schedule's local wall-clock time and IANA time zone. A candidate requires an enabled schedule, an enabled registered device, and active gym and track membership. Any completed workout log for that member's local workout date suppresses the user-level reminder, regardless of track. A schedule/device/date combination is created at most once even if the worker runs repeatedly. Preparation records pending or suppressed audit state. Immediately before each provider attempt, the server rechecks the completed workout, active memberships, schedule, and device. The APNs provider boundary validates an all-or-none server credential set, signs short-lived ES256 provider tokens, builds the date-specific private payload, selects the sandbox or production HTTP/2 endpoint from the registered device environment, and classifies Apple responses without exposing tokens or keys.

An initial transient APNs failure receives up to two additional attempts: approximately fifteen minutes and thirty minutes later, each with zero to fifty-nine seconds of jitter. A transient failure on the third total attempt becomes terminal. Invalid or unregistered tokens become terminal and disable that device token immediately; corrected app registration may enable a current token later. Configuration, authentication, and malformed-request failures are terminal and must be investigated rather than retried automatically. Scheduled APNs transmission remains inert when the complete server credential set is absent.

## 15. Admin experience

### Initial setup

The first build is for one gym, so OC Gym Bend, Sean Wells, and the SP/GP tracks may be seeded. A generalized future setup would ask an admin to create a gym and track.

### Tracks dashboard

- Display Sports Performance and General Population cards
- Show member counts and programming status/date coverage
- Actions: manage programming, view members, and invite members

### Track members

- Toggle or filter between SP and GP
- Search members
- Show membership/invitation status and recent activity
- Select a member to open their workout history and PRs

### Invite Members

- Track selector/context
- Multi-address email input
- `Send Invitation` as the primary red button
- Status list with resend capability
- Generate/copy reusable track-specific share link
- Disable a compromised or outdated link and generate a replacement

### Programming

Admins can paste programming or upload Word, text, or spreadsheet content. One operation may contain a full month.

The initial implementation accepts pasted text and `.txt`, `.md`, `.docx`, `.xlsx`, `.csv`, or `.tsv` files up to 5 MB. When a source date omits its year, the admin supplies the year used by the parser. The extracted source text and review draft remain private to same-gym administrators and are retained for side-by-side comparison; uploaded binary files are not retained after extraction in the MVP.

Workflow:

1. Choose track.
2. Paste content or upload a file.
3. System identifies dates, blocks, movements, prescriptions, and likely result inputs.
4. Review imported dates in a calendar/list with warnings.
5. Compare parsed structure with source text.
6. Correct blocks, labels, inputs, and notes.
7. Preview the member view.
8. Explicitly approve and publish.

Drafts can be saved. Published future programming can be corrected and republished. Past programming may receive spelling or minor content corrections; changes must not overwrite members' historical recorded results.

### Parsing standard

The General Population sample establishes a supported content pattern:

```text
Tuesday, August 04 2026

Strength: 6x6 e/s Kneeling Landmine Press ...
Accessory: 2 rounds ...
Wod: Complete one round every 5:00 for 15:00 ...
Recovery: 1x25 ...
```

The importer must recognize date headings, case-insensitive block labels, GP labels, SP shorthand (`WU`, `J`, `S`, `A`, and `F`), multiline instructions, footnotes, sets/reps, loads, percentages, time domains, `For time`, distance, calories, and alternatives. A block explicitly marked `n/a` is omitted rather than treated as missing content; an empty labeled block remains visible and blocks publication until corrected or removed. The importer may suggest entry schemas but must flag ambiguity for admin confirmation.

Every import requires admin review. Unresolved dates, track conflicts, duplicate active dates, and unresolved required result schemas block publication. Unknown content remains visible and editable; an admin may explicitly preserve it as unscored text rather than discard it.

Changing or confirming the proposed member result input resolves that item's scoring warning. Warm-up and Recovery remain unscored. Publishing is an explicit final action and writes every date in one transaction. Republishing a corrected date archives the prior programming version rather than rewriting it, preserving any member history attached to the prior version.

## 16. Representative user stories and acceptance criteria

### Log assigned workout

As an SP or GP member, I want to see today's programming and enter weights, times, reps, and notes.

Acceptance:

- only programming for an active member track is shown;
- fields match the published result schema;
- a draft is locally restored;
- completion saves History and evaluates PRs;
- no-programming days allow free text.

### Review progress

As a member, I want to find prior workouts and lifts so I can understand progress and plan training weights.

Acceptance:

- History and PR search return relevant movements;
- PR detail includes dated historical bests;
- weighted PR detail calculates the approved percentage table;
- every PR can link back to its workout.

### Receive a reminder

As a member, I want a reminder after my normal training time so I consistently log results.

Acceptance:

- each weekday can use a distinct time;
- apply-to-all is available;
- tapping opens the correct date;
- a completed date is suppressed;
- local-time changes are respected.

### Publish programming

As an admin, I want to upload or paste a month of programming so members can log against structured daily inputs.

Acceptance:

- import supports all approved source types;
- dates and blocks become reviewable drafts;
- ambiguous parsing is visibly flagged;
- admin previews before explicit publication;
- one active workout exists per track/date.

### Inspect a member

As an admin, I want to select a member in a track and view their workouts and PRs.

Acceptance:

- roster is filterable by SP/GP;
- staff can search and open a member;
- member details expose read-only History and PR views;
- access is limited to the admin's gym.

## 17. Data model summary

Core entities:

- User
- Gym
- Gym Membership and role
- Training Track
- Track Membership
- Invitation and Share Link
- Program Import
- Programming Day
- Workout Block
- Movement and Prescribed Movement
- Workout Log
- Movement Result
- Benchmark
- Personal Record
- Reminder Schedule and Device Token

Detailed fields and relationships are maintained in `docs/architecture.md`.

## 18. Privacy, youth, and legal

- Minimum age is 13; children under 13 are excluded from the initial release.
- Guardian consent for minors is expected through gym membership, but the product's reliance on that process must receive legal review.
- Collect only necessary identity and training data. Phone number is excluded from MVP.
- Before launch, publish a clear privacy notice covering collected information, purposes, service providers, retention, security, member choices, deletion, contact details, and youth handling.
- Implement data deletion/export, retention rules, guardian/member access policy, and incident response before production launch.
- Obtain qualified review for applicable federal and Oregon privacy, consumer, biometric/Face ID, and youth requirements. This specification is not legal advice.

## 19. Visual and interaction direction

- Brand-forward black/red appearance is the primary visual direction.
- Preserve the successful light mockup direction as a future light display option.
- Use yellow sparingly for PR status.
- Avoid repeating track labels on every card; use a compact page-level `SP` or `GP` indicator.
- Keep content dense enough for real programming but use progressive detail so History remains scannable.
- Meet iOS accessibility expectations for Dynamic Type, VoiceOver, contrast, touch targets, reduced motion, and non-color status cues.

## 20. Roadmap

### Phase 1 — Product definition (substantially complete)

- Problem, personas, value proposition, primary flows, IA, and design direction
- SP/GP track model and major MVP decisions

### Phase 2 — Detailed requirements and prototype (substantially complete)

- Member and admin workflows
- Result schemas and PR rules
- Reminders, invitations, programming ingestion, and validation
- Outstanding: final legal/privacy requirements, implementation-level validation guardrails, and remaining benchmark conventions

### Phase 3 — Development foundation

- Native iOS and responsive web scaffolds
- Backend selection, schema, environments, CI, authentication, design tokens, and seeded gym/tracks
- Representative parser fixtures and benchmark imports

### Phase 4 — MVP implementation

- Admin programming and invitations
- Member onboarding, Today, logging, drafts, History, search, PRs, Profile, and reminders
- Admin member drill-down

### Phase 5 — Pilot and release

- Internal coach testing, TestFlight pilot, accessibility/security/legal review
- Instrument success measures, resolve data-quality issues, and App Store release

### Phase 6 — Expansion

- Kilo integration, Android, custom tracks, granular roles, deeper analytics, and refined notification channels

## 21. Open questions

### Required before pilot

1. Define the hurdle benchmark score measurement before enabling automatic hurdle PRs; notes-only logging may ship without it.
2. Approve configurable plausibility-warning thresholds for each result schema; preserve submitted weight values and tenths-of-a-second time precision.
3. Complete privacy notice, data retention/deletion, guardian access, consent, and legal review.
4. Validate parser confidence behavior against representative monthly SP and GP source files.

### Post-MVP discovery

5. Determine available and commercially permitted Kilo APIs/events.
6. Decide whether attendance prompts replace or supplement scheduled reminders.
7. Define additional tracks and granular staff permissions.
8. Define advanced movement progress charts, reports, or exports.
9. Revisit passkeys and email reminders after MVP usage is understood.

## 22. Glossary

- **A — Accessory:** Supplemental work supporting strength, balance, or durability.
- **Benchmark:** A repeatable movement or workout retained for comparison and PR tracking.
- **F — Finisher:** Work performed at the end of training.
- **GP — General Population:** Adult-focused training track.
- **J — Jumps:** Jump or explosive-performance work.
- **Max lift:** Highest successful load completed under the prescribed movement standard.
- **ME — Max Effort:** Work intended to establish a high-effort strength result.
- **Percentage lift:** Training load derived from a percentage of a max, such as 65 lb at 65% of a 100 lb max.
- **PR — Personal Record:** Best valid recorded score for a defined benchmark; comparison direction depends on score type.
- **S — Strength:** Primary strength-training block.
- **Sets and reps:** Sets are the number of rounds of a movement; reps are repetitions per set. `3x10` means 3 sets of 10.
- **SP — Sports Performance:** Youth/athlete-focused training track.
- **WOD — Workout of the Day:** Conditioning or mixed-modal daily workout.
- **WU — Warm-up:** Preparatory work at the beginning of training.

### Programming import reliability acceptance criteria

- Strength and Accessory headings with blank content or case-insensitive `N/A` content remain visible as `N/A` in member programming. They use notes-only scoring, require no result input or scoring confirmation, and never generate PRs. This applies independently to SP and GP. Other empty section headings are omitted. Original source remains intact, and exercise content on subsequent lines is retained. Missing headings are not synthesized.
- Parser output must satisfy the review contract before a new import is persisted. Empty workout dates and unsupported draft structures produce an actionable upload error.
- A missing or unauthorized draft remains unavailable; database failures and invalid saved drafts display an explanatory review error instead of a misleading 404.

- Today retrieval must return a valid published-workout response when the stored Gym Closed flag is false, and the closed-day response when it is true. Internal flags must not invalidate the member API contract.
