import Testing
import Foundation
@testable import LifePilot

/// Tests for the Habit model's core business logic.
///
/// These tests cover the most complex parts of the app:
/// 1. **Scheduling logic** — verifying that habits correctly determine which days they're active
/// 2. **Streak computation** — the trickiest algorithm, walking backward through calendar days
/// 3. **Completion tracking** — ensuring date normalization and lookup work correctly
/// 4. **ViewModel behavior** — verifying StatsViewModel computes correct derived data
///
/// We use Swift Testing's @Test macro for clean, expressive test declarations.
struct HabitTests {

    // MARK: - Scheduling Tests

    /// Tests that a daily habit is scheduled on every day of the week.
    /// This validates the simplest frequency case as a baseline.
    @Test func dailyHabitIsAlwaysScheduled() {
        let habit = Habit(name: "Test", frequency: .daily)
        let cal = Calendar.current

        // Check all 7 days of the current week
        let today = cal.startOfDay(for: Date())
        for offset in 0..<7 {
            let date = cal.date(byAdding: .day, value: offset, to: today)!
            #expect(habit.isScheduled(for: date),
                    "Daily habit should be scheduled on every day")
        }
    }

    /// Tests that a weekday habit is only scheduled Monday–Friday (weekdays 2–6).
    /// Verifies the boundary between weekdays and weekends.
    @Test func weekdayHabitSkipsWeekends() {
        let habit = Habit(name: "Work Out", frequency: .weekdays)
        let cal = Calendar.current

        // Find next Sunday (weekday = 1)
        var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 1 // Sunday
        let sunday = cal.date(from: components)!

        #expect(!habit.isScheduled(for: sunday),
                "Weekday habit should NOT be scheduled on Sunday")

        // Monday (weekday = 2) should be scheduled
        let monday = cal.date(byAdding: .day, value: 1, to: sunday)!
        #expect(habit.isScheduled(for: monday),
                "Weekday habit should be scheduled on Monday")

        // Saturday (weekday = 7) should not be scheduled
        let saturday = cal.date(byAdding: .day, value: 6, to: sunday)!
        #expect(!habit.isScheduled(for: saturday),
                "Weekday habit should NOT be scheduled on Saturday")
    }

    /// Tests that a weekend habit is only scheduled on Saturday and Sunday.
    @Test func weekendHabitOnlySatSun() {
        let habit = Habit(name: "Relax", frequency: .weekends)
        let cal = Calendar.current

        var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 1
        let sunday = cal.date(from: components)!
        let monday = cal.date(byAdding: .day, value: 1, to: sunday)!
        let saturday = cal.date(byAdding: .day, value: 6, to: sunday)!

        #expect(habit.isScheduled(for: sunday),
                "Weekend habit should be scheduled on Sunday")
        #expect(habit.isScheduled(for: saturday),
                "Weekend habit should be scheduled on Saturday")
        #expect(!habit.isScheduled(for: monday),
                "Weekend habit should NOT be scheduled on Monday")
    }

    /// Tests custom frequency with specific days selected (e.g., Mon/Wed/Fri).
    /// Validates that only the chosen weekday numbers match.
    @Test func customDaysMatchSelectedWeekdays() {
        // Select Mon(2), Wed(4), Fri(6)
        let habit = Habit(name: "MWF", frequency: .custom, customDays: [2, 4, 6])
        let cal = Calendar.current

        var components = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 1
        let sunday = cal.date(from: components)!

        // Sunday(1) = not scheduled
        #expect(!habit.isScheduled(for: sunday))

        // Monday(2) = scheduled
        let monday = cal.date(byAdding: .day, value: 1, to: sunday)!
        #expect(habit.isScheduled(for: monday))

        // Tuesday(3) = not scheduled
        let tuesday = cal.date(byAdding: .day, value: 2, to: sunday)!
        #expect(!habit.isScheduled(for: tuesday))

        // Wednesday(4) = scheduled
        let wednesday = cal.date(byAdding: .day, value: 3, to: sunday)!
        #expect(habit.isScheduled(for: wednesday))
    }

    // MARK: - Completion Tests

    /// Tests that adding a completion marks the habit as done for that date.
    /// Also verifies that the date is normalized to start-of-day.
    @Test func completionMarksHabitDone() {
        let habit = Habit(name: "Read")
        let today = Date()

        // Initially not completed
        #expect(!habit.isCompleted(on: today),
                "Habit should not be completed before adding a completion")

        // Add a completion for today
        let completion = HabitCompletion(date: today)
        habit.completions.append(completion)

        #expect(habit.isCompleted(on: today),
                "Habit should be completed after adding a completion")
    }

    /// Tests that completions on different days don't interfere with each other.
    /// A completion yesterday should not mark today as done.
    @Test func completionIsDateSpecific() {
        let habit = Habit(name: "Meditate")
        let cal = Calendar.current
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!

        let completion = HabitCompletion(date: yesterday)
        habit.completions.append(completion)

        #expect(habit.isCompleted(on: yesterday),
                "Habit should be completed on the day the completion was added")
        #expect(!habit.isCompleted(on: Date()),
                "Habit should NOT be completed on a different day")
    }

    // MARK: - Streak Tests

    /// Tests that a new habit with no completions has a streak of zero.
    @Test func newHabitHasZeroStreak() {
        let habit = Habit(name: "New Habit")
        #expect(habit.currentStreak == 0, "A new habit with no completions should have streak 0")
        #expect(habit.bestStreak == 0, "A new habit with no completions should have best streak 0")
    }

    /// Tests streak computation with consecutive daily completions.
    /// This is the core streak algorithm: walk backwards through scheduled days.
    @Test func consecutiveCompletionsBuildStreak() {
        let habit = Habit(name: "Daily")
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Backdate the habit's creation to 5 days ago
        habit.createdAt = cal.date(byAdding: .day, value: -5, to: today)!

        // Add completions for today and the past 2 days (3-day streak)
        for offset in 0..<3 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let completion = HabitCompletion(date: date)
            habit.completions.append(completion)
        }

        #expect(habit.currentStreak == 3,
                "3 consecutive completions ending today should give a streak of 3")
        #expect(habit.bestStreak >= 3,
                "Best streak should be at least 3")
    }

    /// Tests that a broken streak resets the current count but preserves the best.
    /// Verifies that a gap (missed day) breaks the streak correctly.
    @Test func brokenStreakResetsCurrent() {
        let habit = Habit(name: "Exercise")
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        // Backdate creation
        habit.createdAt = cal.date(byAdding: .day, value: -10, to: today)!

        // Build a 4-day streak from day -9 to day -6
        for offset in 6...9 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let completion = HabitCompletion(date: date)
            habit.completions.append(completion)
        }

        // Skip day -5 (gap), then complete days -4 to today (5-day streak)
        for offset in 0...4 {
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let completion = HabitCompletion(date: date)
            habit.completions.append(completion)
        }

        #expect(habit.currentStreak == 5,
                "Current streak should be 5 (the most recent consecutive block)")
        #expect(habit.bestStreak == 5,
                "Best streak should be 5 (the longer of the two blocks)")
    }

    // MARK: - Model Mutation Tests

    /// Tests that markComplete creates a completion and markIncomplete removes it.
    /// These are the Model's own mutation methods that ViewModels call.
    @Test func markCompleteAndIncomplete() {
        let habit = Habit(name: "Test")
        let today = Date()

        // markComplete should add a completion
        habit.markComplete(on: today)
        #expect(habit.isCompleted(on: today),
                "markComplete should mark the habit as done")
        #expect(habit.completions.count == 1)

        // Calling markComplete again should be a no-op (idempotent)
        habit.markComplete(on: today)
        #expect(habit.completions.count == 1,
                "markComplete should not duplicate completions")

        // markIncomplete should remove it and return the removed completion
        let removed = habit.markIncomplete(on: today)
        #expect(removed != nil, "markIncomplete should return the removed completion")
        #expect(!habit.isCompleted(on: today),
                "markIncomplete should unmark the habit")
        #expect(habit.completions.isEmpty)
    }

    /// Tests that the update method sets all editable properties on the Model.
    @Test func updateModifiesProperties() {
        let habit = Habit(name: "Old", icon: "circle.fill", colorHex: "007AFF",
                          frequency: .daily, customDays: [])

        habit.update(name: "New", icon: "star.fill", colorHex: "FF3B30",
                     frequency: .weekdays, customDays: [2, 4])

        #expect(habit.name == "New")
        #expect(habit.icon == "star.fill")
        #expect(habit.colorHex == "FF3B30")
        #expect(habit.frequency == .weekdays)
        #expect(habit.customDays == [2, 4])
    }

    // MARK: - Frequency Helpers

    /// Tests the frequency computed property roundtrips correctly through raw storage.
    @Test func frequencyRoundtrip() {
        let habit = Habit(name: "Test", frequency: .weekdays)
        #expect(habit.frequency == .weekdays)
        #expect(habit.frequencyRaw == "Weekdays")

        habit.frequency = .custom
        #expect(habit.frequencyRaw == "Custom")
    }
}

