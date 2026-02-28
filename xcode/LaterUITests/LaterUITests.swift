import XCTest
import AppKit

final class LaterUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        terminateExistingLaterInstances()
    }

    private func terminateExistingLaterInstances() {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: "alyssaxuu.Later")
        for app in runningApps {
            app.forceTerminate()
        }
    }

    @MainActor
    func testLaunchShowsPrimaryActions() throws {
        let app = XCUIApplication()
        app.launchArguments.append("UITEST_MODE")
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
