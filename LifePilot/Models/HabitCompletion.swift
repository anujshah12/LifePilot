import Foundation
import SwiftData

/// Records a single day's completion of a habit.
/// Each entry is normalized to the start of the day it represents.
@Model
final class HabitCompletion {
    var id: UUID
    var date: Date          // Start-of-day for the completion date
    var completedAt: Date   // Exact timestamp when the user checked it off

    var habit: Habit?

    init(date: Date) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.completedAt = Date()
    }
}
