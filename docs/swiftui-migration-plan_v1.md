# SwiftUI Migration Plan

## Goal
Migrate Later's UI from AppKit (`ViewController` + storyboard) to SwiftUI with no behavior regressions.

## Current State
- App lifecycle and popover are AppKit-based (`AppDelegate` + `NSPopover`).
- Primary UI is storyboard + `ViewController.swift`.
- Business logic and UI state are mixed inside `ViewController`.

## Migration Principles
- No big-bang rewrite.
- Keep behavior parity at each step.
- Move logic out of UI first, then swap rendering layer.
- Keep PRs small and reversible.
- Prefer pure Swift domain logic over view-coupled code.
- Views render state and dispatch intents; services perform side effects.

## Regression Checklist (Baseline)
- Save session hides/quits correct apps.
- Restore session reopens hidden/closed apps.
- Ignore system apps option works.
- Custom ignored apps list works.
- Close-vs-hide toggle works.
- Reopen timer + cancel work.
- Menu actions still work.
- Global hotkeys still work.

## Test Strategy
- Focus on unit tests for domain/services first.
- Add lightweight SwiftUI state tests where practical.
- Keep UI snapshot/smoke tests optional until migration stabilizes.

### Test Layers
1. Service unit tests (highest priority)
2. ViewModel/AppState tests
3. Minimal integration tests for key flows

### Test Coverage Targets
- `AppFilterService`
  - ignores system apps when enabled
  - does not ignore non-system apps when disabled
  - ignores custom bundle IDs
  - handles missing `bundleIdentifier` safely
- `SessionService`
  - builds expected session metadata from given app list
  - excludes ignored apps
  - preserves ordering/labels used by UI
- `ReopenTimerService`
  - starts with expected duration for each preset
  - emits countdown updates
  - cancels correctly
  - triggers restore callback exactly once
- `SettingsStore`
  - reads defaults correctly when keys are missing
  - round-trips all settings keys

### Test Milestones by Phase
- Phase 1
  - Create test target if missing
  - Add tests for `SettingsStore` and `AppFilterService`
- Phase 2
  - Add tests for `AppState` action handlers using mocked services
- Phase 3
  - Add tests validating settings mutations flow through `AppState` to `SettingsStore`
- Phase 4
  - Add tests for session save/restore orchestration in `SessionService`
- Phase 5
  - Add `ReopenTimerService` tests (start/cancel/finish)
- Phase 6
  - Regression-focused final test pass and gap cleanup

## Phase Plan

### Phase 1: Architecture Extraction
Move logic out of `ViewController` into plain Swift services.

Deliverables:
- `AppState` (`ObservableObject`) for UI-facing state.
- `SettingsStore` for persistence (UserDefaults wrapper).
- `SessionService` for save/restore.
- `AppFilterService` for ignore rules.
- `ReopenTimerService` for timer behavior.
- Unit test target and first service tests.

Acceptance:
- Existing AppKit UI still functions.
- No behavior changes from baseline checklist.
- New tests pass for `SettingsStore` and `AppFilterService`.

### Phase 2: SwiftUI Host in Existing AppKit Shell
Keep AppKit app shell, replace popover content with SwiftUI.

Deliverables:
- `NSHostingController(rootView: MainPopoverView())` in `AppDelegate`.
- Minimal SwiftUI placeholder view wired to `AppState`.

Acceptance:
- Popover opens reliably from menu bar.
- No launch or target-action regressions.
- `AppState` tests pass with mocked services.

### Phase 3: Settings UI Migration
Rebuild settings controls in SwiftUI.

Deliverables:
- SwiftUI toggles/dropdowns for current settings.
- Add/clear custom ignored app actions bridged to AppKit where needed (`NSOpenPanel`).

Acceptance:
- Settings persist and reload exactly as before.
- Settings-related unit tests pass.

### Phase 4: Session Summary + Actions Migration
Rebuild session card and save/restore actions in SwiftUI.

Deliverables:
- SwiftUI session metadata view.
- Save/restore buttons bound to service methods.

Acceptance:
- Save and restore behavior matches baseline.
- Session orchestration tests pass.

### Phase 5: Timer UI Migration
Rebuild timer strip and cancel flow in SwiftUI.

Deliverables:
- SwiftUI countdown UI.
- Timer service integration.

Acceptance:
- Timer starts/stops/cancels correctly.
- Timer service tests pass.

### Phase 6: Cleanup
Remove obsolete storyboard and controller code.

Deliverables:
- Remove unused storyboard scenes/outlets/actions.
- Keep only required AppKit bridge code.

Acceptance:
- No runtime nib/action warnings.
- App behavior unchanged.
- All migration tests green on clean run.

## PR Breakdown
1. `AppState + SettingsStore + service scaffolding + initial tests` (no UI change)
2. `SwiftUI popover host`
3. `Settings section migration`
4. `Session summary + actions migration`
5. `Timer migration`
6. `Cleanup/removal of legacy UI`

## SwiftUI Design Principles

### Architecture
- Use unidirectional flow:
  - View reads state
  - View triggers intent/action
  - State layer coordinates services
  - Services perform side effects
- Keep business logic out of `View` structs.
- Inject dependencies via protocols for testability.

### State Management
- `@State` for local ephemeral view state only.
- `@ObservableObject` + `@StateObject` for screen-level state (`AppState`).
- `@EnvironmentObject` only for truly shared app-wide objects.
- Avoid duplicating derived state; compute it from source of truth.

### View Composition
- Build small reusable views (settings row, session card, timer row).
- Keep view files focused; move formatting helpers to extensions.
- Prefer explicit models for rows/items over passing many primitives.

### Side Effects
- Centralize side effects (workspace, timers, defaults, open panel) in services.
- Avoid direct `NSWorkspace`/`UserDefaults` calls inside view bodies.
- Use async/task boundaries deliberately and cancel long-lived tasks on disappear.

### Interop with AppKit
- Keep AppKit bridge thin and isolated (popover host, `NSOpenPanel` helper).
- Do not leak AppKit types deep into domain/service layers unless required.
- Wrap AppKit dependencies behind protocol adapters when feasible.

### Review Checklist (SwiftUI PRs)
- Does the view only render state and dispatch actions?
- Is side-effect logic outside the view body?
- Are dependencies injectable and mockable?
- Is state ownership clear (`@State` vs `@StateObject` vs `@EnvironmentObject`)?
- Are there tests for new service/state behavior?

## Pair Programming Workflow
- We pick one PR slice at a time.
- For each slice:
  1. I implement code changes.
  2. I provide a focused diff summary.
  3. You run and validate against checklist.
  4. I fix issues and prep commit.

## Next Step
Start with PR slice 1:
- Add `AppState`, `SettingsStore`, and empty service skeletons.
- Keep all existing behavior untouched.
