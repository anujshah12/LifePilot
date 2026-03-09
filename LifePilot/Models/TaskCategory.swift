import Foundation
import SwiftData
import SwiftUI

@Model
final class TaskCategory {
    var id: UUID
    var name: String
    var colorHex: String
    var createdAt: Date

    @Relationship(inverse: \DayTask.category)
    var dayTasks: [DayTask]

    @Relationship(inverse: \TemplateTask.category)
    var templateTasks: [TemplateTask]

    init(name: String, colorHex: String) {
        self.id = UUID()
        self.name = name
        self.colorHex = colorHex
        self.createdAt = Date()
        self.dayTasks = []
        self.templateTasks = []
    }

    var color: Color {
        Color(hex: colorHex)
    }
}
