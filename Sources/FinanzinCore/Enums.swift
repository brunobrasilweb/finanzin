import Foundation

/// Tipo de transação: a pagar ou a receber.
/// Espelha `FinancialTransactionType` do admin + `TransactionType` do Inofinancy.
public enum TransactionType: String, CaseIterable, Codable, Sendable {
    case receivable
    case payable

    public var label: String {
        switch self {
        case .receivable: "A Receber"
        case .payable: "A Pagar"
        }
    }
}

/// Recorrência. `unique` == `single` do Inofinancy (mapeado na importação).
public enum RecurrenceType: String, CaseIterable, Codable, Sendable {
    case unique
    case fixed
    case recurring
    case installment

    public var label: String {
        switch self {
        case .unique: "Única"
        case .fixed: "Fixa"
        case .recurring: "Recorrente"
        case .installment: "Parcelada"
        }
    }
}

public enum InstallmentInterval: String, CaseIterable, Codable, Sendable {
    case weekly
    case biweekly
    case monthly
    case yearly

    public var label: String {
        switch self {
        case .weekly: "Semanal"
        case .biweekly: "Quinzenal"
        case .monthly: "Mensal"
        case .yearly: "Anual"
        }
    }
}

public enum TransactionStatus: String, CaseIterable, Codable, Sendable {
    case pending
    case paid
    case canceled
    case overdue

    public var label: String {
        switch self {
        case .pending: "Pendente"
        case .paid: "Pago"
        case .canceled: "Cancelado"
        case .overdue: "Vencido"
        }
    }
}

public enum CategoryType: String, CaseIterable, Codable, Sendable {
    case income
    case expense

    public var label: String {
        switch self {
        case .income: "Receita"
        case .expense: "Despesa"
        }
    }
}

public enum FundMovementType: String, CaseIterable, Codable, Sendable {
    case application
    case withdrawal

    public var label: String {
        switch self {
        case .application: "Aplicação"
        case .withdrawal: "Saque"
        }
    }
}

public enum WishlistPriority: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high

    public var label: String {
        switch self {
        case .low: "Baixa"
        case .medium: "Média"
        case .high: "Alta"
        }
    }
}

/// Escopo de edição/exclusão de séries (espelha `InstallmentEditScope`).
public enum EditScope: String, CaseIterable, Codable, Sendable {
    case thisOne
    case future
    case all

    public var label: String {
        switch self {
        case .thisOne: "Somente esta"
        case .future: "Esta e as próximas"
        case .all: "Todas"
        }
    }
}
