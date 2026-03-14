import Foundation
import SwiftData

/// ViewModel for HabitListView — manages habit CRUD operations and sheet presentation state.
/// Acts as gatekeeper: all mutations go through this ViewModel, which calls Model methods.
@Observable
final class HabitListViewModel {

    // MARK: - UI State

    /// Controls the "Add Habit" sheet presentation.
    var showAddSheet = false

    /// The habit currently being edited, or nil if no edit sheet is shown.
    var habitToEdit: Habit?

    // MARK: - Actions

    /// Deletes habits at the given index offsets from the provided array.
    func deleteHabits(at offsets: IndexSet, from habits: [Habit], context: ModelContext) {
        for index in offsets {
            context.delete(habits[index])
        }
    }

    /// Creates a new habit and inserts it into the model context.
    func addHabit(name: String, icon: String, colorHex: String,
                  frequency: HabitFrequency, customDays: [Int],
                  context: ModelContext) {
        let habit = Habit(
            name: name,
            icon: icon,
            colorHex: colorHex,
            frequency: frequency,
            customDays: customDays
        )
        context.insert(habit)
    }

    /// Updates an existing habit using the Model's own update method.
    func updateHabit(_ habit: Habit, name: String, icon: String,
                     colorHex: String, frequency: HabitFrequency, customDays: [Int]) {
        habit.update(name: name, icon: icon, colorHex: colorHex,
                     frequency: frequency, customDays: customDays)
    }

    /// Deletes a specific habit from the model context.
    func deleteHabit(_ habit: Habit, context: ModelContext) {
        context.delete(habit)
        habitToEdit = nil
    }
}
