import SwiftUI
import SwiftData

struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = DayViewModel()

    // Motivational quote from API
    private var quoteService = QuoteService.shared

    // Focus sound manager for ambient audio
    private var soundManager = FocusSoundManager.shared

    // Navigation & sheet state
    @State private var showTemplateSelection = false
    @State private var showEndDayConfirmation = false
    @State private var showSoundPicker = false

    // Inline task editor state
    @State private var isAddingTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskEstimate = 15

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.state {
                case .notPlanned:
                    notPlannedView
                case .planned:
                    plannedView
                case .active:
                    activeView
                case .completed:
                    completedView
                }
            }
            .navigationTitle("Today")
            .onAppear {
                viewModel.fetchTodayPlan(context: modelContext)
            }
            .task {
                // Fetch a motivational quote from the API on launch.
                await quoteService.fetchDailyQuote()
            }
            .sheet(isPresented: $showTemplateSelection) {
                TemplateSelectionSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - STATE 1: No Plan Yet

    private var notPlannedView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "sunrise.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange.gradient)
                .symbolEffect(.pulse, options: .repeating)

            VStack(spacing: 8) {
                Text("No plan for today yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Start by choosing a template or building your plan from scratch.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            VStack(spacing: 14) {
                Button {
                    showTemplateSelection = true
                } label: {
                    Label("Choose a Template", systemImage: "doc.on.doc")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                Button {
                    createPlanAndStartAdding()
                } label: {
                    Label("Build from Scratch", systemImage: "plus.square.dashed")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 32)

            // Daily motivational quote fetched from ZenQuotes API
            quoteCard

            Spacer()
        }
    }

    // MARK: - STATE 2: Plan Ready

    private var plannedView: some View {
        VStack(spacing: 0) {
            // Header summary
            planSummaryHeader

            // Task list preview
            List {
                Section {
                    ForEach(viewModel.sortedTasks) { task in
                        taskPreviewRow(task)
                    }
                    .onMove { from, to in
                        viewModel.moveTasks(from: from, to: to)
                    }
                    .onDelete { offsets in
                        let tasks = viewModel.sortedTasks
                        for index in offsets {
                            viewModel.removeTask(tasks[index], context: modelContext)
                        }
                    }
                } header: {
                    Text("Your Plan")
                        .textCase(nil)
                        .font(.headline)
                }

                // Inline add task
                Section {
                    if isAddingTask {
                        inlineTaskEditor
                    } else {
                        Button {
                            withAnimation {
                                isAddingTask = true
                            }
                        } label: {
                            Label("Add a Task", systemImage: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)

            // Start My Day button
            startMyDayButton
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    private var planSummaryHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .foregroundStyle(.blue)
                Text("\(viewModel.totalCount) tasks")
                    .fontWeight(.medium)

                Text("  ~\(TimeFormatter.minutesToDisplay(viewModel.totalEstimatedMinutes))")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    private func taskPreviewRow(_ task: DayTask) -> some View {
        HStack(spacing: 12) {
            if let category = task.category {
                Circle()
                    .fill(category.color)
                    .frame(width: 10, height: 10)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.body)
                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(TimeFormatter.minutesToDisplay(task.estimatedMinutes))
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
        .padding(.vertical, 2)
    }

    private var inlineTaskEditor: some View {
        VStack(spacing: 12) {
            TextField("Task name", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)

            Stepper("Estimated: \(newTaskEstimate) min", value: $newTaskEstimate, in: 5...240, step: 5)
                .font(.subheadline)

            HStack {
                Button("Cancel") {
                    withAnimation {
                        newTaskTitle = ""
                        newTaskEstimate = 15
                        isAddingTask = false
                    }
                }
                .foregroundStyle(.secondary)

                Spacer()

                Button("Add") {
                    guard !newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    viewModel.addTask(
                        title: newTaskTitle.trimmingCharacters(in: .whitespaces),
                        estimatedMinutes: newTaskEstimate,
                        context: modelContext
                    )
                    newTaskTitle = ""
                    newTaskEstimate = 15
                    // Keep editor open for rapid entry.
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private var startMyDayButton: some View {
        Button {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                viewModel.startDay()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "play.fill")
                    .font(.title3)
                Text("Start My Day")
                    .font(.title3)
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.bar)
    }

    // MARK: - STATE 3: Day In Progress

    private var activeView: some View {
        VStack(spacing: 0) {
            // Live timer header
            activeHeader

            // Task list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.sortedTasks) { task in
                        activeTaskRow(task)
                        if task.id != viewModel.sortedTasks.last?.id {
                            Divider()
                                .padding(.leading, 56)
                        }
                    }
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 0)

            // End Day Early button
            Button(role: .destructive) {
                showEndDayConfirmation = true
            } label: {
                Label("End Day Early", systemImage: "stop.circle")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.bottom, 16)
            .alert("End Day Early?", isPresented: $showEndDayConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("End Day", role: .destructive) {
                    withAnimation {
                        viewModel.endDayEarly()
                    }
                    // Stop ambient focus sounds when the day ends
                    soundManager.stopAmbientSound()
                }
            } message: {
                Text("This will stop tracking and mark the day as complete. Remaining tasks will not be started.")
            }
        }
    }

    private var activeHeader: some View {
        VStack(spacing: 12) {
            // Day elapsed timer
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundStyle(.blue)
                Text(viewModel.dayElapsedString)
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.semibold)
                    .contentTransition(.numericText())

                Spacer()

                // Focus sound toggle — plays ambient audio during task sessions
                focusSoundButton
            }

            // Progress bar
            VStack(spacing: 6) {
                ProgressView(value: viewModel.progressFraction)
                    .tint(.blue)

                Text("\(viewModel.completedCount) of \(viewModel.totalCount) tasks complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func activeTaskRow(_ task: DayTask) -> some View {
        let taskState = viewModel.taskState(for: task)

        HStack(spacing: 14) {
            // Status icon
            statusIcon(for: taskState)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.body)
                    .fontWeight(taskState == .current ? .semibold : .regular)
                    .foregroundStyle(taskState == .locked ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let category = task.category {
                        Text(category.name)
                            .font(.caption2)
                            .foregroundStyle(category.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(category.color.opacity(0.12), in: Capsule())
                    }

                    if taskState == .current {
                        Text(viewModel.currentTaskElapsedString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.blue)
                    } else if taskState == .completed, let actual = task.actualMinutes {
                        Text(TimeFormatter.minutesToDisplay(actual))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("~\(TimeFormatter.minutesToDisplay(task.estimatedMinutes))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            // Complete button for current task
            if taskState == .current {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        viewModel.completeCurrentTask()
                    }
                    // Play a chime on task completion (media playback)
                    soundManager.playCompletionSound()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(taskState == .current ? Color.blue.opacity(0.06) : Color.clear)
    }

    @ViewBuilder
    private func statusIcon(for state: DayViewModel.TaskDisplayState) -> some View {
        switch state {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)
        case .current:
            Image(systemName: "play.circle.fill")
                .font(.title3)
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, options: .repeating)
        case .locked:
            Image(systemName: "lock.circle")
                .font(.title3)
                .foregroundStyle(.quaternary)
        }
    }

    // MARK: - STATE 4: Day Complete

    private var completedView: some View {
        ScrollView {
            VStack(spacing: 28) {
                // Congratulations
                VStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.yellow.gradient)

                    Text("Day Complete!")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Great work today. Here is your summary.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 24)

                // Motivational quote from API
                quoteCard

                // Summary stats
                summaryStatsCard

                // Task breakdown
                completedTasksList

                // Plan Tomorrow
                Button {
                    // Reset for tomorrow: clear the view model so state becomes .notPlanned
                    // The user can plan tomorrow when tomorrow comes.
                } label: {
                    Label("Plan Tomorrow", systemImage: "calendar.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private var summaryStatsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                statTile(
                    title: "Total Time",
                    value: viewModel.dayElapsedString,
                    icon: "clock.fill",
                    color: .blue
                )

                Divider()
                    .frame(height: 44)

                statTile(
                    title: "Tasks Done",
                    value: "\(viewModel.completedCount)/\(viewModel.totalCount)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
            }

            Divider()

            HStack(spacing: 0) {
                statTile(
                    title: "Estimated",
                    value: TimeFormatter.minutesToDisplay(viewModel.totalEstimatedMinutes),
                    icon: "gauge.with.needle",
                    color: .orange
                )

                Divider()
                    .frame(height: 44)

                statTile(
                    title: "Actual",
                    value: TimeFormatter.minutesToDisplay(viewModel.totalActualMinutes),
                    icon: "stopwatch.fill",
                    color: timeDeltaColor
                )
            }
        }
        .padding(.vertical, 16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 24)
    }

    private var timeDeltaColor: Color {
        let estimated = viewModel.totalEstimatedMinutes
        let actual = viewModel.totalActualMinutes
        guard estimated > 0 else { return .secondary }
        if actual <= estimated {
            return .green
        } else {
            return .red
        }
    }

    private func statTile(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var completedTasksList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Task Breakdown")
                .font(.headline)
                .padding(.horizontal, 24)

            VStack(spacing: 0) {
                ForEach(viewModel.sortedTasks) { task in
                    HStack(spacing: 12) {
                        Image(systemName: task.isComplete ? "checkmark.circle.fill" : "minus.circle")
                            .foregroundStyle(task.isComplete ? .green : .secondary)
                            .font(.body)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.body)
                                .strikethrough(!task.isComplete, color: .secondary)
                                .foregroundStyle(task.isComplete ? .primary : .secondary)

                            if let category = task.category {
                                Text(category.name)
                                    .font(.caption2)
                                    .foregroundStyle(category.color)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            if let actual = task.actualMinutes {
                                Text(TimeFormatter.minutesToDisplay(actual))
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }

                            let est = task.estimatedMinutes
                            Text("est. \(TimeFormatter.minutesToDisplay(est))")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)

                    if task.id != viewModel.sortedTasks.last?.id {
                        Divider()
                            .padding(.leading, 48)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Quote Card (API-driven content)

    private var quoteCard: some View {
        Group {
            if quoteService.isLoading {
                ProgressView()
                    .padding()
            } else if !quoteService.quoteText.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "quote.opening")
                        .font(.title3)
                        .foregroundStyle(.blue.opacity(0.6))

                    Text(quoteService.quoteText)
                        .font(.subheadline)
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)

                    Text("— \(quoteService.quoteAuthor)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Refresh button to fetch a new quote from the API
                    Button {
                        Task { await quoteService.refreshQuote() }
                    } label: {
                        Label("New Quote", systemImage: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Focus Sound Picker

    private var focusSoundButton: some View {
        Button {
            showSoundPicker = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: soundManager.isPlaying ? "speaker.wave.2.fill" : "speaker.slash")
                    .font(.caption)
                Text(soundManager.isPlaying ? soundManager.selectedSound.rawValue : "Focus Sound")
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSoundPicker) {
            FocusSoundPickerSheet()
                .presentationDetents([.medium])
        }
    }

    // MARK: - Helpers

    private func createPlanAndStartAdding() {
        viewModel.createTodayPlan(context: modelContext)
        withAnimation {
            isAddingTask = true
        }
    }
}

// MARK: - Template Selection Sheet

private struct TemplateSelectionSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Template.updatedAt, order: .reverse) private var templates: [Template]

    let viewModel: DayViewModel

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView(
                        "No Templates",
                        systemImage: "doc.on.doc",
                        description: Text("Create a template first from the Templates tab.")
                    )
                } else {
                    List(templates) { template in
                        Button {
                            viewModel.applyTemplate(template, context: modelContext)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    let taskCount = template.tasks.count
                                    let totalMin = template.sortedTasks.reduce(0) { $0 + $1.estimatedMinutes }
                                    Text("\(taskCount) tasks  ~\(TimeFormatter.minutesToDisplay(totalMin))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Choose a Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Not Planned") {
    TodayView()
        .modelContainer(for: [DayPlan.self, DayTask.self, Template.self, TemplateTask.self, TaskCategory.self], inMemory: true)
}

#Preview("Planned") {
    let container = try! ModelContainer(for: DayPlan.self, DayTask.self, Template.self, TemplateTask.self, TaskCategory.self, configurations: .init(isStoredInMemoryOnly: true))
    let context = container.mainContext

    let plan = DayPlan(date: Date())
    context.insert(plan)

    let tasks = ["Morning review", "Deep work block", "Email triage", "Lunch break", "Afternoon sprint"]
    for (i, title) in tasks.enumerated() {
        let task = DayTask(title: title, estimatedMinutes: [10, 90, 20, 30, 60][i], order: i)
        task.dayPlan = plan
        plan.tasks.append(task)
    }

    return TodayView()
        .modelContainer(container)
}
