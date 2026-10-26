# iOS application

The member app is a native SwiftUI application targeting iOS 17 or later.

## Prerequisites

- Full Xcode installation with an iOS simulator runtime
- XcodeGen for deterministic project generation

## Generate and test

Copy the browser-safe local configuration after starting Supabase:

```sh
cp Config/Local.xcconfig.example Config/Local.xcconfig
```

Replace the publishable-key placeholder with the `PUBLISHABLE_KEY` shown by `pnpm db:status`. The example API URL, `http://127.0.0.1:3000`, reaches the local Next.js server from the iOS simulator. A physical iPhone requires the Mac's reachable local-network URL instead. Never place the service-role key in an iOS build setting.

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license
cd apps/ios
xcodegen generate
xcodebuild test \
  -project OCTrainingLog.xcodeproj \
  -scheme OCTrainingLog \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The generated Xcode project may be recreated from `project.yml`; application source and tests remain the authoritative inputs.

After member sign-in, the Home screen calls the authenticated Today endpoint for the two supported system tracks and displays only responses authorized for that member. Pull down to refresh the programming.