// MARK: - StatsViewModel Tests

/// Tests for StatsViewModel's computed statistics.
/// These verify that the ViewModel correctly derives display data from the Model.
struct StatsViewModelTests {

    /// Tests that the completion text correctly formats "done/total".
    @Test func todayCompletionTextFormat() {
        let viewModel = StatsViewModel()
        let habit = Habit(name: "Test", frequency: .daily)

        let text = viewModel.todayCompletionText(from: [habit])

        // The habit has no completions, so it should be "0/1"
        #expect(text == "0/1",
                "With 1 daily habit and no completions, text should be '0/1'")
    }

    /// Tests that overall best streak picks the maximum across habits.
    @Test func overallBestStreakPicksMax() {
        let viewModel = StatsViewModel()

        let habit1 = Habit(name: "A")
        let habit2 = Habit(name: "B")

        // Both have no completions
        #expect(viewModel.overallBestStreak(from: [habit1, habit2]) == 0)
    }

    /// Tests that last7Days returns exactly 7 entries.
    @Test func last7DaysReturnsSevenEntries() {
        let viewModel = StatsViewModel()
        let result = viewModel.last7Days(from: [])
        #expect(result.count == 7,
                "last7Days should always return exactly 7 data points")
    }

    /// Tests that milestone definitions are ordered by increasing days.
    @Test func milestoneDefinitionsAreOrdered() {
        let milestones = StatsViewModel.milestoneDefinitions
        for i in 1..<milestones.count {
            #expect(milestones[i].days > milestones[i-1].days,
                    "Milestones should be in ascending order of days")
        }
    }

    /// Tests that achievedMilestones returns empty for habits with no streaks.
    @Test func noMilestonesForNewHabits() {
        let viewModel = StatsViewModel()
        let habit = Habit(name: "New")
        let achieved = viewModel.achievedMilestones(from: [habit])
        #expect(achieved.isEmpty,
                "New habits with no completions should have no milestones")
    }
}
