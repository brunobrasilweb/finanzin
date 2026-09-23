import Foundation

// MARK: - Preferências do app (Sprint 7: Configurações)
//
// Modelo puro de domínio (sem SwiftUI — o Core não importa SwiftUI,
// pois não resolve no CLT). O mapeamento `ThemeMode → ColorScheme`
// vive em `FinanzinUI/Theme.swift`.

/// Idioma do app (troca in-app, sem depender do idioma do sistema).
public enum AppLanguage: String, CaseIterable, Codable, Sendable {
    case ptBR = "pt-BR"
    case en = "en"

    public var localeIdentifier: String {
        switch self {
        case .ptBR: "pt_BR"
        case .en: "en_US"
        }
    }

    public var label: String {
        switch self {
        case .ptBR: "Português (BR)"
        case .en: "English"
        }
    }

    public var flag: String {
        switch self {
        case .ptBR: "🇧🇷"
        case .en: "🇺🇸"
        }
    }
}

/// As 5 principais moedas suportadas (só formatação, sem conversão).
public enum AppCurrency: String, CaseIterable, Codable, Sendable {
    case BRL
    case USD
    case EUR
    case GBP
    case JPY

    public var currencyCode: String { rawValue }

    public var localeIdentifier: String {
        switch self {
        case .BRL: "pt_BR"
        case .USD: "en_US"
        case .EUR: "de_DE"
        case .GBP: "en_GB"
        case .JPY: "ja_JP"
        }
    }

    /// Símbolo esperado na formatação (usado em testes e no preview).
    public var symbol: String {
        switch self {
        case .BRL: "R$"
        case .USD: "$"
        case .EUR: "€"
        case .GBP: "£"
        case .JPY: "¥"
        }
    }

    public var label: String {
        switch self {
        case .BRL: "Real (BRL)"
        case .USD: "Dólar (USD)"
        case .EUR: "Euro (EUR)"
        case .GBP: "Libra (GBP)"
        case .JPY: "Iene (JPY)"
        }
    }

    public var flag: String {
        switch self {
        case .BRL: "🇧🇷"
        case .USD: "🇺🇸"
        case .EUR: "🇪🇺"
        case .GBP: "🇬🇧"
        case .JPY: "🇯🇵"
        }
    }
}

/// Modo de aparência.
public enum ThemeMode: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark

    public func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.system, .en): "System"
        case (.light, .en): "Light"
        case (.dark, .en): "Dark"
        case (.system, .ptBR): "Sistema"
        case (.light, .ptBR): "Claro"
        case (.dark, .ptBR): "Escuro"
        }
    }
}

/// Preferências de notificação (locais, agendadas no device).
public struct NotificationPrefs: Codable, Sendable, Equatable {
    /// 1. Resumo diário de contas vencidas.
    public var overdueDailyEnabled: Bool
    /// 2. Alerta no dia do vencimento de contas a pagar.
    public var payDueDayEnabled: Bool
    /// 3. Alerta no dia do vencimento de contas a receber.
    public var receiveDueDayEnabled: Bool
    /// Hora comum dos disparos (default 09:00).
    public var hour: Int
    public var minute: Int

    public init(
        overdueDailyEnabled: Bool = false,
        payDueDayEnabled: Bool = false,
        receiveDueDayEnabled: Bool = false,
        hour: Int = 9,
        minute: Int = 0
    ) {
        self.overdueDailyEnabled = overdueDailyEnabled
        self.payDueDayEnabled = payDueDayEnabled
        self.receiveDueDayEnabled = receiveDueDayEnabled
        self.hour = hour
        self.minute = minute
    }

    public var dateComponents: DateComponents {
        DateComponents(hour: hour, minute: minute)
    }

    public var isAnyEnabled: Bool {
        overdueDailyEnabled || payDueDayEnabled || receiveDueDayEnabled
    }
}

public struct AppSettings: Codable, Sendable, Equatable {
    public var language: AppLanguage
    public var currency: AppCurrency
    public var theme: ThemeMode
    public var notifications: NotificationPrefs

    public init(
        language: AppLanguage = .ptBR,
        currency: AppCurrency = .BRL,
        theme: ThemeMode = .system,
        notifications: NotificationPrefs = NotificationPrefs()
    ) {
        self.language = language
        self.currency = currency
        self.theme = theme
        self.notifications = notifications
    }

    public var locale: Locale { Locale(identifier: language.localeIdentifier) }

    public static var defaults: AppSettings { AppSettings() }
}
