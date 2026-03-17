import Combine
import Foundation

@MainActor
public final class AppViewModel: ObservableObject {
    private let settingsStore: SettingsStore

    @Published public private(set) var hasSession = false
    @Published public private(set) var sessionLabel = ""
    @Published public private(set) var sessionDate = ""
    @Published public private(set) var sessionCount = 0
    @Published public private(set) var isSaveEnabled = false
    @Published public private(set) var timerLabel: String?
    @Published public private(set) var isTimerVisible = false

    @Published public private(set) var launchAtLogin = false
    @Published public private(set) var ignoreSystemApps = false
    @Published public private(set) var closeAppsOnRestore = false
    @Published public private(set) var keepWindowsOpen = false
    @Published public private(set) var waitBeforeRestore = false
    @Published public private(set) var selectedTimerDuration = "15 minutes"

    public init(
        settingsStore: SettingsStore = SettingsStore(),
        launchAtLoginEnabled: Bool = false,
        selectedTimerDuration: String = "15 minutes"
    ) {
        self.settingsStore = settingsStore
        self.selectedTimerDuration = selectedTimerDuration
        refreshFromSettings(launchAtLoginEnabled: launchAtLoginEnabled)
    }

    public func refreshFromSettings(launchAtLoginEnabled: Bool) {
        launchAtLogin = launchAtLoginEnabled
        ignoreSystemApps = settingsStore.ignoreSystemApps
        closeAppsOnRestore = settingsStore.closeAppsOnRestore
        keepWindowsOpen = settingsStore.keepWindowsOpen
        waitBeforeRestore = settingsStore.waitBeforeRestore

        hasSession = settingsStore.hasSession
        sessionLabel = settingsStore.sessionName
        sessionDate = settingsStore.sessionDate
        sessionCount = Int(settingsStore.totalSessions) ?? settingsStore.savedAppNames.count
        updateTimerVisibility()
    }

    public func refreshSaveAvailability(trackableAppCount: Int) {
        isSaveEnabled = trackableAppCount > 0
    }

    public func refreshTimerState(label: String?) {
        timerLabel = label
        updateTimerVisibility()
    }

    public func refreshSelectedTimerDuration(_ value: String) {
        selectedTimerDuration = value
    }

    private func updateTimerVisibility() {
        isTimerVisible = hasSession && waitBeforeRestore && timerLabel != nil
    }
}
