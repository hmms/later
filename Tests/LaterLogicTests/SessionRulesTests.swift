import Testing
@testable import LaterLogic
import Foundation

@Suite("SessionRules")
struct SessionRulesTests {
    @Test("Quit-apps toggle maps to terminate when enabled")
    func quitToggleEnabledTerminates() {
        #expect(SessionRules.actionForSavedApp(quitAppsInsteadOfHiding: true) == .terminate)
    }

    @Test("Quit-apps toggle maps to hide when disabled")
    func quitToggleDisabledHides() {
        #expect(SessionRules.actionForSavedApp(quitAppsInsteadOfHiding: false) == .hide)
    }

    @Test("System app is ignored when system ignore is enabled")
    func ignoresSystemAppWhenEnabled() {
        let ignored = SessionRules.shouldIgnoreApp(
            bundleID: "com.apple.finder",
            ignoreSystemApps: true,
            customIgnoredBundleIDs: []
        )
        #expect(ignored)
    }

    @Test("System Settings is ignored when system ignore is enabled")
    func ignoresSystemSettingsWhenEnabled() {
        let ignored = SessionRules.shouldIgnoreApp(
            bundleID: "com.apple.SystemSettings",
            ignoreSystemApps: true,
            customIgnoredBundleIDs: []
        )
        #expect(ignored)
    }

    @Test("Legacy System Preferences bundle ID is ignored when system ignore is enabled")
    func ignoresLegacySystemPreferencesWhenEnabled() {
        let ignored = SessionRules.shouldIgnoreApp(
            bundleID: "com.apple.systempreferences",
            ignoreSystemApps: true,
            customIgnoredBundleIDs: []
        )
        #expect(ignored)
    }

    @Test("System app is not ignored when system ignore is disabled")
    func doesNotIgnoreSystemAppWhenDisabled() {
        let ignored = SessionRules.shouldIgnoreApp(
            bundleID: "com.apple.finder",
            ignoreSystemApps: false,
            customIgnoredBundleIDs: []
        )
        #expect(!ignored)
    }

    @Test("Custom ignored bundle IDs are always ignored")
    func ignoresCustomBundleID() {
        let ignored = SessionRules.shouldIgnoreApp(
            bundleID: "com.apple.Music",
            ignoreSystemApps: false,
            customIgnoredBundleIDs: ["com.apple.Music"]
        )
        #expect(ignored)
    }

    @Test("Missing bundle identifier is not ignored")
    func nilBundleIDIsNotIgnored() {
        let ignored = SessionRules.shouldIgnoreApp(
            bundleID: nil,
            ignoreSystemApps: true,
            customIgnoredBundleIDs: ["com.apple.finder"]
        )
        #expect(!ignored)
    }

    @Test("Timer option mapping uses expected durations")
    func timerOptionMapping() {
        #expect(SessionRules.reopenDelaySeconds(for: "15 minutes") == 900)
        #expect(SessionRules.reopenDelaySeconds(for: "30 minutes") == 1800)
        #expect(SessionRules.reopenDelaySeconds(for: "1 hour") == 3600)
        #expect(SessionRules.reopenDelaySeconds(for: "5 hours") == 18000)
    }

    @Test("Unknown timer option falls back to 10 seconds")
    func timerOptionFallback() {
        #expect(SessionRules.reopenDelaySeconds(for: "unknown") == 10)
        #expect(SessionRules.reopenDelaySeconds(for: nil) == 10)
    }

    @Test("Session summary displays +N more when over visible app limit")
    func sessionSummaryWithRemainingCount() {
        let summary = SessionPresentation.summarizeSession(
            appNames: ["Safari", "Xcode", "Notes", "Slack", "Mail"],
            visibleAppLimit: 3
        )
        #expect(summary.sessionName == "Safari, Xcode, Notes, +2 more")
        #expect(summary.sessionFullName == "Safari, Xcode, Notes, Slack, Mail")
        #expect(summary.totalSessions == 5)
    }

    @Test("Session summary handles empty app lists")
    func sessionSummaryWithNoApps() {
        let summary = SessionPresentation.summarizeSession(appNames: [])
        #expect(summary.sessionName == "")
        #expect(summary.sessionFullName == "")
        #expect(summary.totalSessions == 0)
    }

    @Test("Session app filtering removes system apps when enabled")
    func sessionFilteringRespectsSystemToggle() {
        let apps = [
            SessionAppDescriptor(localizedName: "Safari", bundleIdentifier: "com.apple.Safari"),
            SessionAppDescriptor(localizedName: "Finder", bundleIdentifier: "com.apple.finder"),
        ]
        let filtered = SessionPresentation.filteredApps(
            apps,
            ignoreSystemApps: true,
            ignoredSystemBundleIDs: SessionRules.ignoredSystemBundleIDs
        )
        #expect(filtered.map(\.localizedName) == ["Safari"])
    }

