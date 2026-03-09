import SwiftUI
import SwiftData
import Charts

struct WeeklyDashboardView: View {

    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = WeeklyReportViewModel()
    @State private var selectedDay: WeeklyReportViewModel.DailyData?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    weekNavigationHeader
                    overviewCard
                    categoryBreakdownSection
                    dailyTimelineSection
                    accuracySection
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Weekly Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                viewModel.load(context: modelContext)
            }
            .sheet(item: $selectedDay) { day in
                if let plan = day.plan {
                    DayDetailView(dayPlan: plan, date: day.date)
                }
            }
        }
    }

    // MARK: - Week Navigation Header

    private var weekNavigationHeader: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.goToPreviousWeek()
                }
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.weekLabel)
                    .font(.headline)
                    .fontWeight(.semibold)
            }

            Spacer()

            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    viewModel.goToNextWeek()
                }
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(viewModel.canGoForward ? Color.blue : Color.gray.opacity(0.3))
            }
            .disabled(!viewModel.canGoForward)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                // Productivity Score — large circular gauge
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(Color.blue.opacity(0.15), lineWidth: 8)
                            .frame(width: 80, height: 80)

                        Circle()
                            .trim(from: 0, to: Double(viewModel.productivityScore) / 100.0)
                            .stroke(
                                productivityColor,
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.6), value: viewModel.productivityScore)

                        VStack(spacing: 0) {
                            Text("\(viewModel.productivityScore)")
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(productivityColor)
                            Text("%")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("Productivity")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Stats column
                VStack(alignment: .leading, spacing: 12) {
                    statRow(
                        icon: "clock.fill",
                        color: .blue,
                        title: "Tracked",
                        value: viewModel.totalTrackedDisplay
                    )

                    statRow(
                        icon: "checkmark.circle.fill",
                        color: .green,
                        title: "Completed",
                        value: "\(viewModel.totalCompletedTasks)/\(viewModel.totalPlannedTasks)"
                    )

                    statRow(
                        icon: "flame.fill",
                        color: .orange,
                        title: "Streak",
                        value: "\(viewModel.currentStreak) day\(viewModel.currentStreak == 1 ? "" : "s")"
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func statRow(icon: String, color: Color, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var productivityColor: Color {
        let score = viewModel.productivityScore
        if score >= 80 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Category Breakdown")
                .font(.headline)
                .padding(.horizontal, 20)

            if viewModel.categoryBreakdowns.isEmpty {
                emptyStateCard(message: "No task data this week")
            } else {
                VStack(spacing: 16) {
                    // Bar Chart
                    Chart(viewModel.categoryBreakdowns) { item in
                        BarMark(
                            x: .value("Hours", item.hours),
                            y: .value("Category", item.categoryName)
                        )
                        .foregroundStyle(Color(hex: item.colorHex))
                        .cornerRadius(4)
                        .annotation(position: .trailing, spacing: 4) {
                            Text(TimeFormatter.minutesToDisplay(item.totalMinutes))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartXAxisLabel("Hours", position: .bottom)
                    .chartXAxis {
                        AxisMarks(position: .bottom) { value in
                            AxisValueLabel {
                                if let hours = value.as(Double.self) {
                                    Text(String(format: "%.0f", hours))
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel()
                        }
                    }
                    .frame(height: CGFloat(max(viewModel.categoryBreakdowns.count, 1)) * 44)

                    Divider()

                    // Legend
                    VStack(spacing: 8) {
                        ForEach(viewModel.categoryBreakdowns) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: item.colorHex))
                                    .frame(width: 10, height: 10)

                                Text(item.categoryName)
                                    .font(.subheadline)

                                Spacer()

                                Text(TimeFormatter.minutesToDisplay(item.totalMinutes))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()

                                Text(String(format: "%.0f%%", item.percentage))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 36, alignment: .trailing)
                            }
                        }
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Daily Timeline

    private var dailyTimelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Daily Overview")
                .font(.headline)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(viewModel.dailyData) { day in
                        dayColumn(day)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func dayColumn(_ day: WeeklyReportViewModel.DailyData) -> some View {
        Button {
            if day.plan != nil {
                selectedDay = day
            }
        } label: {
            VStack(spacing: 6) {
                // Day label
                Text(day.dayName)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(day.isToday ? .blue : .secondary)

                Text(day.dayNumber)
                    .font(.caption)
                    .fontWeight(day.isToday ? .bold : .regular)
                    .foregroundStyle(day.isToday ? .blue : .primary)

                // Timeline column
                if day.tasks.isEmpty {
                    VStack {
                        Spacer()
                        Text("--")
                            .font(.caption2)
                            .foregroundStyle(.quaternary)
                        Spacer()
                    }
                    .frame(width: 40, height: 140)
                } else {
                    timelineBlocks(for: day.tasks)
                        .frame(width: 40, height: 140)
                }

                // Completion count
                if let plan = day.plan {
                    Text("\(plan.completedTaskCount)/\(plan.tasks.count)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text("")
                        .font(.system(size: 9))
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(day.isToday ? Color.blue.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func timelineBlocks(for tasks: [DayTask]) -> some View {
        GeometryReader { geo in
            let totalMinutes = max(tasks.reduce(0) { $0 + ($1.actualMinutes ?? $1.estimatedMinutes) }, 1)
            let availableHeight = geo.size.height

            VStack(spacing: 1) {
                ForEach(tasks) { task in
                    let minutes = task.actualMinutes ?? task.estimatedMinutes
                    let proportion = Double(minutes) / Double(totalMinutes)
                    let blockHeight = max(proportion * availableHeight, 4)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(taskBlockColor(for: task))
                        .frame(height: blockHeight)
                        .opacity(task.isComplete ? 1.0 : 0.4)
                }
            }
        }
    }

    private func taskBlockColor(for task: DayTask) -> Color {
        if let category = task.category {
            return category.color
        }
        return .gray
    }

    // MARK: - Accuracy Section

    private var accuracySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Estimation Accuracy")
                .font(.headline)
                .padding(.horizontal, 20)

            if viewModel.totalPlannedTasks == 0 {
                emptyStateCard(message: "No completed tasks to compare")
            } else {
                VStack(spacing: 16) {
                    // Comparison bar chart
                    Chart(viewModel.estimateVsActualData) { entry in
                        BarMark(
                            x: .value("Type", entry.label),
                            y: .value("Minutes", entry.minutes)
                        )
                        .foregroundStyle(entry.label == "Estimated" ? Color.blue : Color.orange)
                        .cornerRadius(6)
                        .annotation(position: .top, spacing: 4) {
                            Text(TimeFormatter.minutesToDisplay(entry.minutes))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .chartYAxisLabel("Minutes", position: .leading)
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .frame(height: 180)

                    Divider()

                    // Summary text
                    HStack(spacing: 16) {
                        VStack(spacing: 4) {
                            Image(systemName: "gauge.with.needle")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            Text("Estimated")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(viewModel.estimatedDisplay)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Image(systemName: accuracyIcon)
                                .font(.title3)
                                .foregroundStyle(accuracyColor)
                            Text("Accuracy")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.accuracyPercentage)%")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(accuracyColor)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Image(systemName: "stopwatch.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            Text("Actual")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(viewModel.actualDisplay)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
    }

    private var accuracyColor: Color {
        let ratio = viewModel.accuracyRatio
        if ratio >= 0.9 && ratio <= 1.1 { return .green }
        if ratio >= 0.75 && ratio <= 1.25 { return .orange }
        return .red
    }

    private var accuracyIcon: String {
        let ratio = viewModel.accuracyRatio
        if ratio >= 0.9 && ratio <= 1.1 { return "checkmark.seal.fill" }
        if ratio > 1.1 { return "arrow.up.circle.fill" }
        return "arrow.down.circle.fill"
    }

    // MARK: - Empty State

    private func emptyStateCard(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.title2)
                .foregroundStyle(.quaternary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    WeeklyDashboardView()
        .modelContainer(
            for: [DayPlan.self, DayTask.self, TaskCategory.self],
            inMemory: true
        )
}
