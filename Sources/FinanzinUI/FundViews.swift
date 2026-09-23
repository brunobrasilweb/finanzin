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
                ScreenHeader("Fundos") {
                    if showClose {
                        HeaderButton("xmark") { dismiss() }
                    }
                    HeaderButton("plus") { showingForm = true }
                }
                if store.funds.isEmpty {
                    EmptyStateView(
                        title: "Sem fundos",
                        subtitle: "Crie um fundo para separar reservas (ex.: Viagem, Emergência).",
                        icon: "chart.pie.fill"
                    )
                } else {
                    List {
                        ForEach(store.funds.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) { fund in
                            card(fund)
                                .finRow()
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        do { try store.deleteFund(id: fund.id) }
                                        catch Store.FundError.hasMovements {
                                            alertMessage = "“\(fund.name)” tem movimentações e não pode ser excluído (histórico preservado)."
                                        } catch {
                                            alertMessage = "Não foi possível excluir."
                                        }
                                    } label: {
                                        Label("Excluir", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button {
                                        editing = fund
                                    } label: {
                                        Label("Editar", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .onTapGesture { selectedID = fund.id }
                        }
                    }
                    .finList()
                }
            }
            .finBackground()
            .finHideNavBar()
            .sheet(isPresented: $showingForm) { FundFormView() }
            .sheet(item: $editing) { fund in FundFormView(editing: fund) }
            .navigationDestination(item: $selectedID) { id in
                if store.funds.first(where: { $0.id == id }) != nil {
                    FundDetailView(fundID: id)
                }
            }
            .alert("Atenção", isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button("OK") {}
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
                Text("\(store.fundTransactions(fundID: fund.id).count) movimentações")
                    .font(.caption).foregroundStyle(VercelTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                AmountText(store.balance(of: fund.id) ?? fund.initialAmount, style: .subheadline)
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
            ZStack {
                VercelTheme.bg.ignoresSafeArea()
                Form {
                    Section("Dados") {
                        TextField("Nome (ex.: Viagem)", text: $name)
                        CurrencyField(value: $initialAmount)
                        TextField("Observações", text: $notes)
                    }
                    Section("Cor (\(CategoryPalettes.colors.count) cores)") {
                        ColorOptionsGrid(selection: $color)
                    }
                    Section("Ícone (\(CategoryPalettes.icons.count) ícones)") {
                        IconOptionsGrid(selection: $icon, tintHex: color)
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(editing == nil ? "Novo fundo" : "Editar fundo")
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
            errorMessage = "Nome é obrigatório."
        } catch Store.FundError.invalidAmount {
            errorMessage = "Valor inicial não pode ser negativo."
        } catch {
            errorMessage = "Não foi possível salvar."
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
                            Text(Format.currency(store.balance(of: fund.id) ?? fund.initialAmount))
                                .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                                .foregroundStyle(VercelTheme.textPrimary)
                            Text("inicial \(Format.currency(fund.initialAmount))")
                                .font(.caption).foregroundStyle(VercelTheme.textSecondary)
                            if let notes = fund.notes, !notes.isEmpty {
                                Text(notes).font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    Section("Movimentações") {
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
                                    Text(Format.shortDate(t.dueDate)).font(.caption).foregroundStyle(VercelTheme.textTertiary)
                                }
                                Spacer()
                                Text("\(t.fundMovementType == .withdrawal ? "−" : "+")\(Format.currency(t.amount))")
                                    .font(.subheadline.bold())
                                    .monospacedDigit()
                                    .foregroundStyle(t.fundMovementType == .withdrawal ? .orange : .green)
                            }
                            .finRow()
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.deleteTransactions(ids: [t.id])
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                                .tint(.red)
                                Button {
                                    editingTx = t
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            .onTapGesture { editingTx = t }
                        }
                    }
                }
                .finList()
                .navigationTitle(fund.name)
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button("Sacar") { movement = .withdrawal }
                        Button("Aportar") { movement = .application }
                    }
                }
                .sheet(item: $movement) { kind in
                    FundMovementView(fundID: fund.id, movement: kind)
                }
                .sheet(item: $editingTx) { tx in
                    let comp = Dates.competence(of: tx.dueDate)
                    TransactionFormView(editing: tx, year: comp.year, month: comp.month)
                }
            } else {
                EmptyStateView(title: "Fundo removido", subtitle: "Volte para a lista.", icon: "chart.pie.fill")
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

    public init(fundID: String, movement: FundMovementType) {
        self.fundID = fundID
        self.movement = movement
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VercelTheme.bg.ignoresSafeArea()
                Form {
                    Section(movement == .application ? "Aporte (conta a pagar)" : "Saque") {
                        TextField("Descrição", text: $description)
                        CurrencyField(value: $amount)
                        DatePicker("Data", selection: $date, displayedComponents: .date)
                        if movement == .withdrawal,
                           let bal = store.balance(of: fundID)
                        {
                            Text("Disponível: \(Format.currency(bal))")
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                        Text("Será lançada como conta a pagar vinculada ao fundo.")
                            .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(movement == .application ? "Aportar" : "Sacar")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                }
            }
            .onAppear {
                if description.isEmpty,
                   let fund = store.funds.first(where: { $0.id == fundID })
                {
                    description = movement == .application ? "Aporte \(fund.name)" : "Saque \(fund.name)"
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
            errorMessage = "Descrição é obrigatória."
        } catch Store.FundError.invalidAmount {
            errorMessage = "Valor deve ser maior que zero."
        } catch Store.FundError.insufficientBalance {
            errorMessage = "Saldo insuficiente para este saque."
        } catch {
            errorMessage = "Não foi possível salvar."
        }
    }
}

extension FundMovementType: Identifiable {
    public var id: String { rawValue }
}
