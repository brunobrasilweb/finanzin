import Foundation
import FinanzinCore

#if canImport(UserNotifications)
import UserNotifications

// MARK: - Agendamento de notificações locais (Sprint 7)
//
// O QUÊ agendar é puro e testável (`NotificationPlanner`, no Core).
// Aqui vive só a ponte com `UNUserNotificationCenter` (API de plataforma).
// Sem backend/APNs: tudo local, agendado no device.

public enum NotificationService {
    public static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    public static func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { cont in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                cont.resume(returning: settings.authorizationStatus)
            }
        }
    }

    /// Recria todos os agendamentos a partir do estado atual.
    /// Chamar em: mudança de transações/settings e ao ativar o app.
    public static func rescheduleAll(transactions: [FinancialTransaction], settings: AppSettings) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: pendingIDs(transactions: transactions))
        let plans = NotificationPlanner.plans(transactions: transactions, settings: settings)
        for plan in plans {
            let content = UNMutableNotificationContent()
            content.title = plan.title
            content.body = plan.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: plan.components, repeats: plan.repeats)
            center.add(UNNotificationRequest(identifier: plan.id, content: content, trigger: trigger))
        }
    }

    public static func cancelAll(transactions: [FinancialTransaction]) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: pendingIDs(transactions: transactions))
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["fin.overdue.daily"])
    }

    private static func pendingIDs(transactions: [FinancialTransaction]) -> [String] {
        var ids = ["fin.overdue.daily"]
        ids += transactions.flatMap {
            ["fin.payDueDay.\($0.id)", "fin.receiveDueDay.\($0.id)"]
        }
        return ids
    }
}
#endif
