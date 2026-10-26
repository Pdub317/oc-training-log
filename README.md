# OC Training Log

OC Training Log is an iOS-first training journal for members of OC Gym Bend. It gives athletes their assigned daily programming, makes structured result entry fast, automatically identifies personal records, and gives coaches visibility into member progress.

## Product status

The product foundation, MVP requirements, development stack, and implementation milestones are documented. Development-foundation scaffolding is underway. The initial member product is a native iOS application; the Owner/Coach/Admin experience is a responsive web application.

## Documentation

- [Product specification](docs/product-spec.md)
- [Technical architecture](docs/architecture.md)
- [Benchmark catalog](docs/benchmarks.md)
- [Decision log](docs/decision-log.md)
- [Development plan](docs/development-plan.md)

## Initial product surfaces

- Member iOS app: onboarding, daily programming, result logging, workout history, personal records, profile, and reminders
- Responsive admin web app: tracks, programming import/review/publish, invitations, members, and member progress
- Shared backend: identity, programming, workout results, PR calculation, invitations, and notifications

## Initial tracks

- Sports Performance (SP)
- General Population (GP)

## Development setup

Prerequisites:

- Node.js 24 and pnpm 11
- Full Xcode with an iOS simulator runtime
- XcodeGen
- Docker Desktop or another Docker-compatible runtime

Install JavaScript dependencies and verify the admin workspace:

```sh
pnpm install --frozen-lockfile
pnpm check
pnpm build
```

Start the admin application:

```sh
pnpm dev
```

The admin application is available at `http://127.0.0.1:3000`, and its non-sensitive readiness endpoint is available at `/api/health`.

Generate the iOS project after installing full Xcode and XcodeGen:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license
cd apps/ios
xcodegen generate
```

The license command presents Apple's agreement for you to review and accept. It cannot be accepted on your behalf.

Start the local backend after Docker is running:

```sh
pnpm db:start
```

Recreate and verify the local database:

```sh
pnpm db:reset
pnpm db:lint
pnpm db:test
```

Copy the public Supabase values from `.env.example` into `apps/admin-web/.env.local`, using the URL and publishable key printed by `pnpm db:status`. For iOS, copy `apps/ios/Config/Local.xcconfig.example` to `apps/ios/Config/Local.xcconfig` and add the same public values. Never commit either local file or place a service-role key in a client configuration.

## Repository note

This repository currently contains the development foundation and living documentation. Implementation choices should follow the product specification and architecture unless superseded by an entry in the decision log.
