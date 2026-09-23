import Foundation

/// Motor de regras de transações. Lógica pura (sem persistência),
/// portada de `inofinancy/src/services/transaction.service.ts`.
public enum TransactionEngine {
    /// Horizonte de geração para fixa/recorrente (igual `RECURRING_HORIZON_MONTHS`).
    public static let recurringHorizonMonths = 24

    public struct CreateInput: Sendable {
        public var description: String
        public var type: TransactionType
        public var categoryID: String?
        public var amount: Decimal
        public var recurrence: RecurrenceType
        public var dueDate: Date
        public var notes: String?
        public var totalInstallments: Int?
        public var interval: InstallmentInterval?
        public var fundID: String?
        public var fundMovementType: FundMovementType?

        public init(
            description: String, type: TransactionType, categoryID: String? = nil,
            amount: Decimal, recurrence: RecurrenceType = .unique, dueDate: Date = Date(),
            notes: String? = nil, totalInstallments: Int? = nil,
            interval: InstallmentInterval? = nil, fundID: String? = nil,
            fundMovementType: FundMovementType? = nil
        ) {
            self.description = description
            self.type = type
            self.categoryID = categoryID
            self.amount = amount
            self.recurrence = recurrence
            self.dueDate = dueDate
            self.notes = notes
            self.totalInstallments = totalInstallments
            self.interval = interval
            self.fundID = fundID
            self.fundMovementType = fundMovementType
        }
    }

    /// Cria a transação raiz + filhas (parcelas ou recorrências futuras).
    /// Retorna todas para o `Store` persistir de uma vez.
    public static func expand(_ input: CreateInput) -> [FinancialTransaction] {
        let trimmed = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        let root = FinancialTransaction(
            description: trimmed,
            type: input.type,
            recurrence: input.recurrence,
            categoryID: input.categoryID,
            totalAmount: input.amount,
            amount: input.recurrence == .installment ? (Currency.split(input.amount, into: max(input.totalInstallments ?? 1, 1)).first ?? input.amount) : input.amount,
            installmentCount: input.totalInstallments ?? 1,
            currentInstallment: input.recurrence == .installment ? 1 : nil,
            installmentInterval: input.interval,
            dueDate: input.dueDate,
            notes: input.notes,
            fundID: input.fundID,
            fundMovementType: input.fundMovementType
        )

        switch input.recurrence {
        case .unique:
            return [root]
        case .installment:
            return expandInstallments(root: root, input: input)
        case .fixed, .recurring:
            return [root] + expandRecurring(root: root, input: input)
        }
    }

    private static func expandInstallments(root: FinancialTransaction, input: CreateInput) -> [FinancialTransaction] {
        let count = max(input.totalInstallments ?? 1, 1)
        guard count > 1, let interval = input.interval else { return [root] }
        let amounts = Currency.split(input.amount, into: count)
        let dates = Dates.installmentDates(from: input.dueDate, count: count, interval: interval)
        var out: [FinancialTransaction] = []
        for i in 0 ..< count {
            if i == 0 {
                var first = root
                first.amount = amounts[0]
                first.dueDate = dates[0]
                out.append(first)
            } else {
                out.append(FinancialTransaction(
                    description: root.description,
                    type: root.type,
                    recurrence: .installment,
                    categoryID: root.categoryID,
                    totalAmount: input.amount,
                    amount: amounts[i],
                    installmentCount: count,
                    currentInstallment: i + 1,
                    installmentInterval: interval,
                    dueDate: dates[i],
                    notes: root.notes,
                    parentID: root.id,
                    fundID: root.fundID,
                    fundMovementType: root.fundMovementType
                ))
            }
        }
        return out
    }

    private static func expandRecurring(root: FinancialTransaction, input: CreateInput) -> [FinancialTransaction] {
        let interval: InstallmentInterval = input.recurrence == .fixed ? .monthly : (input.interval ?? .monthly)
        var out: [FinancialTransaction] = []
        for i in 1 ... recurringHorizonMonths {
            out.append(FinancialTransaction(
                description: root.description,
                type: root.type,
                recurrence: input.recurrence,
                categoryID: root.categoryID,
                totalAmount: input.amount,
                amount: input.amount,
                installmentCount: 1,
                installmentInterval: interval,
                dueDate: Dates.addPeriod(input.dueDate, interval: interval, steps: i),
                notes: root.notes,
                parentID: root.id,
                fundID: root.fundID,
                fundMovementType: root.fundMovementType
            ))
        }
        return out
    }

