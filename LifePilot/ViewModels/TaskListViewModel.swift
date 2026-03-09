import Foundation
import SwiftData
import Observation

@Observable
final class TaskListViewModel {

    // MARK: - Properties

    private let dayPlan: DayPlan
    private var timer: Timer?

    /// Live-updated elapsed time string for the current task (e.g. "3:42").
    var currentTaskElapsed: String = "0:00"

    // MARK: - Init / Deinit

    init(dayPlan: DayPlan) {
        self.dayPlan = dayPlan
        startTimer()
    }

    deinit {
        stopTimer()
    }

    // MARK: - Computed — Task Access

    var sortedTasks: [DayTask] {
        dayPlan.sortedTasks
    }

    var currentTask: DayTask? {
        dayPlan.currentTask
    }

    // MARK: - Computed — Progress

    var completedCount: Int {
        dayPlan.completedTaskCount
    }

    var totalCount: Int {
        dayPlan.tasks.count
    }

    /// A value between 0.0 and 1.0 representing overall completion.
    var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    /// Human-readable percentage, e.g. "67%".
    var progressPercent: String {
        let pct = Int(progressFraction * 100)
        return "\(pct)%"
    }

    var allTasksComplete: Bool {
        dayPlan.allTasksComplete
    }

    var isDayStarted: Bool {
        dayPlan.isStarted
    }

    var isDayEnded: Bool {
        dayPlan.isEnded
    }

    var totalEstimatedMinutes: Int {
        dayPlan.totalEstimatedMinutes
    }

    var totalActualMinutes: Int {
        dayPlan.totalActualMinutes
    }

    // MARK: - Actions

    func completeCurrentTask() {
        dayPlan.completeCurrentTask()
        updateElapsed()
    }

    func startDay() {
        dayPlan.startDay()
        updateElapsed()
    }

    // MARK: - Task State Helpers

    /// Returns the visual state for a given task relative to the current sequence.
    func state(for task: DayTask) -> TaskState {
        if task.isComplete {
            return .completed
        } else if task.id == currentTask?.id {
            return .current
        } else {
            return .locked
        }
    }

    enum TaskState {
        case completed
        case current
        case locked
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateElapsed()
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updateElapsed() {
        guard let task = currentTask, let start = task.startedAt else {
            currentTaskElapsed = "0:00"
            return
        }
        currentTaskElapsed = TimeFormatter.elapsedString(from: start)
    }
}
