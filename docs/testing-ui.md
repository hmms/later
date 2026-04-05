# UI Testing Guide (macOS)

This project uses `XCTest` UI tests in `xcode/LaterUITests/LaterUITests.swift`.

## Run tests

Run all UI tests:

```bash
xcodebuild test -project xcode/Later.xcodeproj -scheme LaterUITests -destination 'platform=macOS'
```

Run all unit tests:

```bash
xcodebuild test -project xcode/Later.xcodeproj -scheme LaterTests -destination 'platform=macOS'
```

## Test architecture

UI tests launch the app with `UITEST_MODE` and optional launch arguments to drive deterministic behavior.

The app writes a JSON state snapshot to a file path passed via launch environment variable:

- `UITEST_STATE_FILE`

This avoids flaky assertions against shared defaults domains and gives reliable state checks across real app relaunches.

## Supported UITest launch arguments

These are handled in `ViewController.runUITestHooks()`:

- `UITEST_MODE`
- `UITEST_STUB_SESSION`
- `UITEST_RESET_DEFAULTS`
- `UITEST_ENABLE_WAIT`
- `UITEST_DISABLE_SHORTCUTS`
- `UITEST_ENABLE_SHORTCUTS`
- `UITEST_TOGGLE_LAUNCH_AT_LOGIN`
- `UITEST_TRIGGER_SAVE`
- `UITEST_TRIGGER_SHORTCUT_SAVE`
- `UITEST_TRIGGER_SHORTCUT_RESTORE`
- `UITEST_TRIGGER_RESTORE`
- `UITEST_TRIGGER_CANCEL_TIMER`

Additional launch path toggle in `AppDelegate`:

- `USE_SWIFTUI_POPOVER`

You can also enable the same path with environment variable `LATER_USE_SWIFTUI_POPOVER=1` for local/manual validation without changing the default storyboard path.

Current smoke coverage also includes a gated SwiftUI-host launch path check using `USE_SWIFTUI_POPOVER`.

## Snapshot schema

`ViewController.writeUITestStateSnapshot()` currently emits:

- `hasSession: Bool`
- `savedAppCount: Int`
- `timerScheduled: Bool`
- `globalShortcutsDisabled: Bool`
- `launchAtLoginEnabled: Bool`
- `swiftUIPopoverActive: Bool`

When the gated SwiftUI host path is enabled, `AppDelegate` now writes the same snapshot schema so UI tests can validate that path without depending on menubar popover accessibility queries.

## Current high-value scenarios covered

- Save/restore behavior across app relaunches
- Timer UX (schedule + cancel)
- Hotkey enable/disable persistence
- Launch-at-login persistence across app relaunches

## How to add a new UI scenario

1. Add or reuse a launch argument in `runUITestHooks()` for the behavior you need to trigger.
2. Ensure `writeUITestStateSnapshot()` includes any state needed for assertions.
3. Add a focused test in `LaterUITests` that:
   - launches with `UITEST_MODE`
   - optionally sets behavior args
   - waits for a snapshot predicate
   - relaunches and re-asserts persisted behavior if required
4. Keep tests isolated by using `UITEST_RESET_DEFAULTS` on first launch in that test.

## Notes

- `LaterUITests` kills existing `alyssaxuu.Later` instances in `setUpWithError()`.
- Snapshot file is recreated per test (`/tmp/later-uitest-state.json` via `NSTemporaryDirectory()`).
- If a UI test fails unexpectedly, run the single test first with `-only-testing:` before running the full suite.
