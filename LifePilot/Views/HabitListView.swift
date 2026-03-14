import SwiftUI
import SwiftData

/// Manages the user's habit collection: add, edit, and delete habits.
/// Delegates data operations to HabitListViewModel.
struct HabitListView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    /// ViewModel handles CRUD operations and sheet state.
    @State private var viewModel = HabitListViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView {
                        Label("No Habits", systemImage: "list.bullet.clipboard")
                    } description: {
                        Text("Tap + to add your first habit.")
                    } actions: {
                        Button("Add Habit") { viewModel.showAddSheet = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(habits) { habit in
                            HabitRow(habit: habit)
                                .contentShape(Rectangle())
                                .onTapGesture { viewModel.habitToEdit = habit }
                        }
                        .onDelete { offsets in
                            viewModel.deleteHabits(at: offsets, from: habits, context: modelContext)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { viewModel.showAddSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddSheet) {
                HabitEditorSheet(mode: .add, viewModel: viewModel)
            }
            .sheet(item: $viewModel.habitToEdit) { habit in
                HabitEditorSheet(mode: .edit(habit), viewModel: viewModel)
            }
        }
    }
}

// MARK: - Habit Row

/// Displays a habit's icon, name, frequency, and current streak in the list.
struct HabitRow: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: habit.icon)
                .font(.title3)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color(hex: habit.colorHex), in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text(habit.frequency.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Streak display
            if habit.currentStreak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("\(habit.currentStreak)")
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}
