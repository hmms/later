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
- [ ] Create initial `AppViewModel` with read-only state mirrored from current UI.
- [ ] Move timer state + timer actions from `ViewController` into `AppViewModel`.
- [ ] Move save/restore orchestration from `ViewController` into `AppViewModel`.
- [ ] Move hotkey wiring out of `ViewController` and into `AppViewModel` or `AppDelegate`.
- [ ] Refactor `ViewController` into adapter-only: outlets bind to model, IBActions forward actions.
- [ ] Add unit tests for `AppViewModel` state transitions and settings writes.

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
