import Foundation
import SwiftData
import Combine
import Observation

@Observable
final class DayViewModel {

    // MARK: - Day State Enum

    enum DayState {
        case notPlanned
        case planned
        case active
        case completed
    }

    // MARK: - Published Properties

    /// The current day plan (nil when no plan exists for today).
    var dayPlan: DayPlan?

    /// Live-updating elapsed time since the day was started.
    var dayElapsedString: String = "0:00"

    /// Live-updating elapsed time for the current active task.
    var currentTaskElapsedString: String = "0:00"

    /// Tick counter that increments every second to drive SwiftUI redraws.
    var tick: Int = 0

    // MARK: - Private

    private var timerCancellable: AnyCancellable?

    // MARK: - Init / Deinit

    init() {}

    deinit {
        stopTimer()
    }

    // MARK: - Computed — State

    var state: DayState {
        guard let plan = dayPlan else {
            return .notPlanned
        }
        if plan.isEnded || plan.allTasksComplete {
            return .completed
        }
        if plan.isActive {
            return .active
        }
        // Plan exists, has tasks, but hasn't started yet.
        if !plan.tasks.isEmpty {
            return .planned
        }
        // Plan exists but has no tasks — treat as not planned.
        return .notPlanned
    }

    // MARK: - Computed — Progress

    var completedCount: Int {
        dayPlan?.completedTaskCount ?? 0
    }

    var totalCount: Int {
        dayPlan?.tasks.count ?? 0
    }

    var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var sortedTasks: [DayTask] {
        dayPlan?.sortedTasks ?? []
    }

    var currentTask: DayTask? {
        dayPlan?.currentTask
    }

    var totalEstimatedMinutes: Int {
        dayPlan?.totalEstimatedMinutes ?? 0
    }

    var totalActualMinutes: Int {
        dayPlan?.totalActualMinutes ?? 0
    }

    // MARK: - Data Loading

    /// Fetches today's DayPlan from the model context, or returns nil if none exists.
    func fetchTodayPlan(context: ModelContext) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())

        let descriptor = FetchDescriptor<DayPlan>(
            predicate: #Predicate<DayPlan> { plan in
                plan.date >= startOfToday
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let plans = try context.fetch(descriptor)
            // Find the plan whose date matches today exactly.
            dayPlan = plans.first { calendar.isDate($0.date, inSameDayAs: startOfToday) }
        } catch {
            dayPlan = nil
        }

        // Start the timer if we have an active day.
        if state == .active {
            startTimer()
        }
        updateElapsedStrings()
    }

    /// Creates a new empty DayPlan for today and inserts it into the context.
    @discardableResult
    func createTodayPlan(context: ModelContext) -> DayPlan {
        let plan = DayPlan(date: Date())
        context.insert(plan)
        dayPlan = plan
        return plan
    }

    // MARK: - Actions

    /// Starts the day: stamps the start time, activates the first task, begins the timer.
    func startDay() {
        guard let plan = dayPlan, !plan.isStarted else { return }
        plan.startDay()
        startTimer()
        updateElapsedStrings()
    }

    /// Completes the current task and auto-starts the next one.
    func completeCurrentTask() {
        guard let plan = dayPlan else { return }
        plan.completeCurrentTask()
        updateElapsedStrings()

        // If all tasks are now done, the plan ended itself — stop the timer and sounds.
        if plan.isEnded {
            stopTimer()
            FocusSoundManager.shared.stopAmbientSound()
            FocusSoundManager.shared.playDayCompleteSound()
        }
    }

    /// Ends the day early before all tasks are finished.
    func endDayEarly() {
        guard let plan = dayPlan, plan.isActive else { return }

        // Mark the currently active task as completed so it records its time.
        if let current = plan.currentTask, current.isActive {
            current.markCompleted()
        }

        plan.endDay()
        stopTimer()
        updateElapsedStrings()
    }

    /// Adds a task to the current day plan.
    func addTask(title: String, description: String = "", estimatedMinutes: Int = 15, context: ModelContext) {
        let plan: DayPlan
        if let existing = dayPlan {
            plan = existing
        } else {
            plan = createTodayPlan(context: context)
        }

        let order = plan.tasks.count
        let task = DayTask(
            title: title,
            taskDescription: description,
            estimatedMinutes: estimatedMinutes,
            order: order
        )
        task.dayPlan = plan
        plan.tasks.append(task)
    }

    /// Removes a task from the day plan.
    func removeTask(_ task: DayTask, context: ModelContext) {
        guard let plan = dayPlan else { return }
        plan.tasks.removeAll { $0.id == task.id }
        context.delete(task)

        // Reorder remaining tasks.
        for (index, t) in plan.sortedTasks.enumerated() {
            t.order = index
        }
    }

    /// Moves tasks within the plan (for reordering support).
    func moveTasks(from source: IndexSet, to destination: Int) {
        guard let plan = dayPlan else { return }
        var ordered = plan.sortedTasks
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, task) in ordered.enumerated() {
            task.order = index
        }
    }

    /// Loads tasks from a template into today's plan.
    func applyTemplate(_ template: Template, context: ModelContext) {
        let plan: DayPlan
        if let existing = dayPlan {
            plan = existing
        } else {
            plan = createTodayPlan(context: context)
        }

        // Clear existing tasks if any.
        for task in plan.tasks {
            context.delete(task)
        }
        plan.tasks.removeAll()

        // Convert template tasks into day tasks.
        for templateTask in template.sortedTasks {
            let dayTask = templateTask.toDayTask()
            dayTask.dayPlan = plan
            plan.tasks.append(dayTask)
        }
    }

    // MARK: - Task State Helper

    func taskState(for task: DayTask) -> TaskDisplayState {
        if task.isComplete {
            return .completed
        } else if task.id == currentTask?.id {
            return .current
        } else {
            return .locked
        }
    }

    enum TaskDisplayState {
        case completed
        case current
        case locked
    }

    // MARK: - Timer

    private func startTimer() {
        // Avoid duplicate timers.
        guard timerCancellable == nil else { return }

        timerCancellable = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick += 1
                self?.updateElapsedStrings()
            }
    }

    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
    }

    private func updateElapsedStrings() {
        // Day elapsed.
        if let start = dayPlan?.startedAt {
            let end = dayPlan?.endedAt ?? Date()
            dayElapsedString = TimeFormatter.elapsedString(from: start, to: end)
        } else {
            dayElapsedString = "0:00"
        }

        // Current task elapsed.
        if let task = currentTask, let start = task.startedAt {
            currentTaskElapsedString = TimeFormatter.elapsedString(from: start)
        } else {
            currentTaskElapsedString = "0:00"
        }
    }
}