    // MARK: - Validação (Sprint 1: à vista)

    /// Retorna lista de erros em pt-BR; vazia = válido.
    public static func validate(description: String, amount: Decimal) -> [String] {
        var errors: [String] = []
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Descrição é obrigatória.")
        }
        if (amount as NSDecimalNumber).doubleValue < 0 {
            errors.append("Valor não pode ser negativo.")
        }
        return errors
    }

    /// Valida série parcelada/recorrente. Retorna erros em pt-BR.
    public static func validateSeries(recurrence: RecurrenceType, count: Int?, interval: InstallmentInterval?) -> [String] {
        switch recurrence {
        case .unique, .fixed:
            return []
        case .installment:
            var errors: [String] = []
            if (count ?? 0) < 2 { errors.append("Parcelamento precisa de ao menos 2 parcelas.") }
            if interval == nil { errors.append("Escolha o intervalo das parcelas.") }
            return errors
        case .recurring:
            // Intervalo tem padrão mensal; nada obrigatório.
            return []
        }
    }

    // MARK: - Filtros e escopos

    public static func filter(
        _ all: [FinancialTransaction],
        year: Int, month: Int,
        type: TransactionType? = nil,
        status: TransactionStatus? = nil,
        categoryID: String? = nil,
        search: String? = nil
    ) -> [FinancialTransaction] {
        all.filter { t in
            guard Dates.isInMonth(t.dueDate, year: year, month: month) else { return false }
            if let type, t.type != type { return false }
            if let status, t.status != status { return false }
            if let categoryID, t.categoryID != categoryID { return false }
            if let q = search?.lowercased(), !q.isEmpty {
                let hay = (t.description + " " + (t.notes ?? "")).lowercased()
                guard hay.contains(q) else { return false }
            }
            return true
        }.sorted { $0.dueDate < $1.dueDate }
    }

    /// Resolve IDs afetados por edição/exclusão com escopo (espelha Inofinancy).
    /// - `.thisOne`: só o lançamento tocado.
    /// - `.all`: raiz + todas as filhas da série.
    /// - `.future`: alvo + próximas (parceladas: por nº da parcela;
    ///   fixas/recorrentes: por vencimento, pois não têm numeração).
    public static func resolveScopeIDs(
        all: [FinancialTransaction],
        targetID: String,
        scope: EditScope
    ) -> [String] {
        guard let target = all.first(where: { $0.id == targetID }) else { return [] }
        if scope == .thisOne { return [targetID] }
        let parentID = target.parentID ?? target.id
        // Toda a série: raiz + filhas ligadas a ela.
        let series = all.filter { $0.id == parentID || $0.parentID == parentID }
        if scope == .all { return series.map(\.id) }
        // scope == .future
        if target.recurrence == .installment {
            let current = target.currentInstallment ?? 1
            return series.filter { member in
                if member.id == target.id { return true }
                if let n = member.currentInstallment {
                    // Raiz vale 1; filhas 2...N. Passadas têm nº menor.
                    return n >= current
                }
                // Sem numeração (legado): desempata pelo vencimento.
                return member.dueDate >= target.dueDate
            }.map(\.id)
        }
        // Fixa / recorrente: ordena por vencimento.
        return series.filter { $0.dueDate >= target.dueDate }.map(\.id)
    }

    public static func toggling(_ t: FinancialTransaction, to status: TransactionStatus) -> FinancialTransaction {
        var copy = t
        copy.status = status
        copy.paidDate = status == .paid ? Date() : nil
        return copy
    }

    /// Baixa com valor e data informados (permite juros/desconto e data diferente
    /// do vencimento). Retorna cópia com `status == .paid`.
    public static func settling(_ t: FinancialTransaction, amount: Decimal, paidDate: Date) -> FinancialTransaction {
        var copy = t
        copy.status = .paid
        copy.amount = amount
        // Conta única: total acompanha o valor baixado; parcelada/fixa/recorrente
        // preserva o total original da série.
        if copy.recurrence == .unique {
            copy.totalAmount = amount
        }
        copy.paidDate = paidDate
        return copy
    }

    /// Validação da baixa: valor não negativo.
    public static func validateSettle(amount: Decimal) -> [String] {
        if (amount as NSDecimalNumber).doubleValue < 0 {
            return ["Valor da baixa não pode ser negativo."]
        }
        return []
    }
}
