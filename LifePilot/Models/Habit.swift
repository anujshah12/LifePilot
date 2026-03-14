import Foundation
import SwiftData

// MARK: - Frequency

/// How often a habit is scheduled.
enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily = "Daily"
    case weekdays = "Weekdays"
    case weekends = "Weekends"
    case custom = "Custom"

    var id: String { rawValue }
}

// MARK: - Habit Model

/// A habit the user wants to track, with a name, icon, color, and scheduling frequency.
@Model
final class Habit {
    var id: UUID
    var name: String
    var icon: String                 // SF Symbol name
    var colorHex: String
    var frequencyRaw: String         // Stores HabitFrequency.rawValue
    var customDays: [Int]            // Weekday numbers for custom frequency (1=Sun … 7=Sat)
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \HabitCompletion.habit)
    var completions: [HabitCompletion]

    init(
        name: String,
        icon: String = "circle.fill",
        colorHex: String = "007AFF",
        frequency: HabitFrequency = .daily,
        customDays: [Int] = []
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.frequencyRaw = frequency.rawValue
        self.customDays = customDays
        self.createdAt = Date()
        self.completions = []
    }

    // MARK: - Frequency helpers

    var frequency: HabitFrequency {
        get { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    /// Whether this habit is scheduled for the given date's weekday.
    func isScheduled(for date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date) // 1=Sun
        switch frequency {
        case .daily:    return true
        case .weekdays: return (2...6).contains(weekday)
        case .weekends: return weekday == 1 || weekday == 7
        case .custom:   return customDays.contains(weekday)
        }
    }

    /// Whether a completion log exists for the given date.
    func isCompleted(on date: Date) -> Bool {
        let cal = Calendar.current
        return completions.contains { cal.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Mutations

    /// Marks this habit as completed for the given date.
    /// Creates a new HabitCompletion record and appends it to completions.
    func markComplete(on date: Date) {
        guard !isCompleted(on: date) else { return }
        let completion = HabitCompletion(date: date)
        completion.habit = self
        completions.append(completion)
    }

    /// Removes the completion record for the given date, if one exists.
    /// Returns the removed completion so the caller can delete it from the context.
    @discardableResult
    func markIncomplete(on date: Date) -> HabitCompletion? {
        guard let completion = completions.first(where: {
            Calendar.current.isDate($0.date, inSameDayAs: date)
        }) else { return nil }
        completions.removeAll { $0.id == completion.id }
        return completion
    }

    /// Updates this habit's editable properties.
    func update(name: String, icon: String, colorHex: String,
                frequency: HabitFrequency, customDays: [Int]) {
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.frequency = frequency
        self.customDays = customDays
    }

    // MARK: - Streak computation

    /// Current consecutive-day streak ending today (or yesterday if today isn't done yet).
    var currentStreak: Int {
        let cal = Calendar.current
        var streak = 0
        var checkDate = cal.startOfDay(for: Date())

        // If today is scheduled but not yet completed, start checking from yesterday.
        if isScheduled(for: checkDate) && !isCompleted(on: checkDate) {
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
        }

        // Walk backwards through scheduled days.
        while true {
            if isScheduled(for: checkDate) {
                if isCompleted(on: checkDate) {
                    streak += 1
                } else {
                    break
                }
            }
            // Don't count days before the habit was created.
            if checkDate < cal.startOfDay(for: createdAt) { break }
            checkDate = cal.date(byAdding: .day, value: -1, to: checkDate)!
        }
        return streak
    }

    /// Best streak ever achieved.
    var bestStreak: Int {
        let cal = Calendar.current
        guard !completions.isEmpty else { return 0 }

        var best = 0
        var current = 0
        let start = cal.startOfDay(for: createdAt)
        var day = start
        let today = cal.startOfDay(for: Date())

        while day <= today {
            if isScheduled(for: day) {
                if isCompleted(on: day) {
                    current += 1
                    best = max(best, current)
                } else {
                    current = 0
                }
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return best
    }
}
