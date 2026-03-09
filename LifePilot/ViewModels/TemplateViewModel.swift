import Foundation
import SwiftData
import Observation

@Observable
final class TemplateViewModel {

    // MARK: - Validation State

    /// Non-empty when the last mutating operation failed validation.
    var validationError: String?

    // MARK: - Template CRUD

    /// Creates a new template with the given name and inserts it into the model context.
    /// - Returns: The newly created `Template`, or `nil` if validation fails.
    @discardableResult
    func createTemplate(name: String, context: ModelContext) -> Template? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationError = "Template name cannot be empty."
            return nil
        }
        validationError = nil
        let template = Template(name: trimmed)
        context.insert(template)
        return template
    }

    /// Deletes the given template from the model context.
    func deleteTemplate(_ template: Template, context: ModelContext) {
        context.delete(template)
    }

    /// Duplicates a template (including all its tasks) and inserts the copy.
    @discardableResult
    func duplicateTemplate(_ template: Template, context: ModelContext) -> Template {
        let copy = Template(name: "\(template.name) Copy")
        context.insert(copy)

        for task in template.sortedTasks {
            let newTask = TemplateTask(
                title: task.title,
                taskDescription: task.taskDescription,
                estimatedMinutes: task.estimatedMinutes,
                order: task.order,
                category: task.category
            )
            copy.tasks.append(newTask)
        }
        return copy
    }

    // MARK: - Task Management

    /// Adds a new task to the end of the template's task list.
    @discardableResult
    func addTaskToTemplate(
        _ template: Template,
        title: String,
        description: String = "",
        estimatedMinutes: Int = 15,
        category: TaskCategory? = nil
    ) -> TemplateTask? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            validationError = "Task title cannot be empty."
            return nil
        }
        validationError = nil

        let nextOrder = (template.tasks.map(\.order).max() ?? -1) + 1
        let task = TemplateTask(
            title: trimmed,
            taskDescription: description,
            estimatedMinutes: max(1, estimatedMinutes),
            order: nextOrder,
            category: category
        )
        template.tasks.append(task)
        template.updatedAt = Date()
        return task
    }

    /// Removes a task from the template and re-indexes remaining task orders.
    func removeTaskFromTemplate(_ task: TemplateTask, template: Template, context: ModelContext) {
        template.tasks.removeAll { $0.id == task.id }
        context.delete(task)
        reindexTasks(in: template)
        template.updatedAt = Date()
    }

    /// Reorders tasks based on a standard SwiftUI `onMove` index set operation.
    func reorderTasks(in template: Template, from source: IndexSet, to destination: Int) {
        var ordered = template.sortedTasks
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in ordered.enumerated() {
            task.order = index
        }
        template.updatedAt = Date()
    }

    // MARK: - Load into Day Plan

    /// Validates a template is ready to be used as a day plan.
    func canLoadTemplate(_ template: Template) -> Bool {
        guard !template.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            validationError = "Template name cannot be empty."
            return false
        }
        guard !template.tasks.isEmpty else {
            validationError = "Template must have at least one task."
            return false
        }
        validationError = nil
        return true
    }

    /// Creates a new `DayPlan` from a template for the specified date.
    /// Converts each `TemplateTask` to a `DayTask` using `toDayTask()`.
    /// - Returns: The new `DayPlan`, or `nil` if validation fails.
    @discardableResult
    func loadTemplateIntoDayPlan(
        template: Template,
        date: Date = Date(),
        context: ModelContext
    ) -> DayPlan? {
        guard canLoadTemplate(template) else { return nil }

        let dayPlan = DayPlan(date: date)
        context.insert(dayPlan)

        for templateTask in template.sortedTasks {
            let dayTask = templateTask.toDayTask()
            dayPlan.tasks.append(dayTask)
        }

        return dayPlan
    }

    // MARK: - Helpers

    /// Returns the total estimated minutes across all tasks in a template.
    func totalEstimatedMinutes(for template: Template) -> Int {
        template.tasks.reduce(0) { $0 + $1.estimatedMinutes }
    }

    // MARK: - Private

    private func reindexTasks(in template: Template) {
        for (index, task) in template.sortedTasks.enumerated() {
            task.order = index
        }
    }
}
