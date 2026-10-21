# fitness-tracker

**FitnessTracker** is a personal SwiftUI + SwiftData app for logging NordicTrack s22i / iFit rides and comparing repeat efforts on the same workout. It's one multiplatform target for iOS 17+ and macOS 14+.

## Setup

Requirements: **Xcode 16 or later** (the project uses folder-synced groups, so any file you add under `FitnessTracker/` is picked up automatically).

1. `git clone https://github.com/Jonathan-Lehr/fitness-tracker && cd fitness-tracker`
2. `open FitnessTracker.xcodeproj`
3. Set your signing team once (it's kept out of git, so it won't revert on pull):
   ```sh
   cp Config/Local.xcconfig.example Config/Local.xcconfig
   # edit Config/Local.xcconfig: DEVELOPMENT_TEAM = <your 10-character Team ID>
   ```
   Your Team ID is in Xcode → Settings → Accounts (a free personal team works). Don't pick the team in Signing & Capabilities, because that writes it into the shared project file. If Xcode did that, delete the `DEVELOPMENT_TEAM` line it added to `project.pbxproj`.
4. Pick **My Mac** or an iPhone simulator/device and Run.

If the committed project doesn't open for some reason, regenerate it with XcodeGen (`project.yml` mirrors the committed project, including the test target and shared scheme):

```sh
brew install xcodegen
xcodegen        # reads project.yml, writes FitnessTracker.xcodeproj
```

## Features

- **Log**: rides grouped by Week / Month / Year with totals per section (rides, time, miles, calories, climbing). Filters for date range, program, workout type, and minimum average watts. Swipe to delete.
- **Programs**: every iFit program you've ridden. Program detail has a Swift Charts chart of watts, duration, or calories over time, marks your best effort (highest avg watts) with a star, and lets you pick two efforts for a side-by-side compare with deltas.
- **Trends**: weekly or monthly charts of ride time, distance, calories, and average watts.
- **Add Ride is photo-first**: **Take Photo** (iPhone camera) or **Choose Photo** (Photos picker, iOS + macOS). On the Mac you can also drag an image onto the drop area or use **Open Image File…**. The photo is read with Vision text recognition and parsed into a draft ride. The form then opens prefilled for review, with the photo attached (downscaled JPEG) and any field the parser couldn't find flagged in orange. **Enter manually** opens an empty form. Existing programs are matched by title (case-insensitive), or a new one is created.
- **Edit ride**: change any field, notes, or remove the photo.
- **Seed data**: the 4 real rides from Oct 2026 are inserted on first launch.
- **Debug menu** (ladybug toolbar button, DEBUG builds only): generate ~18 months of simulated rides (3–5/week, 20 Utah-themed programs, 4 favorites ridden many times with watts slowly improving), remove simulated rides, re-insert real rides, or clear everything.

## Photo parsing

- `Import/PhotoImport.swift`: ImageIO decode/downscale (orientation-correct), JPEG export, and `VNRecognizeTextRequest` (accurate, no language correction).
- `Import/IFitSummaryParser.swift`: pure Swift (no Vision/UI), so it's unit-testable. It groups OCR observations into lines and parses the joined text with tolerant regexes: title (text just above "Last completed", ignoring buttons), date/time, duration (`42 min` / `1 hr 5 min`), miles, cals, ft, avg rpm, avg watts, incline avg/max %, resistance avg/max. Chart axis labels are ignored because every value needs its unit.

## Tests and CI

- `FitnessTrackerTests/IFitSummaryParserTests.swift`: parser unit tests with OCR-like fixtures for the 4 real rides, plus missing-field and title-proximity cases. `PhotoOCRIntegrationTests` runs real Vision OCR on the sample photos in `FitnessTrackerTests/Resources/` and reports every mismatched field together with the OCR text (currently 48/48 fields correct).
- Run locally: ⌘U in Xcode, or `xcodebuild -scheme FitnessTracker -destination 'platform=macOS' test`.
- GitHub Actions (`.github/workflows/build.yml`) runs on every push and PR. It builds for the iOS Simulator and macOS, runs the tests on macOS, and regenerates the project from `project.yml` with XcodeGen to check that the spec still matches the committed project.

## Data model

- `Program`: `title`, `type` (endurance / interval / recovery / climb / tempo / other, inferred from the title), `workouts`.
- `Workout`: date, duration, distance, calories, elevation, avg RPM, avg watts, incline avg/max, resistance avg/max, notes, photo (external storage), `program`.

The models are CloudKit-compatible: no unique constraints, every attribute defaulted or optional, and optional relationships with inverses.

## iCloud sync

Rides sync between your devices through CloudKit (private database, container `iCloud.com.jonathanlehr.FitnessTracker`). Tests and SwiftUI previews use an in-memory store without CloudKit, so unsigned CI builds still work.

One-time setup (needs a paid Apple Developer membership):

1. Make sure `Config/Local.xcconfig` exists with your `DEVELOPMENT_TEAM` (see Setup).
2. In Xcode, open the FitnessTracker target → **Signing & Capabilities**. Check that **iCloud** shows CloudKit with the container `iCloud.com.jonathanlehr.FitnessTracker` (click **+** under Containers to create it if it shows red), **Push Notifications** is present, and on iOS **Background Modes → Remote notifications** is checked. The entitlements live in `Config/FitnessTracker-iOS.entitlements` and `Config/FitnessTracker-macOS.entitlements`. If Xcode offers to "fix" signing, let it register the App ID and container, then discard any `DEVELOPMENT_TEAM` line it writes into `project.pbxproj`.
3. Sign in to the same iCloud account on each device, and run the app on each.

Duplicates: CloudKit can't enforce uniqueness, so `DataDeduper` merges Programs with the same title and Workouts with the same title and start minute. It runs on launch and after each CloudKit import. The 4 real rides are seeded once per device and skipped if they already exist.

**Before any TestFlight or App Store release:** open the [CloudKit Console](https://icloud.developer.apple.com), select the container, and **Deploy Schema Changes** from Development to Production. Production builds only see the Production schema. Also switch `aps-environment` to `production` (Xcode does this automatically for distribution builds).
