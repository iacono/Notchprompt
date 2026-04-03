import Cocoa

NSLog("Testing keyboard monitor...")
NSLog("AXIsProcessTrusted: %d", AXIsProcessTrusted())

let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

class Handler {
    func handle(type: CGEventType, event: CGEvent) {
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        NSLog("Key pressed: keyCode=%d", keyCode)
    }
}

let handler = Handler()

if let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .listenOnly,
    eventsOfInterest: eventMask,
    callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
        guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
        let h = Unmanaged<Handler>.fromOpaque(refcon).takeUnretainedValue()
        h.handle(type: type, event: event)
        return Unmanaged.passUnretained(event)
    },
    userInfo: Unmanaged.passUnretained(handler).toOpaque()
) {
    NSLog("CGEvent tap created successfully!")
    let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)
} else {
    NSLog("CGEvent tap FAILED")
    NSLog("Trying NSEvent global monitor...")

    NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
        NSLog("Global monitor key: keyCode=%d", event.keyCode)
    }
    NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
        NSLog("Local monitor key: keyCode=%d", event.keyCode)
        return event
    }
}

NSLog("Running... press keys to test (Ctrl+C to quit)")
NSApp.setActivationPolicy(.accessory)
NSApp.run()
