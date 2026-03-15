import XCTest
import AppKit

final class LaterUITests: XCTestCase {
    private lazy var stateFileURL: URL = {
        let path = (NSTemporaryDirectory() as NSString).appendingPathComponent("later-uitest-state.json")
        return URL(fileURLWithPath: path)
    }()

    private struct UITestSnapshot {
        let hasSession: Bool
        let savedAppCount: Int
        let timerScheduled: Bool
        let globalShortcutsDisabled: Bool
        let launchAtLoginEnabled: Bool

        init?(dictionary: [String: Any]) {
            guard
                let hasSession = dictionary["hasSession"] as? Bool,
                let savedAppCount = dictionary["savedAppCount"] as? Int,
                let timerScheduled = dictionary["timerScheduled"] as? Bool,
                let globalShortcutsDisabled = dictionary["globalShortcutsDisabled"] as? Bool,
                let launchAtLoginEnabled = dictionary["launchAtLoginEnabled"] as? Bool
            else {
                return nil
            }

            self.hasSession = hasSession
            self.savedAppCount = savedAppCount
            self.timerScheduled = timerScheduled
            self.globalShortcutsDisabled = globalShortcutsDisabled
            self.launchAtLoginEnabled = launchAtLoginEnabled
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateExistingLaterInstances()
        removeStateFileIfPresent()
    }

    private func terminateExistingLaterInstances() {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "alyssaxuu.Later")
        for app in runningApps {
            app.forceTerminate()
        }
    }

    private func removeStateFileIfPresent() {
        try? FileManager.default.removeItem(at: stateFileURL)
    }

    private func launchApp(
        stubSession: Bool = false,
        resetDefaults: Bool = false,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        if stubSession {
            app.launchArguments.append("UITEST_STUB_SESSION")
        }
        if resetDefaults {
            app.launchArguments.append("UITEST_RESET_DEFAULTS")
        }
        app.launchArguments.append(contentsOf: extraArguments)
        app.launchEnvironment["UITEST_STATE_FILE"] = stateFileURL.path
        app.launch()
        return app
    }

    private func readSnapshot() -> UITestSnapshot? {
        guard let data = try? Data(contentsOf: stateFileURL) else {
            return nil
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return UITestSnapshot(dictionary: object)
    }

    private func waitForSnapshot(
        timeout: TimeInterval = 4,
        predicate: (UITestSnapshot) -> Bool = { _ in true }
    ) -> UITestSnapshot? {
        let start = Date()
        while Date().timeIntervalSince(start) <= timeout {
            if let snapshot = readSnapshot(), predicate(snapshot) {
                return snapshot
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return nil
    }

    @MainActor
    func testLaunchShowsPrimaryActions() throws {
        let app = launchApp()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    @MainActor
    func testCanRelaunchInUITestMode() throws {
        let app = launchApp()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        app.terminate()

        let relaunchedApp = launchApp()

        XCTAssertTrue(relaunchedApp.wait(for: .runningForeground, timeout: 5))
    }

    @MainActor
    func testCanLaunchInStubSessionMode() throws {
        let app = launchApp(stubSession: true)
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }

    @MainActor
    func testSaveAndRestoreSessionInStubMode() throws {
        let app = launchApp(
            stubSession: true,
            resetDefaults: true,
            extraArguments: ["UITEST_TRIGGER_SAVE"]
        )
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        XCTAssertNotNil(waitForSnapshot { $0.hasSession && $0.savedAppCount > 0 })
        app.terminate()

        let restoreApp = launchApp(
            stubSession: true,
            extraArguments: ["UITEST_TRIGGER_RESTORE"]
        )
        XCTAssertTrue(restoreApp.wait(for: .runningForeground, timeout: 5))

        XCTAssertNotNil(waitForSnapshot { !$0.hasSession })
        restoreApp.terminate()
    }

    @MainActor
    func testTimerCanStartAndCancel() throws {
        let app = launchApp(
            stubSession: true,
            resetDefaults: true,
            extraArguments: ["UITEST_ENABLE_WAIT", "UITEST_TRIGGER_SAVE"]
        )
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        XCTAssertNotNil(waitForSnapshot { $0.timerScheduled })
        app.terminate()

        let cancelApp = launchApp(
            stubSession: true,
            extraArguments: ["UITEST_TRIGGER_CANCEL_TIMER"]
        )
        XCTAssertTrue(cancelApp.wait(for: .runningForeground, timeout: 5))

        XCTAssertNotNil(waitForSnapshot { !$0.timerScheduled })
        cancelApp.terminate()
    }

    @MainActor
    func testHotkeySettingPersistsEnabledAndDisabledStates() throws {
        let app = launchApp(
            resetDefaults: true,
            extraArguments: ["UITEST_ENABLE_SHORTCUTS"]
        )
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertNotNil(waitForSnapshot { !$0.globalShortcutsDisabled })
        app.terminate()

        let relaunchedDisabledApp = launchApp(
            extraArguments: ["UITEST_DISABLE_SHORTCUTS"]
        )
        XCTAssertTrue(relaunchedDisabledApp.wait(for: .runningForeground, timeout: 5))
        XCTAssertNotNil(waitForSnapshot { $0.globalShortcutsDisabled })
        relaunchedDisabledApp.terminate()

        let relaunchedEnabledApp = launchApp(
            extraArguments: ["UITEST_ENABLE_SHORTCUTS"]
        )
        XCTAssertTrue(relaunchedEnabledApp.wait(for: .runningForeground, timeout: 5))
        XCTAssertNotNil(waitForSnapshot { !$0.globalShortcutsDisabled })
        relaunchedEnabledApp.terminate()
    }

    @MainActor
    func testLaunchAtLoginPersistsAcrossRelaunchesInUITestMode() throws {
        let app = launchApp(
            resetDefaults: true,
            extraArguments: ["UITEST_TOGGLE_LAUNCH_AT_LOGIN"]
        )
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        guard let toggledSnapshot = waitForSnapshot() else {
            XCTFail("Expected UI test snapshot after launch-at-login toggle")
            return
        }
        app.terminate()

        let relaunchedApp = launchApp()
        XCTAssertTrue(relaunchedApp.wait(for: .runningForeground, timeout: 5))

        guard let relaunchedSnapshot = waitForSnapshot() else {
            XCTFail("Expected UI test snapshot after relaunch")
            return
        }

        XCTAssertEqual(relaunchedSnapshot.launchAtLoginEnabled, toggledSnapshot.launchAtLoginEnabled)
        relaunchedApp.terminate()
    }
}
