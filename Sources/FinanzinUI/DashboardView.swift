import Charts
import SwiftUI
import FinanzinCore

// MARK: - Dashboard mensal (Sprint 6)

public struct DashboardView: View {
    @EnvironmentObject var store: Store
    @Binding var year: Int
    @Binding var month: Int
    var onSelectCategory: (String?) -> Void
    var onSelectBudgets: () -> Void = {}
    var onSelectInvoices: () -> Void = {}
    @State private var showFunds = false

    public init(year: Binding<Int>, month: Binding<Int>, onSelectCategory: @escaping (String?) -> Void, onSelectBudgets: @escaping () -> Void = {}, onSelectInvoices: @escaping () -> Void = {}) {
        _year = year
        _month = month
        self.onSelectCategory = onSelectCategory
        self.onSelectBudgets = onSelectBudgets
        self.onSelectInvoices = onSelectInvoices
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                // `metrics` avaliado UMA vez por `body` (antes: cada card
                // reexecutava `MetricsService.monthly` → 7 varreduras).
                let m = metrics
                VStack(alignment: .leading, spacing: FinSpacing.md) {
                    ScreenHeader(L10n.t(.summary, store.settings.language)) {
                        SettingsGearButton()
                        PrivacyEyeButton()
                    }
                    MonthPicker(
                        year: $year, month: $month,
                        localeIdentifier: store.lang.localeIdentifier
                    )
                    heroCard(m)
                    statGrid(m)
                    fundsCard
                    if !store.creditCards.isEmpty {
                        invoicesCard
                    }
                    if !budgetRows.isEmpty {
                        budgetsCard
                    }
                    evolutionCard
                    breakdownCard
                    upcomingCard(m)
                }
                .padding(.horizontal, FinSpacing.lg)
                .padding(.bottom, FinSpacing.xl)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .finBackground()
            .finHideNavBar()
            .sheet(isPresented: $showFunds) {
                FundListView(showClose: true)
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Dados

    private var metrics: MonthlyMetrics {
        MetricsService.monthly(store.transactions, year: year, month: month)
    }

    private var breakdown: [CategoryBreakdown] {
        MetricsService.breakdown(
            store.transactions, categories: store.categories,
            year: year, month: month
        )
    }

    private var evolution: [MonthlyEvolution] {
        let base = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        return MetricsService.evolution(
            store.transactions, months: 6, base: base,
            localeIdentifier: store.lang.localeIdentifier
        )
    }

    private var upcoming: [FinancialTransaction] {
        MetricsService.upcoming(store.transactions, days: 7)
    }

    // MARK: - Hero de saldo

    private func heroCard(_ m: MonthlyMetrics) -> some View {
        VStack(spacing: FinSpacing.sm) {
            Text(store.t(.dashBalance))
                .font(.caption.bold())
                .foregroundStyle(VercelTheme.textSecondary)
                .textCase(.uppercase)
            Text(store.maskedAmount(m.balance))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(VercelTheme.textPrimary)
            HStack(spacing: FinSpacing.sm) {
                HeroFlow(title: store.t(.dashChartIncome), valueText: store.maskedAmount(m.totalIncome), color: .green, icon: "arrow.down.left")
                HeroFlow(title: store.t(.dashChartExpense), valueText: store.maskedAmount(m.totalExpense), color: .red, icon: "arrow.up.right")
            }
        }
        .frame(maxWidth: .infinity)
        .finCard()
        .overlay(
            RoundedRectangle(cornerRadius: FinRadius.lg, style: .continuous)
                .stroke(
                    VercelTheme.edgeHighlight,
                    lineWidth: 1
                )
        )
    }

    // MARK: - Grade secundária

    private func statGrid(_ m: MonthlyMetrics) -> some View {
        let recvText = store.maskedAmount(m.pendingReceivable)
        let overText = store.maskedAmount(m.overdueAmount)
        let recvZero = m.pendingReceivable == 0
        let overZero = m.overdueAmount == 0
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FinSpacing.sm) {
            MiniStat(title: store.t(.dashSavings), custom: String(format: "%.0f%%", m.savingsRate))
            MiniStat(title: store.t(.dashToReceive), valueText: recvText, dimmed: recvZero, color: .green)
            MiniStat(title: store.t(.dashOverdueStat), valueText: overText, dimmed: overZero, color: overZero ? nil : .red)
        }
    }

    // MARK: - Fundos (atalho para a lista completa)

    private var fundsTotal: Decimal {
        let balances = store.fundBalances()
        return store.funds.reduce(Decimal(0)) { $0 + (balances[$1.id] ?? $1.initialAmount) }
    }

    private var fundsCard: some View {
        Button { showFunds = true } label: {
            HStack(spacing: FinSpacing.md) {
                TintedIcon("chart.pie.fill", tint: .purple, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.t(.funds))
                        .font(.subheadline.bold())
                        .foregroundStyle(VercelTheme.textPrimary)
                    Text(store.funds.isEmpty
                        ? store.t(.dashNoFunds)
                        : String(format: store.t(.dashFundsSummary), store.funds.count, store.maskedAmount(fundsTotal)))
                        .font(.caption).foregroundStyle(VercelTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(VercelTheme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .finCard()
    }

    // MARK: - Faturas dos cartões (atalho para Transações)

    private struct InvoiceSummary {
        var card: CreditCard
        var total: Decimal
        var paid: Bool
    }

    /// Um resumo por cartão com lançamentos no mês + total geral.
    private var invoiceSummaries: [InvoiceSummary] {
        store.creditCards
            .sorted { $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending }
            .compactMap { card in
                let items = store.invoiceTransactions(cardID: card.id, year: year, month: month)
                guard !items.isEmpty else { return nil }
                return InvoiceSummary(
                    card: card,
                    total: InvoiceService.total(items),
                    paid: InvoiceService.isPaid(items)
                )
            }
    }

    private var invoicesCard: some View {
        // Avalia os resumos uma única vez por `body` (antes: 3+ varreduras).
        let summaries = invoiceSummaries
        let total = summaries.reduce(Decimal(0)) { $0 + $1.total }
        return Button(action: onSelectInvoices) {
            VStack(alignment: .leading, spacing: FinSpacing.sm) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    Text(store.t(.dashInvoices))
                        .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
                    Spacer()
                    Text(store.maskedAmount(total))
                        .font(.subheadline.bold()).monospacedDigit()
                        .foregroundStyle(VercelTheme.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(VercelTheme.textTertiary)
                }
                if summaries.isEmpty {
                    Text(store.t(.dashNoMovement))
                        .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                } else {
                    ForEach(Array(summaries.prefix(5)), id: \.card.id) { summary in
                        InvoiceSummaryRow(
                            name: summary.card.name,
                            totalText: store.maskedAmount(summary.total),
                            paid: summary.paid
                        )
                    }
                    if summaries.count > 5 {
                        Text(String(format: store.t(.dashOthers), summaries.count - 5))
                            .font(.caption).foregroundStyle(VercelTheme.textTertiary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .finCard()
    }

    // MARK: - Orçamentos do mês (atalho para a lista completa)

    private var budgetRows: [BudgetService.Row] {
        BudgetService.rows(limits: store.budgets, transactions: store.transactions, year: year, month: month)
            .sorted { $0.percent > $1.percent }
    }

    private var budgetsCard: some View {
        // `budgetRows` avaliado uma vez; linhas recebem só strings prontas.
        let rows = budgetRows
        let categories = Dictionary(uniqueKeysWithValues: store.categories.map { ($0.id, $0) })
        let currencyCode = store.settings.currency.currencyCode
        let localeID = store.settings.currency.localeIdentifier
        let hidden = store.valuesHidden
        let noCategory = store.t(.dashNoCategory)
        let ofTemplate = store.t(.budOfTemplate)
        let overBy = store.t(.dashOverBy)
        let left = store.t(.dashLeft)
        return Button(action: onSelectBudgets) {
            VStack(alignment: .leading, spacing: FinSpacing.sm) {
                HStack {
                    Text(store.t(.budgets))
                        .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
                    Spacer()
                    Text("\(rows.count)")
                        .font(.caption.bold()).foregroundStyle(VercelTheme.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(VercelTheme.textTertiary)
                }
                ForEach(Array(rows.prefix(5)), id: \.limit.id) { row in
                    let cat = categories[row.limit.categoryID]
                    let usedText = hidden ? "••••••" : Currency.format(row.used, currencyCode: currencyCode, localeIdentifier: localeID)
                    let limitText = hidden ? "••••••" : Currency.format(row.limit.limitAmount, currencyCode: currencyCode, localeIdentifier: localeID)
                    let over = hidden ? "••••••" : Currency.format(row.used - row.limit.limitAmount, currencyCode: currencyCode, localeIdentifier: localeID)
                    let rem = hidden ? "••••••" : Currency.format(row.remaining, currencyCode: currencyCode, localeIdentifier: localeID)
                    BudgetLineRow(
                        title: cat?.name ?? noCategory,
                        colorHex: cat?.color ?? "#64748b",
                        statusText: row.isOver ? String(format: overBy, over) : String(format: left, rem),
                        statusColor: row.isOver ? .red : (row.isWarning ? .orange : nil),
                        detailText: String(format: ofTemplate, usedText, limitText),
                        fraction: row.percent / 100
                    )
                }
                if rows.count > 5 {
                    Text(String(format: store.t(.dashOthers), rows.count - 5))
                        .font(.caption).foregroundStyle(VercelTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .finCard()
    }

    // MARK: - Evolução 6 meses

    private var evolutionCard: some View {
        let incomeLabel = store.t(.dashChartIncome)
        let expenseLabel = store.t(.dashChartExpense)
        return VStack(alignment: .leading, spacing: FinSpacing.sm) {
            Text(store.t(.dashEvolution))
                .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
            if evolution.allSatisfy({ ($0.income as NSDecimalNumber).doubleValue == 0 && ($0.expense as NSDecimalNumber).doubleValue == 0 }) {
                VStack(spacing: FinSpacing.sm) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title)
                        .foregroundStyle(VercelTheme.textTertiary)
                    Text(store.t(.dashNoMovement))
                        .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(evolution, id: \.stableID) { point in
                    BarMark(
                        x: .value("Mês", point.label),
                        y: .value("Valor", (point.income as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(by: .value("Tipo", incomeLabel))
                    .position(by: .value("Tipo", incomeLabel))
                    .cornerRadius(4)
                    BarMark(
                        x: .value("Mês", point.label),
                        y: .value("Valor", (point.expense as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(by: .value("Tipo", expenseLabel))
                    .position(by: .value("Tipo", expenseLabel))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale([
                    incomeLabel: Color.green.gradient,
                    expenseLabel: Color.red.gradient,
                ])
                .chartXAxis { AxisMarks { AxisValueLabel().foregroundStyle(VercelTheme.textTertiary).font(.caption2) } }
                .chartYAxisHidden(store.valuesHidden)
                .chartLegend(position: .bottom, alignment: .leading, spacing: FinSpacing.sm)
                .frame(minHeight: 180, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .finCard()
    }

    // MARK: - Donut por categoria

    private var breakdownCard: some View {
        // Total avaliado uma vez (antes: `breakdown` + `reduce` por acesso).
        let items = breakdown
        let total = items.reduce(Decimal(0)) { $0 + $1.total }
        return VStack(alignment: .leading, spacing: FinSpacing.sm) {
            Text(store.t(.dashBreakdown))
                .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
            if items.isEmpty {
                Text(store.t(.dashNoExpenses))
                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
            } else {
                HStack(spacing: FinSpacing.lg) {
                    Chart(items, id: \.categoryID) { item in
                        SectorMark(
                            angle: .value("Total", (item.total as NSDecimalNumber).doubleValue),
                            innerRadius: .ratio(0.64),
                            angularInset: 2
                        )
                        .foregroundStyle(VercelTheme.hex(item.categoryColor))
                    }
                    .frame(width: 128, height: 128)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.t(.dashTotal))
                            .font(.caption).foregroundStyle(VercelTheme.textSecondary)
                        Text(store.maskedAmount(total))
                            .font(.headline).monospacedDigit()
                            .foregroundStyle(VercelTheme.textPrimary)
                        Text(String(format: store.t(.dashCategoriesCount), items.count))
                            .font(.caption).foregroundStyle(VercelTheme.textTertiary)
                    }
                    Spacer()
                }
                Divider().background(VercelTheme.border)
                ForEach(items, id: \.categoryID) { item in
                    Button { onSelectCategory(item.categoryID == "none" ? nil : item.categoryID) } label: {
                        BreakdownRow(
                            colorHex: item.categoryColor,
                            name: item.categoryName,
                            totalText: store.maskedAmount(item.total),
                            percent: Int(item.percentage)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .finCard()
    }

    // MARK: - Próximos 7 dias

    private func upcomingCard(_ m: MonthlyMetrics) -> some View {
        // Strings prontas por linha; a row recebe só `let`s (sem `store`).
        let items = Array(upcoming.prefix(5))
        let localeID = store.lang.localeIdentifier
        let currencyCode = store.settings.currency.currencyCode
        let hidden = store.valuesHidden
        let pending = m.pendingPayable
        return VStack(alignment: .leading, spacing: FinSpacing.sm) {
            HStack {
                Text(store.t(.dashUpcoming7))
                    .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
                Spacer()
                if pending > 0 {
                    Text(store.maskedAmount(pending))
                        .font(.caption.bold()).monospacedDigit()
                        .foregroundStyle(.orange)
                }
            }
            if items.isEmpty {
                Text(store.t(.dashNothingDue))
                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
            } else {
                ForEach(items) { t in
                    UpcomingRow(
                        title: t.description,
                        dateText: Format.shortDate(t.dueDate, localeIdentifier: localeID),
                        amountText: hidden ? "••••••" : Currency.format(t.amount, currencyCode: currencyCode, localeIdentifier: localeID),
                        isIncome: t.type == .receivable
                    )
                }
            }
        }
        .finCard()
    }
}

// MARK: - Linhas estreitas (só `let`s: sem `@EnvironmentObject`, sem re-query)

private struct HeroFlow: View {
    let title: String
    let valueText: String
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(VercelTheme.textSecondary)
                Text(valueText)
                    .font(.subheadline.bold()).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            }
        }
        .padding(.horizontal, FinSpacing.md)
        .padding(.vertical, FinSpacing.sm)
        .background(VercelTheme.inset)
        .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
    }
}

private struct MiniStat: View {
    let title: String
    var valueText: String? = nil
    var dimmed: Bool = false
    var color: Color? = nil
    var custom: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(VercelTheme.textSecondary)
            if let custom {
                Text(custom)
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            } else if let valueText {
                Text(valueText)
                    .font(.subheadline.bold()).monospacedDigit()
                    .foregroundStyle(dimmed ? VercelTheme.textTertiary : (color ?? VercelTheme.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .finCard()
    }
}

private struct InvoiceSummaryRow: View {
    let name: String
    let totalText: String
    let paid: Bool

    var body: some View {
        HStack(spacing: FinSpacing.sm) {
            Circle()
                .fill(paid ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(name)
                .font(.subheadline)
                .foregroundStyle(VercelTheme.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(totalText)
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(VercelTheme.textSecondary)
        }
        .padding(.vertical, 3)
    }
}

private struct BudgetLineRow: View {
    let title: String
    let colorHex: String
    let statusText: String
    let statusColor: Color?
    let detailText: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: FinSpacing.sm) {
                Circle()
                    .fill(VercelTheme.hex(colorHex))
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text(statusText)
                    .font(.caption.bold()).monospacedDigit()
                    .foregroundStyle(statusColor ?? VercelTheme.textSecondary)
            }
            FinProgressBar(
                fraction: fraction,
                color: statusColor == .red ? .red : (statusColor == .orange ? .orange : .green),
                height: 6
            )
            Text(detailText)
                .font(.caption2)
                .foregroundStyle(VercelTheme.textTertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct BreakdownRow: View {
    let colorHex: String
    let name: String
    let totalText: String
    let percent: Int

    var body: some View {
        HStack(spacing: FinSpacing.sm) {
            Circle().fill(VercelTheme.hex(colorHex)).frame(width: 10, height: 10)
            Text(name)
                .font(.subheadline).foregroundStyle(VercelTheme.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(totalText)
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(VercelTheme.textSecondary)
            Text("\(percent)%")
                .font(.caption.bold()).foregroundStyle(VercelTheme.textTertiary)
                .frame(width: 42, alignment: .trailing)
            Image(systemName: "chevron.right")
                .font(.caption2.bold())
                .foregroundStyle(VercelTheme.textTertiary)
        }
        .padding(.vertical, 5)
    }
}

private struct UpcomingRow: View {
    let title: String
    let dateText: String
    let amountText: String
    let isIncome: Bool

    var body: some View {
        HStack(spacing: FinSpacing.sm) {
            TintedIcon(
                isIncome ? "arrow.down.left" : "arrow.up.right",
                tint: isIncome ? .green : .red.opacity(0.85),
                size: 32
            )
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.subheadline).foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                Text(dateText)
                    .font(.caption).foregroundStyle(VercelTheme.textTertiary)
            }
            Spacer()
            Text(amountText)
                .font(.subheadline.bold()).monospacedDigit()
                .foregroundStyle(isIncome ? .green : VercelTheme.textPrimary)
        }
        .padding(.vertical, 3)
    }
}

// MARK: - Eixo Y condicional (modo privado esconde a escala de valores)

private extension View {
    @ViewBuilder
    func chartYAxisHidden(_ hidden: Bool) -> some View {
        if hidden {
            self.chartYAxis(.hidden)
        } else {
            self.chartYAxis {
                AxisMarks {
                    AxisValueLabel()
                        .foregroundStyle(VercelTheme.textTertiary)
                        .font(.caption2)
                }
            }
        }
    }
}