    @Test("Last-state marker only set when quit mode is enabled for non-Finder apps")
    func lastStateRules() {
        #expect(SessionPresentation.shouldSetLastState(keepWindowsOpen: false, bundleIdentifier: "com.apple.Safari"))
        #expect(!SessionPresentation.shouldSetLastState(keepWindowsOpen: false, bundleIdentifier: "com.apple.finder"))
        #expect(!SessionPresentation.shouldSetLastState(keepWindowsOpen: true, bundleIdentifier: "com.apple.Safari"))
    }
}

@Suite("AppFilterService")
struct AppFilterServiceTests {
    private let service = AppFilterService()

    @Test("Nil bundle identifier is not ignored")
    func nilBundleIDIsNotIgnored() {
        #expect(!service.shouldIgnore(bundleID: nil, ignoreSystemApps: true))
    }

    @Test("System app is ignored when system filtering is enabled")
    func systemAppIgnoredWhenEnabled() {
        #expect(service.shouldIgnore(bundleID: "com.apple.finder", ignoreSystemApps: true))
    }

    @Test("System app is not ignored when system filtering is disabled")
    func systemAppNotIgnoredWhenDisabled() {
        #expect(!service.shouldIgnore(bundleID: "com.apple.finder", ignoreSystemApps: false))
    }

    @Test("Custom ignored bundle ID is ignored")
    func customIgnoredBundleIDIsIgnored() {
        #expect(
            service.shouldIgnore(
                bundleID: "com.apple.Music",
                ignoreSystemApps: false,
                customIgnoredBundleIDs: ["com.apple.Music"]
            )
        )
    }

    @Test("Only regular activation policy apps are tracked")
    func nonRegularAppsAreNotTracked() {
        #expect(
            !service.shouldTrack(
                activationPolicyIsRegular: false,
                localizedName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                includeTerminal: true,
                includeLater: true,
                ignoreSystemApps: false
            )
        )
    }

    @Test("Terminal and Later filters are respected")
    func terminalAndLaterFiltersAreRespected() {
        #expect(
            !service.shouldTrack(
                activationPolicyIsRegular: true,
                localizedName: "Terminal",
                bundleIdentifier: "com.apple.Terminal",
                includeTerminal: false,
                includeLater: true,
                ignoreSystemApps: false
            )
        )
        #expect(
            !service.shouldTrack(
                activationPolicyIsRegular: true,
                localizedName: "Later",
                bundleIdentifier: "alyssaxuu.Later",
                includeTerminal: true,
                includeLater: false,
                ignoreSystemApps: false
            )
        )
    }

    @Test("Excluded bundle IDs are not tracked")
    func excludedBundleIDsAreNotTracked() {
        #expect(
            !service.shouldTrack(
                activationPolicyIsRegular: true,
                localizedName: "Later",
                bundleIdentifier: "alyssaxuu.Later",
                includeTerminal: true,
                includeLater: true,
                ignoreSystemApps: false,
                excludedBundleIDs: ["alyssaxuu.Later"]
            )
        )
    }
}

@Suite("SettingsStore")
struct SettingsStoreTests {
    private func makeStore() -> (SettingsStore, UserDefaults, String) {
        let suiteName = "LaterLogic.SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (SettingsStore(userDefaults: defaults), defaults, suiteName)
    }

