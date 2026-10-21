# fitness-tracker

**FitnessTracker** is a personal SwiftUI + SwiftData app for logging NordicTrack s22i / iFit rides and comparing repeat efforts on the same workout. It's one multiplatform target for iOS 17+ and macOS 14+.

## Setup

Requirements: **Xcode 16 or later** (the project uses folder-synced groups, so any file you add under `FitnessTracker/` is picked up automatically).

1. `git clone https://github.com/Jonathan-Lehr/fitness-tracker && cd fitness-tracker`
2. `open FitnessTracker.xcodeproj`
3. Select the FitnessTracker target → Signing & Capabilities → choose your Team (a free personal team works).
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

The models are CloudKit-compatible: no unique constraints, every property defaulted or optional, optional relationships. iCloud sync is **off** for now (`cloudKitDatabase: .none` in `FitnessTrackerApp.swift`). To turn it on, add the iCloud (CloudKit) and Background Modes → Remote notifications capabilities, then switch to `.automatic`.
