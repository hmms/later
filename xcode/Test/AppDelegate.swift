//
//  AppDelegate.swift
//  Later
//
//  Created by Alyssa X on 1/22/22.
//

import Cocoa
import SwiftUI
import HotKey
import LaunchAtLogin
import LaterLogic

final class AppLifecycleAdapter {
    func applyPreSaveEffects(plan: SessionSaveExecutionPlan) {
        if plan.shouldCaptureScreenshot {
            captureScreenshot()
        }
        if let policy = plan.preSaveActivationPolicy {
            applyActivationPolicy(policy)
        }
    }

    func applyPostSaveEffects(plan: SessionSaveExecutionPlan) {
        if let policy = plan.postSaveActivationPolicy {
            applyActivationPolicy(policy)
        }
    }

    private func applyActivationPolicy(_ policy: SessionActivationPolicy) {
        switch policy {
        case .regular:
            NSApp.setActivationPolicy(.regular)
        case .accessory:
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // Capture workspace state for session preview.
    private func captureScreenshot() {
        guard let screenshot = CGDisplayCreateImage(CGMainDisplayID()) else {
            return
        }

        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent("screenshot.jpg")
        let bitmapRep = NSBitmapImageRep(cgImage: screenshot)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [:]) else {
            return
        }

        do {
            try jpegData.write(to: fileURL, options: .atomic)
        } catch {
            print("error: \(error)")
        }
    }
}

final class LaunchAtLoginAdapter {
    func currentLaunchAtLoginEnabled(isUITestMode: Bool, settingsStore: SettingsStore) -> Bool {
        if isUITestMode {
            return settingsStore.launchAtLoginEnabled
        }
        return LaunchAtLogin.isEnabled
    }

