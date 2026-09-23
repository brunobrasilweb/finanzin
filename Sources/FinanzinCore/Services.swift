import Foundation

/// Agregações mensais. Portado de `metrics.service.ts` para `Decimal`.
public enum MetricsService {
    public static func monthly(_ all: [FinancialTransaction], year: Int, month: Int) -> MonthlyMetrics {
        var inc: Decimal = 0, exp: Decimal = 0
        var pRec: Decimal = 0, pPay: Decimal = 0
        for t in all where Dates.isInMonth(t.dueDate, year: year, month: month) {
            switch (t.type, t.status) {
            case (.receivable, .paid): inc += t.amount
            case (.payable, .paid): exp += t.amount
            case (.receivable, .pending): pRec += t.amount
            case (.payable, .pending): pPay += t.amount
            default: break
            }
        }
        let today = Dates.startOfDay(Date())
        let overdue = all
            .filter { $0.type == .payable && $0.status == .pending && $0.dueDate < today }
            .reduce(Decimal(0)) { $0 + $1.amount }
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
        }.sorted { ($0.total as NSDecimalNumber).doubleValue > ($1.total as NSDecimalNumber).doubleValue }
    }

    public static func evolution(_ all: [FinancialTransaction], months: Int = 6, base: Date = Date()) -> [MonthlyEvolution] {
        let comp = Dates.competence(of: base)
        var out: [MonthlyEvolution] = []
        for i in stride(from: months - 1, through: 0, by: -1) {
            let (y, m) = Dates.shiftMonth(year: comp.year, month: comp.month, by: -i)
            var inc: Decimal = 0, exp: Decimal = 0
            for t in all where Dates.isInMonth(t.dueDate, year: y, month: m)
                && (t.status == .paid || t.status == .pending)
            {
                if t.type == .receivable { inc += t.amount } else { exp += t.amount }
            }
            out.append(MonthlyEvolution(month: m, year: y, label: Dates.monthLabel(year: y, month: m), income: inc, expense: exp))
        }
        return out
    }

    public static func upcoming(_ all: [FinancialTransaction], days: Int = 7, base: Date = Date()) -> [FinancialTransaction] {
        let start = Dates.startOfDay(base)
        let end = Calendar.current.date(byAdding: .day, value: days, to: start) ?? start
        return all.filter { $0.status == .pending && $0.dueDate >= start && $0.dueDate <= end }
            .sorted { $0.dueDate < $1.dueDate }
    }
}

/// Regras de fundos e orçamentos (puras, testáveis).
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
        return effective.values.map { l in
            let used = transactions
                .filter {
                    $0.type == .payable && ($0.status == .paid || $0.status == .pending)
                        && $0.categoryID == l.categoryID
                        && Dates.isInMonth($0.dueDate, year: year, month: month)
                }
                .reduce(Decimal(0)) { $0 + $1.amount }
            return Row(limit: l, used: used)
        }
    }
}
