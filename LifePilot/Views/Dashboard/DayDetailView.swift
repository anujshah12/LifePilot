import SwiftUI
import SwiftData
import Charts

struct DayDetailView: View {

    let dayPlan: DayPlan
    let date: Date

    @Environment(\.dismiss) private var dismiss

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }

    private var sortedTasks: [DayTask] {
        dayPlan.sortedTasks
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    daySummaryHeader
                    taskTimelineSection
                    dayCategoryBreakdown
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Day Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Day Summary Header

    private var daySummaryHeader: some View {
        VStack(spacing: 16) {
            Text(dateString)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                summaryTile(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    value: "\(dayPlan.completedTaskCount)/\(dayPlan.tasks.count)",
                    label: "Tasks"
                )

                Divider()
                    .frame(height: 44)

                summaryTile(
                    icon: "clock.fill",
                    color: .blue,
                    value: TimeFormatter.minutesToDisplay(dayPlan.totalActualMinutes),
                    label: "Actual"
                )

                Divider()
                    .frame(height: 44)

                summaryTile(
                    icon: "gauge.with.needle",
                    color: .orange,
                    value: TimeFormatter.minutesToDisplay(dayPlan.totalEstimatedMinutes),
                    label: "Estimated"
                )
            }

            if dayPlan.allTasksComplete {
                Label("All tasks completed", systemImage: "star.fill")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.1), in: Capsule())
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func summaryTile(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Task Timeline

    private var taskTimelineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Task Timeline")
                .font(.headline)
                .padding(.horizontal, 20)

            if sortedTasks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                    Text("No tasks for this day")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sortedTasks.enumerated()), id: \.element.id) { index, task in
                        taskTimelineRow(task, isLast: index == sortedTasks.count - 1)
                    }
                }
                .padding(.vertical, 8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            }
        }
    }

    private func taskTimelineRow(_ task: DayTask, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline connector
            VStack(spacing: 0) {
                Circle()
                    .fill(taskColor(for: task))
                    .frame(width: 12, height: 12)

                if !isLast {
                    Rectangle()
                        .fill(taskColor(for: task).opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Task detail card
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(task.isComplete ? .primary : .secondary)
                        .strikethrough(!task.isComplete, color: .secondary)

                    Spacer()

                    if task.isComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }

                HStack(spacing: 12) {
                    if let category = task.category {
                        Text(category.name)
                            .font(.caption2)
                            .foregroundStyle(category.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(category.color.opacity(0.12), in: Capsule())
                    }

                    if let start = task.startedAt {
                        let timeFormatter = DateFormatter()
                        let _ = timeFormatter.dateFormat = "h:mm a"
                        Label(timeFormatter.string(from: start), systemImage: "play.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let end = task.completedAt {
                        let timeFormatter = DateFormatter()
                        let _ = timeFormatter.dateFormat = "h:mm a"
                        Label(timeFormatter.string(from: end), systemImage: "stop.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                // Duration comparison
                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.with.needle")
                            .font(.system(size: 9))
                        Text("Est: \(TimeFormatter.minutesToDisplay(task.estimatedMinutes))")
                    }
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                    if let actual = task.actualMinutes {
                        HStack(spacing: 4) {
                            Image(systemName: "stopwatch.fill")
                                .font(.system(size: 9))
                            Text("Act: \(TimeFormatter.minutesToDisplay(actual))")
                        }
                        .font(.caption2)
                        .foregroundStyle(durationColor(estimated: task.estimatedMinutes, actual: actual))
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .padding(.horizontal, 16)
    }

    private func taskColor(for task: DayTask) -> Color {
        if let category = task.category {
            return category.color
        }
        return task.isComplete ? .green : .gray
    }

    private func durationColor(estimated: Int, actual: Int) -> Color {
        if actual <= estimated { return .green }
        let ratio = Double(actual) / Double(max(estimated, 1))
        if ratio <= 1.2 { return .orange }
        return .red
    }

    // MARK: - Day Category Breakdown

    private var dayCategoryBreakdown: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Time by Category")
                .font(.headline)
                .padding(.horizontal, 20)

            let breakdown = computeDayCategoryBreakdown()

            if breakdown.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.pie")
                        .font(.title2)
                        .foregroundStyle(.quaternary)
                    Text("No category data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 16)
            } else {
                VStack(spacing: 12) {
                    Chart(breakdown, id: \.name) { item in
                        SectorMark(
                            angle: .value("Minutes", item.minutes),
                            innerRadius: .ratio(0.5),
                            angularInset: 1.5
                        )
                        .foregroundStyle(Color(hex: item.colorHex))
                        .cornerRadius(4)
                    }
                    .frame(height: 180)

                    Divider()

                    VStack(spacing: 6) {
                        ForEach(breakdown, id: \.name) { item in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(Color(hex: item.colorHex))
                                    .frame(width: 10, height: 10)
                                Text(item.name)
                                    .font(.subheadline)
                                Spacer()
                                Text(TimeFormatter.minutesToDisplay(item.minutes))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
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

    private struct CategoryEntry {
        let name: String
        let colorHex: String
        let minutes: Int
    }

    private func computeDayCategoryBreakdown() -> [CategoryEntry] {
        var dict: [String: (String, Int)] = [:]

        for task in sortedTasks {
            let minutes = task.actualMinutes ?? task.estimatedMinutes
            let name = task.category?.name ?? "Uncategorized"
            let hex = task.category?.colorHex ?? "999999"
            let existing = dict[name] ?? (hex, 0)
            dict[name] = (existing.0, existing.1 + minutes)
        }

        return dict.map { CategoryEntry(name: $0.key, colorHex: $0.value.0, minutes: $0.value.1) }
            .sorted { $0.minutes > $1.minutes }
    }
}

// MARK: - Preview

#Preview {
    DayDetailView(dayPlan: DayPlan(), date: Date())
        .modelContainer(
            for: [DayPlan.self, DayTask.self, TaskCategory.self],
            inMemory: true
        )
}
