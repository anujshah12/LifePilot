import SwiftUI
import SwiftData

/// Main daily checklist: shows habits scheduled for today with toggle completion.
/// Displays a motivational quote from the ZenQuotes API at the top.
struct TodayView: View {

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Habit.createdAt) private var allHabits: [Habit]

    // Quote from ZenQuotes API (networking + concurrency requirement)
    private var quoteService = QuoteService.shared

    // Triggers re-evaluation of completion state after toggling
    @State private var refreshTick = 0

    // Celebration state for completing all habits
    @State private var showCelebration = false

    /// Only habits scheduled for today.
    private var todaysHabits: [Habit] {
        allHabits.filter { $0.isScheduled(for: Date()) }
    }

    private var completedCount: Int {
        todaysHabits.filter { $0.isCompleted(on: Date()) }.count
    }

    private var allDone: Bool {
        !todaysHabits.isEmpty && completedCount == todaysHabits.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    // Motivational quote section (API-driven)
                    quoteSection

                    // Progress summary
                    if !todaysHabits.isEmpty {
                        progressSection
                    }

                    // Habit checklist
                    if todaysHabits.isEmpty {
                        Section {
                            ContentUnavailableView(
                                "No Habits Scheduled",
                                systemImage: "calendar.badge.plus",
                                description: Text("Add habits in the Habits tab to get started.")
                            )
                        }
                    } else {
                        Section("Today's Habits") {
                            ForEach(todaysHabits) { habit in
                                HabitCheckRow(habit: habit) {
                                    toggleHabit(habit)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)

                // Celebration overlay when all habits are done
                if showCelebration {
                    CelebrationOverlay()
                        .onAppear {
                            // Auto-dismiss after 2 seconds
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation { showCelebration = false }
                            }
                        }
                }
            }
            .navigationTitle("Today")
            .task {
                await quoteService.fetchDailyQuote()
            }
        }
    }

    // MARK: - Quote Section

    private var quoteSection: some View {
        Section {
            if quoteService.isLoading {
                HStack { Spacer(); ProgressView(); Spacer() }
            } else if !quoteService.quoteText.isEmpty {
                VStack(spacing: 6) {
                    Text(quoteService.quoteText)
                        .font(.subheadline)
                        .italic()
                        .multilineTextAlignment(.center)

                    Text("-- \(quoteService.quoteAuthor)")
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
        Section {
            VStack(spacing: 8) {
                ProgressView(value: Double(completedCount), total: Double(todaysHabits.count))
                    .tint(allDone ? .green : .blue)

                Text("\(completedCount) of \(todaysHabits.count) complete")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Toggle Logic

    private func toggleHabit(_ habit: Habit) {
        let today = Date()

        if habit.isCompleted(on: today) {
            // Uncheck: remove today's completion
            if let completion = habit.completions.first(where: {
                Calendar.current.isDate($0.date, inSameDayAs: today)
            }) {
                modelContext.delete(completion)
                habit.completions.removeAll { $0.id == completion.id }
                SoundManager.shared.playUncheckSound()
            }
        } else {
            // Check: add a completion for today
            let completion = HabitCompletion(date: today)
            completion.habit = habit
            habit.completions.append(completion)
            SoundManager.shared.playCheckSound()

            // Check if all habits are now done
            let nowComplete = todaysHabits.filter { $0.isCompleted(on: today) }.count + 1
            if nowComplete == todaysHabits.count {
                SoundManager.shared.playAllCompleteSound()
                withAnimation(.spring(response: 0.4)) {
                    showCelebration = true
                }
            }
        }

        refreshTick += 1
    }
}

// MARK: - Habit Check Row

/// A single habit row with a tappable checkbox, name, streak badge, and icon.
private struct HabitCheckRow: View {
    let habit: Habit
    let onToggle: () -> Void

    private var isDone: Bool {
        habit.isCompleted(on: Date())
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 14) {
                // Checkbox
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
private struct CelebrationOverlay: View {
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
