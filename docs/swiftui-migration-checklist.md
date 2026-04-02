# SwiftUI Migration Execution Checklist

This checklist operationalizes [swiftui-migration-plan_v2.md](./swiftui-migration-plan_v2.md) into small, trackable tasks.

## Status Legend
- `[ ]` Not started
- `[/]` In progress
- `[x]` Completed

## Phase 0: Baseline and Bug-Fix Readiness
- [x] Confirm UI test target (`LaterUITests`) launches app successfully.
- [x] Add baseline launch smoke test gate.
- [x] Add baseline relaunch lifecycle smoke test gate in `UITEST_MODE`.
- [x] Review and fix all Phase 0 bug items listed in `swiftui-migration-plan_v2.md`.
- [ ] Record pre-migration manual regression run for current AppKit behavior.

## Phase 1: Architecture Extraction (Current)
- [/] Define extraction boundaries in code:
  - `AppViewModel` owns UI state and actions.
  - `SettingsStore` wraps `UserDefaults` keys.
  - `AppFilterService` holds app inclusion logic.
- [x] Create `SettingsStore` with typed getters/setters for existing keys.
- [x] Add `SettingsStore` tests for defaults and round-trip persistence.
- [x] Introduce `AppFilterService` and migrate all filtering checks to it.
- [x] Add `AppFilterService` tests for system/custom/nil bundle-id cases.
- [x] Create initial `AppViewModel` with read-only state mirrored from current UI.
- [x] Move timer state + timer actions from `ViewController` into `AppViewModel`.
- [x] Move save/restore orchestration from `ViewController` into `AppViewModel`.
- [x] Move hotkey wiring out of `ViewController` and into `AppViewModel` or `AppDelegate`.
- [/] Refactor `ViewController` into adapter-only: outlets bind to model, IBActions forward actions.
- [x] Add unit tests for `AppViewModel` state transitions and settings writes.

## Phase 2: SwiftUI Host
- [ ] Build `MainPopoverView` in SwiftUI with parity layout sections.
- [ ] Host SwiftUI view with `NSHostingController` in `AppDelegate`.
- [ ] Keep existing `NSStatusItem` + `NSPopover` lifecycle unchanged.
- [ ] Validate popover sizing behavior for timer visibility transitions.
- [ ] Validate popover background appearance with SwiftUI content.
- [ ] Keep `EventMonitor` behavior parity.

## Phase 3: Cleanup
- [ ] Remove storyboard dependency from app launch path.
- [ ] Remove `ViewController.swift` once parity is verified.
- [ ] Remove unused resources/outlets/actions.
- [ ] Final clean build + test pass.

## 3 PR Refactor Guidelines

Use this sequence to keep architecture changes small, reviewable, and reversible.

### PR 1: Extract Session Orchestration from `ViewController`
- Scope:
  - Move save/restore orchestration logic out of `ViewController` into `LaterLogic` (or a thin app-layer coordinator backed by `LaterLogic` types).
  - Keep UI behavior unchanged.
- Ownership:
  - `xcode/Test/ViewController.swift`: reduce to forwarding and UI binding only.
  - `Sources/LaterLogic/*`: add coordinator/use-case types and tests.
- Acceptance:
  - No functional behavior changes.
  - `swift test` and `LaterTests` pass.
  - Manual checks: save, restore, close-vs-hide, ignore-system-apps.

### PR 2: Move Remaining Side Effects Behind Explicit Boundaries
- Scope:
  - Move hotkey wiring and app lifecycle operations behind dedicated collaborators (`ShortcutManager`, app lifecycle adapter).
  - Isolate UI-test harness state writes from production code paths where practical.
- Ownership:
  - `xcode/Test/ViewController.swift`: remove direct `HotKey` and direct side-effect orchestration.
  - `xcode/Test/AppDelegate.swift`: keep popover lifecycle, delegate wiring.
  - `Sources/LaterLogic/*`: expose state/actions needed by adapters.
- Acceptance:
  - Global shortcuts still work with popover closed.
  - Launch-at-login and settings persistence unchanged.
  - Tests remain green.

### PR 3: Adapter-Only `ViewController` + SwiftUI Host Readiness
- Scope:
  - Refactor `ViewController` into adapter-only (IBOutlet rendering + IBAction forwarding).
  - Remove duplicated business decisions from controller.
  - Prepare direct handoff to SwiftUI host in next phase.
- Ownership:
  - `xcode/Test/ViewController.swift`: presentation adapter only.
  - `Sources/LaterLogic/AppViewModel.swift`: single source of truth for UI state/actions.
  - `docs/*`: update checklist/progress notes with completed extraction.
- Acceptance:
  - Controller complexity significantly reduced.
  - Migration path to `NSHostingController` is straightforward.
  - Regression checklist items stay green.

## Gating Checks (Run after each phase)
- [x] `swift test`
- [x] `xcodebuild test -project xcode/Later.xcodeproj -scheme LaterTests -destination 'platform=macOS'`
- [x] `xcodebuild test -project xcode/Later.xcodeproj -scheme LaterUITests -destination 'platform=macOS'`
- [ ] Manual regression checklist in `swiftui-migration-plan_v2.md`

## Current Progress Notes
- 2026-03-14: Started Phase 1 execution checklist.
- 2026-03-14: Established baseline UI smoke tests in `LaterUITests` for launch + relaunch lifecycle.
- 2026-03-14: Completed Phase 0 code fixes from `swiftui-migration-plan_v2.md`.
- 2026-03-14: Added typed `SettingsStore` in `LaterLogic` and migrated `ViewController`/`AppDelegate` key usage to it.
- 2026-03-14: Added `SettingsStore` default-value and round-trip persistence tests in both `LaterLogicTests` and `LaterTests`.
- 2026-03-15: Added `AppFilterService`, migrated app filtering in `ViewController`, and added `AppFilterService` tests in both `LaterLogicTests` and `LaterTests`.
- 2026-03-16: Added initial `AppViewModel` read-only state in `LaterLogic` with mirrored tests in `LaterLogicTests` and `LaterTests`.
- 2026-04-01: Moved restore timer scheduling/countdown/cancel behavior from `ViewController` into `AppViewModel` with mirrored timer-action tests.
- 2026-04-01: Moved session snapshot persistence/clear orchestration from `ViewController` into `AppViewModel` with mirrored state-write tests.
- 2026-04-01: Moved global hotkey wiring to `AppDelegate`; `ViewController` now forwards shortcut enable/disable and trigger flows.
- 2026-04-01: Added `AppViewModel` setting action methods and mirrored tests for settings persistence + wait-timer cancellation transitions.