    @Test("SettingsStore returns empty/false defaults before first write")
    func defaultsBeforeWrite() {
        let (store, _, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        #expect(!store.closeAppsOnRestore)
        #expect(!store.ignoreSystemApps)
        #expect(!store.keepWindowsOpen)
        #expect(!store.waitBeforeRestore)
        #expect(!store.globalShortcutsDisabled)
        #expect(!store.hasSession)
        #expect(!store.lastStateWasTerminate)
        #expect(store.savedAppURLs.isEmpty)
        #expect(store.savedAppNames.isEmpty)
        #expect(store.sessionName.isEmpty)
        #expect(store.sessionFullName.isEmpty)
        #expect(store.totalSessions.isEmpty)
        #expect(store.sessionDate.isEmpty)
        #expect(!store.launchAtLoginEnabled)
    }

    @Test("SettingsStore round-trips all supported keys")
    func roundTripPersistence() {
        var (store, _, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        store.closeAppsOnRestore = true
        store.ignoreSystemApps = true
        store.keepWindowsOpen = true
        store.waitBeforeRestore = true
        store.globalShortcutsDisabled = true
        store.hasSession = true
        store.lastStateWasTerminate = true
        store.savedAppURLs = ["file:///Applications/Safari.app"]
        store.savedAppNames = ["Safari"]
        store.sessionName = "Safari"
        store.sessionFullName = "Safari, Notes"
        store.totalSessions = "2"
        store.sessionDate = "Mar 14, 2026 at 10:40 PM"
        store.launchAtLoginEnabled = true

        let reloaded = SettingsStore(userDefaults: UserDefaults(suiteName: suiteName)!)
        #expect(reloaded.closeAppsOnRestore)
        #expect(reloaded.ignoreSystemApps)
        #expect(reloaded.keepWindowsOpen)
        #expect(reloaded.waitBeforeRestore)
        #expect(reloaded.globalShortcutsDisabled)
        #expect(reloaded.hasSession)
        #expect(reloaded.lastStateWasTerminate)
        #expect(reloaded.savedAppURLs == ["file:///Applications/Safari.app"])
        #expect(reloaded.savedAppNames == ["Safari"])
        #expect(reloaded.sessionName == "Safari")
        #expect(reloaded.sessionFullName == "Safari, Notes")
        #expect(reloaded.totalSessions == "2")
        #expect(reloaded.sessionDate == "Mar 14, 2026 at 10:40 PM")
        #expect(reloaded.launchAtLoginEnabled)
    }
}

@MainActor
@Suite("AppViewModel")
struct AppViewModelTests {
    private func makeStore() -> (SettingsStore, String) {
        let suiteName = "LaterLogic.AppViewModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (SettingsStore(userDefaults: defaults), suiteName)
    }

    @Test("AppViewModel mirrors read-only settings/session state on init")
    func mirrorsStateOnInit() {
        var (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        store.hasSession = true
        store.sessionName = "Safari, Xcode, +1 more"
        store.sessionDate = "Mar 16, 2026 at 5:10 PM"
        store.totalSessions = "3"
        store.savedAppNames = ["Safari", "Xcode", "Notes"]
        store.ignoreSystemApps = true
        store.closeAppsOnRestore = true
        store.keepWindowsOpen = true
        store.waitBeforeRestore = true

        let viewModel = AppViewModel(
            settingsStore: store,
            launchAtLoginEnabled: true,
            selectedTimerDuration: "30 minutes"
        )

        #expect(viewModel.hasSession)
        #expect(viewModel.sessionLabel == "Safari, Xcode, +1 more")
        #expect(viewModel.sessionDate == "Mar 16, 2026 at 5:10 PM")
        #expect(viewModel.sessionCount == 3)
        #expect(viewModel.launchAtLogin)
        #expect(viewModel.ignoreSystemApps)
        #expect(viewModel.closeAppsOnRestore)
        #expect(viewModel.keepWindowsOpen)
        #expect(viewModel.waitBeforeRestore)
        #expect(viewModel.selectedTimerDuration == "30 minutes")
    }

    @Test("Session count falls back to saved app names when totalSessions is invalid")
    func sessionCountFallback() {
        var (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        store.hasSession = true
        store.totalSessions = "not-a-number"
        store.savedAppNames = ["Safari", "Xcode"]

        let viewModel = AppViewModel(settingsStore: store)
        #expect(viewModel.sessionCount == 2)
    }

    @Test("Saving snapshot updates view model and settings")
    func saveSnapshotUpdatesStateAndStore() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let viewModel = AppViewModel(settingsStore: store)
        let snapshot = SessionSnapshot(
            appURLs: ["file:///Applications/Safari.app"],
            appNames: ["Safari"],
            sessionName: "Safari",
            sessionFullName: "Safari",
            totalSessions: 1,
            sessionDate: "Apr 1, 2026 at 6:00:00 PM",
            lastStateWasTerminate: true
        )

        viewModel.saveSessionSnapshot(snapshot)

        #expect(viewModel.hasSession)
        #expect(viewModel.sessionLabel == "Safari")
        #expect(viewModel.sessionFullName == "Safari")
        #expect(viewModel.sessionCount == 1)
        #expect(viewModel.savedSessionApps == ["Safari"])
        #expect(viewModel.savedSessionURLs == ["file:///Applications/Safari.app"])

        let reloaded = SettingsStore(userDefaults: UserDefaults(suiteName: suiteName)!)
        #expect(reloaded.hasSession)
        #expect(reloaded.sessionName == "Safari")
        #expect(reloaded.sessionFullName == "Safari")
        #expect(reloaded.totalSessions == "1")
        #expect(reloaded.lastStateWasTerminate)
    }

    @Test("Clearing active session resets session visibility state")
    func clearActiveSession() {
        var (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        store.hasSession = true
        store.sessionName = "Safari"
        let viewModel = AppViewModel(settingsStore: store)
        #expect(viewModel.hasSession)

        viewModel.clearActiveSession()
        #expect(!viewModel.hasSession)

        let reloaded = SettingsStore(userDefaults: UserDefaults(suiteName: suiteName)!)
        #expect(!reloaded.hasSession)
    }

    @Test("Save availability tracks available app count")
    func saveAvailability() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let viewModel = AppViewModel(settingsStore: store)
        #expect(!viewModel.isSaveEnabled)

        viewModel.refreshSaveAvailability(trackableAppCount: 3)
        #expect(viewModel.isSaveEnabled)

        viewModel.refreshSaveAvailability(trackableAppCount: 0)
        #expect(!viewModel.isSaveEnabled)
    }

    @Test("Timer visibility requires session, wait toggle, and timer label")
    func timerVisibilityRules() {
        var (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        store.hasSession = true
        store.waitBeforeRestore = true
        let viewModel = AppViewModel(settingsStore: store)

        #expect(!viewModel.isTimerVisible)
        viewModel.refreshTimerState(label: "Reopening in 00:14:59")
        #expect(viewModel.isTimerVisible)

        viewModel.refreshTimerState(label: nil)
        #expect(!viewModel.isTimerVisible)
    }

    @Test("Scheduling and canceling restore timer updates timer state")
    func scheduleAndCancelTimer() {
        var (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        store.hasSession = true
        store.waitBeforeRestore = true
        let viewModel = AppViewModel(settingsStore: store)

        var observedLabel: String?
        viewModel.scheduleRestoreTimer(
            durationOption: "15 minutes",
            onTick: { observedLabel = $0 },
            onComplete: {}
        )

        #expect(viewModel.isTimerVisible)
        #expect(viewModel.selectedTimerDuration == "15 minutes")
        #expect(observedLabel != nil)

        viewModel.cancelRestoreTimer()
        #expect(!viewModel.isTimerVisible)
        #expect(viewModel.timerLabel == nil)
    }

    @Test("Restore timer invokes completion callback on expiry")
    func timerCompletionOnExpiry() async {
        var (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        store.hasSession = true
        store.waitBeforeRestore = true
        let viewModel = AppViewModel(settingsStore: store)

        var didComplete = false
        viewModel.scheduleRestoreTimer(
            durationOption: "15 minutes",
            durationOverride: 0.05,
            onTick: { _ in },
            onComplete: { didComplete = true }
        )

        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(didComplete)
        #expect(!viewModel.isTimerVisible)
        #expect(viewModel.timerLabel == nil)
    }

    @Test("Setting actions persist values and update published state")
    func settingActionsPersistAndPublish() {
        let (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        let viewModel = AppViewModel(settingsStore: store, launchAtLoginEnabled: false)
        viewModel.setLaunchAtLogin(true)
        viewModel.setIgnoreSystemApps(true)
        viewModel.setCloseAppsOnRestore(true)
        viewModel.setKeepWindowsOpen(true)
        viewModel.setWaitBeforeRestore(true)

        #expect(viewModel.launchAtLogin)
        #expect(viewModel.ignoreSystemApps)
        #expect(viewModel.closeAppsOnRestore)
        #expect(viewModel.keepWindowsOpen)
        #expect(viewModel.waitBeforeRestore)

        let reloaded = SettingsStore(userDefaults: UserDefaults(suiteName: suiteName)!)
        #expect(reloaded.launchAtLoginEnabled)
        #expect(reloaded.ignoreSystemApps)
        #expect(reloaded.closeAppsOnRestore)
        #expect(reloaded.keepWindowsOpen)
        #expect(reloaded.waitBeforeRestore)
    }

    @Test("Disabling wait-before-restore clears any active timer")
    func disablingWaitBeforeRestoreCancelsTimer() {
        var (store, suiteName) = makeStore()
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        store.hasSession = true
        store.waitBeforeRestore = true
        let viewModel = AppViewModel(settingsStore: store)
        viewModel.scheduleRestoreTimer(
            durationOption: "15 minutes",
            onTick: { _ in },
            onComplete: {}
        )
        #expect(viewModel.isTimerVisible)

        viewModel.setWaitBeforeRestore(false)
        #expect(!viewModel.waitBeforeRestore)
        #expect(!viewModel.isTimerVisible)
        #expect(viewModel.timerLabel == nil)

        let reloaded = SettingsStore(userDefaults: UserDefaults(suiteName: suiteName)!)
        #expect(!reloaded.waitBeforeRestore)
    }
}
