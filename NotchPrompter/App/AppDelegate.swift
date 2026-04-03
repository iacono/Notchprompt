import Cocoa
import SwiftUI
import Combine
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: TeleprompterPanel?
    private var curvePanel: NSPanel?
    private var settingsWindow: NSWindow?

    let scriptStore = ScriptStore()
    let scrollEngine = ScrollEngine()
    let voiceDetector = VoiceActivityDetector()
    let timerService = TimerService()
    let menuBarManager = MenuBarManager()
    let keyboardMonitor = KeyboardMonitor()
    let appSettings = AppSettings()

    private var showTimer = UserDefaults.standard.bool(forKey: "showTimer")
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessory app — no dock icon, doesn't steal focus from other apps
        // Keyboard events are caught via global monitor from the active app
        NSApp.setActivationPolicy(.accessory)

        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Microphone Access Required"
                    alert.informativeText = "Notchprompt needs microphone access to detect speech for automatic scrolling. Please enable it in System Settings > Privacy & Security > Microphone."
                    alert.alertStyle = .warning
                    alert.runModal()
                }
            }
        }

        // Setup menu bar
        menuBarManager.setup(
            scriptStore: scriptStore,
            onScriptSelected: { [weak self] id in self?.selectScript(id) },
            onSettings: { [weak self] in self?.showSettings() },
            onToggleTimer: { [weak self] in self?.toggleTimer() },
            onTogglePlayPause: { [weak self] in self?.handleDoubleTapSpace() },
            onQuit: { NSApp.terminate(nil) }
        )
        menuBarManager.setShowTimer(showTimer)

        // Setup keyboard monitor for double-tap spacebar
        keyboardMonitor.onAccessibilityNeeded = { [weak self] in
            self?.promptForAccessibility()
        }
        keyboardMonitor.start { [weak self] in
            DispatchQueue.main.async {
                self?.handleDoubleTapSpace()
            }
        }

        // Wire up voice detector to scroll engine
        voiceDetector.$isSpeaking
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speaking in
                guard let self = self, self.scrollEngine.isActive else { return }
                self.scrollEngine.setSpeaking(speaking)
            }
            .store(in: &cancellables)

        // Sync scroll speed setting to engine
        appSettings.$scrollSpeed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] speed in
                self?.scrollEngine.speed = CGFloat(speed)
            }
            .store(in: &cancellables)

        // Rebuild menu when scripts change
        scriptStore.$scripts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarManager.rebuildMenu()
            }
            .store(in: &cancellables)

        scriptStore.$selectedScriptID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.menuBarManager.rebuildMenu()
                self?.updatePanel()
            }
            .store(in: &cancellables)

    }

    private func ensurePanel() {
        if panel == nil {
            let p = TeleprompterPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 120))
            p.scrollEngine = scrollEngine
            p.positionAtNotch()
            self.panel = p
        }
    }

    private var springTimer: Timer?
    private let cornerRadius: CGFloat = 14

    private func showCurvePanel(for frame: NSRect) {
        let cp: NSPanel
        if let existing = curvePanel {
            cp = existing
        } else {
            cp = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            cp.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
            cp.isOpaque = false
            cp.backgroundColor = .clear
            cp.hasShadow = false
            cp.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            cp.isMovableByWindowBackground = false
            cp.hidesOnDeactivate = false
            cp.ignoresMouseEvents = true
            curvePanel = cp
        }

        let r = cornerRadius
        let overshootCover: CGFloat = 30 // extra height below curves to cover spring overshoot
        let curveFrame = NSRect(
            x: frame.origin.x,
            y: frame.origin.y + frame.height - r - overshootCover,
            width: frame.width,
            height: r + overshootCover
        )
        cp.setFrame(curveFrame, display: true)

        let curvesView = TopCurvesView(cornerRadius: r)
        cp.contentView = NSHostingView(rootView: curvesView)
        cp.orderFrontRegardless()
    }

    private func showPanel() {
        ensurePanel()
        guard let panel = panel else { return }
        panel.showTimer = showTimer
        panel.positionAtNotch()
        updatePanelContent()

        let finalFrame = panel.frame

        // Show fixed curve overlay at bezel (in front, never moves)
        showCurvePanel(for: finalFrame)

        // Start main panel fully above (hidden behind bezel), at final size
        panel.setFrame(NSRect(x: finalFrame.origin.x,
                              y: finalFrame.origin.y + finalFrame.height,
                              width: finalFrame.width,
                              height: finalFrame.height), display: true)
        panel.orderFrontRegardless()
        // Ensure curve panel stays in front of the bouncing main panel
        curvePanel?.orderFrontRegardless()

        // Spring simulation — moves entire window as one unit, no size changes
        var currentY = Double(finalFrame.origin.y + finalFrame.height)
        let targetY = Double(finalFrame.origin.y)
        var velocity: Double = 0
        let stiffness: Double = 350
        let damping: Double = 26
        let dt: Double = 1.0 / 120.0

        springTimer?.invalidate()
        springTimer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { [weak self, weak panel] t in
            guard let self = self, let panel = panel else { t.invalidate(); return }

            let displacement = currentY - targetY
            let force = -stiffness * displacement - damping * velocity
            velocity += force * dt
            currentY += velocity * dt

            panel.setFrame(NSRect(x: Double(finalFrame.origin.x), y: currentY,
                                  width: Double(finalFrame.width),
                                  height: Double(finalFrame.height)),
                           display: true)

            if abs(velocity) < 0.3 && abs(displacement) < 0.3 {
                t.invalidate()
                self.springTimer = nil
            }
        }
    }

    private func hidePanel() {
        springTimer?.invalidate()
        springTimer = nil
        panel?.orderOut(nil)
        curvePanel?.orderOut(nil)
    }

    private func updatePanel() {
        if scriptStore.selectedScript != nil {
            showPanel()
        } else {
            hidePanel()
        }
    }

    private func updatePanelContent() {
        guard let panel = panel else { return }

        let hasNotch = NSScreen.screens.contains { $0.safeAreaInsets.top > 0 }

        let view = TeleprompterView(
            scrollEngine: scrollEngine,
            timerService: timerService,
            settings: appSettings,
            text: scriptStore.selectedScript?.resolvedText ?? "",
            showTimer: showTimer,
            hasNotch: hasNotch
        )

        panel.contentView = NSHostingView(rootView: view)
    }

    private func selectScript(_ id: UUID) {
        // Reset scroll position before changing script so the view starts at top
        scrollEngine.reset()
        voiceDetector.stop()
        timerService.reset()

        if scriptStore.selectedScriptID == id {
            scriptStore.selectScript(nil)
        } else {
            scriptStore.selectScript(id)
        }
    }

    private func handleDoubleTapSpace() {
        guard scriptStore.selectedScript != nil else { return }

        if scrollEngine.isActive {
            scrollEngine.deactivate()
            voiceDetector.stop()
            timerService.pause()
            menuBarManager.setPlaying(false)
        } else {
            scrollEngine.activate()
            voiceDetector.start()
            timerService.start()
            menuBarManager.setPlaying(true)
        }
    }

    private func toggleTimer() {
        showTimer.toggle()
        UserDefaults.standard.set(showTimer, forKey: "showTimer")
        menuBarManager.setShowTimer(showTimer)
        panel?.showTimer = showTimer
        panel?.positionAtNotch()
        updatePanelContent()
    }

    private func showSettings() {
        if let window = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(scriptStore: scriptStore, appSettings: appSettings)
        let window = SettingsWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Notchprompt Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false

        self.settingsWindow = window

        // Show as regular app so settings window appears in dock/taskbar
        NSApp.setActivationPolicy(.regular)
        NSApp.applicationIconImage = MenuBarManager.createAppIcon(size: 512)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // Called by KeyboardMonitor when it can't create event tap
    func promptForAccessibility() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = "Notchprompt needs Accessibility access to detect the spacebar for play/pause.\n\nPlease go to System Settings → Privacy & Security → Accessibility and add Notchprompt.\n\nYou can also use the menu bar \"Start Prompter\" option instead."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
        }
    }
}

/// Settings window that reverts to accessory app when closed
class SettingsWindow: NSWindow {
    override func close() {
        super.close()
        // Revert to accessory so we don't steal focus from other apps
        NSApp.setActivationPolicy(.accessory)
    }
}
