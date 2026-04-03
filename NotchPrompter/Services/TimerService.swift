import Foundation
import Combine

class TimerService: ObservableObject {
    @Published var elapsed: TimeInterval = 0
    @Published var isRunning = false

    private var timer: Timer?
    private var startDate: Date?
    private var accumulatedTime: TimeInterval = 0

    var formattedTime: String {
        let total = Int(elapsed)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        startDate = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.startDate else { return }
            self.elapsed = self.accumulatedTime + Date().timeIntervalSince(start)
        }
    }

    func pause() {
        guard isRunning else { return }
        isRunning = false
        if let start = startDate {
            accumulatedTime += Date().timeIntervalSince(start)
        }
        timer?.invalidate()
        timer = nil
        startDate = nil
    }

    func reset() {
        pause()
        elapsed = 0
        accumulatedTime = 0
    }

    deinit {
        timer?.invalidate()
    }
}
