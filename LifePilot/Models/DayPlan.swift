import Foundation
import SwiftData

@Model
final class DayPlan {
    var id: UUID
    var date: Date
    var startedAt: Date?
    var endedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \DayTask.dayPlan)
    var tasks: [DayTask]

    init(date: Date = Date()) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.startedAt = nil
        self.endedAt = nil
        self.tasks = []
    }

    var isStarted: Bool {
        startedAt != nil
    }

    var isEnded: Bool {
        endedAt != nil
    }

    var isActive: Bool {
        isStarted && !isEnded
    }

    var sortedTasks: [DayTask] {
        tasks.sorted { $0.order < $1.order }
    }

    var currentTask: DayTask? {
        sortedTasks.first { !$0.isComplete }
    }

    var completedTaskCount: Int {
        tasks.filter(\.isComplete).count
    }

    var totalEstimatedMinutes: Int {
        tasks.reduce(0) { $0 + $1.estimatedMinutes }
    }

    var totalActualMinutes: Int {
        tasks.compactMap(\.actualMinutes).reduce(0, +)
    }

    var allTasksComplete: Bool {
        !tasks.isEmpty && tasks.allSatisfy(\.isComplete)
    }

    func startDay() {
        startedAt = Date()
        if let first = sortedTasks.first {
            first.markStarted()
        }
    }

    func endDay() {
        endedAt = Date()
    }

    func completeCurrentTask() {
        guard let current = currentTask else { return }
        current.markCompleted()

        // Auto-start next task
        if let next = sortedTasks.first(where: { !$0.isComplete }) {
            next.markStarted()
        } else {
            endDay()
        }
    }
}
