import SwiftUI
import SwiftData

/// Sheet for creating a new habit or editing an existing one.
/// Supports name, icon, color, frequency, and custom day selection.
/// All data mutations are routed through HabitListViewModel.
struct HabitEditorSheet: View {

    enum Mode: Identifiable {
        case add
        case edit(Habit)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let h): return h.id.uuidString
            }
        }
    }

    let mode: Mode
    /// ViewModel that handles all CRUD operations as gatekeeper to the Model.
    let viewModel: HabitListViewModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirmation = false
    @State private var name = ""
    @State private var icon = "circle.fill"
    @State private var colorHex = "007AFF"
    @State private var frequency: HabitFrequency = .daily
    @State private var customDays: Set<Int> = []

    // Available icon choices
    private let icons = [
        "figure.run", "book.fill", "drop.fill", "bed.double.fill",
        "fork.knife", "brain.head.profile.fill", "dumbbell.fill", "pencil.and.outline",
        "heart.fill", "leaf.fill", "sun.max.fill", "moon.fill",
        "music.note", "paintbrush.fill", "graduationcap.fill", "circle.fill"
    ]

    // Available color choices
    private let colors = [
        "007AFF", "34C759", "FF3B30", "FF9500",
        "AF52DE", "FF2D55", "5AC8FA", "FFCC00",
        "8E8E93", "30B0C7", "FF6482", "A2845E"
    ]

    // Weekday labels (Sunday=1 through Saturday=7)
    private let weekdays: [(Int, String)] = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
        (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                // Name
                Section("Name") {
                    TextField("e.g. Drink Water", text: $name)
                }

                // Icon picker
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
                        ForEach(icons, id: \.self) { sym in
                            Image(systemName: sym)
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .background(
                                    icon == sym ? Color(hex: colorHex).opacity(0.2) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(icon == sym ? Color(hex: colorHex) : .clear, lineWidth: 2)
                                )
                                .onTapGesture { icon = sym }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Color picker
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(colors, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .font(.caption.bold())
                                        .foregroundStyle(.white)
                                        .opacity(colorHex == hex ? 1 : 0)
                                )
                                .onTapGesture { colorHex = hex }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Frequency
                Section("Frequency") {
                    Picker("Repeat", selection: $frequency) {
                        ForEach(HabitFrequency.allCases) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Custom day selector
                    if frequency == .custom {
                        HStack(spacing: 8) {
                            ForEach(weekdays, id: \.0) { day in
                                let isSelected = customDays.contains(day.0)
                                Text(day.1)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        isSelected ? Color(hex: colorHex) : Color(.systemGray5),
                                        in: Circle()
                                    )
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .onTapGesture {
                                        if isSelected {
                                            customDays.remove(day.0)
                                        } else {
                                            customDays.insert(day.0)
                                        }
                                    }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                    }
                }

                // Delete button (only in edit mode)
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Label("Delete Habit", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadExistingValues() }
            .confirmationDialog("Delete Habit", isPresented: $showDeleteConfirmation) {
                Button("Delete", role: .destructive) {
                    if case .edit(let habit) = mode {
                        // Route deletion through the ViewModel
                        viewModel.deleteHabit(habit, context: modelContext)
                    }
                    dismiss()
                }
            } message: {
                Text("Are you sure? This will permanently delete this habit and all its completion history.")
            }
        }
    }

    // MARK: - Data

    private func loadExistingValues() {
        if case .edit(let habit) = mode {
            name = habit.name
            icon = habit.icon
            colorHex = habit.colorHex
            frequency = habit.frequency
            customDays = Set(habit.customDays)
        }
    }

    /// Saves the habit by routing through the ViewModel (gatekeeper pattern).
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        switch mode {
        case .add:
            viewModel.addHabit(
                name: trimmed, icon: icon, colorHex: colorHex,
                frequency: frequency, customDays: Array(customDays).sorted(),
                context: modelContext
            )
        case .edit(let habit):
            viewModel.updateHabit(
                habit, name: trimmed, icon: icon, colorHex: colorHex,
                frequency: frequency, customDays: Array(customDays).sorted()
            )
        }

        dismiss()
    }
}
