# SwiftUI Migration Plan

## Goal
Migrate Later's UI from AppKit (`ViewController` + storyboard) to SwiftUI with no behavior regressions — and fix several existing bugs in the process.

## Current State
- App lifecycle and popover are AppKit-based (`AppDelegate` + `NSPopover`).
- Primary UI is storyboard + `ViewController.swift`.
- Business logic and UI state are mixed inside `ViewController`.

## Migration Principles
- No big-bang rewrite.
- Fix bugs before migrating so we're not porting broken behavior.
- Keep PRs small and reversible.
- One `AppViewModel` handles all state — no over-engineered service layers.
- Views render state and dispatch intents; `AppViewModel` coordinates side effects.

---

## Phase 0: Bug Fixes (Pre-Migration)

Fix known bugs in the existing AppKit code before any architecture changes. This gives us a clean, correct baseline to migrate from, and keeps bug fixes isolated from structural changes.

### Bugs to Fix

**1. `keepWindowsOpen` logic is inverted**
When the checkbox is ON, the code calls `terminate()`. When OFF, it calls `hide()`. The labels say the opposite. Audit the intent and correct the branch logic.

**2. Frontmost app is double-added to session**
`saveSessionGlobal` iterates `NSWorkspace.shared.runningApplications` and then handles `frontmostApplication` separately at the bottom. Since the frontmost app is always present in `runningApplications`, it gets appended twice — meaning restore tries to reopen it twice. Fix by filtering it out of the main loop and handling it once, or deduplicate before saving.

**3. `activate(name:url:)` launches raw binaries instead of app bundles**
The restore path uses `Process().run()` with the executable URL, which bypasses Launch Services. Most app restores either fail silently or open a broken instance. Replace with `NSWorkspace.shared.open(URL(fileURLWithPath:))` using the app's bundle URL (use `bundleURL` instead of `executableURL` when saving).

**4. System app filter uses hardcoded English app names**
The `"Finder"`, `"Activity Monitor"`, `"System Preferences"`, `"App Store"` string comparisons appear 4+ times across the file and break on non-English systems. Replace with bundle ID checks (`com.apple.finder`, etc.) which are locale-independent. Deduplicate into a single helper.

**5. Launch at login is force-enabled on every app launch**
`applicationDidFinishLaunching` calls `LaunchAtLogin.isEnabled = true` unconditionally, so user preference is reset every restart. Remove this line; let the stored preference persist naturally.

**6. Screenshot loop overwrites itself on multi-display setups**
`takeScreenshot()` iterates over active displays but writes to the same `screenshot.jpg` filename each iteration, keeping only the last display. Either save only the primary display (`CGMainDisplayID()`) or save per-display with distinct filenames.

### Acceptance
- All items in the regression checklist pass.
- `keepWindowsOpen` behaves as labeled.
- Save/restore round-trip works correctly for a multi-app session.
- System app filter works on a non-English macOS system.
- Launch at login preference survives an app restart.

---

## Phase 1: Architecture Extraction

Move all logic out of `ViewController` into a single `AppViewModel: ObservableObject`. No UI changes yet — the existing storyboard and AppKit views stay untouched and remain the source of truth for the running app.

### Deliverables

**`AppViewModel: ObservableObject`**
Contains all `@Published` state the UI needs:
- `hasSession: Bool`
- `sessionLabel: String`, `sessionDate: String`, `sessionCount: Int`
- `isSaveEnabled: Bool`
- `timerLabel: String?`, `isTimerVisible: Bool`
- Settings: `launchAtLogin`, `ignoreSystemApps`, `closeAppsOnRestore`, `keepWindowsOpen`, `waitBeforeRestore`, `selectedTimerDuration`

Exposes action methods the view calls:
- `saveSession()`
- `restoreSession()`
- `cancelTimer()`
- `clearSession()`
- Setters for each setting that persist to `UserDefaults`

**`SettingsStore`** (simple struct, not a class or protocol)
A thin `UserDefaults` wrapper with typed read/write for each key. No protocol, no mock — just a value type that eliminates raw string keys from the rest of the codebase.

**`AppFilterService`** (free function or namespace, not a class)
A pure function `func shouldInclude(_ app: NSRunningApplication, ignoreSystem: Bool, customIgnored: [String]) -> Bool` using bundle ID checks. Used by `AppViewModel` for both save and restore filtering.

**Hot key wiring**
Move `HotKey` setup into `AppViewModel` or `AppDelegate`. Remove it from `ViewController`.

### ViewController Changes
`ViewController` becomes a thin adapter: it reads from `AppViewModel` to populate outlets and forwards IBActions to `AppViewModel` methods. No logic lives in it. This is the seam that lets Phase 2 swap the view entirely.

### Acceptance
- Existing AppKit UI still functions identically.
- No behavior changes from the Phase 0 baseline.
- `SettingsStore` and `AppFilterService` have unit tests covering key behaviors.

