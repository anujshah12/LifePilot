import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {

    // MARK: - AppStorage (UserDefaults)

    @AppStorage("notifications_morningReminderEnabled") private var morningReminderEnabled = false
    @AppStorage("notifications_morningReminderHour") private var morningReminderHour = 7
    @AppStorage("notifications_morningReminderMinute") private var morningReminderMinute = 0
    @AppStorage("notifications_taskTimerEnabled") private var taskTimerEnabled = true
    @AppStorage("notifications_inactivityNudgeEnabled") private var inactivityNudgeEnabled = true
    @AppStorage("notifications_inactivityThresholdMinutes") private var inactivityThresholdMinutes = 30

    // MARK: - State

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var morningReminderTime = Date()

    // MARK: - Private

    private let notificationManager = NotificationManager.shared

    // MARK: - Body

    var body: some View {
        Form {
            authorizationSection
            morningReminderSection
            taskAlertsSection
            inactivitySection
            managementSection
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshAuthorizationStatus()
            syncTimePickerFromStorage()
        }
    }

    // MARK: - Authorization Section

    private var authorizationSection: some View {
        Section {
            HStack {
                Label {
                    Text("Status")
                } icon: {
                    Image(systemName: authorizationStatusIcon)
                        .foregroundStyle(authorizationStatusColor)
                }

                Spacer()

                Text(authorizationStatusText)
                    .foregroundStyle(.secondary)
            }

            if authorizationStatus == .notDetermined {
                Button {
                    Task {
                        await notificationManager.requestAuthorization()
                        await refreshAuthorizationStatus()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Request Permission")
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
            } else if authorizationStatus == .denied {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Spacer()
                        Text("Open Settings")
                            .fontWeight(.medium)
                        Spacer()
                    }
                }
            }
        } header: {
            Text("Permission")
        } footer: {
            if authorizationStatus == .denied {
                Text("Notifications are disabled. Enable them in Settings to receive reminders.")
            }
        }
    }

    // MARK: - Morning Reminder Section

    private var morningReminderSection: some View {
        Section {
            Toggle("Morning Reminder", isOn: $morningReminderEnabled)
                .onChange(of: morningReminderEnabled) { _, isEnabled in
                    handleMorningReminderToggle(isEnabled)
                }

            if morningReminderEnabled {
                DatePicker(
                    "Reminder Time",
                    selection: $morningReminderTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: morningReminderTime) { _, newTime in
                    handleMorningReminderTimeChange(newTime)
                }
            }
        } header: {
            Text("Morning Reminder")
        } footer: {
            Text("Get a daily reminder to plan and start your day.")
        }
    }

    // MARK: - Task Alerts Section

    private var taskAlertsSection: some View {
        Section {
            Toggle("Task Timer Alerts", isOn: $taskTimerEnabled)
                .onChange(of: taskTimerEnabled) { _, isEnabled in
                    if !isEnabled {
                        notificationManager.cancelTaskTimerAlert()
                    }
                }
        } header: {
            Text("Task Alerts")
        } footer: {
            Text("Get notified when your estimated time for a task runs out.")
        }
    }

    // MARK: - Inactivity Section

    private var inactivitySection: some View {
        Section {
            Toggle("Inactivity Nudges", isOn: $inactivityNudgeEnabled)
                .onChange(of: inactivityNudgeEnabled) { _, isEnabled in
                    if !isEnabled {
                        notificationManager.cancelInactivityNudge()
                    }
                }

            if inactivityNudgeEnabled {
                Stepper(
                    "After \(inactivityThresholdMinutes) minutes",
                    value: $inactivityThresholdMinutes,
                    in: 15...60,
                    step: 5
                )
            }
        } header: {
            Text("Inactivity Nudges")
        } footer: {
            Text("Get a reminder if you haven't marked a task as complete within the threshold.")
        }
    }

    // MARK: - Management Section

    private var managementSection: some View {
        Section {
            Button(role: .destructive) {
                notificationManager.cancelAllPending()
            } label: {
                HStack {
                    Spacer()
                    Text("Cancel All Pending Notifications")
                    Spacer()
                }
            }
        }
    }

    // MARK: - Authorization Helpers

    private var authorizationStatusText: String {
        switch authorizationStatus {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .provisional: return "Provisional"
        case .ephemeral: return "Ephemeral"
        case .notDetermined: return "Not Determined"
        @unknown default: return "Unknown"
        }
    }

    private var authorizationStatusIcon: String {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var authorizationStatusColor: Color {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .secondary
        }
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await notificationManager.authorizationStatus()
    }

    // MARK: - Morning Reminder Helpers

    /// Builds a Date from the stored hour and minute for the DatePicker.
    private func syncTimePickerFromStorage() {
        var components = DateComponents()
        components.hour = morningReminderHour
        components.minute = morningReminderMinute
        if let date = Calendar.current.date(from: components) {
            morningReminderTime = date
        }
    }

    /// Extracts hour and minute from the DatePicker value and persists them.
    private func handleMorningReminderTimeChange(_ newTime: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: newTime)
        morningReminderHour = components.hour ?? 7
        morningReminderMinute = components.minute ?? 0

        // Reschedule with the updated time.
        if morningReminderEnabled {
            notificationManager.scheduleMorningReminder(
                at: morningReminderHour,
                minute: morningReminderMinute
            )
        }
    }

    private func handleMorningReminderToggle(_ isEnabled: Bool) {
        if isEnabled {
            Task {
                let granted = await notificationManager.requestAuthorization()
                await refreshAuthorizationStatus()
                if granted {
                    notificationManager.scheduleMorningReminder(
                        at: morningReminderHour,
                        minute: morningReminderMinute
                    )
                } else {
                    // Revert the toggle if permission was not granted.
                    morningReminderEnabled = false
                }
            }
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [NotificationManager.Identifier.morningReminder]
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}
