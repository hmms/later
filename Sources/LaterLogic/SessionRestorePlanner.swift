import Foundation

public struct SessionRestorePlan: Equatable {
    public let preRestoreAction: SavedAppAction?
    public let shouldRestoreApps: Bool

    public init(preRestoreAction: SavedAppAction?, shouldRestoreApps: Bool) {
        self.preRestoreAction = preRestoreAction
        self.shouldRestoreApps = shouldRestoreApps
    }
}

public enum SessionRestorePlanner {
    public static func makePlan(
        isUITestStubMode: Bool,
        closeAppsOnRestore: Bool,
        appNames: [String],
        appURLs: [String]
    ) -> SessionRestorePlan {
        let preRestoreAction: SavedAppAction? = {
            guard !isUITestStubMode else {
                return nil
            }
            return closeAppsOnRestore ? .terminate : nil
        }()

        let shouldRestoreApps = !appNames.isEmpty && appNames.count == appURLs.count

        return SessionRestorePlan(
            preRestoreAction: preRestoreAction,
            shouldRestoreApps: shouldRestoreApps
        )
    }
}
