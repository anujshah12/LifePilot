import Foundation

/// ViewModel for StatsView — computes statistics, chart data, and milestone achievements.
@Observable
final class StatsViewModel {

    // MARK: - Milestone Definitions

    /// Achievement milestones with (days required, label, SF Symbol).
    static let milestoneDefinitions: [(days: Int, label: String, icon: String)] = [
        (7,   "1 Week",    "flame"),
        (14,  "2 Weeks",   "flame.fill"),
        (30,  "1 Month",   "star.fill"),
        (60,  "2 Months",  "star.circle.fill"),
        (100, "100 Days",  "trophy.fill"),
        (365, "1 Year",    "crown.fill"),
    ]

    // MARK: - Computed Stats

    /// Formatted string showing today's completion ratio (e.g. "3/5").
    func todayCompletionText(from habits: [Habit]) -> String {
        let scheduled = habits.filter { $0.isScheduled(for: Date()) }
        let done = scheduled.filter { $0.isCompleted(on: Date()) }
        return "\(done.count)/\(scheduled.count)"
    }

    /// The best streak across all habits.
    func overallBestStreak(from habits: [Habit]) -> Int {
        habits.map(\.bestStreak).max() ?? 0
    }

    /// Completion data for the last 7 days, used by the weekly bar chart.
    func last7Days(from habits: [Habit]) -> [(date: Date, label: String, completed: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let scheduled = habits.filter { $0.isScheduled(for: date) }
            let completed = scheduled.filter { $0.isCompleted(on: date) }.count
            return (date, formatter.string(from: date), completed)
        }
    }

    /// Returns milestones that have been achieved by at least one habit.
    func achievedMilestones(from habits: [Habit]) -> [(days: Int, label: String, icon: String)] {
        Self.milestoneDefinitions.filter { milestone in
            habits.contains { $0.bestStreak >= milestone.days }
        }
    }
}
