import SwiftUI
import SwiftData

struct TaskListView: View {

    @State private var viewModel: TaskListViewModel

    init(dayPlan: DayPlan) {
        _viewModel = State(initialValue: TaskListViewModel(dayPlan: dayPlan))
    }

    var body: some View {
        VStack(spacing: 0) {
            progressHeader
            taskList
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(viewModel.completedCount) of \(viewModel.totalCount) tasks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(viewModel.progressPercent)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }

            ProgressView(value: viewModel.progressFraction)
                .tint(progressTint)
                .animation(.easeInOut(duration: 0.35), value: viewModel.progressFraction)

            if viewModel.allTasksComplete {
                Label("All tasks complete!", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.green)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding()
        .background(.regularMaterial)
    }

    private var progressTint: Color {
        switch viewModel.progressFraction {
        case 0..<0.33: return .orange
        case 0.33..<0.66: return .yellow
        default: return .green
        }
    }

    // MARK: - Task List

    private var taskList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.sortedTasks, id: \.id) { task in
                        taskRow(for: task)
                            .id(task.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.currentTask?.id) { _, newID in
                guard let newID else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newID, anchor: .center)
                }
            }
        }
    }

    // MARK: - Task Row Dispatch

    @ViewBuilder
    private func taskRow(for task: DayTask) -> some View {
        switch viewModel.state(for: task) {
        case .completed:
            CompletedTaskRow(task: task)
        case .current:
            CurrentTaskRow(task: task, elapsed: viewModel.currentTaskElapsed) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    viewModel.completeCurrentTask()
                }
            }
        case .locked:
            LockedTaskRow(task: task)
        }
    }
}

// MARK: - Current Task Row

private struct CurrentTaskRow: View {
    let task: DayTask
    let elapsed: String
    let onComplete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating)

                categoryDot(for: task)

                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(.white)

                    if !task.taskDescription.isEmpty {
                        Text(task.taskDescription)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                }

                Spacer()
            }

            // Time info
            HStack {
                Label(elapsed, systemImage: "timer")
                    .font(.system(.title3, design: .monospaced).weight(.medium))
                    .foregroundStyle(.white)

                Spacer()

                Text("Est. \(TimeFormatter.minutesToDisplay(task.estimatedMinutes))")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }

            // Complete button
            Button(action: onComplete) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(.white)
                .foregroundStyle(.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [.indigo, .indigo.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .shadow(color: .indigo.opacity(0.35), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Completed Task Row

private struct CompletedTaskRow: View {
    let task: DayTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)

            categoryDot(for: task)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough()
                    .foregroundStyle(.secondary)

                if let actual = task.actualMinutes {
                    Text("\(TimeFormatter.minutesToDisplay(actual)) (est. \(TimeFormatter.minutesToDisplay(task.estimatedMinutes)))")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .opacity(0.75)
    }
}

// MARK: - Locked Task Row

private struct LockedTaskRow: View {
    let task: DayTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(.quaternary)

            categoryDot(for: task)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Text("Est. \(TimeFormatter.minutesToDisplay(task.estimatedMinutes))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .opacity(0.6)
    }
}

// MARK: - Shared Helpers

@ViewBuilder
private func categoryDot(for task: DayTask) -> some View {
    if let category = task.category {
        Circle()
            .fill(category.color)
            .frame(width: 8, height: 8)
    }
}

// MARK: - Preview

#Preview("Task List — In Progress") {
    let plan = DayPlan()
    let t1 = DayTask(title: "Morning meditation", taskDescription: "10 min guided session", estimatedMinutes: 10, order: 0)
    let t2 = DayTask(title: "Code review", taskDescription: "Review open PRs", estimatedMinutes: 30, order: 1)
    let t3 = DayTask(title: "Workout", estimatedMinutes: 45, order: 2)
    let t4 = DayTask(title: "Read", estimatedMinutes: 20, order: 3)
    plan.tasks = [t1, t2, t3, t4]

    // Simulate: first task done, second is current
    t1.markStarted()
    t1.markCompleted()
    t2.markStarted()

    return TaskListView(dayPlan: plan)
}
