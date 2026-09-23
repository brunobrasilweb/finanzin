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
                ScreenHeader(store.t(.budgets)) {
                    PrivacyEyeButton()
                }
                MonthPicker(year: $year, month: $month, localeIdentifier: store.lang.localeIdentifier)
                    .padding(.horizontal, FinSpacing.lg)
                if rows.isEmpty {
                    EmptyStateView(
                        title: store.t(.budEmptyTitle),
                        subtitle: store.t(.budEmptySubtitle),
                        icon: "gauge.with.dots.needle.67percent"
                    )
                } else {
                    List {
                        Section {
                            totalsCard
                                .finCleanRow()
                                .listRowSeparator(.hidden)
                        }
                        Section(header:
                            Text(store.t(.budByCategory))
                                .font(.caption.bold())
                                .foregroundStyle(VercelTheme.textTertiary)
                                .textCase(.uppercase)
                        ) {
                            ForEach(rows, id: \.limit.id) { row in
                                budgetRow(row)
                                    .finCleanRow()
                                    .padding(.vertical, 2)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            store.deleteBudget(id: row.limit.id)
                                        } label: {
                                            Label(store.t(.delete), systemImage: "trash")
                                        }
                                        .tint(.red)
                                        Button {
                                            editing = row.limit
                                        } label: {
                                            Label(store.t(.edit), systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                            }
                        }
                    }
                    .finCleanList()
                }
            }
            .finBackground()
            .finHideNavBar()
            .sheet(item: $editing) { limit in
                BudgetFormView(editing: limit, year: year, month: month)
                    .environmentObject(store)
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
                Text(store.t(.budTotalLimit)).font(.caption).foregroundStyle(VercelTheme.textSecondary)
                Text(store.maskedAmount(totalLimit))
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(store.t(.budUsed)).font(.caption).foregroundStyle(VercelTheme.textSecondary)
                Text(store.maskedAmount(totalUsed))
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
                        Text(cat?.name ?? store.t(.dashNoCategory))
                            .font(.subheadline.bold())
                            .foregroundStyle(VercelTheme.textPrimary)
                        if row.limit.isRecurring {
                            Text(store.t(.budMonthly))
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    Text(String(
                        format: store.t(.budOfTemplate),
                        store.maskedAmount(row.used), store.maskedAmount(row.limit.limitAmount)
                    ))
                        .font(.caption).foregroundStyle(VercelTheme.textSecondary)
                }
                Spacer()
                if row.isOver {
                    StatusPill(store.t(.budOverShort), color: .red)
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
                        .fill(VercelTheme.track)
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
                ? String(format: store.t(.budOverBy), store.maskedAmount(row.used - row.limit.limitAmount))
                : String(format: store.t(.budLeft), store.maskedAmount(row.remaining)))
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
            Form {
                    Section(store.t(.budLimitSection)) {
                        Picker(store.t(.categoryLabel), selection: $categoryID) {
                            Text(store.t(.select)).tag(nil as String?)
                            ForEach(store.categories.filter { $0.type == .expense }) { cat in
                                Text(cat.name).tag(cat.id as String?)
                            }
                        }
                        .disabled(editing != nil)
                        Picker(store.t(.budMonth), selection: $month) {
                            ForEach(1 ... 12, id: \.self) { m in
                                Text(monthName(m)).tag(m)
                            }
                        }
                        .disabled(editing != nil)
                        Stepper(String(format: store.t(.budYear), year), value: $year, in: 2020 ... 2040)
                            .disabled(editing != nil)
                        CurrencyField(
                            value: $amount, okTitle: store.t(.ok),
                            currencyCode: store.settings.currency.currencyCode,
                            localeIdentifier: store.settings.currency.localeIdentifier
                        )
                        Picker(store.t(.budValidFor), selection: $isRecurring) {
                            Text(store.t(.budOnlyThisMonth)).tag(false)
                            Text(store.t(.budEveryMonth)).tag(true)
                        }
                        .pickerStyle(.segmented)
                        if editing != nil {
                            Text(store.t(.budEditFootnote))
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        } else if isRecurring {
                            Text(String(
                                format: store.t(.budRecurringFootnote),
                                monthName(month), year
                            ))
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        } else {
                            Text(String(
                                format: store.t(.budSingleFootnote),
                                monthName(month), year
                            ))
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(VercelTheme.card)
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
            .navigationTitle(editing == nil ? store.t(.budNewTitle) : store.t(.budEditTitle))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(.close)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(.save)) { save() }
                }
            }
        }
    }

    private func monthName(_ m: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: store.lang.localeIdentifier)
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
            errorMessage = store.t(.budErrCategory)
        } catch Store.BudgetError.invalidAmount {
            errorMessage = store.t(.budErrAmount)
        } catch {
            errorMessage = store.t(.couldNotSave)
        }
    }
}
