import SwiftUI
import SwiftData

struct CategoryManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskCategory.createdAt) private var categories: [TaskCategory]

    /// When `true`, the view shows a Done button to dismiss itself (for sheet presentation).
    var presentedAsSheet: Bool = false

    @State private var showingAddSheet = false
    @State private var categoryToEdit: TaskCategory?
    @State private var categoryToDelete: TaskCategory?
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Group {
                if categories.isEmpty {
                    emptyState
                } else {
                    categoryList
                }
            }
            .navigationTitle("Categories")
            .toolbar {
                if presentedAsSheet {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CategoryFormSheet(mode: .add) { name, colorHex in
                    addCategory(name: name, colorHex: colorHex)
                }
            }
            .sheet(item: $categoryToEdit) { category in
                CategoryFormSheet(
                    mode: .edit(name: category.name, colorHex: category.colorHex)
                ) { name, colorHex in
                    updateCategory(category, name: name, colorHex: colorHex)
                }
            }
            .alert("Delete Category?", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if let category = categoryToDelete {
                        deleteCategory(category)
                    }
                }
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
            } message: {
                if let category = categoryToDelete {
                    let taskCount = category.dayTasks.count + category.templateTasks.count
                    if taskCount > 0 {
                        Text("This category is used by \(taskCount) task\(taskCount == 1 ? "" : "s"). Deleting it will remove the category from those tasks.")
                    } else {
                        Text("Are you sure you want to delete \"\(category.name)\"?")
                    }
                }
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Categories", systemImage: "tag")
        } description: {
            Text("Add categories to organize your tasks by type.")
        } actions: {
            Button("Add Category") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var categoryList: some View {
        List {
            ForEach(categories) { category in
                CategoryRow(category: category)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        categoryToEdit = category
                    }
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    categoryToDelete = categories[index]
                    showDeleteConfirmation = true
                }
            }
        }
    }

    // MARK: - Actions

    private func addCategory(name: String, colorHex: String) {
        let category = TaskCategory(name: name, colorHex: colorHex)
        modelContext.insert(category)
    }

    private func updateCategory(_ category: TaskCategory, name: String, colorHex: String) {
        category.name = name
        category.colorHex = colorHex
    }

    private func deleteCategory(_ category: TaskCategory) {
        // Clear category references on associated tasks before deletion
        for task in category.dayTasks {
            task.category = nil
        }
        for task in category.templateTasks {
            task.category = nil
        }
        modelContext.delete(category)
        categoryToDelete = nil
    }
}

// MARK: - Category Row

private struct CategoryRow: View {
    let category: TaskCategory

    private var taskCount: Int {
        category.dayTasks.count + category.templateTasks.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(category.color)
                .frame(width: 28, height: 28)

            Text(category.name)
                .font(.body)

            Spacer()

            Text("\(taskCount) task\(taskCount == 1 ? "" : "s")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add / Edit Form

private struct CategoryFormSheet: View {
    enum Mode: Identifiable {
        case add
        case edit(name: String, colorHex: String)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let name, _): return "edit-\(name)"
            }
        }
    }

    let mode: Mode
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var selectedColorHex: String = ColorPickerGrid.presetColors[0]
    @FocusState private var nameFieldFocused: Bool

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var title: String {
        isEditing ? "Edit Category" : "New Category"
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Category name", text: $name)
                        .focused($nameFieldFocused)
                        .autocorrectionDisabled()
                }

                Section("Color") {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(hex: selectedColorHex))
                            .frame(width: 36, height: 36)
                        Text(name.isEmpty ? "Preview" : name)
                            .font(.headline)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden, edges: .bottom)

                    ColorPickerGrid(selectedColorHex: $selectedColorHex)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(trimmedName, selectedColorHex)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onAppear {
                if case .edit(let existingName, let existingColor) = mode {
                    name = existingName
                    selectedColorHex = existingColor
                }
                nameFieldFocused = true
            }
        }
    }
}

#Preview("With Categories") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TaskCategory.self, DayTask.self, TemplateTask.self,
        configurations: config
    )

    let sampleCategories = [
        TaskCategory(name: "Work", colorHex: "#007AFF"),
        TaskCategory(name: "Health", colorHex: "#34C759"),
        TaskCategory(name: "Personal", colorHex: "#FF9500")
    ]
    for category in sampleCategories {
        container.mainContext.insert(category)
    }

    return CategoryManagerView()
        .modelContainer(container)
}

#Preview("Empty State") {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TaskCategory.self, DayTask.self, TemplateTask.self,
        configurations: config
    )

    return CategoryManagerView()
        .modelContainer(container)
}
