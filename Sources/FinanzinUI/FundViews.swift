import SwiftUI
import FinanzinCore

// MARK: - Lista de fundos

public struct FundListView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var showClose: Bool = false
    @State private var showingForm = false
    @State private var editing: Fund?
    @State private var selectedID: String?
    @State private var alertMessage: String?

    public init(showClose: Bool = false) {
        self.showClose = showClose
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: FinSpacing.md) {
                ScreenHeader(store.t(.funds)) {
                    if showClose {
                        HeaderButton("xmark") { dismiss() }
                    }
                    PrivacyEyeButton()
                    HeaderButton("plus") { showingForm = true }
                }
                if store.funds.isEmpty {
                    EmptyStateView(
                        title: store.t(.fundEmptyTitle),
                        subtitle: store.t(.fundEmptySubtitle),
                        icon: "chart.pie.fill"
                    )
                } else {
                    List {
                        ForEach(store.funds.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) { fund in
                            card(fund)
                                .finCleanRow()
                                .padding(.vertical, 2)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        do { try store.deleteFund(id: fund.id) }
                                        catch Store.FundError.hasMovements {
                                            alertMessage = String(format: store.t(.fundDeleteBlocked), fund.name)
                                        } catch {
                                            alertMessage = store.t(.fundDeleteFailed)
                                        }
                                    } label: {
                                        Label(store.t(.delete), systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button {
                                        editing = fund
                                    } label: {
                                        Label(store.t(.edit), systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .onTapGesture { selectedID = fund.id }
                        }
                    }
                    .finCleanList()
                }
            }
            .finBackground()
            .finHideNavBar()
            .sheet(isPresented: $showingForm) { FundFormView().environmentObject(store) }
            .sheet(item: $editing) { fund in FundFormView(editing: fund).environmentObject(store) }
            .navigationDestination(item: $selectedID) { id in
                if store.funds.first(where: { $0.id == id }) != nil {
                    FundDetailView(fundID: id)
                }
            }
            .alert(store.t(.fundAttention), isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button(store.t(.ok)) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private func card(_ fund: Fund) -> some View {
        HStack(spacing: FinSpacing.md) {
            TintedIcon(fund.icon, tint: VercelTheme.hex(fund.color), size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(fund.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(VercelTheme.textPrimary)
                Text(String(format: store.t(.fundMovementsCount), store.fundTransactions(fundID: fund.id).count))
                    .font(.caption).foregroundStyle(VercelTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(
                    store.balance(of: fund.id) ?? fund.initialAmount, style: .subheadline, hidden: store.valuesHidden,
                    currencyCode: store.settings.currency.currencyCode,
                    localeIdentifier: store.settings.currency.localeIdentifier
                )
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(VercelTheme.textTertiary)
            }
        }
    }
}

// MARK: - Formulário de fundo

public struct FundFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var editing: Fund?

    @State private var name: String
    @State private var initialAmount: Decimal
    @State private var notes: String
    @State private var color: String
    @State private var icon: String
    @State private var errorMessage: String?
    private enum Field { case name, notes }
    @FocusState private var focusedField: Field?

    public init(editing: Fund? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _initialAmount = State(initialValue: editing?.initialAmount ?? 0)
        _notes = State(initialValue: editing?.notes ?? "")
        _color = State(initialValue: editing?.color ?? "#8b5cf6")
        _icon = State(initialValue: editing?.icon ?? "chart.pie.fill")
    }

    public var body: some View {
        NavigationStack {
            Form {
                    Section(store.t(.dataSection)) {
                        TextField(store.t(.fundNamePh), text: $name)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .notes }
                        CurrencyField(
                            value: $initialAmount, showKeyboardToolbar: false,
                            currencyCode: store.settings.currency.currencyCode,
                            localeIdentifier: store.settings.currency.localeIdentifier
                        )
                        TextField(store.t(.notesField), text: $notes)
                            .focused($focusedField, equals: .notes)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                    }
                    Section(String(format: store.t(.colorsCount), CategoryPalettes.colors.count)) {
                        ColorOptionsGrid(selection: $color)
                    }
                    Section(String(format: store.t(.iconsCount), CategoryPalettes.icons.count)) {
                        IconOptionsGrid(selection: $icon, tintHex: color)
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
            .navigationTitle(editing == nil ? store.t(.fundNewTitle) : store.t(.fundEditTitle))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(.close)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(.save)) { save() }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t(.ok)) {
                        focusedField = nil
                        KeyboardDismisser.dismiss()
                    }
                }
                #endif
            }
        }
    }

    private func save() {
        do {
            let notesValue = notes.isEmpty ? nil : notes
            if var edit = editing {
                edit.name = name
                edit.initialAmount = initialAmount
                edit.color = color
                edit.icon = icon
                edit.notes = notesValue
                try store.updateFund(edit)
            } else {
                try store.addFund(
                    name: name, initialAmount: initialAmount,
                    color: color, icon: icon, notes: notesValue
                )
            }
            dismiss()
        } catch Store.FundError.emptyName {
            errorMessage = store.t(.nameRequired)
        } catch Store.FundError.invalidAmount {
            errorMessage = store.t(.fundErrAmount)
        } catch {
            errorMessage = store.t(.couldNotSave)
        }
    }
}

// MARK: - Detalhe + extrato

public struct FundDetailView: View {
    @EnvironmentObject var store: Store
    var fundID: String

    @State private var movement: FundMovementType?
    @State private var editingTx: FinancialTransaction?

    public init(fundID: String) { self.fundID = fundID }

    public var body: some View {
        VStack(spacing: FinSpacing.md) {
            if let fund = store.funds.first(where: { $0.id == fundID }) {
                List {
                    Section {
                        VStack(spacing: FinSpacing.sm) {
                            TintedIcon(fund.icon, tint: VercelTheme.hex(fund.color), size: 60)
                            Text(store.maskedAmount(store.balance(of: fund.id) ?? fund.initialAmount))
                                .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                                .foregroundStyle(VercelTheme.textPrimary)
                            Text(String(format: store.t(.fundInitial), store.maskedAmount(fund.initialAmount)))
                                .font(.caption).foregroundStyle(VercelTheme.textSecondary)
                            if let notes = fund.notes, !notes.isEmpty {
                                Text(notes).font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .finCleanRow()
                        .listRowSeparator(.hidden)
                    }
                    Section(header:
                        Text(store.t(.fundMovementsSection))
                            .font(.caption.bold())
                            .foregroundStyle(VercelTheme.textTertiary)
                            .textCase(.uppercase)
                    ) {
                        ForEach(store.fundTransactions(fundID: fund.id)) { t in
                            HStack(spacing: FinSpacing.md) {
                                TintedIcon(
                                    t.fundMovementType == .withdrawal ? "arrow.down.to.line" : "chart.line.uptrend.xyaxis",
                                    tint: t.fundMovementType == .withdrawal ? .orange : .green,
                                    size: 34
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(t.description)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(VercelTheme.textPrimary)
                                        .lineLimit(1)
                                    Text(Format.shortDate(t.dueDate, localeIdentifier: store.lang.localeIdentifier)).font(.caption).foregroundStyle(VercelTheme.textTertiary)
                                }
                                Spacer()
                                Text(store.valuesHidden ? "••••••" : "\(t.fundMovementType == .withdrawal ? "−" : "+")\(Format.currency(t.amount, currencyCode: store.settings.currency.currencyCode, localeIdentifier: store.settings.currency.localeIdentifier))")
                                    .font(.subheadline.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(t.fundMovementType == .withdrawal ? .orange : .green)
                            }
                            .finCleanRow()
                            .padding(.vertical, 2)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.deleteTransactions(ids: [t.id])
                                } label: {
                                    Label(store.t(.delete), systemImage: "trash")
                                }
                                .tint(.red)
                                Button {
                                    editingTx = t
                                } label: {
                                    Label(store.t(.edit), systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .onTapGesture { editingTx = t }
                        }
                    }
                }
                .finCleanList()
                .navigationTitle(fund.name)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button {
                            store.setValuesHidden(!store.valuesHidden)
                        } label: {
                            Image(systemName: store.valuesHidden ? "eye.slash" : "eye")
                        }
                        .accessibilityLabel(store.valuesHidden ? store.t(.showValues) : store.t(.hideValues))
                        Button(store.t(.fundWithdraw)) { movement = .withdrawal }
                        Button(store.t(.fundDeposit)) { movement = .application }
                    }
                }
                .sheet(item: $movement) { kind in
                    FundMovementView(fundID: fund.id, movement: kind)
                        .environmentObject(store)
                }
                .sheet(item: $editingTx) { tx in
                    let comp = Dates.competence(of: tx.dueDate)
                    TransactionFormView(editing: tx, year: comp.year, month: comp.month)
                        .environmentObject(store)
                }
            } else {
                EmptyStateView(title: store.t(.fundRemovedTitle), subtitle: store.t(.fundRemovedSubtitle), icon: "chart.pie.fill")
            }
        }
        .finBackground()
        .finDetailChrome()
    }
}

// MARK: - Aporte / saque

public struct FundMovementView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var fundID: String
    var movement: FundMovementType

    @State private var description: String = ""
    @State private var amount: Decimal = 0
    @State private var date: Date = Date()
    @State private var errorMessage: String?
    @FocusState private var descriptionFocused: Bool

    public init(fundID: String, movement: FundMovementType) {
        self.fundID = fundID
        self.movement = movement
    }

    public var body: some View {
        NavigationStack {
            Form {
                    Section(movement == .application ? store.t(.fundDepositSection) : store.t(.fundWithdraw)) {
                        TextField(store.t(.descriptionField), text: $description)
                            .focused($descriptionFocused)
                            .submitLabel(.done)
                            .onSubmit { descriptionFocused = false }
                        CurrencyField(
                            value: $amount, showKeyboardToolbar: false,
                            currencyCode: store.settings.currency.currencyCode,
                            localeIdentifier: store.settings.currency.localeIdentifier
                        )
                        FormDateField(
                            store.t(.fundDate), date: $date,
                            localeIdentifier: store.lang.localeIdentifier,
                            okTitle: store.t(.ok)
                        )
                        if movement == .withdrawal,
                           let bal = store.balance(of: fundID)
                        {
                            Text(String(format: store.t(.fundAvailable), store.maskedAmount(bal)))
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                        Text(store.t(.fundLinkedFootnote))
                            .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
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
            .navigationTitle(movement == .application ? store.t(.fundDeposit) : store.t(.fundWithdraw))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(.close)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(.save)) { save() }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t(.ok)) {
                        descriptionFocused = false
                        KeyboardDismisser.dismiss()
                    }
                }
                #endif
            }
            .onAppear {
                if description.isEmpty,
                   let fund = store.funds.first(where: { $0.id == fundID })
                {
                    description = movement == .application
                        ? String(format: store.t(.fundDefaultDeposit), fund.name)
                        : String(format: store.t(.fundDefaultWithdraw), fund.name)
                }
            }
        }
    }

    private func save() {
        do {
            try store.addFundMovement(
                fundID: fundID, movement: movement,
                amount: amount, description: description, dueDate: date
            )
            dismiss()
        } catch Store.FundError.emptyName {
            errorMessage = store.t(.fundDescriptionRequired)
        } catch Store.FundError.invalidAmount {
            errorMessage = store.t(.fundErrPositive)
        } catch Store.FundError.insufficientBalance {
            errorMessage = store.t(.fundErrBalance)
        } catch {
            errorMessage = store.t(.couldNotSave)
        }
    }
}

extension FundMovementType: Identifiable {
    public var id: String { rawValue }
}
