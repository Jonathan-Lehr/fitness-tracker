# FitnessTracker — agent guide

Personal SwiftUI + SwiftData app for logging NordicTrack S22i / iFit rides and comparing repeat efforts. One multiplatform target: iOS 17+ and macOS 14+. Bundle ID is `com.jonathanlehr.FitnessTracker`. Do not change the bundle ID or the CloudKit container ID.

This file is the project instruction file Grok Build (and other coding agents) load from the repo root. Keep it accurate and concise. Prefer native SwiftUI. Match existing style in neighboring files.

## Architecture

Tabs in `ContentView`: **Log**, **Programs**, **Trends**. Weeks are Monday-first ISO (`Calendar.app`) app-wide.

| Path | Role |
| --- | --- |
| `FitnessTracker/App/` | App entry (`FitnessTrackerApp`), root `ContentView`, window sizing, orientation lock, preview fixtures |
| `FitnessTracker/Log/` | Log tab: list/grid, filters, ride rows |
| `FitnessTracker/Workouts/` | Ride detail, add/edit form, and the scratch-context editing session |
| `FitnessTracker/Summary/` | Period summary model and cards (current and past) |
| `FitnessTracker/Trends/` | Trends tab, chart data, Watts axis math, in-progress comparison |
| `FitnessTracker/Programs/` | Programs tab, program detail, side-by-side compare |
| `FitnessTracker/Import/` | Photo decode/OCR (`PhotoImport`) and the unit-testable `IFitSummaryParser` |
| `FitnessTracker/Data/` | Seed rides, simulated debug data, CloudKit `DataDeduper`, JSON backup, Backup & Restore and debug menus |
| `FitnessTracker/Models/` | SwiftData types (`Program`, `Workout`) and logic shared across features (`AppCalendar`, `GroupingPeriod`, `Totals`) |
| `FitnessTracker/SharedViews/` | Subviews used by several features (`AppColor`, `StatTile`, `TypeTag`, `RideImage`) |
| `FitnessTracker/Extensions/` | General-purpose extensions and formatting helpers |
| `FitnessTrackerTests/` | Unit tests (parser, OCR fixtures, summaries, axis, grid/thumbnails, backup, dedupe, form editing); shared helpers in `TestSupport.swift`. Tests stay in one flat folder. |
| `Config/` | Shared/local xcconfig, entitlements, iOS Info.plist |
| `Design/` | App icon source and renderer |
| `project.yml` | XcodeGen spec that mirrors the committed `FitnessTracker.xcodeproj` |

Feature groups hold their views plus logic used only by that feature. `Models/` holds SwiftData types and logic shared across features, `SharedViews/` holds subviews used by several features, and `Extensions/` holds general extensions and formatting helpers. Tests stay in a flat `FitnessTrackerTests/` folder. Group new files by functional area, not by kind (no Enums or Utilities groups).

`Program` has a title and a `WorkoutType` (endurance, interval, recovery, climb, tempo, other; inferred from the title). `Workout` holds date, duration, distance, calories, elevation, avg RPM/watts, incline, resistance, notes, optional downscaled JPEG (`photoData`, external storage), its Vision thumbnail focus (`thumbnailFocus*`, see `Import/ThumbnailFocus.swift`; computed at import and backfilled at launch by `ThumbnailFocusBackfill`), and `isSimulated`. Models are CloudKit-compatible: no unique constraints, attributes defaulted or optional, optional relationships with inverses.

## Data sources

