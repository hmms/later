import Foundation

public struct SessionAppDescriptor: Equatable {
    public let localizedName: String
    public let bundleIdentifier: String

    public init(localizedName: String, bundleIdentifier: String) {
        self.localizedName = localizedName
        self.bundleIdentifier = bundleIdentifier
    }
}

public struct SessionSummary: Equatable {
    public let sessionName: String
    public let sessionFullName: String
    public let totalSessions: Int

    public init(sessionName: String, sessionFullName: String, totalSessions: Int) {
        self.sessionName = sessionName
        self.sessionFullName = sessionFullName
        self.totalSessions = totalSessions
    }
}

public enum SessionPresentation {
    public static func filteredApps(
        _ apps: [SessionAppDescriptor],
        ignoreSystemApps: Bool,
        ignoredSystemBundleIDs: Set<String>
    ) -> [SessionAppDescriptor] {
        apps.filter { app in
            if ignoreSystemApps && ignoredSystemBundleIDs.contains(app.bundleIdentifier) {
                return false
            }
            return true
        }
    }

    public static func summarizeSession(appNames: [String], visibleAppLimit: Int = 3) -> SessionSummary {
        guard !appNames.isEmpty else {
            return SessionSummary(sessionName: "", sessionFullName: "", totalSessions: 0)
        }

        let displayedNames = appNames.prefix(visibleAppLimit)
        let remainingCount = max(0, appNames.count - displayedNames.count)

        var sessionName = displayedNames.joined(separator: ", ")
        if remainingCount > 0 {
            sessionName += ", +\(remainingCount) more"
        }

        return SessionSummary(
            sessionName: sessionName,
            sessionFullName: appNames.joined(separator: ", "),
            totalSessions: appNames.count
        )
    }

    public static func shouldSetLastState(keepWindowsOpen: Bool, bundleIdentifier: String) -> Bool {
        !keepWindowsOpen && bundleIdentifier != "com.apple.finder"
    }
}
