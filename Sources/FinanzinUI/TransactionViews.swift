import SwiftUI
import FinanzinCore

// MARK: - Lista mensal com filtros + baixa

public struct TransactionListView: View {
    @EnvironmentObject var store: Store
    @Binding var year: Int
    @Binding var month: Int

    @State private var showingCategories = false
    @State private var editing: FinancialTransaction?
    @State private var pendingDelete: FinancialTransaction?
    @State private var typeFilter: TransactionType?
    @State private var statusFilter: TransactionStatus?
    @Binding var categoryID: String?
    @State private var search = ""

    public init(year: Binding<Int>, month: Binding<Int>, categoryID: Binding<String?>) {
        _year = year
        _month = month
        _categoryID = categoryID
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: FinSpacing.sm) {
                ScreenHeader("Transações") {
                    HeaderButton("tag") { showingCategories = true }
                }
                MonthPicker(year: $year, month: $month)
                    .padding(.horizontal, FinSpacing.lg)

                HStack(spacing: FinSpacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(VercelTheme.textTertiary)
                    TextField("Buscar", text: $search)
                }
                .padding(.horizontal, FinSpacing.md)
                .padding(.vertical, FinSpacing.sm)
                .background(VercelTheme.inset)
                .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous)
                        .stroke(VercelTheme.border, lineWidth: 1)
                )
                .padding(.horizontal, FinSpacing.lg)

                filterBar

                if filtered.isEmpty {
                        EmptyStateView(
                            title: "Sem transações",
                            subtitle: "Toque em + para lançar a primeira conta do mês.",
                            icon: "arrow.left.arrow.right"
                        )
                    } else {
                        List {
                            ForEach(filtered) { t in
                                row(t)
                                    .finRow()
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            pendingDelete = t
                                        } label: {
                                            Label("Excluir", systemImage: "trash")
                                        }
                                        .tint(.red)
                                        Button {
                                            editing = t
                                        } label: {
                                            Label("Editar", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .swipeActions(edge: .leading) {
                                        if t.status == .paid {
                                            Button("Reabrir") { store.updateStatus(id: t.id, to: .pending) }
                                                .tint(.orange)
                                        } else {
                                            Button("Dar baixa") { store.updateStatus(id: t.id, to: .paid) }
                                                .tint(.green)
                                        }
                                    }
                                    .onTapGesture { editing = t }
                            }
                        }
                        .finList()
                    }
                }
            .finBackground()
            .finHideNavBar()
            .sheet(isPresented: $showingCategories) {
                CategoryListView()
            }
            .sheet(item: $editing) { t in
                TransactionFormView(editing: t, year: year, month: month)
            }
            .confirmationDialog(
                "Excluir conta",
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { t in
                if store.isSeriesMember(t) {
                    Button("\(EditScope.thisOne.label) (1)", role: .destructive) {
                        store.deleteSeries(targetID: t.id, scope: .thisOne)
                    }
                    Button("\(EditScope.future.label) (\(store.scopeCount(targetID: t.id, scope: .future)))", role: .destructive) {
                        store.deleteSeries(targetID: t.id, scope: .future)
                    }
                    Button("\(EditScope.all.label) (\(store.scopeCount(targetID: t.id, scope: .all)))", role: .destructive) {
                        store.deleteSeries(targetID: t.id, scope: .all)
                    }
                } else {
                    Button("Excluir", role: .destructive) {
                        store.deleteTransactions(ids: [t.id])
                    }
                }
                Button("Cancelar", role: .cancel) {}
            } message: { t in
                Text(store.isSeriesMember(t)
                    ? "“\(t.description)” é \(t.recurrence.label.lowercased()) e faz parte de uma série de \(store.seriesMembers(targetID: t.id).count) lançamentos. O que excluir?"
                    : "Excluir “\(t.description)”?")
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip("Todas", selected: typeFilter == nil) { typeFilter = nil }
                filterChip("A pagar", selected: typeFilter == .payable) { typeFilter = .payable }
                filterChip("A receber", selected: typeFilter == .receivable) { typeFilter = .receivable }
                Divider().frame(height: 20)
                filterChip("Pendente", selected: statusFilter == .pending) {
                    statusFilter = statusFilter == .pending ? nil : .pending
                }
                filterChip("Pago", selected: statusFilter == .paid) {
                    statusFilter = statusFilter == .paid ? nil : .paid
                }
                if categoryID != nil {
                    filterChip("Categoria ×", selected: true) { categoryID = nil }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Color.white : VercelTheme.inset)
                .foregroundStyle(selected ? Color.black : VercelTheme.textSecondary)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(selected ? Color.clear : VercelTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var filtered: [FinancialTransaction] {
        TransactionEngine.filter(
            store.transactions, year: year, month: month,
            type: typeFilter, status: statusFilter,
            categoryID: categoryID,
            search: search.isEmpty ? nil : search
        )
    }

    private func row(_ t: FinancialTransaction) -> some View {
        HStack(spacing: FinSpacing.md) {
            TintedIcon(
                t.type == .payable ? "arrow.up.right" : "arrow.down.left",
                tint: t.type == .payable ? .red.opacity(0.85) : .green
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(t.description)
                    .font(.subheadline.bold())
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let cat = store.category(id: t.categoryID) {
                        Circle().fill(VercelTheme.hex(cat.color)).frame(width: 7, height: 7)
                        Text(cat.name).font(.caption).foregroundStyle(VercelTheme.textSecondary)
                    }
                    Text(shortDate(t.dueDate)).font(.caption).foregroundStyle(VercelTheme.textTertiary)
                    if let n = t.currentInstallment, t.recurrence == .installment {
                        Text("\(n)/\(t.installmentCount)").font(.caption).foregroundStyle(VercelTheme.textTertiary)
                    } else if t.recurrence == .fixed {
                        Text("Fixa").font(.caption).foregroundStyle(VercelTheme.textTertiary)
                    } else if t.recurrence == .recurring {
                        Text("Recorrente").font(.caption).foregroundStyle(VercelTheme.textTertiary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(amountString(t.amount))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(t.type == .receivable ? .green : VercelTheme.textPrimary)
                statusPill(t)
            }
        }
    }

    private func statusPill(_ t: FinancialTransaction) -> StatusPill {
        if t.isOverdue {
            return StatusPill("Vencido", color: .red)
        }
        switch t.status {
        case .pending: return StatusPill("Pendente", color: .orange)
        case .paid: return StatusPill("Pago", color: .green)
        case .canceled: return StatusPill("Cancelado", color: .gray)
        case .overdue: return StatusPill("Vencido", color: .red)
        }
    }

    private func shortDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM"
        return f.string(from: d)
    }

    private func amountString(_ v: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.numberStyle = .currency
        f.currencyCode = "BRL"
        return f.string(from: v as NSDecimalNumber) ?? "R$ 0,00"
    }
}

// MARK: - Formulário (à vista — Sprint 1)

public struct TransactionFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var editing: FinancialTransaction?
    var year: Int
    var month: Int

    @State private var description: String
    @State private var type: TransactionType
    @State private var amount: Decimal
    @State private var categoryID: String?
    @State private var dueDate: Date
    @State private var status: TransactionStatus
    @State private var notes: String
    @State private var recurrence: RecurrenceType
    @State private var installmentCount: Int
    @State private var interval: InstallmentInterval
    @State private var showingScopeConfirm = false
    @State private var errors: [String] = []

    public init(editing: FinancialTransaction? = nil, year: Int, month: Int) {
        self.editing = editing
        self.year = year
        self.month = month
        _description = State(initialValue: editing?.description ?? "")
        _type = State(initialValue: editing?.type ?? .payable)
        _amount = State(initialValue: editing?.amount ?? 0)
        _categoryID = State(initialValue: editing?.categoryID)
        _dueDate = State(initialValue: editing?.dueDate ?? Date())
        _status = State(initialValue: editing?.status == .paid ? .paid : .pending)
        _notes = State(initialValue: editing?.notes ?? "")
        _recurrence = State(initialValue: editing?.recurrence ?? .unique)
        _installmentCount = State(initialValue: max(editing?.installmentCount ?? 2, 2))
        _interval = State(initialValue: editing?.installmentInterval ?? .monthly)
    }

    private var editingIsSeries: Bool {
        editing.map { store.isSeriesMember($0) } ?? false
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VercelTheme.bg.ignoresSafeArea()
                Form {
                    Section("Tipo de conta") {
                        Picker("Tipo", selection: $type) {
                            Label("A pagar", systemImage: "arrow.up.circle.fill").tag(TransactionType.payable)
                            Label("A receber", systemImage: "arrow.down.circle.fill").tag(TransactionType.receivable)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: type) { categoryID = nil }
                    }
                    Section("Valor") {
                        ProminentCurrencyField(
                            value: $amount,
                            tint: type == .payable ? .red.opacity(0.9) : .green
                        )
                    }
                    Section("Dados") {
                        TextField("Descrição", text: $description)
                        Picker("Categoria", selection: $categoryID) {
                            Text("Sem categoria").tag(nil as String?)
                            ForEach(store.categories.filter { $0.type == (type == .payable ? .expense : .income) }) { cat in
                                Text(cat.name).tag(cat.id as String?)
                            }
                        }
                    }
                    Section("Vencimento e status") {
                        DatePicker("Vencimento", selection: $dueDate, displayedComponents: .date)
                        Picker("Status", selection: $status) {
                            Text("Pendente").tag(TransactionStatus.pending)
                            Text("Pago").tag(TransactionStatus.paid)
                        }
                        TextField("Observações", text: $notes)
                        if editingIsSeries {
                            Text("Se o alcance incluir outras parcelas, cada uma mantém seu vencimento.")
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    if editing == nil {
                        Section("Recorrência") {
                            Picker("Tipo", selection: $recurrence) {
                                Text("Única").tag(RecurrenceType.unique)
                                Text("Parcelada").tag(RecurrenceType.installment)
                                Text("Fixa").tag(RecurrenceType.fixed)
                                Text("Recorrente").tag(RecurrenceType.recurring)
                            }
                            if recurrence == .installment {
                                Stepper("Parcelas: \(installmentCount)", value: $installmentCount, in: 2 ... 48)
                                Picker("Intervalo", selection: $interval) {
                                    Text("Semanal").tag(InstallmentInterval.weekly)
                                    Text("Quinzenal").tag(InstallmentInterval.biweekly)
                                    Text("Mensal").tag(InstallmentInterval.monthly)
                                    Text("Anual").tag(InstallmentInterval.yearly)
                                }
                            }
                            if recurrence == .recurring {
                                Picker("Intervalo", selection: $interval) {
                                    Text("Semanal").tag(InstallmentInterval.weekly)
                                    Text("Quinzenal").tag(InstallmentInterval.biweekly)
                                    Text("Mensal").tag(InstallmentInterval.monthly)
                                    Text("Anual").tag(InstallmentInterval.yearly)
                                }
                                Text("Gera os próximos 24 lançamentos.")
                                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                            }
                            if recurrence == .fixed {
                                Text("Gera 24 competências mensais.")
                                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                            }
                        }
                    }
                    if editingIsSeries, let seriesTarget = editing {
                        Section("Conta em série") {
                            Text("Esta conta é \(seriesTarget.recurrence.label.lowercased()) e faz parte de uma série de \(store.seriesMembers(targetID: seriesTarget.id).count) lançamentos. Ao salvar, escolha o alcance da alteração.")
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    if !errors.isEmpty {
                        Section {
                            ForEach(errors, id: \.self) { e in
                                Text(e).foregroundStyle(.red)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(editing == nil ? "Nova transação" : "Editar transação")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { requestSave() }
                }
            }
            .confirmationDialog(
                "Editar conta em série",
                isPresented: $showingScopeConfirm,
                presenting: editing
            ) { target in
                Button("\(EditScope.thisOne.label) (1)") {
                    performSave(scope: .thisOne)
                }
                Button("\(EditScope.future.label) (\(store.scopeCount(targetID: target.id, scope: .future)))") {
                    performSave(scope: .future)
                }
                Button("\(EditScope.all.label) (\(store.scopeCount(targetID: target.id, scope: .all)))") {
                    performSave(scope: .all)
                }
                Button("Cancelar", role: .cancel) {}
            } message: { target in
                Text("“\(target.description)” é \(target.recurrence.label.lowercased()). Alterar somente esta, esta e as próximas ou todas? Vencimentos das demais são preservados.")
            }
        }
    }

    private func requestSave() {
        let amountDecimal = amount
        errors = TransactionEngine.validate(description: description, amount: amountDecimal)
        if editing == nil {
            errors += TransactionEngine.validateSeries(
                recurrence: recurrence,
                count: recurrence == .installment ? installmentCount : nil,
                interval: recurrence == .installment ? interval : nil
            )
        }
        guard errors.isEmpty else { return }
        // Conta fixa, recorrente ou parcelada em série: pergunta o alcance.
        if editing != nil, editingIsSeries {
            showingScopeConfirm = true
        } else {
            performSave(scope: .thisOne)
        }
    }

    private func performSave(scope: EditScope) {
        let amountDecimal = amount
        errors = TransactionEngine.validate(description: description, amount: amountDecimal)
        guard errors.isEmpty else { return }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        let notesValue = notes.isEmpty ? nil : notes

        if let edit = editing, editingIsSeries, scope != .thisOne {
            store.applySeriesEdit(
                targetID: edit.id, scope: scope,
                edit: Store.SeriesEdit(
                    description: trimmed, type: type, categoryID: categoryID,
                    amount: amountDecimal, notes: notesValue,
                    status: status != edit.status ? status : nil
                )
            )
        } else if var edit = editing {
            edit.description = trimmed
            edit.type = type
            edit.amount = amountDecimal
            edit.totalAmount = amountDecimal
            edit.categoryID = categoryID
            edit.dueDate = dueDate
            edit.notes = notesValue
            if status == .paid && edit.status != .paid {
                edit = TransactionEngine.toggling(edit, to: .paid)
            } else if status == .pending && edit.status == .paid {
                edit = TransactionEngine.toggling(edit, to: .pending)
            }
            store.updateTransaction(edit)
        } else {
            let input = TransactionEngine.CreateInput(
                description: description, type: type, categoryID: categoryID,
                amount: amountDecimal, recurrence: recurrence, dueDate: dueDate,
                notes: notesValue,
                totalInstallments: recurrence == .installment ? installmentCount : nil,
                interval: recurrence == .installment || recurrence == .recurring ? interval : nil
            )
            let items = store.create(input)
            if status == .paid, let first = items.first {
                store.updateStatus(id: first.id, to: .paid)
            }
        }
        dismiss()
    }
}
