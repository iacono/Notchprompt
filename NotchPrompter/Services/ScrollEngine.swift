import Foundation
import Combine

class ScrollEngine: ObservableObject {
    @Published var scrollOffset: CGFloat = 0
    @Published var isActive = false

    var speed: CGFloat = 0.35
    private var timer: Timer?
    private var coastTimer: Timer?
    /// How long to keep scrolling after speech stops (seconds)
    private let coastDuration: TimeInterval = 0.8

    func activate() {
        guard !isActive else { return }
        isActive = true
    }

    func deactivate() {
        guard isActive else { return }
        isActive = false
        stopTimer()
        cancelCoast()
    }

    func reset() {
        isActive = false
        stopTimer()
        cancelCoast()
        scrollOffset = 0
    }

    func setSpeaking(_ speaking: Bool) {
        guard isActive else { return }
        if speaking {
            cancelCoast()
            startTimer()
        } else {
            // Keep scrolling for coastDuration before stopping
            startCoast()
        }
    }

    func adjustOffset(by delta: CGFloat) {
        // Manual scroll: stop auto-scroll and coast so we don't fight the user
        stopTimer()
        cancelCoast()
        scrollOffset += delta
        if scrollOffset < 0 { scrollOffset = 0 }
    }

    private func startTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.scrollOffset += self.speed
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func startCoast() {
        cancelCoast()
        coastTimer = Timer.scheduledTimer(withTimeInterval: coastDuration, repeats: false) { [weak self] _ in
            self?.stopTimer()
            self?.coastTimer = nil
        }
    }

    private func cancelCoast() {
        coastTimer?.invalidate()
        coastTimer = nil
    }

    deinit {
        stopTimer()
        cancelCoast()
    }
}