- **iFit screenshot OCR (the current import path).** Add Ride is photo-first: camera, Photos picker, or (Mac) drag-and-drop / file open. `PhotoImport` decodes and downscales with ImageIO, runs `VNRecognizeTextRequest`, and writes a reduced JPEG. `IFitSummaryParser` is pure Swift (no Vision/UI) and parses title, date/time, duration, miles, calories, elevation, RPM, watts, incline, and resistance. The form opens prefilled for review; unmatched fields are flagged. Existing programs are matched by title (case-insensitive).
- **Ride form editing.** New and existing rides are edited in a scratch `ModelContext` on the same container, with autosave off. The presenting view (`AddRideView` or `WorkoutDetailView`) creates a `WorkoutFormEditing` session and passes it into `WorkoutFormView`, because `@Environment(\.modelContext)` isn't available in `View.init`. Save `findOrCreate`s the program in the scratch context and persists; cancel drops the unsaved context, which discards the edits.
- **SwiftData + CloudKit.** Private database container `iCloud.com.jonathanlehr.FitnessTracker`. Tests and SwiftUI `#Preview`s use an in-memory store with `cloudKitDatabase: .none` so unsigned CI builds work. `#Preview`s for a few views (`WorkoutDetailView`, `PeriodSummaryCard`, `WorkoutRow`, type tags, and section headers) are built through `PreviewSupport`, which seeds the four real rides. Broader preview coverage is #45. `DataDeduper` merges Programs with the same title and Workouts with the same title and start minute (on launch and after CloudKit imports). Four real Oct 2026 rides are seeded once per device.
- **JSON backup.** Versioned export/import in `Data/Backup.swift` (merge or replace, with dedupe). UI lives in Backup & Restore, from the Log toolbar's More menu, and in the debug menu.
- **HealthKit is not implemented.** Heart-rate from Apple Fitness is backlog issue #19. Do not add HealthKit code unless that issue (or a later one) is the work being done.

## Build and test

Requirements: Xcode 16 or later. The committed project uses folder-synced groups, so new files under `FitnessTracker/` or `FitnessTrackerTests/` are picked up automatically — do not list them in `project.yml`.

Signing stays out of git. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig` (gitignored) and set `DEVELOPMENT_TEAM`. `Config/Shared.xcconfig` includes it optionally. Never write the Team ID into `project.pbxproj` or commit `Local.xcconfig`. CI builds with `CODE_SIGNING_ALLOWED=NO`.

```sh
# After changing targets, settings, entitlements, schemes, or Info.plist keys:
# edit project.yml, then regenerate and commit both project.yml and FitnessTracker.xcodeproj
brew install xcodegen   # once
xcodegen                # reads project.yml, writes FitnessTracker.xcodeproj

# macOS build + tests (same as the CI macOS job)
xcodebuild -project FitnessTracker.xcodeproj -scheme FitnessTracker \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test

# iOS Simulator compile (same as the CI iOS job; does not run tests)
xcodebuild -project FitnessTracker.xcodeproj -scheme FitnessTracker \
  -destination 'generic/platform=iOS Simulator' \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build-for-testing
