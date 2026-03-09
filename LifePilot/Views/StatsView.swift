import SwiftUI
import SwiftData
import Charts

/// Displays streak stats, completion history, and milestone badges for all habits.
struct StatsView: View {

    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    var body: some View {
        NavigationStack {
            List {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No Stats Yet",
                        systemImage: "chart.bar",
                        description: Text("Add habits to start tracking your progress.")
                    )
                } else {
                    // Overall summary
                    overviewSection

                    // Weekly completion chart
                    weeklyChartSection

                    // Per-habit streak details
                    Section("Habit Streaks") {
                        ForEach(habits) { habit in
                            HabitStreakRow(habit: habit)
                        }
                    }

                    // Milestone badges
                    milestonesSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Stats")
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        Section {
            HStack(spacing: 0) {
                StatCard(
                    title: "Active",
                    value: "\(habits.count)",
                    icon: "list.bullet",
                    color: .blue
                )
                StatCard(
                    title: "Best Streak",
                    value: "\(habits.map(\.bestStreak).max() ?? 0)",
                    icon: "flame.fill",
                    color: .orange
                )
                StatCard(
                    title: "Today",
                    value: todayCompletionText,
                    icon: "checkmark.circle",
                    color: .green
                )
            }
        }
    }

    private var todayCompletionText: String {
        let scheduled = habits.filter { $0.isScheduled(for: Date()) }
        let done = scheduled.filter { $0.isCompleted(on: Date()) }
        return "\(done.count)/\(scheduled.count)"
    }

    // MARK: - Weekly Chart

    private var weeklyChartSection: some View {
        Section("Last 7 Days") {
            Chart {
                ForEach(last7Days, id: \.date) { day in
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Completed", day.completed)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
            }
            .chartYAxis {
                AxisMarks(preset: .automatic, position: .leading)
            }
            .frame(height: 160)
            .padding(.vertical, 8)
        }
    }

    /// Completion counts for the last 7 days.
    private var last7Days: [(date: Date, label: String, completed: Int)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"

        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: today)!
            let scheduled = habits.filter { $0.isScheduled(for: date) }
            let completed = scheduled.filter { $0.isCompleted(on: date) }.count
            return (date, formatter.string(from: date), completed)
        }
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        let milestones: [(Int, String, String)] = [
            (7,   "1 Week",    "flame"),
            (14,  "2 Weeks",   "flame.fill"),
            (30,  "1 Month",   "star.fill"),
            (60,  "2 Months",  "star.circle.fill"),
            (100, "100 Days",  "trophy.fill"),
            (365, "1 Year",    "crown.fill"),
        ]

        // Collect all achieved milestones across habits
        let achieved = milestones.filter { milestone in
            habits.contains { $0.bestStreak >= milestone.0 }
        }

        return Group {
            if !achieved.isEmpty {
                Section("Milestones") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                        ForEach(achieved, id: \.0) { milestone in
                            VStack(spacing: 6) {
                                Image(systemName: milestone.2)
                                    .font(.title2)
                                    .foregroundStyle(.yellow.gradient)
                                Text(milestone.1)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
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
}

// MARK: - Habit Streak Row

private struct HabitStreakRow: View {
    let habit: Habit

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: habit.icon)
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Color(hex: habit.colorHex), in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(habit.frequency.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Current and best streaks
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Text("\(habit.currentStreak)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text("best: \(habit.bestStreak)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
