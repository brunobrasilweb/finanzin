import Foundation

/// Regras de fatura do cartão de crédito. Lógica pura (sem persistência).
///
/// A fatura é uma identidade virtual `(cardID, ano, mêsDeVencimento)` —
/// nada é persistido: o `dueDate` da transação JÁ é o vencimento da fatura,
/// então o filtro mensal existente agrupa certo sem mudanças.
///
/// Regra "mesma fatura ou próxima", pela data de fechamento:
/// - compra até o fechamento (inclusive) → fatura que está fechando;
/// - depois → próxima fatura.
/// A fatura é identificada pelo mês do FECHAMENTO; o vencimento cai no
/// mesmo mês (fecha 10/vence 17) ou no seguinte (fecha 28/vence 10).
/// Dias 29-31 valem com clamp para o fim do mês (fev ajusta sozinho).
public enum InvoiceService {
    public struct Invoice: Hashable, Sendable {
        public var cardID: String
        public var year: Int
        public var month: Int
        public var dueDate: Date

        public init(cardID: String, year: Int, month: Int, dueDate: Date) {
            self.cardID = cardID
            self.year = year
            self.month = month
            self.dueDate = dueDate
        }
    }

    /// Data (com clamp para o fim do mês) de um dia em uma competência.
    public static func dayInMonth(year: Int, month: Int, day: Int) -> Date {
        let lastDay = Calendar.current.range(of: .day, in: .month, for: Dates.startOfMonth(year: year, month: month))?.count ?? 28
        let clamped = min(max(day, 1), lastDay)
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: clamped)) ?? Dates.startOfMonth(year: year, month: month)
    }

    /// Vencimento da fatura com clamp para o fim do mês.
    public static func invoiceDueDate(year: Int, month: Int, dueDay: Int) -> Date {
        dayInMonth(year: year, month: month, day: dueDay)
    }

    /// Competência do fechamento: o mês cujo fechamento ainda não passou
    /// na data da compra (o dia do fechamento, inclusive, é da fatura atual).
    static func closingCompetence(purchaseDate: Date, card: CreditCard) -> (year: Int, month: Int) {
        let comp = Dates.competence(of: purchaseDate)
        let closing = dayInMonth(year: comp.year, month: comp.month, day: card.closingDay)
        if Dates.startOfDay(purchaseDate) <= closing { return comp }
        return Dates.shiftMonth(year: comp.year, month: comp.month, by: 1)
    }

    /// Competência do vencimento a partir do fechamento: mesmo mês
    /// (fecha 10/vence 17) ou mês seguinte (fecha 28/vence 10).
    static func dueCompetence(closing: (year: Int, month: Int), card: CreditCard) -> (year: Int, month: Int) {
        guard card.dueDay <= card.closingDay else { return closing }
        return Dates.shiftMonth(year: closing.year, month: closing.month, by: 1)
    }

    /// Fatura de uma compra: mesma ou próxima, pelo dia de fechamento.
    /// `(year, month)` do retorno é a competência do VENCIMENTO.
    public static func invoiceFor(purchaseDate: Date, card: CreditCard) -> Invoice {
        let closing = closingCompetence(purchaseDate: purchaseDate, card: card)
        let due = dueCompetence(closing: closing, card: card)
        return Invoice(
            cardID: card.id, year: due.year, month: due.month,
            dueDate: invoiceDueDate(year: due.year, month: due.month, dueDay: card.dueDay)
        )
    }

    /// Vencimentos das N faturas a partir da compra (1ª pela regra de
    /// fechamento, demais uma por mês seguinte). Usado pelo parcelado.
    public static func invoiceDueDates(purchaseDate: Date, card: CreditCard, count: Int) -> [Date] {
        guard count > 0 else { return [] }
        let firstClosing = closingCompetence(purchaseDate: purchaseDate, card: card)
        return (0 ..< count).map { i in
            let closing = Dates.shiftMonth(year: firstClosing.year, month: firstClosing.month, by: i)
            let due = dueCompetence(closing: closing, card: card)
            return invoiceDueDate(year: due.year, month: due.month, dueDay: card.dueDay)
        }
    }

    /// Transações de uma fatura (cartão + competência do vencimento).
    /// Exclui `canceled` por padrão (não compõe total nem baixa).
    public static func transactions(
        _ all: [FinancialTransaction],
        cardID: String, year: Int, month: Int,
        includeCanceled: Bool = false
    ) -> [FinancialTransaction] {
        all.filter { t in
            guard t.creditCardID == cardID else { return false }
            guard Dates.isInMonth(t.dueDate, year: year, month: month) else { return false }
            if !includeCanceled, t.status == .canceled { return false }
            return true
        }.sorted { $0.dueDate < $1.dueDate }
    }

    /// Total da fatura (soma `paid` + `pending`, exclui `canceled`).
    public static func total(_ invoiceTransactions: [FinancialTransaction]) -> Decimal {
        invoiceTransactions
            .filter { $0.status != .canceled }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    /// Situação da fatura no mês: paga (nada pendente), parcial ou aberta.
    public static func isPaid(_ invoiceTransactions: [FinancialTransaction]) -> Bool {
        let open = invoiceTransactions.filter { $0.status == .pending }
        return !invoiceTransactions.isEmpty && open.isEmpty
    }

    /// Fatura fechada = hoje passou do dia de fechamento.
    /// `(year, month)` é a competência do VENCIMENTO; o fechamento é no
    /// mesmo mês (fecha 10/vence 17) ou no anterior (fecha 28/vence 10).
    /// (Só visual no v1 — não bloqueia lançamentos.)
    public static func isClosed(card: CreditCard, year: Int, month: Int, now: Date = Date()) -> Bool {
        let closingComp: (year: Int, month: Int)
        if card.dueDay > card.closingDay {
            closingComp = (year, month)
        } else {
            closingComp = Dates.shiftMonth(year: year, month: month, by: -1)
        }
        let closing = dayInMonth(year: closingComp.year, month: closingComp.month, day: card.closingDay)
        return Dates.startOfDay(now) > closing
    }

    /// IDs pendentes da fatura (alvo da baixa única).
    public static func pendingIDs(_ invoiceTransactions: [FinancialTransaction]) -> [String] {
        invoiceTransactions.filter { $0.status == .pending }.map(\.id)
    }

    // MARK: - Validação do cartão

    public static func validateCard(
        name: String, closingDay: Int, dueDay: Int,
        language: AppLanguage = .ptBR
    ) -> [String] {
        var errors: [String] = []
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            switch language {
            case .en: errors.append("Card name is required.")
            case .ptBR: errors.append("Nome do cartão é obrigatório.")
            }
        }
        if !(1 ... 31).contains(closingDay) || !(1 ... 31).contains(dueDay) {
            switch language {
            case .en: errors.append("Closing and due days must be between 1 and 31.")
            case .ptBR: errors.append("Fechamento e vencimento devem ser entre 1 e 31.")
            }
        }
        return errors
    }
}
