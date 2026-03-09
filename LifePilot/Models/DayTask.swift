import Foundation
import SwiftData

@Model
final class DayTask {
    var id: UUID
    var title: String
    var taskDescription: String
    var estimatedMinutes: Int
    var actualMinutes: Int?
    var order: Int
    var isComplete: Bool
    var startedAt: Date?
    var completedAt: Date?

    var category: TaskCategory?
    var dayPlan: DayPlan?

    init(
        title: String,
        taskDescription: String = "",
        estimatedMinutes: Int = 15,
        order: Int,
        category: TaskCategory? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.taskDescription = taskDescription
        self.estimatedMinutes = estimatedMinutes
        self.actualMinutes = nil
        self.order = order
        self.isComplete = false
        self.startedAt = nil
        self.completedAt = nil
        self.category = category
        self.dayPlan = nil
    }

    var isActive: Bool {
        startedAt != nil && !isComplete
    }

    var elapsedMinutes: Int {
        guard let start = startedAt else { return 0 }
        if let completed = completedAt {
            return Int(completed.timeIntervalSince(start) / 60)
        }
        return Int(Date().timeIntervalSince(start) / 60)
    }

    func markStarted() {
        startedAt = Date()
    }

    func markCompleted() {
        completedAt = Date()
        isComplete = true
        if let start = startedAt {
            actualMinutes = Int(completedAt!.timeIntervalSince(start) / 60)
        }
    }
}
