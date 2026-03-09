import Foundation
import SwiftData

@Model
final class Template {
    var id: UUID
    var name: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \TemplateTask.template)
    var tasks: [TemplateTask]

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
        self.tasks = []
    }

    var sortedTasks: [TemplateTask] {
        tasks.sorted { $0.order < $1.order }
    }
}
