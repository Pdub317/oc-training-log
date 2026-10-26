# AGENTS.md

## Product context

This repository contains OC Training Log, an iOS-first member application and responsive web administration experience for OC Gym Bend.

Before making product or architectural changes, read:

1. `docs/product-spec.md`
2. `docs/architecture.md`
3. `docs/decision-log.md`
4. `docs/benchmarks.md` when working on results or PRs

## Working agreements

- Treat the product specification as a living document and update its version history when requirements change.
- Record consequential decisions in `docs/decision-log.md`.
- Do not invent unresolved business rules. Add them to the Open Questions section of the product specification.
- Keep Sports Performance and General Population programming and benchmark data isolated by track.
- Optimize member interactions for quick, accessible use on an iPhone in or immediately after a workout.
- Build the admin experience responsively, with desktop web as the primary layout.
- Preserve user-entered values. Validation should prevent obvious mistakes without silently changing entries.
- Treat member identity, workout history, and records as private data.
- Minors under 13 are out of scope. Privacy and consent language requires legal review before launch.

## Engineering quality

- Add tests for business rules, especially workout parsing, result validation, PR directionality, percentage calculations, track authorization, and reminder suppression.
- Use migrations for persisted schema changes.
- Keep parsing output reviewable by an admin before publication.
- Never publish imported programming automatically when parsing confidence is uncertain.
- Store timestamps in UTC and render schedules in the member's local time zone, including daylight-saving changes.
- Support lightweight local autosave for in-progress workout results.

## Documentation maintenance

When behavior changes:

- update the affected requirement and acceptance criteria;
- add a dated version-history entry;
- update the decision log if the change resolves a tradeoff or open question;
- update architecture and benchmark documentation when relevant.
