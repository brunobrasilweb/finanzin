import Foundation

/// Agregações mensais. Portado de `metrics.service.ts` para `Decimal`.
public enum MetricsService {
    public static func monthly(_ all: [FinancialTransaction], year: Int, month: Int) -> MonthlyMetrics {
        var inc: Decimal = 0, exp: Decimal = 0
        var pRec: Decimal = 0, pPay: Decimal = 0
        var overdue: Decimal = 0
        let today = Dates.startOfDay(Date())
        // Passe único: agregados do mês + vencidos globais juntos
        // (antes eram 2 varreduras do array).
        for t in all {
            if t.type == .payable, t.status == .pending, t.dueDate < today {
                overdue += t.amount
            }
            guard Dates.isInMonth(t.dueDate, year: year, month: month) else { continue }
            switch (t.type, t.status) {
            case (.receivable, .paid): inc += t.amount
            case (.payable, .paid): exp += t.amount
            case (.receivable, .pending): pRec += t.amount
            case (.payable, .pending): pPay += t.amount
            default: break
            }
        }
        return MonthlyMetrics(
            totalIncome: inc, totalExpense: exp,
            pendingReceivable: pRec, pendingPayable: pPay,
            overdueAmount: overdue
        )
    }

    public static func breakdown(
        _ all: [FinancialTransaction],
        categories: [FinanceCategory],
        year: Int, month: Int,
        type: TransactionType = .payable
    ) -> [CategoryBreakdown] {
        let byID = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        var totals: [String: Decimal] = [:]
        for t in all where t.type == type && (t.status == .paid || t.status == .pending)
            && Dates.isInMonth(t.dueDate, year: year, month: month)
        {
            totals[t.categoryID ?? "none", default: 0] += t.amount
        }
        let grand = totals.values.reduce(Decimal(0), +)
        let grandD = (grand as NSDecimalNumber).doubleValue
        return totals.map { key, total in
            let cat = byID[key]
            let d = (total as NSDecimalNumber).doubleValue
            return CategoryBreakdown(
                categoryID: key,
                categoryName: cat?.name ?? "Sem categoria",
                categoryColor: cat?.color ?? "#64748b",
                total: total,
                percentage: grandD > 0 ? (d / grandD) * 100 : 0
            )
        }.sorted { $0.total > $1.total }
    }

    public static func evolution(_ all: [FinancialTransaction], months: Int = 6, base: Date = Date(), localeIdentifier: String = "pt_BR") -> [MonthlyEvolution] {
        let comp = Dates.competence(of: base)
        // Alvos ordenados do mais antigo ao atual + índice por competência.
        var targets: [(year: Int, month: Int)] = []
        targets.reserveCapacity(months)
        for i in stride(from: months - 1, through: 0, by: -1) {
            targets.append(Dates.shiftMonth(year: comp.year, month: comp.month, by: -i))
        }
        var indexByKey: [Int: Int] = [:]
        for (i, t) in targets.enumerated() { indexByKey[t.year * 12 + t.month] = i }
        // Passe único sobre as transações (antes: 6 filtros O(6n)).
        var incomes = Array(repeating: Decimal(0), count: targets.count)
        var expenses = Array(repeating: Decimal(0), count: targets.count)
        for t in all where t.status == .paid || t.status == .pending {
            let c = Dates.competence(of: t.dueDate)
            guard let i = indexByKey[c.year * 12 + c.month] else { continue }
            if t.type == .receivable { incomes[i] += t.amount } else { expenses[i] += t.amount }
        }
        return targets.enumerated().map { i, t in
            MonthlyEvolution(
                month: t.month, year: t.year,
                label: Dates.monthLabel(year: t.year, month: t.month, localeIdentifier: localeIdentifier),
                income: incomes[i], expense: expenses[i]
            )
        }
    }

    public static func upcoming(_ all: [FinancialTransaction], days: Int = 7, base: Date = Date()) -> [FinancialTransaction] {
        let start = Dates.startOfDay(base)
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        return all.filter { $0.status == .pending && $0.dueDate >= start && $0.dueDate <= end }
            .sorted { $0.dueDate < $1.dueDate }
    }
}

