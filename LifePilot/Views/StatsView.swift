import SwiftUI
import SwiftData
import Charts

/// Displays streak stats, completion history, and milestone badges for all habits.
/// Delegates computation to StatsViewModel.
struct StatsView: View {

    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    /// ViewModel computes stats, chart data, and milestones.
    @State private var viewModel = StatsViewModel()

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
                    // Overall summary cards
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
                    value: "\(viewModel.overallBestStreak(from: habits))",
                    icon: "flame.fill",
                    color: .orange
                )
                StatCard(
                    title: "Today",
                    value: viewModel.todayCompletionText(from: habits),
                    icon: "checkmark.circle",
                    color: .green
                )
            }
        }
    }

    // MARK: - Weekly Chart

    private var weeklyChartSection: some View {
        Section("Last 7 Days") {
            Chart {
                ForEach(viewModel.last7Days(from: habits), id: \.date) { day in
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

    // MARK: - Milestones

    private var milestonesSection: some View {
        let achieved = viewModel.achievedMilestones(from: habits)

        return Group {
            if !achieved.isEmpty {
                Section("Milestones") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 12) {
                        ForEach(achieved, id: \.days) { milestone in
                            VStack(spacing: 6) {
                                Image(systemName: milestone.icon)
                                    .font(.title2)
                                    .foregroundStyle(.yellow.gradient)
                                Text(milestone.label)
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

/// Reusable card showing an icon, value, and title for overview stats.
struct StatCard: View {
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

/// Shows a habit's current and best streak with its icon and color.
struct HabitStreakRow: View {
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