```

Or ⌘U in Xcode for tests. Add or update unit tests when you change logic.

## CI

`.github/workflows/build.yml` runs on every push and PR as a single **Build and test** job. It runs on Jonathan's self-hosted Mac when the repo variable `MACOS_RUNNER` is set (for example `["self-hosted","macOS","ARM64"]`), and falls back to GitHub-hosted `macos-26` when that variable is unset. Pull requests from forks always use hosted `macos-26`, so outside code never runs on the self-hosted Mac. Hosted runners select the latest-stable Xcode.

The job runs these checks in order, and a failure in one does not skip the others:

1. **XcodeGen spec check** — regenerates `FitnessTracker.xcodeproj` from `project.yml` and confirms the `FitnessTrackerTests` target exists.
2. **Test (macOS)** — `xcodebuild test` on `platform=macOS`.
3. **Build for testing (iOS Simulator, arm64)** — `build-for-testing` for `generic/platform=iOS Simulator`.

Keep `project.yml` in sync with any structural project change. A Swift file added under an existing synced folder does not require a `project.yml` edit.

## Workflow

- Track every enhancement or bug as a GitHub Issue on the [FitnessTracker project](https://github.com/users/Jonathan-Lehr/projects/2) (Backlog → Ready → In progress → Done). Reuse a related open issue when one exists. Keep the board status aligned with real progress.
- Label issues by kind (`enhancement`, `bug`, `refactor`, `documentation`) and, when known, by priority (`priority: high`, `priority: medium`, `priority: low`).
- Recording an idea as an issue does not authorize implementing it. Implement only the issue you were asked to work on.
- One branch and one PR per issue. The PR body starts with `Closes #N`. Never push to `main`. Jonathan merges PRs himself.
- After pushing: pure layout changes can be handed off for review immediately. Logic changes wait for green CI.
- When a design is settled, add a **Design decisions** comment on the issue (see [#18](https://github.com/Jonathan-Lehr/fitness-tracker/issues/18#issuecomment-6750071723)). That comment is the lasting record.

## Code quality

Code quality, especially readability, maintainability, and reuse, is an important consideration.

- Reuse existing views, helpers, formatters, and models before adding new ones. Extract shared logic instead of duplicating it.
- Display numbers with the locale-aware helpers in `Formatting.swift` (`FormatStyle`), not `String(format:)`. Pass an explicit `Locale` in tests. Machine-readable values (backups, CloudKit, OCR parsing) stay locale-independent.
- Keep SwiftUI views small and focused. Make liberal use of computed properties, methods, and small subview structs so `body` reads as a clear outline of the layout. Place simpler variable and constant declarations before `body`; methods and view-building properties can follow it. Move calculations and data shaping out of `body` into testable helpers or view models.
- Several types can share a file when they logically belong together. A type used from other files, such as a subview shared by several views, goes in its own file.
- Use clear, descriptive names, and follow the surrounding code's patterns and file organization. Straightforward naming reduces the cognitive burden for human readers, slightly in some cases and significantly in others. Even a local or parameter name should make it obvious what the value *is* (for example `context`, or `scratchContext` when the distinction matters; a name that distinguishes a distance from a duration), and should match related parameter names. A `String` parameter named `s` should be `text`, or a name that says what it is.
- Avoid abbreviations in API and parameter names, types, and global or static properties and constants (for example, `avgWatts`, not `avgW`). Well-established abbreviations such as `avg`, `max`, `min`, `mph`, `rpm`, `id`, and `url` are fine. Spell out `current` (for example `currentTotal`, not `cur` or `curr`). Don't use single-letter or cryptic names such as `m` outside the tightest scopes (for example, `i` in a loop or `$0`). When unsure whether a name is acceptable, ask Jonathan. Apply this to new code and code you're already changing.
- Prefer one enum case per line (`case grid` and `case list`, not `case grid, list`). Leave a blank line after the last case when the enum also has properties, methods, or nested types.
- Prefer one statement per line. Don't stack assignments or other statements with a semicolon (`count += 1; minutes += workout.durationMinutes`). In a view builder, put each view on its own line (`Text("Next")` and `Image(...)`, not `Text("Next"); Image(...)`).
- Comment the *why* for non-obvious decisions, not the *what*.
- Prefer small, coherent changes. Remove dead code and unused helpers you replace.
- Refactor where appropriate, for example code you touch that is duplicated, tangled, or hard to follow. Keep small refactors in the current PR. A refactoring that touches many files or lines of code gets its own issue and PR, separate from feature or bug work.

## UI conventions

Settled during implementation (especially #14, #18, #20). Follow these unless the current issue explicitly changes them.

- Prefer native SwiftUI controls (`List`, `Picker`, `NavigationStack`, and so on).
- Log history photo mode: **iPhone** uses individual native `List` rows grouped by date (date header in the first ride's row; no nested one-column grid). **Mac** keeps the multi-column day-column grid. Both modes share one `List` so the summary card stays the same size and position when toggling.
- Rows and date subheads share the section headers' leading and trailing edges (default insets). Keep section backgrounds so rows line up with the summary card. iPhone photo rows use standard separators, no card borders, and 6 pt of padding at the bottom of each section.
- The List/Grid control is a mutually exclusive segmented `Picker` in its own leading toolbar group, sized with `@ScaledMetric` (44 pt per segment on iOS, 36 pt on Mac).
- Period headers use non-hierarchical secondary gray in both list and grid modes.
- Ride-type tag colors: endurance blue, climb magenta, interval coral, recovery purple, tempo gold, other green (see `WorkoutType.color`). Show the text label and a tinted capsule.
- Custom colors are named color sets in `Assets.xcassets` (light and dark variants), referenced through `AppColor` (#34). Don't hardcode RGB values in views; system colors are used directly.
- Grid/detail navigation uses `NavigationPath` and `Button`s so Back returns to the grid, not a previous detail. On Mac, `selectionDisabled` on the grid's containing row prevents a highlight on return.
- Trends charts use completed periods only; the in-progress period is omitted from the charts and shown separately. Average Watts fits the Y axis to the plotted data (padded, rounded, never below 0) and the X axis to the first–last period that has watts (no empty end padding). Interior periods without watts are dashed bridges, not measured values. The current unfinished period is compared with the same elapsed portion of the previous period ("so far").
