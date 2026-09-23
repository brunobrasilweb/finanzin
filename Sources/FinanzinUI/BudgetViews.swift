import SwiftUI
import FinanzinCore

// MARK: - Listagem mensal limite vs utilizado

public struct BudgetListView: View {
    @EnvironmentObject var store: Store
    @Binding var year: Int
    @Binding var month: Int

    @State private var editing: BudgetLimit?

    public init(year: Binding<Int>, month: Binding<Int>) {
        _year = year
        _month = month
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: FinSpacing.md) {
                ScreenHeader("Orçamento")
                MonthPicker(year: $year, month: $month)
                    .padding(.horizontal, FinSpacing.lg)
                if rows.isEmpty {
                    EmptyStateView(
                        title: "Sem orçamentos",
                        subtitle: "Defina um limite mensal por categoria para acompanhar.",
                        icon: "gauge.with.dots.needle.67percent"
                    )
                } else {
                    List {
                        Section { totalsCard.finRow() }
                        Section("Por categoria") {
                            ForEach(rows, id: \.limit.id) { row in
                                budgetRow(row)
                                    .finRow()
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            store.deleteBudget(id: row.limit.id)
                                        } label: {
                                            Label("Excluir", systemImage: "trash")
                                        }
                                        .tint(.red)
                                        Button {
                                            editing = row.limit
                                        } label: {
                                            Label("Editar", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                    .finList()
                }
            }
            .finBackground()
            .finHideNavBar()
            .sheet(item: $editing) { limit in
                BudgetFormView(editing: limit, year: year, month: month)
            }
        }
    }

    private var rows: [BudgetService.Row] {
        BudgetService.rows(limits: store.budgets, transactions: store.transactions, year: year, month: month)
            .sorted { $0.percent > $1.percent }
    }

    private var totalsCard: some View {
        let totalLimit = rows.reduce(Decimal(0)) { $0 + $1.limit.limitAmount }
        let totalUsed = rows.reduce(Decimal(0)) { $0 + $1.used }
        return HStack(spacing: FinSpacing.lg) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Limite total").font(.caption).foregroundStyle(VercelTheme.textSecondary)
                Text(Format.currency(totalLimit))
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("Utilizado").font(.caption).foregroundStyle(VercelTheme.textSecondary)
                Text(Format.currency(totalUsed))
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(totalUsed > totalLimit ? .red : VercelTheme.textPrimary)
            }
        }
    }

    private func budgetRow(_ row: BudgetService.Row) -> some View {
        let cat = store.category(id: row.limit.categoryID)
        let barColor: Color = row.isOver ? .red : row.isWarning ? .orange : .green
        return VStack(alignment: .leading, spacing: FinSpacing.sm) {
            HStack(spacing: FinSpacing.md) {
                TintedIcon(cat?.icon ?? "tag", tint: VercelTheme.hex(cat?.color ?? "#64748b"), size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(cat?.name ?? "Categoria removida")
                            .font(.subheadline.bold())
                            .foregroundStyle(VercelTheme.textPrimary)
                        if row.limit.isRecurring {
                            Text("Mensal")
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    Text("\(Format.currency(row.used)) de \(Format.currency(row.limit.limitAmount))")
                        .font(.caption).foregroundStyle(VercelTheme.textSecondary)
                }
                Spacer()
                if row.isOver {
                    StatusPill("Estourou", color: .red)
                } else if row.isWarning {
                    StatusPill("\(Int(row.percent))%", color: .orange)
                } else {
                    Text("\(Int(row.percent))%")
                        .font(.caption.bold()).foregroundStyle(VercelTheme.textTertiary)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 10)
                    LinearGradient(
                        colors: [barColor.opacity(0.7), barColor],
                        startPoint: .leading, endPoint: .trailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .frame(width: max(geo.size.width * min(row.percent / 100, 1), row.percent > 0 ? 10 : 0), height: 10)
                }
            }
            .frame(height: 10)
            Text(row.isOver
                ? "Acima do limite por \(Format.currency(row.used - row.limit.limitAmount))"
                : "Restam \(Format.currency(row.remaining))")
                .font(.caption)
                .foregroundStyle(row.isOver ? .red : VercelTheme.textSecondary)
        }
    }
}

// MARK: - Formulário de limite

public struct BudgetFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var editing: BudgetLimit?

    @State private var categoryID: String?
    @State private var month: Int
    @State private var year: Int
    @State private var amount: Decimal
    @State private var isRecurring = false
    @State private var errorMessage: String?

    public init(editing: BudgetLimit? = nil, year: Int, month: Int) {
        self.editing = editing
        _categoryID = State(initialValue: editing?.categoryID)
        _month = State(initialValue: editing?.month ?? month)
        _year = State(initialValue: editing?.year ?? year)
        _amount = State(initialValue: editing?.limitAmount ?? 0)
        _isRecurring = State(initialValue: editing?.isRecurring ?? false)
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VercelTheme.bg.ignoresSafeArea()
                Form {
                    Section("Limite mensal") {
                        Picker("Categoria", selection: $categoryID) {
                            Text("Selecione").tag(nil as String?)
                            ForEach(store.categories.filter { $0.type == .expense }) { cat in
                                Text(cat.name).tag(cat.id as String?)
                            }
                        }
                        .disabled(editing != nil)
                        Picker("Mês", selection: $month) {
                            ForEach(1 ... 12, id: \.self) { m in
                                Text(monthName(m)).tag(m)
                            }
                        }
                        .disabled(editing != nil)
                        Stepper("Ano: \(year)", value: $year, in: 2020 ... 2040)
                            .disabled(editing != nil)
                        CurrencyField(value: $amount)
                        Picker("Vale por", selection: $isRecurring) {
                            Text("Somente este mês").tag(false)
                            Text("Todos os meses (mensal)").tag(true)
                        }
                        .pickerStyle(.segmented)
                        if editing != nil {
                            Text("Categoria e competência não mudam; valor e recorrência sim. Mensal vale para este e os próximos meses.")
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        } else if isRecurring {
                            Text("Será criado um limite mensal que aparece em \(monthName(month)) de \(year) e em todos os meses seguintes.")
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        } else {
                            Text("Vale somente \(monthName(month)) de \(year). Se já existir limite da categoria no mês, o valor será atualizado.")
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(editing == nil ? "Novo orçamento" : "Editar orçamento")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                }
            }
        }
    }

    private func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        return f.monthSymbols[m - 1].capitalized
    }

    private func save() {
        do {
            if let editing {
                try store.updateBudget(id: editing.id, limitAmount: amount, isRecurring: isRecurring)
            } else {
                try store.saveBudget(
                    categoryID: categoryID, month: month, year: year,
                    limitAmount: amount, isRecurring: isRecurring
                )
            }
            dismiss()
        } catch Store.BudgetError.categoryRequired {
            errorMessage = "Escolha uma categoria."
        } catch Store.BudgetError.invalidAmount {
            errorMessage = "Limite deve ser maior que zero."
        } catch {
            errorMessage = "Não foi possível salvar."
        }
    }
}
