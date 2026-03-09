import Foundation
import SwiftData
import Observation

@Observable
final class WeeklyReportViewModel {

    // MARK: - Week Navigation

    /// The Monday that starts the currently selected week.
    var selectedWeekStart: Date {
        didSet { reload() }
    }

    // MARK: - Fetched Data

    private(set) var weekPlans: [DayPlan] = []

    /// All plans ever fetched for streak calculation (cached after first load).
    private var allPlans: [DayPlan] = []

    // MARK: - Private

    private var modelContext: ModelContext?

    // MARK: - Init

    init() {
        self.selectedWeekStart = Self.mondayOfWeek(containing: Date())
    }

    // MARK: - Data Loading

    func load(context: ModelContext) {
        self.modelContext = context
        reload()
    }

    private func reload() {
        guard let context = modelContext else { return }
        fetchWeekPlans(context: context)
        fetchAllPlans(context: context)
    }

    private func fetchWeekPlans(context: ModelContext) {
        let start = selectedWeekStart
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start)!

        let descriptor = FetchDescriptor<DayPlan>(
            predicate: #Predicate<DayPlan> { plan in
                plan.date >= start && plan.date < end
            },
            sortBy: [SortDescriptor(\.date)]
        )

        do {
            weekPlans = try context.fetch(descriptor)
        } catch {
            weekPlans = []
        }
    }

    private func fetchAllPlans(context: ModelContext) {
        let descriptor = FetchDescriptor<DayPlan>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            allPlans = try context.fetch(descriptor)
        } catch {
            allPlans = []
        }
    }

    // MARK: - Week Navigation

    var weekLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let endDate = Calendar.current.date(byAdding: .day, value: 6, to: selectedWeekStart)!
        return "Week of \(formatter.string(from: selectedWeekStart)) - \(formatter.string(from: endDate))"
    }

    var canGoForward: Bool {
        let nextWeekStart = Calendar.current.date(byAdding: .day, value: 7, to: selectedWeekStart)!
        return nextWeekStart <= Self.mondayOfWeek(containing: Date())
    }

    func goToPreviousWeek() {
        selectedWeekStart = Calendar.current.date(byAdding: .day, value: -7, to: selectedWeekStart)!
    }

    func goToNextWeek() {
        guard canGoForward else { return }
        selectedWeekStart = Calendar.current.date(byAdding: .day, value: 7, to: selectedWeekStart)!
    }

    // MARK: - All Tasks This Week

    var allWeekTasks: [DayTask] {
        weekPlans.flatMap { $0.tasks }
    }

    // MARK: - Total Tracked Minutes

    var totalTrackedMinutes: Int {
        allWeekTasks.compactMap(\.actualMinutes).reduce(0, +)
    }

    var totalTrackedDisplay: String {
        TimeFormatter.minutesToDisplay(totalTrackedMinutes)
    }

    // MARK: - Completion Stats

    var totalPlannedTasks: Int {
        allWeekTasks.count
    }

    var totalCompletedTasks: Int {
        allWeekTasks.filter(\.isComplete).count
    }

    // MARK: - Productivity Score

    var productivityScore: Int {
        guard totalPlannedTasks > 0 else { return 0 }
        let raw = (Double(totalCompletedTasks) / Double(totalPlannedTasks)) * 100.0
        return min(100, max(0, Int(raw)))
    }

    // MARK: - Streak

    /// Consecutive days (looking back from today) where all tasks were completed.
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Build a dictionary: startOfDay -> DayPlan
        var plansByDate: [Date: DayPlan] = [:]
        for plan in allPlans {
            let day = calendar.startOfDay(for: plan.date)
            plansByDate[day] = plan
        }

        var streak = 0
        var checkDate = today

        while true {
            guard let plan = plansByDate[checkDate] else {
                // No plan for this date — streak broken (unless it is today and no plan yet)
                if checkDate == today {
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                    continue
                }
                break
            }

            if plan.allTasksComplete {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
            } else {
                // If it is today and still in progress, skip without breaking
                if checkDate == today {
                    checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate)!
                    continue
                }
                break
            }
        }

        return streak
    }

    // MARK: - Category Breakdown

    struct CategoryBreakdown: Identifiable {
        let id = UUID()
        let category: TaskCategory?
        let categoryName: String
        let colorHex: String
        let totalMinutes: Int
        var hours: Double { Double(totalMinutes) / 60.0 }
        var percentage: Double = 0
    }

    var categoryBreakdowns: [CategoryBreakdown] {
        var dict: [String: (TaskCategory?, Int)] = [:]

        for task in allWeekTasks {
            let actual = task.actualMinutes ?? task.estimatedMinutes
            let key = task.category?.name ?? "Uncategorized"
            let existing = dict[key] ?? (task.category, 0)
            dict[key] = (existing.0, existing.1 + actual)
        }

        let totalMinutes = dict.values.reduce(0) { $0 + $1.1 }

        var results = dict.map { key, value in
            CategoryBreakdown(
                category: value.0,
                categoryName: key,
                colorHex: value.0?.colorHex ?? "999999",
                totalMinutes: value.1,
                percentage: totalMinutes > 0 ? (Double(value.1) / Double(totalMinutes)) * 100 : 0
            )
        }

        results.sort { $0.totalMinutes > $1.totalMinutes }
        return results
    }

    // MARK: - Daily Data

    struct DailyData: Identifiable {
        let id = UUID()
        let date: Date
        let dayName: String
        let dayNumber: String
        let plan: DayPlan?
        let tasks: [DayTask]
        let isToday: Bool
    }

    var dailyData: [DailyData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dayNameFormatter = DateFormatter()
        dayNameFormatter.dateFormat = "EEE"
        let dayNumberFormatter = DateFormatter()
        dayNumberFormatter.dateFormat = "d"

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: selectedWeekStart)!
            let dayStart = calendar.startOfDay(for: date)
            let plan = weekPlans.first { calendar.isDate($0.date, inSameDayAs: dayStart) }
            let tasks = plan?.sortedTasks ?? []

            return DailyData(
                date: dayStart,
                dayName: dayNameFormatter.string(from: dayStart),
                dayNumber: dayNumberFormatter.string(from: dayStart),
                plan: plan,
                tasks: tasks,
                isToday: calendar.isDate(dayStart, inSameDayAs: today)
            )
        }
    }

    // MARK: - Estimated vs Actual Accuracy

    var totalEstimatedMinutes: Int {
        allWeekTasks.reduce(0) { $0 + $1.estimatedMinutes }
    }

    var totalActualMinutes: Int {
        allWeekTasks.compactMap(\.actualMinutes).reduce(0, +)
    }

    var estimatedDisplay: String {
        TimeFormatter.minutesToDisplay(totalEstimatedMinutes)
    }

    var actualDisplay: String {
        TimeFormatter.minutesToDisplay(totalActualMinutes)
    }

    /// Average ratio of actual/estimated across completed tasks. 1.0 = perfect.
    var accuracyRatio: Double {
        let completed = allWeekTasks.filter { $0.isComplete && $0.actualMinutes != nil }
        guard !completed.isEmpty else { return 1.0 }

        let ratios = completed.compactMap { task -> Double? in
            guard let actual = task.actualMinutes, task.estimatedMinutes > 0 else { return nil }
            return Double(actual) / Double(task.estimatedMinutes)
        }

        guard !ratios.isEmpty else { return 1.0 }
        return ratios.reduce(0, +) / Double(ratios.count)
    }

    var accuracyPercentage: Int {
        // How close to the estimate: 100% = exactly on target
        // > 100 means took longer, < 100 means finished faster
        Int(accuracyRatio * 100)
    }

    // MARK: - Chart Data Helpers

    struct EstimateVsActualEntry: Identifiable {
        let id = UUID()
        let label: String
        let minutes: Int
    }

    var estimateVsActualData: [EstimateVsActualEntry] {
        [
            EstimateVsActualEntry(label: "Estimated", minutes: totalEstimatedMinutes),
            EstimateVsActualEntry(label: "Actual", minutes: totalActualMinutes)
        ]
    }

    // MARK: - Plan for Day

    func plan(for date: Date) -> DayPlan? {
        let calendar = Calendar.current
        return weekPlans.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    // MARK: - Static Helpers

    static func mondayOfWeek(containing date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }
}
