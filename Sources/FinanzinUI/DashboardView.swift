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
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: FinSpacing.md) {
                        ScreenHeader(L10n.t(.summary, store.settings.language)) {
                            SettingsGearButton()
                            PrivacyEyeButton()
                        }
                        MonthPicker(
                            year: $year, month: $month,
                            localeIdentifier: store.lang.localeIdentifier
                        )
                        heroCard
                        statGrid
                        fundsCard
                        if !store.creditCards.isEmpty {
                            invoicesCard
                        }
                        if !budgetRows.isEmpty {
                            budgetsCard
                        }
                        evolutionCard
                        breakdownCard
                        upcomingCard
                    }
                    .padding(.horizontal, FinSpacing.lg)
                    .padding(.bottom, FinSpacing.xl)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
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

    private var heroCard: some View {
        VStack(spacing: FinSpacing.sm) {
            Text(store.t(.dashBalance))
                .font(.caption.bold())
                .foregroundStyle(VercelTheme.textSecondary)
                .textCase(.uppercase)
            Text(store.maskedAmount(metrics.balance))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(VercelTheme.textPrimary)
            HStack(spacing: FinSpacing.sm) {
                heroFlow(store.t(.dashChartIncome), metrics.totalIncome, .green, icon: "arrow.down.left")
                heroFlow(store.t(.dashChartExpense), metrics.totalExpense, .red, icon: "arrow.up.right")
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

    private func heroFlow(_ title: String, _ value: Decimal, _ color: Color, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.bold())
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.caption2).foregroundStyle(VercelTheme.textSecondary)
                Text(store.maskedAmount(value))
                    .font(.subheadline.bold()).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            }
        }
        .padding(.horizontal, FinSpacing.md)
        .padding(.vertical, FinSpacing.sm)
        .background(VercelTheme.inset)
        .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
    }

    // MARK: - Grade secundária

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: FinSpacing.sm) {
            miniStat(store.t(.dashSavings), custom: String(format: "%.0f%%", metrics.savingsRate))
            miniStat(store.t(.dashToReceive), value: metrics.pendingReceivable, color: .green)
            miniStat(store.t(.dashOverdueStat), value: metrics.overdueAmount, color: metrics.overdueAmount > 0 ? .red : nil)
        }
    }

    private func miniStat(_ title: String, value: Decimal? = nil, color: Color? = nil, custom: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2).foregroundStyle(VercelTheme.textSecondary)
            if let custom {
                Text(custom)
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            } else if let value {
                let isZero = (value as NSDecimalNumber).doubleValue == 0
                Text(store.maskedAmount(value))
                    .font(.subheadline.bold()).monospacedDigit()
                    .foregroundStyle(isZero ? VercelTheme.textTertiary : (color ?? VercelTheme.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .finCard()
    }

    // MARK: - Fundos (atalho para a lista completa)

    private var fundsTotal: Decimal {
        store.funds.reduce(Decimal(0)) { $0 + (store.balance(of: $1.id) ?? $1.initialAmount) }
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

    private var invoicesTotal: Decimal {
        invoiceSummaries.reduce(Decimal(0)) { $0 + $1.total }
    }

    private var invoicesCard: some View {
        Button(action: onSelectInvoices) {
            VStack(alignment: .leading, spacing: FinSpacing.sm) {
                HStack {
                    Image(systemName: "creditcard.fill")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)
                    Text(store.t(.dashInvoices))
                        .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
                    Spacer()
                    Text(store.maskedAmount(invoicesTotal))
                        .font(.subheadline.bold()).monospacedDigit()
                        .foregroundStyle(VercelTheme.textPrimary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(VercelTheme.textTertiary)
                }
                if invoiceSummaries.isEmpty {
                    Text(store.t(.dashNoMovement))
                        .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                } else {
                    ForEach(invoiceSummaries.prefix(5), id: \.card.id) { summary in
                        HStack(spacing: FinSpacing.sm) {
                            Circle()
                                .fill(summary.paid ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(summary.card.name)
                                .font(.subheadline)
                                .foregroundStyle(VercelTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(store.maskedAmount(summary.total))
                                .font(.subheadline).monospacedDigit()
                                .foregroundStyle(VercelTheme.textSecondary)
                        }
                        .padding(.vertical, 3)
                    }
                    if invoiceSummaries.count > 5 {
                        Text(String(format: store.t(.dashOthers), invoiceSummaries.count - 5))
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
        Button(action: onSelectBudgets) {
            VStack(alignment: .leading, spacing: FinSpacing.sm) {
                HStack {
                    Text(store.t(.budgets))
                        .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
                    Spacer()
                    Text("\(budgetRows.count)")
                        .font(.caption.bold()).foregroundStyle(VercelTheme.textTertiary)
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(VercelTheme.textTertiary)
                }
                ForEach(budgetRows.prefix(5), id: \.limit.id) { row in
                    budgetLine(row)
                }
                if budgetRows.count > 5 {
                    Text(String(format: store.t(.dashOthers), budgetRows.count - 5))
                        .font(.caption).foregroundStyle(VercelTheme.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .finCard()
    }

    private func budgetLine(_ row: BudgetService.Row) -> some View {
        let cat = store.category(id: row.limit.categoryID)
        let barColor: Color = row.isOver ? .red : row.isWarning ? .orange : .green
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: FinSpacing.sm) {
                Circle()
                    .fill(VercelTheme.hex(cat?.color ?? "#64748b"))
                    .frame(width: 8, height: 8)
                Text(cat?.name ?? store.t(.dashNoCategory))
                    .font(.subheadline)
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                if row.isOver {
                    Text(String(format: store.t(.dashOverBy), store.maskedAmount(row.used - row.limit.limitAmount)))
                        .font(.caption.bold()).monospacedDigit()
                        .foregroundStyle(.red)
                } else {
                    Text(String(format: store.t(.dashLeft), store.maskedAmount(row.remaining)))
                        .font(.caption.bold()).monospacedDigit()
                        .foregroundStyle(row.isWarning ? .orange : VercelTheme.textSecondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(VercelTheme.track)
                        .frame(height: 6)
                    LinearGradient(
                        colors: [barColor.opacity(0.7), barColor],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .frame(width: max(geo.size.width * min(row.percent / 100, 1), row.percent > 0 ? 8 : 0), height: 6)
                }
            }
            .frame(height: 6)
            Text(String(
                format: store.t(.budOfTemplate),
                store.maskedAmount(row.used), store.maskedAmount(row.limit.limitAmount)
            ))
                .font(.caption2)
                .foregroundStyle(VercelTheme.textTertiary)
        }
        .padding(.vertical, 4)
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
                Chart(evolution, id: \.label) { point in
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
        VStack(alignment: .leading, spacing: FinSpacing.sm) {
            Text(store.t(.dashBreakdown))
                .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
            if breakdown.isEmpty {
                Text(store.t(.dashNoExpenses))
                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
            } else {
                HStack(spacing: FinSpacing.lg) {
                    Chart(breakdown, id: \.categoryID) { item in
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
                        Text(store.maskedAmount(breakdownTotal))
                            .font(.headline).monospacedDigit()
                            .foregroundStyle(VercelTheme.textPrimary)
                        Text(String(format: store.t(.dashCategoriesCount), breakdown.count))
                            .font(.caption).foregroundStyle(VercelTheme.textTertiary)
                    }
                    Spacer()
                }
                Divider().background(VercelTheme.border)
                ForEach(breakdown, id: \.categoryID) { item in
                    Button { onSelectCategory(item.categoryID == "none" ? nil : item.categoryID) } label: {
                        HStack(spacing: FinSpacing.sm) {
                            Circle().fill(VercelTheme.hex(item.categoryColor)).frame(width: 10, height: 10)
                            Text(item.categoryName)
                                .font(.subheadline).foregroundStyle(VercelTheme.textPrimary)
                                .lineLimit(1)
                            Spacer()
                            Text(store.maskedAmount(item.total))
                                .font(.subheadline).monospacedDigit()
                                .foregroundStyle(VercelTheme.textSecondary)
                            Text("\(Int(item.percentage))%")
                                .font(.caption.bold()).foregroundStyle(VercelTheme.textTertiary)
                                .frame(width: 42, alignment: .trailing)
                            Image(systemName: "chevron.right")
                                .font(.caption2.bold())
                                .foregroundStyle(VercelTheme.textTertiary)
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .finCard()
    }

    private var breakdownTotal: Decimal {
        breakdown.reduce(Decimal(0)) { $0 + $1.total }
    }

    // MARK: - Próximos 7 dias

    private var upcomingCard: some View {
        VStack(alignment: .leading, spacing: FinSpacing.sm) {
            HStack {
                Text(store.t(.dashUpcoming7))
                    .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
                Spacer()
                if metrics.pendingPayable > 0 {
                    Text(store.maskedAmount(metrics.pendingPayable))
                        .font(.caption.bold()).monospacedDigit()
                        .foregroundStyle(.orange)
                }
            }
            if upcoming.isEmpty {
                Text(store.t(.dashNothingDue))
                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
            } else {
                ForEach(upcoming.prefix(5)) { t in
                    HStack(spacing: FinSpacing.sm) {
                        TintedIcon(
                            t.type == .receivable ? "arrow.down.left" : "arrow.up.right",
                            tint: t.type == .receivable ? .green : .red.opacity(0.85),
                            size: 32
                        )
                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.description)
                                .font(.subheadline).foregroundStyle(VercelTheme.textPrimary)
                                .lineLimit(1)
                            Text(Format.shortDate(t.dueDate, localeIdentifier: store.lang.localeIdentifier))
                                .font(.caption).foregroundStyle(VercelTheme.textTertiary)
                        }
                        Spacer()
                        Text(store.maskedAmount(t.amount))
                            .font(.subheadline.bold()).monospacedDigit()
                            .foregroundStyle(t.type == .receivable ? .green : VercelTheme.textPrimary)
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .finCard()
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