    func applyLaunchAtLogin(enabled: Bool, isUITestMode: Bool, settingsStore: inout SettingsStore) {
        if isUITestMode {
            settingsStore.launchAtLoginEnabled = enabled
            return
        }
        LaunchAtLogin.isEnabled = enabled
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    let statusItem = NSStatusBar.system.statusItem(withLength: 20)
    let popoverView = NSPopover()
    var eventMonitor: EventMonitor?
    private var settings = SettingsStore()
    private let appFilter = AppFilterService()
    private let lifecycleAdapter = AppLifecycleAdapter()
    private var saveHotKey: HotKey?
    private var restoreHotKey: HotKey?
    private let launchAtLoginAdapter = LaunchAtLoginAdapter()
    private lazy var sessionRuntime = SessionRuntimeCoordinator(
        appFilter: appFilter,
        currentBundleIdentifier: Bundle.main.bundleIdentifier
    )
    private var swiftUIPopoverHostingController: NSHostingController<MainPopoverView>?
    private var swiftUIPopoverViewModel: AppViewModel?
    private var saveShortcutHandler: (() -> Void)?
    private var restoreShortcutHandler: (() -> Void)?
    private var isUITestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }
    private var isUITestStubMode: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_STUB_SESSION")
    }
    private var shouldResetUITestDefaults: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_RESET_DEFAULTS")
    }
    private var uiTestStateFileURL: URL? {
        guard let path = ProcessInfo.processInfo.environment["UITEST_STATE_FILE"], !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path)
    }
    private var shouldUseSwiftUIPopover: Bool {
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("USE_SWIFTUI_POPOVER") {
            return true
        }

        guard let value = processInfo.environment["LATER_USE_SWIFTUI_POPOVER"]?.lowercased() else {
            return false
        }
        return value == "1" || value == "true" || value == "yes"
    }
    private struct StubSessionApp {
        let localizedName: String
        let bundleIdentifier: String
        let bundleURLString: String
    }
    private let uiTestStubApps: [StubSessionApp] = [
        StubSessionApp(
            localizedName: "Safari",
            bundleIdentifier: "com.apple.Safari",
            bundleURLString: "file:///Applications/Safari.app"
        ),
        StubSessionApp(
            localizedName: "Xcode",
            bundleIdentifier: "com.apple.dt.Xcode",
            bundleURLString: "file:///Applications/Xcode.app"
        ),
        StubSessionApp(
            localizedName: "Finder",
            bundleIdentifier: "com.apple.finder",
            bundleURLString: "file:///System/Library/CoreServices/Finder.app"
        ),
    ]
     
    @MainActor
    func runApp() {
        statusItem.button?.image = NSImage(named: NSImage.Name("icon"))
        statusItem.button?.target = self
        statusItem.button?.action = #selector(AppDelegate.togglePopover(_:))

        if shouldUseSwiftUIPopover {
            popoverView.contentViewController = makeSwiftUIPopoverContentViewController()
        } else {
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            guard let vc = storyboard.instantiateController(withIdentifier: "ViewController1") as? ViewController else {
                fatalError("Unable to find ViewController")
            }
            popoverView.contentViewController = vc
        }
        popoverView.behavior = .transient
        eventMonitor = EventMonitor(mask: [.leftMouseDown, .rightMouseDown]) { [unowned self] event in
            if popoverView.isShown {
                closePopover(event)
            }
        }
        eventMonitor?.start()
    }

    // Phase 2 seam: keep launch behavior on the storyboard controller until SwiftUI parity is verified.
    @MainActor
    private func makeSwiftUIPopoverContentViewController() -> NSViewController {
        let hostingController = swiftUIPopoverHostingController ?? NSHostingController(rootView: makeSwiftUIPopoverRootView())
        let contentSize = NSSize(width: 340, height: 620)
        hostingController.view.frame = NSRect(origin: .zero, size: contentSize)
        hostingController.preferredContentSize = contentSize
        swiftUIPopoverHostingController = hostingController
        refreshSwiftUIPopoverContent()
        return hostingController
    }

    private func currentAppVersionText() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version.map { "v\($0)" } ?? "Later"
    }

    @MainActor
    private func swiftUIViewModel() -> AppViewModel {
        if let swiftUIPopoverViewModel {
            swiftUIPopoverViewModel.refreshFromSettings(
                launchAtLoginEnabled: launchAtLoginEnabled(isUITestMode: isUITestMode)
            )
            return swiftUIPopoverViewModel
        }

        let viewModel = AppViewModel(
            settingsStore: settings,
            launchAtLoginEnabled: launchAtLoginEnabled(isUITestMode: isUITestMode)
        )
        swiftUIPopoverViewModel = viewModel
        return viewModel
    }

    @MainActor
    private func makeSwiftUIPopoverRootView() -> MainPopoverView {
        let viewModel = swiftUIViewModel()
        let state = MainPopoverViewState(
            snapshot: viewModel.mainPopoverSnapshot,
            appVersion: currentAppVersionText()
        )
        return MainPopoverView(
            state: state,
            shortcutsMenuTitle: shortcutsDisabled ? "Enable all shortcuts" : "Disable all shortcuts",
            onSave: { [weak self] in self?.saveSessionFromSwiftUI() },
            onRestore: { [weak self] in self?.restoreSessionFromSwiftUI() },
            onCancelTimer: { [weak self] in self?.cancelRestoreTimerFromSwiftUI() },
            onToggleCloseAppsOnRestore: { [weak self] in self?.toggleCloseAppsOnRestoreFromSwiftUI() },
            onToggleQuitAppsInsteadOfHiding: { [weak self] in self?.toggleQuitAppsInsteadOfHidingFromSwiftUI() },
            onToggleWaitBeforeRestore: { [weak self] in self?.toggleWaitBeforeRestoreFromSwiftUI() },
            onToggleIgnoreSystemWindows: { [weak self] in self?.toggleIgnoreSystemWindowsFromSwiftUI() },
            onToggleLaunchAtLogin: { [weak self] in self?.toggleLaunchAtLoginFromSwiftUI() },
            onOpenWebsite: { [weak self] in self?.openWebsite() },
            onToggleShortcuts: { [weak self] in self?.toggleShortcutsFromMenu() },
            onQuitApp: { NSApp.terminate(nil) }
        )
    }

    @MainActor
    private func refreshSwiftUIPopoverContent() {
        swiftUIPopoverHostingController?.rootView = makeSwiftUIPopoverRootView()
    }

    @MainActor
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        if isUITestMode && shouldResetUITestDefaults, let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }

        NSApp.setActivationPolicy(isUITestMode ? .regular : .accessory)
        runApp();
        
        if isUITestMode {
            showPopover(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        refreshHotKeyRegistration()
        writeUITestStateSnapshotIfNeeded()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if popoverView.isShown {
            closePopover(sender)
        } else {
            showPopover(sender)
        }
    }
    
    func showPopover(_ sender: AnyObject?) {
        popoverView.animates = true
        if let button = statusItem.button {
            popoverView.backgroundColor = #colorLiteral(red: 0.1490048468, green: 0.1490279436, blue: 0.1489969194, alpha: 1)
            popoverView.appearance = NSAppearance(named: .aqua)
            popoverView.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        }
        eventMonitor?.start()
    }
    
    func closePopover(_ sender: AnyObject?) {
        popoverView.performClose(sender)
        eventMonitor?.stop()
    }

    @objc private func openWebsite() {
        guard let url = URL(string: "https://twitter.com/alyssaxuu") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleShortcutsFromMenu() {
        setShortcutsDisabled(!shortcutsDisabled)
        Task { @MainActor in
            self.refreshSwiftUIPopoverContent()
            self.writeUITestStateSnapshotIfNeeded()
        }
    }

    func configureShortcutHandlers(
        onSave: @escaping () -> Void,
        onRestore: @escaping () -> Void
    ) {
        saveShortcutHandler = onSave
        restoreShortcutHandler = onRestore
        refreshHotKeyRegistration()
    }

    var shortcutsDisabled: Bool {
        settings.globalShortcutsDisabled
    }

    func setShortcutsDisabled(_ disabled: Bool) {
        settings.globalShortcutsDisabled = disabled
        refreshHotKeyRegistration()
    }

    func triggerSaveShortcutForTesting() {
        guard !settings.globalShortcutsDisabled else { return }
        saveShortcutHandler?()
    }

    func triggerRestoreShortcutForTesting() {
        guard !settings.globalShortcutsDisabled else { return }
        restoreShortcutHandler?()
    }

    func launchAtLoginEnabled(isUITestMode: Bool) -> Bool {
        launchAtLoginAdapter.currentLaunchAtLoginEnabled(
            isUITestMode: isUITestMode,
            settingsStore: settings
        )
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool, isUITestMode: Bool) {
        launchAtLoginAdapter.applyLaunchAtLogin(
            enabled: enabled,
            isUITestMode: isUITestMode,
            settingsStore: &settings
        )
    }

    private func refreshHotKeyRegistration() {
        if settings.globalShortcutsDisabled {
            saveHotKey = nil
            restoreHotKey = nil
            return
        }

        saveHotKey = HotKey(key: .l, modifiers: [.command, .shift])
        saveHotKey?.keyDownHandler = { [weak self] in
            self?.saveShortcutHandler?()
        }

        restoreHotKey = HotKey(key: .r, modifiers: [.command, .shift])
        restoreHotKey?.keyDownHandler = { [weak self] in
            self?.restoreShortcutHandler?()
        }
    }

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
        return formatter.string(from: Date())
    }

    private func closePopoverIfNeeded() {
        if !isUITestMode {
            closePopover(self)
        }
    }

    @MainActor
    private func swiftUIStubSessionAppsForSave(viewModel: AppViewModel) -> [StubSessionApp] {
        let ignoreSystemApps = viewModel.ignoreSystemApps
        return uiTestStubApps.filter { app in
            !appFilter.shouldIgnore(
                bundleID: app.bundleIdentifier,
                ignoreSystemApps: ignoreSystemApps
            )
        }
    }

    @MainActor
    private func saveSessionFromSwiftUI() {
        let viewModel = swiftUIViewModel()
        let ignoreSystemApps = viewModel.ignoreSystemApps
        var capturedApps = [SessionCapturedApp]()
        var lastStateWasTerminate = false
        let action = SessionSavePlanner.actionForSave(
            quitAppsInsteadOfHiding: !viewModel.keepWindowsOpen
        )
        let sideEffectsPlan = SessionSaveSideEffectsPlanner.makePlan(isUITestStubMode: isUITestStubMode)
        lifecycleAdapter.applyPreSaveEffects(plan: sideEffectsPlan)

        if isUITestStubMode {
            for runningApplication in swiftUIStubSessionAppsForSave(viewModel: viewModel) {
                capturedApps.append(
                    SessionCapturedApp(
                        localizedName: runningApplication.localizedName,
                        bundleIdentifier: runningApplication.bundleIdentifier,
                        bundleURLString: runningApplication.bundleURLString
                    )
                )
            }
            lastStateWasTerminate = SessionSavePlanner.lastStateWasTerminate(
                capturedApps: capturedApps,
                action: action
            )
        } else {
            let trackedApplications = sessionRuntime.trackableRunningApps(
                includeTerminal: true,
                includeLater: false,
                ignoreSystemApps: ignoreSystemApps
            )
            for runningApplication in trackedApplications {
                capturedApps.append(
                    SessionCapturedApp(
                        localizedName: runningApplication.localizedName ?? "",
                        bundleIdentifier: runningApplication.bundleIdentifier,
                        bundleURLString: runningApplication.bundleURL?.absoluteString
                    )
                )
            }
            lastStateWasTerminate = sessionRuntime.applySavedAppAction(action, to: trackedApplications)
        }

        lifecycleAdapter.applyPostSaveEffects(plan: sideEffectsPlan)

        let snapshotDraft = SessionSavePlanner.makeDraft(from: capturedApps)
        let snapshot = SessionSnapshotComposer.makeSnapshot(
            draft: snapshotDraft,
            sessionDate: currentDateString(),
            lastStateWasTerminate: lastStateWasTerminate
        )
        viewModel.saveSessionSnapshot(snapshot)

        if viewModel.waitBeforeRestore {
            scheduleRestoreTimerFromSwiftUI()
        }

        refreshSwiftUIPopoverContent()
        writeUITestStateSnapshotIfNeeded()
        closePopoverIfNeeded()
    }

    @MainActor
    private func scheduleRestoreTimerFromSwiftUI() {
        let viewModel = swiftUIViewModel()
        viewModel.scheduleRestoreTimer(
            durationOption: viewModel.selectedTimerDuration,
            onTick: { [weak self] _ in
                Task { @MainActor in
                    self?.refreshSwiftUIPopoverContent()
                    self?.writeUITestStateSnapshotIfNeeded()
                }
            },
            onComplete: { [weak self] in
                Task { @MainActor in
                    self?.restoreSessionFromSwiftUI()
                }
            }
        )
        if isUITestMode {
            UITestStateStore.setTimerScheduled(true)
        }
    }

    @MainActor
    private func cancelRestoreTimerFromSwiftUI() {
        let viewModel = swiftUIViewModel()
        viewModel.cancelRestoreTimer()
        if isUITestMode {
            UITestStateStore.setTimerScheduled(false)
        }
        refreshSwiftUIPopoverContent()
        writeUITestStateSnapshotIfNeeded()
    }

    @MainActor
    private func toggleCloseAppsOnRestoreFromSwiftUI() {
        let viewModel = swiftUIViewModel()
        viewModel.setCloseAppsOnRestore(!viewModel.closeAppsOnRestore)
        refreshSwiftUIPopoverContent()
        writeUITestStateSnapshotIfNeeded()
    }

    @MainActor
    private func toggleQuitAppsInsteadOfHidingFromSwiftUI() {
        let viewModel = swiftUIViewModel()
        let nextQuitAppsInsteadOfHiding = !viewModel.keepWindowsOpen
        viewModel.setKeepWindowsOpen(nextQuitAppsInsteadOfHiding)
        refreshSwiftUIPopoverContent()
        writeUITestStateSnapshotIfNeeded()
    }

    @MainActor
    private func toggleWaitBeforeRestoreFromSwiftUI() {
        let viewModel = swiftUIViewModel()
        let nextValue = !viewModel.waitBeforeRestore
        viewModel.setWaitBeforeRestore(nextValue)
        if !nextValue, isUITestMode {
            UITestStateStore.setTimerScheduled(false)
        }
        refreshSwiftUIPopoverContent()
        writeUITestStateSnapshotIfNeeded()
    }

    @MainActor
    private func toggleIgnoreSystemWindowsFromSwiftUI() {
        let viewModel = swiftUIViewModel()
        viewModel.setIgnoreSystemApps(!viewModel.ignoreSystemApps)
        refreshSwiftUIPopoverContent()
        writeUITestStateSnapshotIfNeeded()
    }

    @MainActor
    private func toggleLaunchAtLoginFromSwiftUI() {
        let viewModel = swiftUIViewModel()
        let nextValue = !viewModel.launchAtLogin
        setLaunchAtLoginEnabled(nextValue, isUITestMode: isUITestMode)
        viewModel.setLaunchAtLogin(nextValue)
        refreshSwiftUIPopoverContent()
        writeUITestStateSnapshotIfNeeded()
    }

    @MainActor
    private func restoreSessionFromSwiftUI() {
        let viewModel = swiftUIViewModel()
        let ignoreSystemApps = viewModel.ignoreSystemApps
        viewModel.cancelRestoreTimer()
        if isUITestMode {
            UITestStateStore.setTimerScheduled(false)
        }

        let apps = viewModel.savedSessionApps
        let executables = viewModel.savedSessionURLs

        let restorePlan = SessionRestorePlanner.makePlan(
            isUITestStubMode: isUITestStubMode,
            closeAppsOnRestore: viewModel.closeAppsOnRestore,
            appNames: apps,
            appURLs: executables
        )

        if let preRestoreAction = restorePlan.preRestoreAction {
            let runningApps = sessionRuntime.trackableRunningApps(
                includeTerminal: false,
                includeLater: true,
                ignoreSystemApps: ignoreSystemApps
            )
            _ = sessionRuntime.applySavedAppAction(preRestoreAction, to: runningApps)
        }

        if restorePlan.shouldRestoreApps {
            if !isUITestStubMode {
                sessionRuntime.restoreSavedApps(names: apps, urls: executables)
            }
            viewModel.clearActiveSession()
        }

        refreshSwiftUIPopoverContent()
        writeUITestStateSnapshotIfNeeded()
        closePopoverIfNeeded()
    }

    @MainActor
    private func writeUITestStateSnapshotIfNeeded() {
        guard isUITestMode, shouldUseSwiftUIPopover, let url = uiTestStateFileURL else {
            return
        }

        let viewModel = AppViewModel(
            settingsStore: settings,
            launchAtLoginEnabled: launchAtLoginEnabled(isUITestMode: isUITestMode)
        )
        let popoverSnapshot = viewModel.mainPopoverSnapshot
        let savedAppCount = Int(popoverSnapshot.sessionCountText) ?? settings.savedAppNames.count
        let snapshot = UITestStateSnapshotComposer.makeSnapshot(
            hasSession: popoverSnapshot.hasSession,
            savedAppCount: savedAppCount,
            timerScheduled: popoverSnapshot.timerLabel != nil || UITestStateStore.isTimerScheduled(),
            globalShortcutsDisabled: settings.globalShortcutsDisabled,
            launchAtLoginEnabled: launchAtLoginEnabled(isUITestMode: isUITestMode),
            swiftUIPopoverActive: true
        )

        do {
            try UITestStateWriter.write(snapshot, to: url)
        } catch {
            print("Failed to write UI test snapshot: \(error)")
        }
    }
    
    
}

