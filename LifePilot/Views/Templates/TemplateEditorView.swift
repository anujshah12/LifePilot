import SwiftUI
import SwiftData

struct TemplateEditorView: View {

    @Environment(\.modelContext) private var modelContext
    @Bindable var template: Template
    var viewModel: TemplateViewModel

    @Query(sort: \TaskCategory.name) private var categories: [TaskCategory]

    @State private var showAddTaskSheet = false
    @State private var showValidationAlert = false

    var body: some View {
        List {
            templateInfoSection
            tasksSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Edit Template")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                showAddTaskSheet = true
            } label: {
                Label("Add Task", systemImage: "plus.circle.fill")
                    .font(.headline)
            }
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showAddTaskSheet) {
            AddTaskSheet(
                template: template,
                viewModel: viewModel,
                categories: categories
            )
        }
        .alert("Validation Error", isPresented: $showValidationAlert) {
            Button("OK", role: .cancel) {
                viewModel.validationError = nil
            }
        } message: {
            Text(viewModel.validationError ?? "")
        }
    }

    // MARK: - Sections

    private var templateInfoSection: some View {
        Section {
            HStack {
                Text("Name")
                    .foregroundStyle(.secondary)
                TextField("Template Name", text: $template.name)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Template")
        } footer: {
            HStack(spacing: 16) {
                Label(
                    "\(template.tasks.count) task\(template.tasks.count == 1 ? "" : "s")",
                    systemImage: "checklist"
                )
                Label(
                    TimeFormatter.minutesToDisplay(
                        viewModel.totalEstimatedMinutes(for: template)
                    ),
                    systemImage: "clock"
                )
            }
            .font(.caption)
        }
    }

    private var tasksSection: some View {
        Section {
            if template.tasks.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("No tasks yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("Tap the + button below to add tasks.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            } else {
                ForEach(template.sortedTasks) { task in
                    TaskRowView(task: task, categories: categories)
                }
                .onDelete(perform: deleteTasks)
                .onMove(perform: moveTasks)
            }
        } header: {
            Text("Tasks")
        }
    }

    // MARK: - Actions

    private func deleteTasks(at offsets: IndexSet) {
        let sorted = template.sortedTasks
        for index in offsets {
            viewModel.removeTaskFromTemplate(
                sorted[index],
                template: template,
                context: modelContext
            )
        }
    }

    private func moveTasks(from source: IndexSet, to destination: Int) {
        viewModel.reorderTasks(in: template, from: source, to: destination)
    }
}

// MARK: - Task Row

private struct TaskRowView: View {

    @Bindable var task: TemplateTask
    let categories: [TaskCategory]

    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            taskDetailFields
        } label: {
            taskLabel
        }
    }

    private var taskLabel: some View {
        HStack(spacing: 10) {
            // Order badge
            Text("\(task.order + 1)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(
                    task.category?.color ?? .accentColor,
                    in: Circle()
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

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
                .padding(.vertical, 3)
                .background(.fill.tertiary, in: Capsule())
        }
    }

    private var taskDetailFields: some View {
        Group {
            TextField("Title", text: $task.title)
                .font(.subheadline)

            TextField("Description", text: $task.taskDescription, axis: .vertical)
                .font(.subheadline)
                .lineLimit(2...4)

            Stepper(
                "Estimated: \(TimeFormatter.minutesToDisplay(task.estimatedMinutes))",
                value: $task.estimatedMinutes,
                in: 1...480,
                step: 5
            )
            .font(.subheadline)

            Picker("Category", selection: $task.category) {
                Text("None")
                    .tag(TaskCategory?.none)
                ForEach(categories) { cat in
                    HStack {
                        Circle()
                            .fill(cat.color)
                            .frame(width: 10, height: 10)
                        Text(cat.name)
                    }
                    .tag(TaskCategory?.some(cat))
                }
            }
            .font(.subheadline)
        }
    }
}

// MARK: - Add Task Sheet

private struct AddTaskSheet: View {

    let template: Template
    let viewModel: TemplateViewModel
    let categories: [TaskCategory]

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var estimatedMinutes = 15
    @State private var selectedCategory: TaskCategory?
    @State private var showValidationError = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)

                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Time Estimate") {
                    Stepper(
                        TimeFormatter.minutesToDisplay(estimatedMinutes),
                        value: $estimatedMinutes,
                        in: 1...480,
                        step: 5
                    )

                    // Quick-select buttons
                    HStack(spacing: 8) {
                        ForEach([5, 15, 30, 45, 60], id: \.self) { mins in
                            Button(TimeFormatter.minutesToDisplay(mins)) {
                                estimatedMinutes = mins
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                            .tint(estimatedMinutes == mins ? .accentColor : .secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 4)
                }

                if !categories.isEmpty {
                    Section("Category") {
                        Picker("Category", selection: $selectedCategory) {
                            Text("None")
                                .tag(TaskCategory?.none)
                            ForEach(categories) { cat in
                                HStack {
                                    Circle()
                                        .fill(cat.color)
                                        .frame(width: 10, height: 10)
                                    Text(cat.name)
                                }
                                .tag(TaskCategory?.some(cat))
                            }
                        }
                        .pickerStyle(.inline)
                        .labelsHidden()
                    }
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTask()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: $showValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.validationError ?? "Could not add task.")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addTask() {
        let result = viewModel.addTaskToTemplate(
            template,
            title: title,
            description: description,
            estimatedMinutes: estimatedMinutes,
            category: selectedCategory
        )
        if result != nil {
            dismiss()
        } else {
            showValidationError = true
        }
    }
}

#Preview {
    NavigationStack {
        TemplateEditorView(
            template: {
                let t = Template(name: "Morning Routine")
                t.tasks = [
                    TemplateTask(title: "Meditate", estimatedMinutes: 10, order: 0),
                    TemplateTask(title: "Exercise", estimatedMinutes: 30, order: 1),
                    TemplateTask(title: "Journal", taskDescription: "Write 3 pages", estimatedMinutes: 20, order: 2)
                ]
                return t
            }(),
            viewModel: TemplateViewModel()
        )
    }
    .modelContainer(for: [
        Template.self,
        TemplateTask.self,
        TaskCategory.self,
        DayPlan.self,
        DayTask.self
    ], inMemory: true)
}
