import Foundation

public struct AppFilterService {
    public let ignoredSystemBundleIDs: Set<String>

    public init(ignoredSystemBundleIDs: Set<String> = SessionRules.ignoredSystemBundleIDs) {
        self.ignoredSystemBundleIDs = ignoredSystemBundleIDs
    }

    public func shouldIgnore(
        bundleID: String?,
        ignoreSystemApps: Bool,
        customIgnoredBundleIDs: Set<String> = []
    ) -> Bool {
        SessionRules.shouldIgnoreApp(
            bundleID: bundleID,
            ignoreSystemApps: ignoreSystemApps,
            customIgnoredBundleIDs: customIgnoredBundleIDs
        )
    }

    public func shouldTrack(
        activationPolicyIsRegular: Bool,
        localizedName: String?,
        bundleIdentifier: String?,
        includeTerminal: Bool,
        includeLater: Bool,
        ignoreSystemApps: Bool,
        customIgnoredBundleIDs: Set<String> = [],
        excludedBundleIDs: Set<String> = []
    ) -> Bool {
        guard activationPolicyIsRegular else {
            return false
        }

        if let bundleIdentifier, excludedBundleIDs.contains(bundleIdentifier) {
            return false
        }

        if !includeLater && localizedName == "Later" {
            return false
        }

        if !includeTerminal && localizedName == "Terminal" {
            return false
        }

        if shouldIgnore(
            bundleID: bundleIdentifier,
            ignoreSystemApps: ignoreSystemApps,
            customIgnoredBundleIDs: customIgnoredBundleIDs
        ) {
            return false
        }

        return true
    }
}
