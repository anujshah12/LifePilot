import SwiftUI
import SwiftData

/// Main daily checklist: shows habits scheduled for today with toggle completion.
/// Delegates all business logic to TodayViewModel.
struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var allHabits: [Habit]

    /// ViewModel handles toggle logic, celebration state, and quote fetching.
    @State private var viewModel = TodayViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    // Motivational quote section (API-driven via QuoteService)
                    quoteSection

                    // Progress summary
                    if !viewModel.todaysHabits(from: allHabits).isEmpty {
                        progressSection
                    }

                    // Habit checklist
                    if viewModel.todaysHabits(from: allHabits).isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No Habits Scheduled",
                                systemImage: "calendar.badge.plus",
                                description: Text("Add habits in the Habits tab to get started.")
                            )
                        }
                    } else {
                        Section("Today's Habits") {
                            ForEach(viewModel.todaysHabits(from: allHabits)) { habit in
                                HabitCheckRow(habit: habit) {
                                    // Animation lives in the View; logic lives in the ViewModel
                                    let celebrate = viewModel.toggleHabit(habit, allHabits: allHabits, context: modelContext)
                                    if celebrate {
                                        withAnimation(.spring(response: 0.4)) {
                                            viewModel.showCelebration = true
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Celebration overlay when all habits are done
                if viewModel.showCelebration {
                    CelebrationOverlay()
                        .onAppear {
                            // Auto-dismiss after 2 seconds with animation (View concern)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    viewModel.dismissCelebration()
                                }
                            }
                        }
                }
            }
            .navigationTitle("Today")
            .task {
                await viewModel.loadQuote()
            }
        }
    }

    // MARK: - Quote Section

    private var quoteSection: some View {
        Section {
            if viewModel.quoteService.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if !viewModel.quoteService.quoteText.isEmpty {
                VStack(spacing: 6) {
                    Text(viewModel.quoteService.quoteText)
                        .font(.subheadline)
                        .italic()
                        .multilineTextAlignment(.center)

                    Text("-- \(viewModel.quoteService.quoteAuthor)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        let completed = viewModel.completedCount(from: allHabits)
        let total = viewModel.todaysHabits(from: allHabits).count
        let done = viewModel.allDone(from: allHabits)

        return Section {
            VStack(spacing: 8) {
                ProgressView(value: Double(completed), total: Double(total))
                    .tint(done ? .green : .blue)

                Text("\(completed) of \(total) complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Habit Check Row

/// A single habit row with a tappable checkbox, name, streak badge, and icon.
struct HabitCheckRow: View {
    let habit: Habit
    let onToggle: () -> Void

    private var isDone: Bool {
        habit.isCompleted(on: Date())
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Checkbox icon
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isDone ? Color(hex: habit.colorHex) : .gray)
                    .contentTransition(.symbolEffect(.replace))

                // Habit icon + name
                Image(systemName: habit.icon)
                    .foregroundStyle(Color(hex: habit.colorHex))
                    .frame(width: 24)

                Text(habit.name)
                    .strikethrough(isDone, color: .secondary)
                    .foregroundStyle(isDone ? .secondary : .primary)

                Spacer()

                // Streak badge
                if habit.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(habit.currentStreak)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.orange.opacity(0.12), in: Capsule())
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Celebration Overlay

/// Full-screen animated overlay shown when all habits are completed for the day.
struct CelebrationOverlay: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "party.popper.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.yellow.gradient)
                    .scaleEffect(animate ? 1.2 : 0.5)
                    .rotationEffect(.degrees(animate ? 0 : -20))

                Text("All Done!")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)

                Text("You completed every habit today!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .scaleEffect(animate ? 1 : 0.8)
            .opacity(animate ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                animate = true
            }
        }
        .allowsHitTesting(false)
    }
}
