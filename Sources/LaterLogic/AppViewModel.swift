import Combine
import Foundation

public struct SessionSnapshot: Equatable {
    public let appURLs: [String]
    public let appNames: [String]
    public let sessionName: String
    public let sessionFullName: String
    public let totalSessions: Int
    public let sessionDate: String
    public let lastStateWasTerminate: Bool

    public init(
        appURLs: [String],
        appNames: [String],
        sessionName: String,
        sessionFullName: String,
        totalSessions: Int,
        sessionDate: String,
        lastStateWasTerminate: Bool
    ) {
        self.appURLs = appURLs
        self.appNames = appNames
        self.sessionName = sessionName
        self.sessionFullName = sessionFullName
        self.totalSessions = totalSessions
        self.sessionDate = sessionDate
        self.lastStateWasTerminate = lastStateWasTerminate
    }
}

@MainActor
public final class AppViewModel: NSObject, ObservableObject {
    private var settingsStore: SettingsStore
    private var countdownTimer: Timer?
    private var restoreWorkItem: DispatchWorkItem?
    private var restoreDeadline: Date?
    private var timerCompletion: (() -> Void)?
    private var timerTickHandler: ((String) -> Void)?

    @Published public private(set) var hasSession = false
    @Published public private(set) var sessionLabel = ""
    @Published public private(set) var sessionFullName = ""
    @Published public private(set) var sessionDate = ""
    @Published public private(set) var sessionCount = 0
    @Published public private(set) var isSaveEnabled = false
    @Published public private(set) var timerLabel: String?
    @Published public private(set) var isTimerVisible = false

    @Published public private(set) var launchAtLogin = false
    @Published public private(set) var ignoreSystemApps = false
    @Published public private(set) var closeAppsOnRestore = false
    @Published public private(set) var keepWindowsOpen = false
    @Published public private(set) var waitBeforeRestore = false
    @Published public private(set) var selectedTimerDuration = "15 minutes"

    public init(
        settingsStore: SettingsStore = SettingsStore(),
        launchAtLoginEnabled: Bool = false,
        selectedTimerDuration: String = "15 minutes"
    ) {
        self.settingsStore = settingsStore
        self.selectedTimerDuration = selectedTimerDuration
        super.init()
        refreshFromSettings(launchAtLoginEnabled: launchAtLoginEnabled)
    }

    public func refreshFromSettings(launchAtLoginEnabled: Bool) {
        launchAtLogin = launchAtLoginEnabled
        ignoreSystemApps = settingsStore.ignoreSystemApps
        closeAppsOnRestore = settingsStore.closeAppsOnRestore
        keepWindowsOpen = settingsStore.keepWindowsOpen
        waitBeforeRestore = settingsStore.waitBeforeRestore

        hasSession = settingsStore.hasSession
        sessionLabel = settingsStore.sessionName
        sessionFullName = settingsStore.sessionFullName
        sessionDate = settingsStore.sessionDate
        sessionCount = Int(settingsStore.totalSessions) ?? settingsStore.savedAppNames.count
        updateTimerVisibility()
    }

    public func refreshSaveAvailability(trackableAppCount: Int) {
        isSaveEnabled = trackableAppCount > 0
    }

    public func refreshTimerState(label: String?) {
        timerLabel = label
        updateTimerVisibility()
    }

