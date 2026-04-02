import Foundation

public struct SessionSnapshotDraft: Equatable {
    public let appURLs: [String]
    public let appNames: [String]
    public let appBundleIDs: [String?]

    public init(appURLs: [String], appNames: [String], appBundleIDs: [String?]) {
        self.appURLs = appURLs
        self.appNames = appNames
        self.appBundleIDs = appBundleIDs
    }
}

public enum SessionSnapshotComposer {
    public static func makeSnapshot(
        draft: SessionSnapshotDraft,
        action: SavedAppAction,
        sessionDate: String
    ) -> SessionSnapshot {
        let summary = SessionPresentation.summarizeSession(appNames: draft.appNames)
        let lastStateWasTerminate = action == .terminate && draft.appBundleIDs.contains { bundleID in
            guard let bundleID else {
                return false
            }
            return SessionPresentation.shouldSetLastState(
                keepWindowsOpen: false,
                bundleIdentifier: bundleID
            )
        }

        return SessionSnapshot(
            appURLs: draft.appURLs,
            appNames: draft.appNames,
            sessionName: summary.sessionName,
            sessionFullName: summary.sessionFullName,
            totalSessions: summary.totalSessions,
            sessionDate: sessionDate,
            lastStateWasTerminate: lastStateWasTerminate
        )
    }
}