extension NSPopover {
    
    private struct Keys {
        static var backgroundViewKey = "backgroundKey"
    }
    
    private var backgroundView: NSView {
        let bgView = objc_getAssociatedObject(self, &Keys.backgroundViewKey) as? NSView
        if let view = bgView {
            return view
        }
        
        let view = NSView()
        objc_setAssociatedObject(self, &Keys.backgroundViewKey, view, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        NotificationCenter.default.addObserver(self, selector: #selector(popoverWillOpen(_:)), name: NSPopover.willShowNotification, object: nil)
        return view
    }
    
    @objc private func popoverWillOpen(_ notification: Notification) {
        if backgroundView.superview == nil {
            if let contentView = contentViewController?.view, let frameView = contentView.superview {
                frameView.wantsLayer = true
                backgroundView.frame = NSInsetRect(frameView.frame, 1, 1)
                backgroundView.autoresizingMask = [.width, .height]
                frameView.addSubview(backgroundView, positioned: .below, relativeTo: contentView)
            }
        }
    }
    
    var backgroundColor: NSColor? {
        get {
            if let bgColor = backgroundView.layer?.backgroundColor {
                return NSColor(cgColor: bgColor)
            }
            return nil
        }
        set {
            backgroundView.wantsLayer = true
            backgroundView.layer?.backgroundColor = newValue?.cgColor
            backgroundView.layer?.borderColor = newValue?.cgColor
        }
    }
}
