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
    @State private var showFunds = false

    public init(year: Binding<Int>, month: Binding<Int>, onSelectCategory: @escaping (String?) -> Void, onSelectBudgets: @escaping () -> Void = {}) {
        _year = year
        _month = month
        self.onSelectCategory = onSelectCategory
        self.onSelectBudgets = onSelectBudgets
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView {
                    VStack(alignment: .leading, spacing: FinSpacing.md) {
                        ScreenHeader("Resumo") {
                            PrivacyEyeButton()
                        }
                        MonthPicker(year: $year, month: $month)
                        heroCard
                        statGrid
                        fundsCard
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
        return MetricsService.evolution(store.transactions, months: 6, base: base)
    }

    private var upcoming: [FinancialTransaction] {
        MetricsService.upcoming(store.transactions, days: 7)
    }

    // MARK: - Hero de saldo

    private var heroCard: some View {
        VStack(spacing: FinSpacing.sm) {
            Text("Balanço do mês")
                .font(.caption.bold())
                .foregroundStyle(VercelTheme.textSecondary)
                .textCase(.uppercase)
            Text(store.maskedAmount(metrics.balance))
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(VercelTheme.textPrimary)
            HStack(spacing: FinSpacing.sm) {
                heroFlow("Receitas", metrics.totalIncome, .green, icon: "arrow.down.left")
                heroFlow("Despesas", metrics.totalExpense, .red, icon: "arrow.up.right")
            }
        }
        .frame(maxWidth: .infinity)
        .finCard()
        .overlay(
            RoundedRectangle(cornerRadius: FinRadius.lg, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.22), Color.white.opacity(0.05)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
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
            miniStat("Poupança", custom: String(format: "%.0f%%", metrics.savingsRate))
            miniStat("A receber", value: metrics.pendingReceivable, color: .green)
            miniStat("Vencido", value: metrics.overdueAmount, color: metrics.overdueAmount > 0 ? .red : nil)
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
                    Text("Fundos")
                        .font(.subheadline.bold())
                        .foregroundStyle(VercelTheme.textPrimary)
                    Text(store.funds.isEmpty
                        ? "Nenhum fundo criado"
                        : "\(store.funds.count) fundo(s) · \(store.maskedAmount(fundsTotal))")
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

    // MARK: - Orçamentos do mês (atalho para a lista completa)

    private var budgetRows: [BudgetService.Row] {
        BudgetService.rows(limits: store.budgets, transactions: store.transactions, year: year, month: month)
            .sorted { $0.percent > $1.percent }
    }

    private var budgetsCard: some View {
        Button(action: onSelectBudgets) {
            VStack(alignment: .leading, spacing: FinSpacing.sm) {
                HStack {
                    Text("Orçamentos")
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
                    Text("+\(budgetRows.count - 5) outros")
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
                Text(cat?.name ?? "Categoria removida")
                    .font(.subheadline)
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                Spacer()
                if row.isOver {
                    Text("Estourou \(store.maskedAmount(row.used - row.limit.limitAmount))")
                        .font(.caption.bold()).monospacedDigit()
                        .foregroundStyle(.red)
                } else {
                    Text("Restam \(store.maskedAmount(row.remaining))")
                        .font(.caption.bold()).monospacedDigit()
                        .foregroundStyle(row.isWarning ? .orange : VercelTheme.textSecondary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.08))
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
            Text("\(store.maskedAmount(row.used)) de \(store.maskedAmount(row.limit.limitAmount))")
                .font(.caption2)
                .foregroundStyle(VercelTheme.textTertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Evolução 6 meses

    private var evolutionCard: some View {
        VStack(alignment: .leading, spacing: FinSpacing.sm) {
            Text("Evolução · 6 meses")
                .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
            if evolution.allSatisfy({ ($0.income as NSDecimalNumber).doubleValue == 0 && ($0.expense as NSDecimalNumber).doubleValue == 0 }) {
                VStack(spacing: FinSpacing.sm) {
                    Image(systemName: "chart.bar.fill")
                        .font(.title)
                        .foregroundStyle(VercelTheme.textTertiary)
                    Text("Sem movimentações no período.")
                        .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Chart(evolution, id: \.label) { point in
                    BarMark(
                        x: .value("Mês", point.label),
                        y: .value("Valor", (point.income as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(by: .value("Tipo", "Receitas"))
                    .position(by: .value("Tipo", "Receitas"))
                    .cornerRadius(4)
                    BarMark(
                        x: .value("Mês", point.label),
                        y: .value("Valor", (point.expense as NSDecimalNumber).doubleValue)
                    )
                    .foregroundStyle(by: .value("Tipo", "Despesas"))
                    .position(by: .value("Tipo", "Despesas"))
                    .cornerRadius(4)
                }
                .chartForegroundStyleScale([
                    "Receitas": Color.green.gradient,
                    "Despesas": Color.red.gradient,
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
            Text("Despesas por categoria")
                .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
            if breakdown.isEmpty {
                Text("Nenhuma despesa no mês.")
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
                        Text("Total")
                            .font(.caption).foregroundStyle(VercelTheme.textSecondary)
                        Text(store.maskedAmount(breakdownTotal))
                            .font(.headline).monospacedDigit()
                            .foregroundStyle(VercelTheme.textPrimary)
                        Text("\(breakdown.count) categorias")
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
                Text("Próximos 7 dias")
                    .font(.subheadline.bold()).foregroundStyle(VercelTheme.textPrimary)
                Spacer()
                if metrics.pendingPayable > 0 {
                    Text(store.maskedAmount(metrics.pendingPayable))
                        .font(.caption.bold()).monospacedDigit()
                        .foregroundStyle(.orange)
                }
            }
            if upcoming.isEmpty {
                Text("Nada vencendo nos próximos 7 dias. 🎉")
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
                            Text(Format.shortDate(t.dueDate))
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
