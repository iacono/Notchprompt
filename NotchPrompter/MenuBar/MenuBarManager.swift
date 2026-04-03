import Cocoa

class MenuBarManager: NSObject {
    private var statusItem: NSStatusItem!
    private var onScriptSelected: ((UUID) -> Void)?
    private var onSettings: (() -> Void)?
    private var onToggleTimer: (() -> Void)?
    private var onTogglePlayPause: (() -> Void)?
    private var onQuit: (() -> Void)?

    private weak var scriptStore: ScriptStore?
    private var showTimer = false
    private var isPlaying = false

    func setup(
        scriptStore: ScriptStore,
        onScriptSelected: @escaping (UUID) -> Void,
        onSettings: @escaping () -> Void,
        onToggleTimer: @escaping () -> Void,
        onTogglePlayPause: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.scriptStore = scriptStore
        self.onScriptSelected = onScriptSelected
        self.onSettings = onSettings
        self.onToggleTimer = onToggleTimer
        self.onTogglePlayPause = onTogglePlayPause
        self.onQuit = onQuit

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "com.marco.Notchprompt.statusItem"

        if let button = statusItem.button {
            button.image = createMenuBarIcon()
            button.image?.isTemplate = true
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        if let store = scriptStore {
            if store.scripts.isEmpty {
                let item = NSMenuItem(title: "No Scripts", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            } else {
                for script in store.scripts {
                    let item = NSMenuItem(
                        title: script.title,
                        action: #selector(scriptItemClicked(_:)),
                        keyEquivalent: ""
                    )
                    item.target = self
                    item.representedObject = script.id
                    item.state = (store.selectedScriptID == script.id) ? .on : .off
                    menu.addItem(item)
                }
            }
        }

        menu.addItem(.separator())

        // Play/Pause (double-tap spacebar)
        let hasScript = scriptStore?.selectedScriptID != nil
        let playPauseItem = NSMenuItem(
            title: isPlaying ? "Pause Prompter" : "Start Prompter",
            action: hasScript ? #selector(playPauseClicked) : nil,
            keyEquivalent: ""
        )
        playPauseItem.target = self
        playPauseItem.isEnabled = hasScript
        menu.addItem(playPauseItem)

        menu.addItem(.separator())

        // Timer toggle
        let timerItem = NSMenuItem(
            title: "Show Timer",
            action: #selector(toggleTimerClicked),
            keyEquivalent: ""
        )
        timerItem.target = self
        timerItem.state = showTimer ? .on : .off
        menu.addItem(timerItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(settingsClicked),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let quitItem = NSMenuItem(
            title: "Quit Notchprompt",
            action: #selector(quitClicked),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    func setShowTimer(_ show: Bool) {
        showTimer = show
        rebuildMenu()
    }

    func setPlaying(_ playing: Bool) {
        isPlaying = playing
        rebuildMenu()
    }

    @objc private func scriptItemClicked(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        onScriptSelected?(id)
    }

    @objc private func playPauseClicked() {
        onTogglePlayPause?()
    }

    @objc private func toggleTimerClicked() {
        showTimer.toggle()
        onToggleTimer?()
        rebuildMenu()
    }

    @objc private func settingsClicked() {
        onSettings?()
    }

    @objc private func quitClicked() {
        onQuit?()
    }

    // MARK: - Menu Bar Icon (18x18 template)

    private func createMenuBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            // Vertically center the entire icon content
            // Total content height: screen(9) + gap(1) + neck(2) + base(0.5) = 12.5
            // Vertical offset to center in 18pt: (18 - 12.5) / 2 = 2.75
            let oy: CGFloat = 3.5
            let lineWeight: CGFloat = 1.2
            NSColor.black.setStroke()

            // Screen body
            let screenRect = NSRect(x: 2, y: oy, width: 14, height: 9)
            let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: 1.5, yRadius: 1.5)
            screenPath.lineWidth = lineWeight
            screenPath.stroke()

            // Stand neck
            let neckPath = NSBezierPath()
            neckPath.move(to: NSPoint(x: 9, y: oy + 9))
            neckPath.line(to: NSPoint(x: 9, y: oy + 11.5))
            neckPath.lineWidth = lineWeight
            neckPath.stroke()

            // Stand base
            let basePath = NSBezierPath()
            basePath.move(to: NSPoint(x: 5.5, y: oy + 11.5))
            basePath.line(to: NSPoint(x: 12.5, y: oy + 11.5))
            basePath.lineWidth = lineWeight
            basePath.stroke()

            // Text lines inside screen (centered within screen)
            let cx: CGFloat = 9.0
            let linesData: [(y: CGFloat, halfW: CGFloat)] = [
                (oy + 2.5, 4.5),
                (oy + 4.5, 3.5),
                (oy + 6.5, 2.5),
            ]
            for line in linesData {
                let p = NSBezierPath()
                p.move(to: NSPoint(x: cx - line.halfW, y: line.y))
                p.line(to: NSPoint(x: cx + line.halfW, y: line.y))
                p.lineWidth = 0.9
                p.lineCapStyle = .round
                p.stroke()
            }

            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - App Icon (any size, for dock icon)

    static func createAppIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { rect in
            let pad = size * 0.08
            let bgRect = rect.insetBy(dx: pad, dy: pad)

            // Background rounded rect
            let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: size * 0.18, yRadius: size * 0.18)
            let gradient = NSGradient(
                starting: NSColor(red: 0.12, green: 0.12, blue: 0.18, alpha: 1),
                ending: NSColor(red: 0.04, green: 0.04, blue: 0.08, alpha: 1)
            )
            gradient?.draw(in: bgPath, angle: -90)

            let lw: CGFloat = size * 0.02
            let cx = size / 2

            // Content dimensions
            let sh: CGFloat = size * 0.34
            let neckH: CGFloat = size * 0.07
            let screenStrokeW = lw * 2.0
            let baseStrokeW = lw * 2.5
            // Total visual height: top of screen stroke to bottom of base stroke
            let totalH = screenStrokeW / 2 + sh + neckH + baseStrokeW / 2
            // Center within bgRect
            let topY = bgRect.origin.y + (bgRect.height - totalH) / 2 + screenStrokeW / 2

            // Screen
            let sw: CGFloat = size * 0.52
            let screenRect = NSRect(x: cx - sw / 2, y: topY, width: sw, height: sh)
            let screenPath = NSBezierPath(roundedRect: screenRect, xRadius: size * 0.025, yRadius: size * 0.025)
            NSColor.white.setStroke()
            screenPath.lineWidth = lw * 2.0
            screenPath.stroke()

            // Stand neck
            let neckTop = screenRect.maxY
            let neckBot = neckTop + size * 0.07
            let neckPath = NSBezierPath()
            neckPath.move(to: NSPoint(x: cx, y: neckTop))
            neckPath.line(to: NSPoint(x: cx, y: neckBot))
            neckPath.lineWidth = lw * 2.0
            neckPath.stroke()

            // Stand base
            let baseW: CGFloat = size * 0.26
            let basePath = NSBezierPath()
            basePath.move(to: NSPoint(x: cx - baseW / 2, y: neckBot))
            basePath.line(to: NSPoint(x: cx + baseW / 2, y: neckBot))
            basePath.lineWidth = lw * 2.5
            basePath.lineCapStyle = .round
            basePath.stroke()

            // Text lines inside screen (centered)
            let linesData: [(yFrac: CGFloat, wFrac: CGFloat)] = [
                (0.28, 0.8),
                (0.50, 0.6),
                (0.72, 0.4),
            ]
            let innerW = sw - size * 0.08
            NSColor(white: 0.55, alpha: 1).setStroke()
            for line in linesData {
                let y = screenRect.minY + sh * line.yFrac
                let w = innerW * line.wFrac
                let p = NSBezierPath()
                p.move(to: NSPoint(x: cx - w / 2, y: y))
                p.line(to: NSPoint(x: cx + w / 2, y: y))
                p.lineWidth = lw * 1.8
                p.lineCapStyle = .round
                p.stroke()
            }

            return true
        }
        return image
    }
}
