import AppKit
import Foundation

public final class SessionRuntimeCoordinator {
    private let appFilter: AppFilterService
    private let currentBundleIdentifier: String?

    public init(appFilter: AppFilterService, currentBundleIdentifier: String?) {
        self.appFilter = appFilter
        self.currentBundleIdentifier = currentBundleIdentifier
    }

    public func trackableRunningApps(
        includeTerminal: Bool,
        includeLater: Bool,
        ignoreSystemApps: Bool
    ) -> [NSRunningApplication] {
        let excludedBundleIDs: Set<String> = {
            guard let currentBundleIdentifier else {
                return []
            }
            return [currentBundleIdentifier]
        }()

        return NSWorkspace.shared.runningApplications.filter { runningApplication in
            appFilter.shouldTrack(
                activationPolicyIsRegular: runningApplication.activationPolicy == .regular,
                localizedName: runningApplication.localizedName,
                bundleIdentifier: runningApplication.bundleIdentifier,
                includeTerminal: includeTerminal,
                includeLater: includeLater,
                ignoreSystemApps: ignoreSystemApps,
                excludedBundleIDs: excludedBundleIDs
            )
        }
    }

    public func applySavedAppAction(_ action: SavedAppAction, to applications: [NSRunningApplication]) -> Bool {
        switch action {
        case .hide:
            for runningApplication in applications {
                runningApplication.hide()
            }
            return false
        case .terminate:
            var terminatedAny = false
            for runningApplication in applications where !Self.isFinderApp(bundleIdentifier: runningApplication.bundleIdentifier) {
                runningApplication.terminate()
                terminatedAny = true
            }
            return terminatedAny
        }
    }

    public func restoreSavedApps(names: [String], urls: [String]) {
        guard !names.isEmpty, names.count == urls.count else {
            assertionFailure("restoreSavedApps requires non-empty arrays with matching counts")
            print("restoreSavedApps ignored invalid input: names=\(names.count), urls=\(urls.count)")
            return
        }

        for (index, appName) in names.enumerated() {
            activateOrLaunch(name: appName, savedURLString: urls[index])
        }
    }

    private func activateOrLaunch(name: String, savedURLString: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == name }) else {
            if let appURL = Self.restoredAppURL(from: savedURLString) {
                NSWorkspace.shared.openApplication(
                    at: appURL,
                    configuration: NSWorkspace.OpenConfiguration()
                ) { _, error in
                    if let error {
                        print("Error opening \(appURL): \(error)")
                    }
                }
            }
            return
        }

        app.unhide()
    }

    public static func restoredAppURL(from savedURLString: String) -> URL? {
        guard let parsedURL = URL(string: savedURLString) else {
            return nil
        }
        if parsedURL.pathExtension == "app" {
            return parsedURL
        }

        var candidate = parsedURL
        while candidate.path != "/" {
            if candidate.pathExtension == "app" {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        return nil
    }

    public static func isFinderApp(bundleIdentifier: String?) -> Bool {
        bundleIdentifier == "com.apple.finder"
    }
}