### Tests
- `SettingsStore`: round-trips all keys; returns correct defaults on first launch.
- `AppFilterService`: filters system apps by bundle ID when enabled; passes all apps when disabled; handles nil `bundleIdentifier` safely.
- `AppViewModel` save logic: builds correct `sessionLabel` for 1, 3, and 5+ apps; excludes ignored apps.

---

## Phase 2: SwiftUI Host

Keep the AppKit app shell (`AppDelegate` + `NSPopover`). Replace the storyboard content with an `NSHostingController` wrapping a SwiftUI view. This is the highest-risk step and needs careful validation.

### Deliverables

**`MainPopoverView: View`**
Full SwiftUI replacement of the storyboard UI, reading from `AppViewModel` via `@StateObject` or `@EnvironmentObject`. Sections:
- Session card (screenshot, date, label, app count badge)
- Save / Restore buttons
- Settings checkboxes and timer dropdown
- Timer strip (conditionally shown)

**`AppDelegate` changes**
Replace:
```swift
let storyboard = NSStoryboard(name: "Main", bundle: nil)
guard let vc = storyboard.instantiateController(...) as? ViewController else { ... }
popoverView.contentViewController = vc
```
With:
```swift
let viewModel = AppViewModel()
let hosting = NSHostingController(rootView: MainPopoverView().environmentObject(viewModel))
popoverView.contentViewController = hosting
```

**Popover sizing**
`NSHostingController` does not automatically track SwiftUI view size. Set `hosting.sizingOptions = .preferredContentSize` (macOS 13+) or manually set `popoverView.contentSize` and update it when visible state changes (e.g. timer strip appearing/disappearing).

**Popover background color**
The current `objc_setAssociatedObject` hack in the `NSPopover` extension may not behave correctly with SwiftUI-hosted content. Test it explicitly. If it breaks, set background via `.background()` in SwiftUI and remove the AppKit hack.

**`EventMonitor`**
Keep as-is. No changes needed.

### Acceptance
- Popover opens and closes reliably from the menu bar.
- Popover sizes correctly when the timer strip shows and hides.
- All settings persist and reload correctly after popover close/reopen.
- All regression checklist items pass.
- Global hotkeys still function.

### Tests
- `AppViewModel` action handlers: settings changes are reflected in `SettingsStore`; `clearSession()` resets `hasSession` to false.
- `AppViewModel` timer state: `isTimerVisible` is true after `saveSession()` when `waitBeforeRestore` is on; false after `cancelTimer()`.

---

## Phase 3: Cleanup

Remove the storyboard, `ViewController.swift`, and any remaining dead AppKit code.

### Deliverables
- Delete `Main.storyboard` (or remove the ViewController scene from it).
- Delete `ViewController.swift`.
- Remove storyboard reference from `Info.plist` (`NSMainStoryboardFile` key) if present.
- Remove any IBOutlet/IBAction remnants.
- Keep only required AppKit bridge code: `AppDelegate`, `NSHostingController` wiring, `EventMonitor`, `NSPopover` extension (or remove it if replaced in Phase 2).
- Final test pass.

### Acceptance
- No runtime warnings about missing nibs, outlets, or actions.
- App behavior unchanged from Phase 2.
- All tests green on a clean build.

---

## PR Breakdown
1. `Phase 0: Bug fixes` — no structural changes, just correct behavior
2. `Phase 1: AppViewModel + SettingsStore + AppFilterService + tests` — no UI change
3. `Phase 2: SwiftUI popover host` — behavior-parity UI swap
4. `Phase 3: Remove storyboard and ViewController` — cleanup

---

## Regression Checklist (Run After Each Phase)
- [ ] Save session hides/quits correct apps
- [ ] Restore session reopens hidden/closed apps correctly (not raw binaries)
- [ ] Ignore system apps option works (on non-English macOS)
- [ ] Close-vs-hide toggle works as labeled
- [ ] Reopen timer starts, counts down, and fires restore
- [ ] Cancel timer works
- [ ] Launch at login toggle persists across restarts
- [ ] Global hotkeys (⌘⇧L and ⌘⇧R) work when popover is closed
- [ ] Popover opens/closes from menu bar icon
- [ ] Settings persist after popover close and reopen

---

## SwiftUI Design Principles

### State Management
- `@State` for local ephemeral view state only (e.g. hover effects).
- One `AppViewModel` as `@StateObject` owned by the popover host; passed down as `@EnvironmentObject`.
- Avoid duplicating derived state — compute it from source of truth inside `AppViewModel`.

### Side Effects
- All `NSWorkspace`, `UserDefaults`, `HotKey`, and timer calls live in `AppViewModel` or helper types it owns.
- No direct `NSWorkspace`/`UserDefaults` calls inside SwiftUI view bodies.

### AppKit Interop
- Keep the AppKit bridge thin: `AppDelegate` for lifecycle and popover, `NSHostingController` for the content handoff.
- `NSOpenPanel` (if custom ignore list is added later) gets wrapped in a small helper called from `AppViewModel`, not from a view.
