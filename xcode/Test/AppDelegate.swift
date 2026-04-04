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
    private var saveHotKey: HotKey?
    private var restoreHotKey: HotKey?
    private let launchAtLoginAdapter = LaunchAtLoginAdapter()
    private var saveShortcutHandler: (() -> Void)?
    private var restoreShortcutHandler: (() -> Void)?
    private var isUITestMode: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }
    private var shouldResetUITestDefaults: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_RESET_DEFAULTS")
    }
     
    func runApp() {
        statusItem.button?.image = NSImage(named: NSImage.Name("icon"))
        statusItem.button?.target = self
        statusItem.button?.action = #selector(AppDelegate.togglePopover(_:))
        
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        guard let vc = storyboard.instantiateController(withIdentifier: "ViewController1") as? ViewController else {
            fatalError("Unable to find ViewController")
        }
        popoverView.contentViewController = vc
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
        let viewModel = AppViewModel(
            settingsStore: settings,
            launchAtLoginEnabled: launchAtLoginEnabled(isUITestMode: isUITestMode)
        )
        let state = MainPopoverViewState(
            snapshot: viewModel.mainPopoverSnapshot,
            appVersion: currentAppVersionText()
        )
        let hostingController = NSHostingController(rootView: MainPopoverView(state: state))
        hostingController.view.frame = NSRect(x: 0, y: 0, width: 340, height: 520)
        return hostingController
    }

    private func currentAppVersionText() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version.map { "v\($0)" } ?? "Later"
    }


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
