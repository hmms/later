import Foundation

public struct SessionCapturedApp: Equatable {
    public let localizedName: String
    public let bundleIdentifier: String?
    public let bundleURLString: String?

    public init(localizedName: String, bundleIdentifier: String?, bundleURLString: String?) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
        self.bundleURLString = bundleURLString
    }
}

public enum SessionSavePlanner {
    public static func actionForSave(quitAppsInsteadOfHiding: Bool) -> SavedAppAction {
        SessionRules.actionForSavedApp(quitAppsInsteadOfHiding: quitAppsInsteadOfHiding)
    }

    public static func makeDraft(from capturedApps: [SessionCapturedApp]) -> SessionSnapshotDraft {
        let appURLs = capturedApps.compactMap(\.bundleURLString)
        let appNames = capturedApps.map(\.localizedName)
        return SessionSnapshotDraft(appURLs: appURLs, appNames: appNames)
    }

    public static func lastStateWasTerminate(
        capturedApps: [SessionCapturedApp],
        action: SavedAppAction
    ) -> Bool {
        guard action == .terminate else {
            return false
        }

        return capturedApps.contains { app in
            guard let bundleIdentifier = app.bundleIdentifier else {
                return false
            }
            return SessionPresentation.shouldSetLastState(
                keepWindowsOpen: false,
                bundleIdentifier: bundleIdentifier
            )
        }
    }
}
