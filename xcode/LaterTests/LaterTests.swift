import Testing
import LaterLogic

@Suite("LaterTests")
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
}