    public func scheduleRestoreTimer(
        durationOption: String,
        durationOverride: TimeInterval? = nil,
        onTick: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) {
        cancelRestoreTimer()

        selectedTimerDuration = durationOption
        let delay = durationOverride ?? SessionRules.reopenDelaySeconds(for: durationOption)
        let deadline = Date().addingTimeInterval(delay)
        restoreDeadline = deadline
        timerCompletion = onComplete
        timerTickHandler = onTick

        let initialLabel = Self.reopenLabel(remainingSeconds: Int(delay))
        timerLabel = initialLabel
        isTimerVisible = true
        onTick(initialLabel)

        let restoreWork = DispatchWorkItem { [weak self] in
            self?.handleTimerFire()
        }
        restoreWorkItem = restoreWork
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: restoreWork)

        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleCountdownTimerTick),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 0.1
        countdownTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    public func cancelRestoreTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        restoreWorkItem?.cancel()
        restoreWorkItem = nil
        restoreDeadline = nil
        timerCompletion = nil
        timerTickHandler = nil
        timerLabel = nil
        isTimerVisible = false
    }

    public func refreshSelectedTimerDuration(_ value: String) {
        selectedTimerDuration = value
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        settingsStore.launchAtLoginEnabled = enabled
        launchAtLogin = enabled
    }

    public func setIgnoreSystemApps(_ enabled: Bool) {
        settingsStore.ignoreSystemApps = enabled
        ignoreSystemApps = enabled
    }

    public func setCloseAppsOnRestore(_ enabled: Bool) {
        settingsStore.closeAppsOnRestore = enabled
        closeAppsOnRestore = enabled
    }

    // Persisted semantics are legacy: true means keep windows open by hiding apps.
    public func setKeepWindowsOpen(_ enabled: Bool) {
        settingsStore.keepWindowsOpen = enabled
        keepWindowsOpen = enabled
    }

    public func setWaitBeforeRestore(_ enabled: Bool) {
        settingsStore.waitBeforeRestore = enabled
        waitBeforeRestore = enabled
        if !enabled {
            cancelRestoreTimer()
        } else {
            updateTimerVisibility()
        }
    }

    public func saveSessionSnapshot(_ snapshot: SessionSnapshot) {
        settingsStore.lastStateWasTerminate = snapshot.lastStateWasTerminate
        settingsStore.savedAppURLs = snapshot.appURLs
        settingsStore.savedAppNames = snapshot.appNames
        settingsStore.sessionName = snapshot.sessionName
        settingsStore.sessionFullName = snapshot.sessionFullName
        settingsStore.totalSessions = String(snapshot.totalSessions)
        settingsStore.sessionDate = snapshot.sessionDate
        settingsStore.hasSession = true

        hasSession = true
        sessionLabel = snapshot.sessionName
        sessionFullName = snapshot.sessionFullName
        sessionDate = snapshot.sessionDate
        sessionCount = snapshot.totalSessions
        updateTimerVisibility()
    }

    public func clearActiveSession() {
        settingsStore.hasSession = false
        hasSession = false
        updateTimerVisibility()
    }

    public var savedSessionApps: [String] {
        settingsStore.savedAppNames
    }

    public var savedSessionURLs: [String] {
        settingsStore.savedAppURLs
    }

    @objc private func handleCountdownTimerTick() {
        updateCountdown()
    }

    private func handleTimerFire() {
        guard let restoreDeadline, restoreDeadline.timeIntervalSinceNow <= 0 else {
            return
        }
        finishTimer(triggerCompletion: true)
    }

    private func updateCountdown() {
        guard let restoreDeadline else {
            countdownTimer?.invalidate()
            countdownTimer = nil
            return
        }

        let remainingSeconds = max(0, Int(ceil(restoreDeadline.timeIntervalSinceNow)))
        let label = Self.reopenLabel(remainingSeconds: remainingSeconds)
        timerLabel = label
        timerTickHandler?(label)

        if remainingSeconds == 0 {
            countdownTimer?.invalidate()
            countdownTimer = nil
        }
    }

    private func finishTimer(triggerCompletion: Bool) {
        countdownTimer?.invalidate()
        countdownTimer = nil
        restoreWorkItem?.cancel()
        restoreWorkItem = nil
        restoreDeadline = nil
        timerTickHandler = nil
        timerLabel = nil
        isTimerVisible = false

        guard triggerCompletion, let completion = timerCompletion else {
            timerCompletion = nil
            return
        }
        timerCompletion = nil
        completion()
    }

    private static func reopenLabel(remainingSeconds: Int) -> String {
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = (remainingSeconds % 3600) % 60
        return "Reopening in \(padded(hours)):\(padded(minutes)):\(padded(seconds))"
    }

    private static func padded(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private func updateTimerVisibility() {
        isTimerVisible = hasSession && waitBeforeRestore && timerLabel != nil
    }
}
