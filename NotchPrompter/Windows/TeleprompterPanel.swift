import Cocoa

class TeleprompterPanel: NSPanel {

    weak var scrollEngine: ScrollEngine?
    var showTimer = false

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .statusBar
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = false
        self.animationBehavior = .none
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    override func scrollWheel(with event: NSEvent) {
        guard let engine = scrollEngine else {
            super.scrollWheel(with: event)
            return
        }
        let delta = -event.scrollingDeltaY * 2.0
        engine.adjustOffset(by: delta)
    }

    func positionAtNotch() {
        let screen = NSScreen.screens.first(where: {
            $0.safeAreaInsets.top > 0
        }) ?? NSScreen.main ?? NSScreen.screens.first

        guard let screen = screen else { return }

        let screenFrame = screen.frame
        let safeTop = screen.safeAreaInsets.top

        let baseHeight: CGFloat = 187
        let timerExtra: CGFloat = 28
        let windowHeight = baseHeight + timerExtra

        let panelWidth: CGFloat = 442
        let concaveInset: CGFloat = 14
        let windowWidth: CGFloat = panelWidth + 2 * concaveInset
        let x = screenFrame.midX - (windowWidth / 2)
        // Position window top at bezel bottom so concave curves are visible
        let y = screenFrame.maxY - safeTop - windowHeight

        self.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
    }
}
