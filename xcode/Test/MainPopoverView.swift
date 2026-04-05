import SwiftUI
import LaterLogic

struct MainPopoverViewState: Equatable {
    var appVersion = "v1.91"
    var hasSession = false
    var sessionLabel = "Safari, Xcode, +1 more"
    var sessionDate = "Mar 15, 2026 at 6:55:20 PM"
    var sessionCountText = "10"
    var timerLabel: String? = nil
    var closeAppsOnRestore = false
    var quitAppsInsteadOfHiding = false
    var waitBeforeRestore = false
    var ignoreSystemWindows = false
    var launchAtLogin = false
    var timerDuration = "15 minutes"
    var isSaveEnabled = true

    init(
        appVersion: String = "v1.91",
        hasSession: Bool = false,
        sessionLabel: String = "Safari, Xcode, +1 more",
        sessionDate: String = "Mar 15, 2026 at 6:55:20 PM",
        sessionCountText: String = "10",
        timerLabel: String? = nil,
        closeAppsOnRestore: Bool = false,
        quitAppsInsteadOfHiding: Bool = false,
        waitBeforeRestore: Bool = false,
        ignoreSystemWindows: Bool = false,
        launchAtLogin: Bool = false,
        timerDuration: String = "15 minutes",
        isSaveEnabled: Bool = true
    ) {
        self.appVersion = appVersion
        self.hasSession = hasSession
        self.sessionLabel = sessionLabel
        self.sessionDate = sessionDate
        self.sessionCountText = sessionCountText
        self.timerLabel = timerLabel
        self.closeAppsOnRestore = closeAppsOnRestore
        self.quitAppsInsteadOfHiding = quitAppsInsteadOfHiding
        self.waitBeforeRestore = waitBeforeRestore
        self.ignoreSystemWindows = ignoreSystemWindows
        self.launchAtLogin = launchAtLogin
        self.timerDuration = timerDuration
        self.isSaveEnabled = isSaveEnabled
    }

    init(snapshot: MainPopoverSnapshot, appVersion: String = "v1.91") {
        self.init(
            appVersion: appVersion,
            hasSession: snapshot.hasSession,
            sessionLabel: snapshot.sessionLabel,
            sessionDate: snapshot.sessionDate,
            sessionCountText: snapshot.sessionCountText,
            timerLabel: snapshot.timerLabel,
            closeAppsOnRestore: snapshot.closeAppsOnRestore,
            quitAppsInsteadOfHiding: snapshot.quitAppsInsteadOfHiding,
            waitBeforeRestore: snapshot.waitBeforeRestore,
            ignoreSystemWindows: snapshot.ignoreSystemWindows,
            launchAtLogin: snapshot.launchAtLogin,
            timerDuration: snapshot.timerDuration,
            isSaveEnabled: snapshot.isSaveEnabled
        )
    }
}

struct MainPopoverView: View {
    let state: MainPopoverViewState
    var shortcutsMenuTitle = "Disable all shortcuts"
    var onSave: () -> Void = {}
    var onRestore: () -> Void = {}
    var onCancelTimer: () -> Void = {}
    var onToggleCloseAppsOnRestore: () -> Void = {}
    var onToggleQuitAppsInsteadOfHiding: () -> Void = {}
    var onToggleWaitBeforeRestore: () -> Void = {}
    var onToggleIgnoreSystemWindows: () -> Void = {}
    var onToggleLaunchAtLogin: () -> Void = {}
    var onOpenWebsite: () -> Void = {}
    var onToggleShortcuts: () -> Void = {}
    var onQuitApp: () -> Void = {}

    var body: some View {
        VStack(spacing: 18) {
            header
            sessionCard
            settingsCard
            saveButton
        }
        .padding(18)
        .frame(width: 340, alignment: .top)
        .background(Color(nsColor: NSColor(calibratedWhite: 0.15, alpha: 1)))
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Later")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .accessibilityIdentifier("mainPopoverTitle")
            Text(state.appVersion)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.65))
                .accessibilityIdentifier("mainPopoverVersion")
            Spacer()
            Menu {
                Button("Visit website", action: onOpenWebsite)
                Button(shortcutsMenuTitle, action: onToggleShortcuts)
                Divider()
                Button("Quit", action: onQuitApp)
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("openSettingsButton")
        }
    }

    @ViewBuilder
    private var sessionCard: some View {
        if state.hasSession {
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 108, height: 92)
                    .overlay(alignment: .topTrailing) {
                        Text(state.sessionCountText)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(Color(red: 0.94, green: 0.23, blue: 0.42)))
                            .offset(x: 10, y: -10)
                    }

                Text(state.sessionLabel)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(state.sessionDate)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.6))

                Button(action: onRestore) {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Restore session")
                        Spacer()
                        Text("⌘⇧R")
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.18))
                            )
                    }
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(red: 0.40, green: 0.74, blue: 0.22))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("restoreSessionButton")

                if let timerLabel = state.timerLabel {
                    HStack(spacing: 10) {
                        Text(timerLabel)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .accessibilityIdentifier("reopenTimerLabel")
                        Button("Cancel", action: onCancelTimer)
                            .buttonStyle(.plain)
                            .foregroundStyle(Color(red: 0.22, green: 0.55, blue: 1.0))
                            .accessibilityIdentifier("cancelRestoreTimerButton")
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.06))
            )
        }
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            settingsRow("Close all apps when restoring", isOn: state.closeAppsOnRestore, action: onToggleCloseAppsOnRestore)
            settingsRow("Quit apps instead of hiding", isOn: state.quitAppsInsteadOfHiding, action: onToggleQuitAppsInsteadOfHiding)
            HStack {
                settingsRow("Reopen windows in", isOn: state.waitBeforeRestore, action: onToggleWaitBeforeRestore)
                Spacer(minLength: 8)
                Text(state.timerDuration)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.12))
                    )
            }
            settingsRow("Ignore system windows", isOn: state.ignoreSystemWindows, action: onToggleIgnoreSystemWindows)
            settingsRow("Start at login", isOn: state.launchAtLogin, action: onToggleLaunchAtLogin)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white.opacity(0.06))
        )
    }

    private func settingsRow(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.square.fill" : "square.fill")
                    .foregroundStyle(isOn ? Color(red: 0.26, green: 0.52, blue: 0.98) : Color.white.opacity(0.35))
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }

    private var saveButton: some View {
        Button(action: onSave) {
            HStack {
                Image(systemName: "square.and.arrow.down")
                Text("Save windows for later")
                Spacer()
                Text("⌘⇧L")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.18))
                    )
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(red: 0.29, green: 0.50, blue: 0.94))
            )
        }
        .buttonStyle(.plain)
        .disabled(!state.isSaveEnabled)
        .opacity(state.isSaveEnabled ? 1 : 0.6)
        .accessibilityIdentifier("saveSessionButton")
    }
}
