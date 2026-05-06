//
//  NotificationManager.swift
//  Prisma
//
//  Manages local daily reminder notifications using UNUserNotificationCenter.
//  Schedules a nightly reminder at the configured hour if the user hasn't
//  completed all daily puzzles.
//

import UserNotifications
import Foundation

/// Manages daily streak reminder notifications.
@MainActor
final class NotificationManager {

    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()
    private let notificationID = "prisma.daily.reminder"

    // MARK: - Permission

    /// Requests notification authorisation. Returns true if granted.
    func requestAuthorisation() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("[Notifications] Auth request failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Returns the current authorisation status without prompting.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Scheduling

    /// Schedules (or replaces) a daily reminder at the given hour (0–23).
    /// Safe to call multiple times — always cancels the previous request first.
    func scheduleDailyReminder(hour: Int) async {
        // Remove any existing reminder first
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your daily puzzles are waiting 🧩"
        content.body = "Signals, Archive, Cargo, Shift, Circuit — keep your streak alive!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: notificationID,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            print("[Notifications] Daily reminder scheduled at \(hour):00")
        } catch {
            print("[Notifications] Failed to schedule reminder: \(error.localizedDescription)")
        }
    }

    /// Cancels the daily reminder.
    func cancelDailyReminder() {
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        print("[Notifications] Daily reminder cancelled")
    }
}
