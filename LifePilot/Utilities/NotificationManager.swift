import Foundation
import UserNotifications

/// Centralized manager for all local notifications in LifePilot.
///
/// Handles scheduling, cancellation, and permission management for:
/// - Morning reminders to start your day
/// - Task timer alerts when estimated time expires
/// - Inactivity nudges when no progress is detected
/// - Day summary notifications on completion
/// - Weekly report availability alerts
final class NotificationManager: NSObject, @unchecked Sendable {

    // MARK: - Singleton

    static let shared = NotificationManager()

    // MARK: - Notification Identifiers

    /// String constants used to identify and manage each notification type independently.
    enum Identifier {
        static let morningReminder = "morning-reminder"
        static let taskTimer = "task-timer"
        static let inactivityNudge = "inactivity-nudge"
        static let daySummary = "day-summary"
        static let weeklyReport = "weekly-report"
    }

    // MARK: - Category Identifiers

    /// Notification categories for grouping and action handling.
    enum Category {
        static let reminder = "REMINDER_CATEGORY"
        static let taskAlert = "TASK_ALERT_CATEGORY"
        static let nudge = "NUDGE_CATEGORY"
        static let summary = "SUMMARY_CATEGORY"
        static let report = "REPORT_CATEGORY"
    }

    // MARK: - Private Properties

    private let center = UNUserNotificationCenter.current()

    // MARK: - Init

    private override init() {
        super.init()
        registerCategories()
    }

    // MARK: - Category Registration

    /// Registers notification categories so the system can group and display them appropriately.
    private func registerCategories() {
        let reminderCategory = UNNotificationCategory(
            identifier: Category.reminder,
            actions: [],
            intentIdentifiers: []
        )
        let taskAlertCategory = UNNotificationCategory(
            identifier: Category.taskAlert,
            actions: [],
            intentIdentifiers: []
        )
        let nudgeCategory = UNNotificationCategory(
            identifier: Category.nudge,
            actions: [],
            intentIdentifiers: []
        )
        let summaryCategory = UNNotificationCategory(
            identifier: Category.summary,
            actions: [],
            intentIdentifiers: []
        )
        let reportCategory = UNNotificationCategory(
            identifier: Category.report,
            actions: [],
            intentIdentifiers: []
        )

        center.setNotificationCategories([
            reminderCategory,
            taskAlertCategory,
            nudgeCategory,
            summaryCategory,
            reportCategory
        ])
    }

    // MARK: - Authorization

    /// Requests notification permission from the user for alerts, sounds, and badges.
    /// - Returns: `true` if permission was granted, `false` otherwise.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("[NotificationManager] Authorization request failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Returns the current notification authorization status.
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Morning Reminder

    /// Schedules a daily repeating notification to remind the user to start their day.
    ///
    /// Uses a calendar-based trigger so it fires at the same local time every day,
    /// regardless of time zone changes.
    ///
    /// - Parameters:
    ///   - hour: Hour component (0-23). Defaults to 7.
    ///   - minute: Minute component (0-59). Defaults to 0.
    func scheduleMorningReminder(at hour: Int = 7, minute: Int = 0) {
        // Remove any existing morning reminder before scheduling a new one.
        cancelNotification(withIdentifier: Identifier.morningReminder)

        let content = UNMutableNotificationContent()
        content.title = "Good Morning!"
        content.body = "Ready to plan your day? Open LifePilot and set your tasks."
        content.sound = .default
        content.categoryIdentifier = Category.reminder

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: Identifier.morningReminder,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule morning reminder: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Task Timer Alert

    /// Schedules a notification that fires when a task's estimated time is up.
    ///
    /// Only one task timer alert can be active at a time. Scheduling a new one
    /// automatically cancels the previous one.
    ///
    /// - Parameters:
    ///   - taskTitle: The name of the task to display in the notification.
    ///   - estimatedMinutes: The task's estimated duration in minutes.
    func scheduleTaskTimerAlert(taskTitle: String, estimatedMinutes: Int) {
        // Cancel any existing task timer before scheduling a new one.
        cancelTaskTimerAlert()

        guard estimatedMinutes > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Time's Up!"
        content.body = "Time's up for \(taskTitle)! You estimated \(estimatedMinutes) minute\(estimatedMinutes == 1 ? "" : "s")."
        content.sound = .default
        content.categoryIdentifier = Category.taskAlert

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(estimatedMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: Identifier.taskTimer,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule task timer alert: \(error.localizedDescription)")
            }
        }
    }

    /// Cancels any pending task timer alert (e.g., when a task is completed early).
    func cancelTaskTimerAlert() {
        cancelNotification(withIdentifier: Identifier.taskTimer)
    }

    // MARK: - Inactivity Nudge

    /// Schedules a nudge notification if no activity is detected within the specified interval.
    ///
    /// Call this method when a task starts or when activity is detected to reset the timer.
    /// Only one inactivity nudge can be pending at a time.
    ///
    /// - Parameter afterMinutes: Minutes of inactivity before the nudge fires. Defaults to 30.
    func scheduleInactivityNudge(afterMinutes: Int = 30) {
        // Cancel any existing nudge before scheduling a new one.
        cancelInactivityNudge()

        guard afterMinutes > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Still Working?"
        content.body = "Don't forget to mark your task as complete."
        content.sound = .default
        content.categoryIdentifier = Category.nudge

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(afterMinutes * 60),
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: Identifier.inactivityNudge,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule inactivity nudge: \(error.localizedDescription)")
            }
        }
    }

    /// Cancels any pending inactivity nudge (e.g., when a task is completed).
    func cancelInactivityNudge() {
        cancelNotification(withIdentifier: Identifier.inactivityNudge)
    }

    // MARK: - Day Summary

    /// Fires an immediate notification summarizing the completed day.
    ///
    /// - Parameters:
    ///   - completedCount: Number of tasks completed.
    ///   - totalCount: Total number of tasks planned.
    ///   - totalMinutes: Total actual minutes spent on tasks.
    func scheduleDaySummary(completedCount: Int, totalCount: Int, totalMinutes: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Day Complete!"
        content.body = "You finished \(completedCount)/\(totalCount) tasks in \(TimeFormatter.minutesToDisplay(totalMinutes))."
        content.sound = .default
        content.categoryIdentifier = Category.summary

        // Fire almost immediately (1 second delay — minimum for UNTimeIntervalNotificationTrigger).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)

        let request = UNNotificationRequest(
            identifier: Identifier.daySummary,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule day summary: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Weekly Report

    /// Schedules a notification informing the user that their weekly report is ready.
    ///
    /// Fires every Sunday at 6:00 PM local time using a calendar-based trigger.
    func scheduleWeeklyReportReady() {
        // Cancel any existing weekly report notification before scheduling.
        cancelNotification(withIdentifier: Identifier.weeklyReport)

        let content = UNMutableNotificationContent()
        content.title = "Weekly Report Ready"
        content.body = "Your weekly productivity report is available. See how your week went!"
        content.sound = .default
        content.categoryIdentifier = Category.report

        // Sunday = 1 in Calendar's weekday numbering.
        var dateComponents = DateComponents()
        dateComponents.weekday = 1
        dateComponents.hour = 18
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: Identifier.weeklyReport,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("[NotificationManager] Failed to schedule weekly report: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Cancel All

    /// Cancels all pending LifePilot notifications.
    func cancelAllPending() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Private Helpers

    /// Cancels a single pending notification by its identifier.
    private func cancelNotification(withIdentifier identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
