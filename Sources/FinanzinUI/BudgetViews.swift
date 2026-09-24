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
            // `rows` uma vez por `body` + mapas p/ linhas (antes: `rows`
            // rodava 3x e cada linha re-resolvia categoria/formatos).
            let items = rows
            let cats = Dictionary(uniqueKeysWithValues: store.categories.map { ($0.id, $0) })
            VStack(spacing: FinSpacing.md) {
                ScreenHeader(store.t(.budgets)) {
                    PrivacyEyeButton()
                }
                MonthPicker(year: $year, month: $month, localeIdentifier: store.lang.localeIdentifier)
                    .padding(.horizontal, FinSpacing.lg)
                if items.isEmpty {
                    EmptyStateView(
                        title: store.t(.budEmptyTitle),
                        subtitle: store.t(.budEmptySubtitle),
                        icon: "gauge.with.dots.needle.67percent"
                    )
                } else {
                    List {
                        Section {
                            BudgetTotalsCard(
                                limitText: store.maskedAmount(items.reduce(Decimal(0)) { $0 + $1.limit.limitAmount }),
                                usedText: store.maskedAmount(items.reduce(Decimal(0)) { $0 + $1.used }),
                                isOver: items.reduce(Decimal(0)) { $0 + $1.used } > items.reduce(Decimal(0)) { $0 + $1.limit.limitAmount },
                                limitTitle: store.t(.budTotalLimit),
                                usedTitle: store.t(.budUsed)
                            )
                                .finCleanRow()
                                .listRowSeparator(.hidden)
                        }
                        Section(header:
                            Text(store.t(.budByCategory))
                                .font(.caption.bold())
                                .foregroundStyle(VercelTheme.textTertiary)
                                .textCase(.uppercase)
                        ) {
                            ForEach(items, id: \.limit.id) { row in
                                BudgetRow(
                                    icon: cats[row.limit.categoryID]?.icon ?? "tag",
                                    tintHex: cats[row.limit.categoryID]?.color ?? "#64748b",
                                    title: cats[row.limit.categoryID]?.name ?? store.t(.dashNoCategory),
                                    isRecurring: row.limit.isRecurring,
                                    recurringText: store.t(.budMonthly),
                                    detailText: String(
                                        format: store.t(.budOfTemplate),
                                        store.maskedAmount(row.used), store.maskedAmount(row.limit.limitAmount)
                                    ),
                                    percentText: row.isOver ? store.t(.budOverShort) : "\(Int(row.percent))%",
                                    percentPill: row.isOver || row.isWarning,
                                    pillColor: row.isOver ? .red : .orange,
                                    fraction: row.percent / 100,
                                    barColor: row.isOver ? .red : (row.isWarning ? .orange : .green),
                                    statusText: row.isOver
                                        ? String(format: store.t(.budOverBy), store.maskedAmount(row.used - row.limit.limitAmount))
                                        : String(format: store.t(.budLeft), store.maskedAmount(row.remaining)),
                                    isOver: row.isOver
                                )
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

    private func monthName(_ m: Int) -> String {
        Dates.monthName(m, localeIdentifier: store.lang.localeIdentifier)
    }
}

// MARK: - Linhas estreitas (só `let`s)

struct BudgetTotalsCard: View {
    let limitText: String
    let usedText: String
    let isOver: Bool
    let limitTitle: String
    let usedTitle: String

    var body: some View {
        HStack(spacing: FinSpacing.lg) {
            VStack(alignment: .leading, spacing: 3) {
                Text(limitTitle).font(.caption).foregroundStyle(VercelTheme.textSecondary)
                Text(limitText)
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(usedTitle).font(.caption).foregroundStyle(VercelTheme.textSecondary)
                Text(usedText)
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(isOver ? .red : VercelTheme.textPrimary)
            }
        }
    }
}

struct BudgetRow: View {
    let icon: String
    let tintHex: String
    let title: String
    let isRecurring: Bool
    let recurringText: String
    let detailText: String
    let percentText: String
    let percentPill: Bool
    let pillColor: Color
    let fraction: Double
    let barColor: Color
    let statusText: String
    let isOver: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: FinSpacing.sm) {
            HStack(spacing: FinSpacing.md) {
                TintedIcon(icon, tint: VercelTheme.hex(tintHex), size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundStyle(VercelTheme.textPrimary)
                        if isRecurring {
                            Text(recurringText)
                                .font(.caption2.bold())
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.15))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())
                        }
                    }
                    Text(detailText)
                        .font(.caption).foregroundStyle(VercelTheme.textSecondary)
                }
                Spacer()
                if percentPill {
                    StatusPill(percentText, color: pillColor)
                } else {
                    Text(percentText)
                        .font(.caption.bold()).foregroundStyle(VercelTheme.textTertiary)
                }
            }
            FinProgressBar(fraction: fraction, color: barColor)
            Text(statusText)
                .font(.caption)
                .foregroundStyle(isOver ? .red : VercelTheme.textSecondary)
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
        Dates.monthName(m, localeIdentifier: store.lang.localeIdentifier)
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