/// Regras de fundos e orçamentos (puras, testáveis).
public enum AccountService {
    /// Saldo = inicial + recebidas baixadas − pagas baixadas.
    /// Pendentes não entram (são previsão); canceladas nunca compõem.
    public static func balance(account: BankAccount, transactions: [FinancialTransaction]) -> Decimal {
        var bal = account.initialBalance
        for t in transactions where t.accountID == account.id && t.status == .paid {
            if t.type == .receivable { bal += t.amount } else { bal -= t.amount }
        }
        return bal
    }

    /// Saldos de todas as contas em passe único.
    public static func balances(accounts: [BankAccount], transactions: [FinancialTransaction]) -> [String: Decimal] {
        var deltas: [String: Decimal] = [:]
        for t in transactions where t.status == .paid {
            guard let id = t.accountID else { continue }
            deltas[id, default: 0] += (t.type == .receivable ? t.amount : -t.amount)
        }
        var out: [String: Decimal] = [:]
        for account in accounts {
            out[account.id] = account.initialBalance + (deltas[account.id] ?? 0)
        }
        return out
    }
}

public enum FundService {
    public static func balance(fund: Fund, transactions: [FinancialTransaction]) -> Decimal {
        let moves = transactions.filter { $0.fundID == fund.id && $0.status != .canceled }
        var bal = fund.initialAmount
        for t in moves {
            switch t.fundMovementType {
            case .application: bal += t.amount
            case .withdrawal: bal -= t.amount
            case nil:
                // Compat: payable vinculada sem tipo = aplicação.
                if t.type == .payable { bal += t.amount }
            }
        }
        return bal
    }
}

public enum BudgetService {
    public struct Row: Hashable, Sendable {
        public var limit: BudgetLimit
        public var used: Decimal
        public var remaining: Decimal { limit.limitAmount - used }
        public var percent: Double {
            let l = (limit.limitAmount as NSDecimalNumber).doubleValue
            guard l > 0 else { return 0 }
            return ((used as NSDecimalNumber).doubleValue / l) * 100
        }
        public var isOver: Bool { used > limit.limitAmount }
        public var isWarning: Bool { !isOver && percent >= 80 }
    }

    /// Utilizado = soma payable (pendentes + pagas) do mês, por categoria.
    /// Limite único vale só o mês; recorrente vale todos os meses desde o início.
    /// Se houver único + recorrente da mesma categoria no mês, o único prevalece.
    public static func rows(limits: [BudgetLimit], transactions: [FinancialTransaction], year: Int, month: Int) -> [Row] {
        let target = year * 12 + month
        var effective: [String: BudgetLimit] = [:]
        for l in limits {
            if !l.isRecurring {
                guard l.year == year && l.month == month else { continue }
                effective[l.categoryID] = l
            }
        }
        for l in limits where l.isRecurring {
            guard (l.year * 12 + l.month) <= target else { continue }
            // Único do mês tem prioridade sobre o recorrente.
            if effective[l.categoryID] == nil {
                effective[l.categoryID] = l
            }
        }
        // Passe único: soma por categoria só das categorias com limite
        // efetivo (antes: um `filter` O(n) por limite → O(R*n)).
        var usedByCategory: [String: Decimal] = [:]
        if !effective.isEmpty {
            for t in transactions
                where t.type == .payable && (t.status == .paid || t.status == .pending)
                && t.categoryID.map({ effective[$0] != nil }) == true
                && Dates.isInMonth(t.dueDate, year: year, month: month)
            {
                usedByCategory[t.categoryID ?? "", default: 0] += t.amount
            }
        }
        return effective.values.map { l in
            // `used` sai do mapa agrupado em passe único (antes: um
            // `filter` O(n) por limite → O(R*n)).
            Row(limit: l, used: usedByCategory[l.categoryID] ?? 0)
        }
    }
}
