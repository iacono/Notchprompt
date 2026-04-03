import Cocoa

class KeyboardMonitor {
    private var lastSpaceTimestamp: TimeInterval = 0
    private let doubleTapThreshold: TimeInterval = 0.35
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var onDoubleTap: (() -> Void)?
    private var retryTimer: Timer?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private(set) var isListening = false
    var onAccessibilityNeeded: (() -> Void)?
    private var hasPromptedThisLaunch = false

    func start(onDoubleTap: @escaping () -> Void) {
        self.onDoubleTap = onDoubleTap
        attemptTap()
    }

    private func attemptTap() {
        // Clean up everything
        stopTap()
        removeNSEventMonitors()

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
                monitor.handleCGEvent(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("KeyboardMonitor: CGEvent tap failed — using NSEvent monitors instead")
            // Fall back to NSEvent monitors only
            installNSEventMonitors()

            if !hasPromptedThisLaunch {
                hasPromptedThisLaunch = true
                DispatchQueue.main.async { [weak self] in
                    self?.onAccessibilityNeeded?()
                }
            }
            retryTimer?.invalidate()
            retryTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
                if AXIsProcessTrusted() {
                    self?.retryTimer?.invalidate()
                    self?.retryTimer = nil
                    self?.attemptTap()
                }
            }
            return
        }

        // CGEvent tap succeeded — use it exclusively (no NSEvent monitors to avoid duplicates)
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        isListening = true
        print("KeyboardMonitor: CGEvent tap active")
    }

    private func installNSEventMonitors() {
        removeNSEventMonitors()
        print("KeyboardMonitor: Installing NSEvent monitors")

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleNSEvent(event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleNSEvent(event)
            return event
        }

        isListening = true
    }

    private func removeNSEventMonitors() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }

    private func handleNSEvent(_ event: NSEvent) {
        guard event.keyCode == 49 else { return }
        handleSpacePress()
    }

    private func handleCGEvent(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        guard type == .keyDown else { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == 49 else { return }

        handleSpacePress()
    }

    private func handleSpacePress() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastSpaceTimestamp < doubleTapThreshold && lastSpaceTimestamp > 0 {
            lastSpaceTimestamp = 0
            DispatchQueue.main.async { [weak self] in
                self?.onDoubleTap?()
            }
        } else {
            lastSpaceTimestamp = now
        }
    }

    private func stopTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        isListening = false
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        stopTap()
        removeNSEventMonitors()
    }

    deinit {
        stop()
    }
}
