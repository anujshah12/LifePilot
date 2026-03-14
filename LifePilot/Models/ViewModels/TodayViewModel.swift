import Foundation
import SwiftData

/// ViewModel for TodayView — mediates between the View and Habit model.
/// Handles habit toggling, celebration state, and progress tracking.
/// Pure Swift (no SwiftUI) to maintain separation of concerns.
@Observable
final class TodayViewModel {

    // MARK: - UI State

    /// Controls the celebration overlay when all habits are completed.
    var showCelebration = false

    /// Triggers SwiftUI re-evaluation after toggling a completion.
    var refreshTick = 0

    // MARK: - Dependencies

    private let soundManager: SoundManager
    let quoteService: QuoteService

    init(soundManager: SoundManager = .shared, quoteService: QuoteService = .shared) {
        self.soundManager = soundManager
        self.quoteService = quoteService
    }

    // MARK: - Computed Helpers

    /// Filters all habits to only those scheduled for today.
    func todaysHabits(from allHabits: [Habit]) -> [Habit] {
        allHabits.filter { $0.isScheduled(for: Date()) }
    }

    /// Number of today's habits that have been completed.
    func completedCount(from allHabits: [Habit]) -> Int {
        todaysHabits(from: allHabits).filter { $0.isCompleted(on: Date()) }.count
    }

    /// Whether every scheduled habit for today is done.
    func allDone(from allHabits: [Habit]) -> Bool {
        let todays = todaysHabits(from: allHabits)
        return !todays.isEmpty && completedCount(from: allHabits) == todays.count
    }

    // MARK: - Actions

    /// Toggles a habit's completion for today using the Model's own mutation methods.
    /// Returns whether a celebration should be triggered (all habits now done).
    func toggleHabit(_ habit: Habit, allHabits: [Habit], context: ModelContext) -> Bool {
        let today = Date()

        if habit.isCompleted(on: today) {
            // Delegate unchecking to the Model, then clean up the context
            if let removed = habit.markIncomplete(on: today) {
                context.delete(removed)
            }
            soundManager.playUncheckSound()
            refreshTick += 1
            return false
        } else {
            // Delegate checking to the Model
            habit.markComplete(on: today)
            soundManager.playCheckSound()

            // Check if this was the last habit to complete
            let todays = todaysHabits(from: allHabits)
            let nowComplete = todays.filter { $0.isCompleted(on: today) }.count
            let shouldCelebrate = nowComplete == todays.count

            if shouldCelebrate {
                soundManager.playAllCompleteSound()
                showCelebration = true
            }

            refreshTick += 1
            return shouldCelebrate
        }
    }

    /// Fetches the daily motivational quote from the API.
    @MainActor
    func loadQuote() async {
        await quoteService.fetchDailyQuote()
    }

    /// Dismisses the celebration overlay.
    func dismissCelebration() {
        showCelebration = false
    }
}
