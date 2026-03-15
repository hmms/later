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
