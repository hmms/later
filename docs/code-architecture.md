# Code Architecture

## Purpose
This document defines the code architecture for Later during the AppKit -> SwiftUI migration.

## Architectural Goals
- Preserve current behavior while migrating UI technology.
- Keep side effects outside views.
- Make business logic unit-testable with protocol-based boundaries.
- Support incremental migration and easy rollback.

## Layered Architecture

### 1. App Shell Layer (AppKit bridge)
Responsibilities:
- Application lifecycle bootstrap (`AppDelegate`).
- Menu bar status item and popover presentation.
- Global shortcuts registration.
- Launch-at-login integration.

Notes:
- This layer may remain AppKit while UI and logic migrate.

### 2. Presentation Layer (SwiftUI)
Responsibilities:
- Render state from `AppState`.
- Dispatch user intents/actions.
- Compose reusable view components.

Rules:
- No direct `UserDefaults` or `NSWorkspace` calls in view bodies.
- No business logic in view structs.

### 3. State / Orchestration Layer
Primary type:
- `AppState` (`ObservableObject`)

Responsibilities:
- Own screen-level state.
- Coordinate services.
- Translate service results into UI-friendly state.

### 4. Domain / Service Layer
Responsibilities:
- Implement app/session behavior.
- Provide deterministic logic for filtering, timing, and persistence.

Core services:
- `SettingsStore`
- `AppFilterService`
- `SessionService`
- `ReopenTimerService`

### 5. Infrastructure Layer
Responsibilities:
- OS/API adapters for dependencies.

Examples:
- `NSWorkspace` adapter
- `UserDefaults` adapter
- `NSOpenPanel` adapter
- Timer/scheduler adapter

## Proposed Folder Structure

```text
xcode/Test/
  App/
    AppDelegate.swift
    AppEnvironment.swift
  Presentation/
    MainPopoverView.swift
    Components/
      SessionCardView.swift
      SettingsSectionView.swift
      TimerRowView.swift
  State/
    AppState.swift
    AppAction.swift
  Domain/
    Services/
      SessionService.swift
      AppFilterService.swift
      ReopenTimerService.swift
    Models/
      SessionSnapshot.swift
      AppInfo.swift
      Settings.swift
  Infrastructure/
    Persistence/
      UserDefaultsSettingsStore.swift
    System/
      WorkspaceClient.swift
      OpenPanelClient.swift
      SchedulerClient.swift
```

## Data Flow (Unidirectional)
1. User interacts with SwiftUI view.
2. View sends intent to `AppState`.
3. `AppState` invokes one or more services.
4. Services return results/errors.
5. `AppState` publishes updated state.
6. SwiftUI re-renders from new state.

## Dependency Injection
- Depend on protocols at orchestration layer.
- Inject concrete adapters in composition root (App startup).
- Use mocks/fakes in tests.

Example protocol set:
- `SettingsStoring`
- `WorkspaceControlling`
- `SessionServicing`
- `TimerScheduling`

## Error Handling Strategy
- Services return typed errors.
- `AppState` maps errors to user-facing messages/state.
- Views display non-blocking errors where possible.

## State Ownership Rules
- `@State`: local transient UI-only state.
- `@StateObject`: owned app/screen model (`AppState`).
- `@EnvironmentObject`: only if truly shared across multiple roots.
- Derived display values should be computed, not duplicated.

## Testing Architecture
- Unit-test service layer first.
- Unit-test `AppState` orchestration with mocked services.
- Keep infrastructure adapters thin and mostly integration-tested manually.

Minimum required unit tests:
- `AppFilterServiceTests`
- `SettingsStoreTests`
- `SessionServiceTests`
- `ReopenTimerServiceTests`
- `AppStateTests`

## Migration Boundaries
- Keep `ViewController` active until each migrated SwiftUI section reaches parity.
- Remove storyboard/outlets/actions only after final parity checks.
- Prefer introducing new files over large in-place rewrites.

## Definition of Done (Per Slice)
- Behavior parity for touched flow.
- No new runtime warnings.
- Unit tests added/updated and passing.
- Side effects remain outside views.
