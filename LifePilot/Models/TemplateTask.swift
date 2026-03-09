import Foundation
import SwiftData

@Model
final class TemplateTask {
    var id: UUID
    var title: String
    var taskDescription: String
    var estimatedMinutes: Int
    var order: Int

    var category: TaskCategory?
    var template: Template?

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
        self.order = order
        self.category = category
        self.template = nil
    }

    func toDayTask() -> DayTask {
        DayTask(
            title: title,
            taskDescription: taskDescription,
            estimatedMinutes: estimatedMinutes,
            order: order,
            category: category
        )
    }
}
