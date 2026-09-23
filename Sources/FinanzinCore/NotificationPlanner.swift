import Foundation

// MARK: - Planejamento de notificações locais (puro, testável)
//
// Calcula O QUE agendar a partir das transações + prefs. O disparo real
// (`UNUserNotificationCenter`) vive em `FinanzinUI/NotificationService`,
// pois é API de plataforma. Limite do iOS: 64 pendentes — capamos em 30
// por tipo + 1 resumo diário.

public struct NotificationPlan: Hashable, Sendable {
    public enum Kind: String, Hashable, Sendable {
        case overdueDaily
        case payDueDay
        case receiveDueDay
    }

    public var id: String
    public var kind: Kind
    /// Componentes de calendário do disparo (hora de prefs + dia).
    public var components: DateComponents
    public var repeats: Bool
    public var title: String
    public var body: String

    public init(id: String, kind: Kind, components: DateComponents, repeats: Bool, title: String, body: String) {
        self.id = id
        self.kind = kind
        self.components = components
        self.repeats = repeats
        self.title = title
        self.body = body
    }
}

public enum NotificationPlanner {
    /// Máximo de alertas por vencimento (longe do teto de 64 do iOS).
    public static let maxPerKind = 30
    /// Janela futura varrida para "vence hoje" (dias a partir de hoje).
    public static let horizonDays = 30

    public static func plans(
        transactions: [FinancialTransaction],
        settings: AppSettings,
        now: Date = Date()
    ) -> [NotificationPlan] {
        let prefs = settings.notifications
        guard prefs.isAnyEnabled else { return [] }
        let lang = settings.language
        let currency = settings.currency
        var out: [NotificationPlan] = []
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)

        // 1. Resumo diário de vencidas (recorrente, só corpo agregado).
        if prefs.overdueDailyEnabled {
            let overdue = transactions.filter {
                $0.status == .pending && $0.dueDate < today
            }
            if !overdue.isEmpty {
                let total = overdue.reduce(Decimal(0)) { $0 + $1.amount }
                let money = Currency.format(total, currencyCode: currency.currencyCode, localeIdentifier: currency.localeIdentifier)
                let body: String
                switch lang {
                case .en: body = "\(overdue.count) overdue totaling \(money)"
                case .ptBR: body = "\(overdue.count) vencida(s) totalizando \(money)"
                }
                out.append(NotificationPlan(
                    id: "fin.overdue.daily",
                    kind: .overdueDaily,
                    components: prefs.dateComponents,
                    repeats: true,
                    title: L10n.t(.overdueSummary, lang),
                    body: body
                ))
            }
        }

        // 2+3. Alertas no dia do vencimento (próximos N dias).
        func dueDayPlans(type: TransactionType, enabled: Bool, kind: NotificationPlan.Kind) {
            guard enabled else { return }
            let upcoming = transactions
                .filter { $0.type == type && $0.status == .pending }
                .filter {
                    let day = cal.startOfDay(for: $0.dueDate)
                    guard let diff = cal.dateComponents([.day], from: today, to: day).day else { return false }
                    return diff >= 0 && diff <= Self.horizonDays
                }
                .sorted { $0.dueDate < $1.dueDate }
                .prefix(Self.maxPerKind)
            for t in upcoming {
                let day = cal.startOfDay(for: t.dueDate)
                let dc = cal.dateComponents([.year, .month, .day], from: day)
                var comps = DateComponents(
                    year: dc.year, month: dc.month, day: dc.day,
                    hour: prefs.hour, minute: prefs.minute
                )
                comps.calendar = cal
                let money = Currency.format(t.amount, currencyCode: currency.currencyCode, localeIdentifier: currency.localeIdentifier)
                let titleKey: L10nKey = kind == .payDueDay ? .payDueToday : .receiveDueToday
                out.append(NotificationPlan(
                    id: "fin.\(kind.rawValue).\(t.id)",
                    kind: kind,
                    components: comps,
                    repeats: false,
                    title: L10n.t(titleKey, lang),
                    body: "\(t.description) · \(money)"
                ))
            }
        }

        dueDayPlans(type: .payable, enabled: prefs.payDueDayEnabled, kind: .payDueDay)
        dueDayPlans(type: .receivable, enabled: prefs.receiveDueDayEnabled, kind: .receiveDueDay)
        return out
    }
}
