import Foundation

/// Tipo de transação: a pagar ou a receber.
/// Espelha `FinancialTransactionType` do admin + `TransactionType` do Inofinancy.
public enum TransactionType: String, CaseIterable, Codable, Sendable {
    case receivable
    case payable

    public var label: String { label(language: .ptBR) }

    public func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.receivable, .en): "Receivable"
        case (.payable, .en): "Payable"
        case (.receivable, .ptBR): "A Receber"
        case (.payable, .ptBR): "A Pagar"
        }
    }
}

/// Recorrência. `unique` == `single` do Inofinancy (mapeado na importação).
public enum RecurrenceType: String, CaseIterable, Codable, Sendable {
    case unique
    case fixed
    case recurring
    case installment

    public var label: String { label(language: .ptBR) }

    public func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.unique, .en): "One-time"
        case (.fixed, .en): "Fixed"
        case (.recurring, .en): "Recurring"
        case (.installment, .en): "Installments"
        case (.unique, .ptBR): "Única"
        case (.fixed, .ptBR): "Fixa"
        case (.recurring, .ptBR): "Recorrente"
        case (.installment, .ptBR): "Parcelada"
        }
    }
}

public enum InstallmentInterval: String, CaseIterable, Codable, Sendable {
    case weekly
    case biweekly
    case monthly
    case yearly

    public var label: String { label(language: .ptBR) }

    public func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.weekly, .en): "Weekly"
        case (.biweekly, .en): "Biweekly"
        case (.monthly, .en): "Monthly"
        case (.yearly, .en): "Yearly"
        case (.weekly, .ptBR): "Semanal"
        case (.biweekly, .ptBR): "Quinzenal"
        case (.monthly, .ptBR): "Mensal"
        case (.yearly, .ptBR): "Anual"
        }
    }
}

public enum TransactionStatus: String, CaseIterable, Codable, Sendable {
    case pending
    case paid
    case canceled
    case overdue

    public var label: String { label(language: .ptBR) }

    public func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.pending, .en): "Pending"
        case (.paid, .en): "Paid"
        case (.canceled, .en): "Canceled"
        case (.overdue, .en): "Overdue"
        case (.pending, .ptBR): "Pendente"
        case (.paid, .ptBR): "Pago"
        case (.canceled, .ptBR): "Cancelado"
        case (.overdue, .ptBR): "Vencido"
        }
    }
}

public enum CategoryType: String, CaseIterable, Codable, Sendable {
    case income
    case expense

    public var label: String { label(language: .ptBR) }

    public func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.income, .en): "Income"
        case (.expense, .en): "Expense"
        case (.income, .ptBR): "Receita"
        case (.expense, .ptBR): "Despesa"
        }
    }
}

public enum FundMovementType: String, CaseIterable, Codable, Sendable {
    case application
    case withdrawal

    public var label: String { label(language: .ptBR) }

    public func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.application, .en): "Deposit"
        case (.withdrawal, .en): "Withdrawal"
        case (.application, .ptBR): "Aplicação"
        case (.withdrawal, .ptBR): "Saque"
        }
    }
}

public enum WishlistPriority: String, CaseIterable, Codable, Sendable {
    case low
    case medium
    case high

    public var label: String { label(language: .ptBR) }

    public func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.low, .en): "Low"
        case (.medium, .en): "Medium"
        case (.high, .en): "High"
        case (.low, .ptBR): "Baixa"
        case (.medium, .ptBR): "Média"
        case (.high, .ptBR): "Alta"
        }
    }
}

/// Escopo de edição/exclusão de séries (espelha `InstallmentEditScope`).
public enum EditScope: String, CaseIterable, Codable, Sendable {
    case thisOne
    case future
    case all

    public var label: String { label(language: .ptBR) }

    public func label(language: AppLanguage) -> String {
        switch (self, language) {
        case (.thisOne, .en): "This one only"
        case (.future, .en): "This and following"
        case (.all, .en): "All"
        case (.thisOne, .ptBR): "Somente esta"
        case (.future, .ptBR): "Esta e as próximas"
        case (.all, .ptBR): "Todas"
        }
    }
}
