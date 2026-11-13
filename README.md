# fitness-tracker

**FitnessTracker** is a personal SwiftUI + SwiftData app for logging NordicTrack S22i / iFit rides and comparing repeat efforts on the same workout. It's one multiplatform target for iOS 17+ and macOS 14+.

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

- **Log**: rides grouped by Week / Month / Year, with a List/Grid layout toggle. Section headers show ride count, time, average watts, and elevation, with total miles on the trailing edge. Tapping a header opens that calendar period's summary. The top card compares the current rolling period with the previous one. Filters for date range, program, workout type, and minimum average watts. Swipe to delete.
- **Programs**: every iFit program you've ridden. Program detail has a Swift Charts chart of distance, watts, or RPM over time, marks your best effort for the selected metric with a star, and lets you pick two efforts for a side-by-side compare with deltas.
- **Trends**: weekly or monthly charts of ride time, distance, calories, and average watts. The in-progress period is compared with the same elapsed portion of the previous period.
- **Add Ride is photo-first**: **Take Photo** (iPhone camera) or **Choose Photo** (Photos picker, iOS + macOS). On the Mac you can also drag an image onto the drop area or use **Open Image File…**. The photo is read with Vision text recognition and parsed into a new ride. The form then opens prefilled for review, with the photo attached (downscaled JPEG) and any field the parser couldn't find flagged in orange. **Enter manually** opens a form with hand-entry defaults. Nothing is saved until you tap Save; dismissing the form discards the unsaved ride. Existing programs are matched by title (case-insensitive), or a new one is created.
- **Edit ride**: change any field, notes, or the photo. Save persists the changes; cancel discards them.
- **Backup & Restore**: export or import a JSON backup (merge or replace) from the Log toolbar's **More** menu.
- **Seed data**: the 4 real rides from Oct 2026 are inserted on first launch.
- **Debug menu** (DEBUG builds only): **More** (ellipsis) → **Debug…** in the Log toolbar. Generate ~18 months of simulated rides (3–5/week, 20 Utah-themed programs, 4 favorites ridden many times with watts slowly improving), remove simulated rides, re-insert real rides, or clear everything. Destructive actions offer a JSON backup first.

## Photo parsing

- `Import/PhotoImport.swift`: ImageIO decode/downscale (orientation-correct), JPEG export, and `VNRecognizeTextRequest` (accurate, no language correction).
- `Import/IFitSummaryParser.swift`: pure Swift (no Vision/UI), so it's unit-testable. It groups OCR observations into lines and parses the joined text with tolerant regexes: title (text just above "Last completed", ignoring buttons), date/time, duration (`42 min` / `1 hr 5 min`), miles, cals, ft, avg rpm, avg watts, incline avg/max %, resistance avg/max. Chart axis labels are ignored because every value needs its unit.

## Tests and CI

- Unit tests cover the parser (OCR-like fixtures for the 4 real rides, plus `PhotoOCRIntegrationTests` on the sample photos in `FitnessTrackerTests/Resources/`), period summaries, formatting, backup, dedupe, the ride form, and other helpers. Shared test fixtures live in `FitnessTrackerTests/TestSupport.swift`.
- A few screens have Xcode `#Preview`s (`WorkoutDetailView`, `PeriodSummaryCard`, `WorkoutRow`, type tags, and section headers) that use an in-memory store seeded with the real rides.
- Run locally: ⌘U in Xcode, or `xcodebuild -project FitnessTracker.xcodeproj -scheme FitnessTracker -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.
- GitHub Actions (`.github/workflows/build.yml`) runs on every push and PR as a single **Build and test** job. It runs on a self-hosted Mac when the repo variable `MACOS_RUNNER` is set, and falls back to GitHub-hosted `macos-26` otherwise (pull requests from forks always use the hosted runner). The job checks the XcodeGen spec, runs the macOS tests, and compiles for the iOS Simulator.

## Data model

Source files are grouped by feature under `FitnessTracker/`. Each feature group holds that feature's views plus any logic used only there. `Models/` holds the SwiftData types and logic shared across features; `SharedViews/` holds subviews used by several features; `Extensions/` holds general extensions and formatting helpers. Tests stay in one flat `FitnessTrackerTests/` folder.

- `Program`: `title`, `type` (endurance / interval / recovery / climb / tempo / other, inferred from the title), `workouts`.
- `Workout`: date, duration, distance, calories, elevation, avg RPM, avg watts, incline avg/max, resistance avg/max, notes, photo (`photoData`, external storage), Vision thumbnail focus (`thumbnailFocus*` and `thumbnailFocusAnalysisVersion`), `isSimulated`, `program`.

The models are CloudKit-compatible: no unique constraints, every attribute defaulted or optional, and optional relationships with inverses.

## iCloud sync

Rides sync between your devices through CloudKit (private database, container `iCloud.com.jonathanlehr.FitnessTracker`). Tests and SwiftUI previews use an in-memory store without CloudKit, so unsigned CI builds still work.

One-time setup (needs a paid Apple Developer membership):

1. Make sure `Config/Local.xcconfig` exists with your `DEVELOPMENT_TEAM` (see Setup).
2. In Xcode, open the FitnessTracker target → **Signing & Capabilities**. Check that **iCloud** shows CloudKit with the container `iCloud.com.jonathanlehr.FitnessTracker` (click **+** under Containers to create it if it shows red), **Push Notifications** is present, and on iOS **Background Modes → Remote notifications** is checked. The entitlements live in `Config/FitnessTracker-iOS.entitlements` and `Config/FitnessTracker-macOS.entitlements`. If Xcode offers to "fix" signing, let it register the App ID and container, then discard any `DEVELOPMENT_TEAM` line it writes into `project.pbxproj`.
3. Sign in to the same iCloud account on each device, and run the app on each.

Duplicates: CloudKit can't enforce uniqueness, so `DataDeduper` merges Programs with the same title and Workouts with the same title and start minute. It runs on launch and after each CloudKit import. The 4 real rides are seeded once per device and skipped if they already exist.

**Before any TestFlight or App Store release:** open the [CloudKit Console](https://icloud.developer.apple.com), select the container, and **Deploy Schema Changes** from Development to Production. Production builds only see the Production schema. Also switch `aps-environment` to `production` (Xcode does this automatically for distribution builds).
