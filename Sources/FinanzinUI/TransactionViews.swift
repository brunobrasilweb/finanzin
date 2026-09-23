import SwiftUI
import FinanzinCore

// MARK: - Lista mensal com filtros + baixa

public struct TransactionListView: View {
    @EnvironmentObject var store: Store
    @Binding var year: Int
    @Binding var month: Int

    @State private var showingCategories = false
    @State private var editing: FinancialTransaction?
    @State private var settling: FinancialTransaction?
    @State private var pendingDelete: FinancialTransaction?
    @State private var typeFilter: TransactionType?
    @State private var statusFilter: TransactionStatus?
    @Binding var categoryID: String?
    @State private var search = ""
    @FocusState private var searchFocused: Bool

    public init(year: Binding<Int>, month: Binding<Int>, categoryID: Binding<String?>) {
        _year = year
        _month = month
        _categoryID = categoryID
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: FinSpacing.sm) {
                ScreenHeader("Transações") {
                    PrivacyEyeButton()
                    HeaderButton("tag") { showingCategories = true }
                }
                MonthPicker(year: $year, month: $month)
                    .padding(.horizontal, FinSpacing.lg)

                HStack(spacing: FinSpacing.sm) {
                    searchField
                    filterButton
                }
                .padding(.horizontal, FinSpacing.lg)

                Picker("Tipo", selection: $typeFilter) {
                    Text("Todas").tag(nil as TransactionType?)
                    Text("A pagar").tag(TransactionType.payable as TransactionType?)
                    Text("A receber").tag(TransactionType.receivable as TransactionType?)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, FinSpacing.lg)

                if let cid = categoryID, let cat = store.category(id: cid) {
                    HStack {
                        Button { categoryID = nil } label: {
                            HStack(spacing: 6) {
                                Circle().fill(VercelTheme.hex(cat.color)).frame(width: 7, height: 7)
                                Text(cat.name).font(.caption.bold())
                                Image(systemName: "xmark").font(.caption2.bold())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(VercelTheme.inset)
                            .foregroundStyle(VercelTheme.textSecondary)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .padding(.horizontal, FinSpacing.lg)
                }

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
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
                                    .listRowSeparatorTint(VercelTheme.border.opacity(0.6))
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
                                            Button("Dar baixa") { settling = t }
                                                .tint(.green)
                                        }
                                    }
                                    .onTapGesture { editing = t }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        #if os(iOS)
                        .scrollDismissesKeyboard(.immediately)
                        #endif
                    }
                }
            .finBackground()
            .finHideNavBar()
            #if os(iOS)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { searchFocused = false }
                }
            }
            #endif
            .sheet(isPresented: $showingCategories) {
                CategoryListView()
                    .environmentObject(store)
            }
            .sheet(item: $editing) { t in
                TransactionFormView(editing: t, year: year, month: month)
                    .environmentObject(store)
            }
            .sheet(item: $settling) { t in
                SettleTransactionView(transaction: t)
                    .environmentObject(store)
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

    private var hasActiveFilters: Bool {
        statusFilter != nil || categoryID != nil
    }

    private var searchField: some View {
        HStack(spacing: FinSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(VercelTheme.textTertiary)
            TextField("Buscar", text: $search)
                .focused($searchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .foregroundStyle(VercelTheme.textPrimary)
                .tint(VercelTheme.textPrimary)
                .onSubmit { searchFocused = false }
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(VercelTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, FinSpacing.md)
        .padding(.vertical, 9)
        .background(VercelTheme.inset)
        .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
    }

    private var filterButton: some View {
        Menu {
            Section("Status") {
                Button { statusFilter = nil } label: {
                    statusOption("Todas", active: statusFilter == nil)
                }
                Button { statusFilter = .pending } label: {
                    statusOption("Pendente", active: statusFilter == .pending)
                }
                Button { statusFilter = .paid } label: {
                    statusOption("Pago", active: statusFilter == .paid)
                }
            }
            if categoryID != nil {
                Section("Categoria") {
                    Button(role: .destructive) { categoryID = nil } label: {
                        Label("Limpar filtro", systemImage: "xmark")
                    }
                }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.subheadline.bold())
                    .frame(width: 38, height: 38)
                    .background(VercelTheme.inset)
                    .foregroundStyle(hasActiveFilters ? VercelTheme.textPrimary : VercelTheme.textSecondary)
                    .clipShape(Circle())
                if hasActiveFilters {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 8, height: 8)
                        .offset(x: -3, y: 3)
                }
            }
        }
    }

    private func statusOption(_ title: String, active: Bool) -> some View {
        HStack {
            Text(title)
            if active {
                Image(systemName: "checkmark")
            }
        }
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
            Image(systemName: t.type == .payable ? "arrow.up.right" : "arrow.down.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(t.type == .payable ? .red.opacity(0.9) : .green)
                .frame(width: 32, height: 32)
                .background(VercelTheme.inset)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(t.description)
                    .font(.subheadline)
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                Text(metaLine(t))
                    .font(.caption)
                    .foregroundStyle(VercelTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(store.valuesHidden ? "••••••" : amountString(t.amount))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(t.type == .receivable ? .green : VercelTheme.textPrimary)
                statusLine(t)
            }
        }
        .padding(.vertical, 2)
    }

    private func metaLine(_ t: FinancialTransaction) -> String {
        var parts: [String] = []
        if let cat = store.category(id: t.categoryID) {
            parts.append(cat.name)
        }
        parts.append(shortDate(t.dueDate))
        if let n = t.currentInstallment, t.recurrence == .installment {
            parts.append("\(n)/\(t.installmentCount)")
        } else if t.recurrence == .fixed {
            parts.append("Fixa")
        } else if t.recurrence == .recurring {
            parts.append("Recorrente")
        }
        return parts.joined(separator: " • ")
    }

    private func statusLine(_ t: FinancialTransaction) -> some View {
        let (label, color): (String, Color) = {
            if t.isOverdue {
                return ("Vencido", .red)
            }
            switch t.status {
            case .pending: return ("Pendente", .orange)
            case .paid: return ("Pago", VercelTheme.textTertiary)
            case .canceled: return ("Cancelado", .gray)
            case .overdue: return ("Vencido", .red)
            }
        }()
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.caption2).foregroundStyle(color)
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
    private enum Field { case description, notes }
    @FocusState private var focusedField: Field?

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
                            tint: type == .payable ? .red.opacity(0.9) : .green,
                            showKeyboardToolbar: false
                        )
                    }
                    Section("Dados") {
                        TextField("Descrição", text: $description)
                            .focused($focusedField, equals: .description)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .notes }
                        Picker("Categoria", selection: $categoryID) {
                            Text("Sem categoria").tag(nil as String?)
                            ForEach(store.categories.filter { $0.type == (type == .payable ? .expense : .income) }) { cat in
                                Text(cat.name).tag(cat.id as String?)
                            }
                        }
                    }
                    Section("Vencimento e status") {
                        FormDateField("Vencimento", date: $dueDate)
                        Picker("Status", selection: $status) {
                            Text("Pendente").tag(TransactionStatus.pending)
                            Text("Pago").tag(TransactionStatus.paid)
                        }
                        TextField("Observações", text: $notes)
                            .focused($focusedField, equals: .notes)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
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
                .background(VercelTheme.bg)
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
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
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("OK") { dismissKeyboard() }
                }
                #endif
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

    private func dismissKeyboard() {
        focusedField = nil
        KeyboardDismisser.dismiss()
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

// MARK: - Dar baixa com valor e data

public struct SettleTransactionView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var transaction: FinancialTransaction

    // Pré-preenchidos com os dados da transação (valor e vencimento),
    // editáveis antes de confirmar a baixa.
    @State private var amount: Decimal
    @State private var paidDate: Date
    @State private var errors: [String] = []

    public init(transaction: FinancialTransaction) {
        self.transaction = transaction
        _amount = State(initialValue: transaction.amount)
        _paidDate = State(initialValue: transaction.paidDate ?? transaction.dueDate)
    }

    public var body: some View {
        NavigationStack {
            Form {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(transaction.description)
                                .font(.headline)
                                .foregroundStyle(VercelTheme.textPrimary)
                            Text("Vencimento \(fullDate(transaction.dueDate)) • \(transaction.type.label)")
                                .font(.caption)
                                .foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    Section("Valor pago") {
                        ProminentCurrencyField(
                            value: $amount,
                            tint: transaction.type == .payable ? .red.opacity(0.9) : .green
                        )
                        if amount != transaction.amount {
                            Text("Valor original: \(store.maskedAmount(transaction.amount))")
                                .font(.footnote)
                                .foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    Section("Data da baixa") {
                        FormDateField("Pago em", date: $paidDate)
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
                .background(VercelTheme.bg)
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
            .navigationTitle("Dar baixa")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(transaction.type == .receivable ? "Receber" : "Pagar") { confirm() }
                        .bold()
                }
            }
        }
    }

    private func confirm() {
        errors = TransactionEngine.validateSettle(amount: amount)
        guard errors.isEmpty else { return }
        store.settle(id: transaction.id, amount: amount, paidDate: paidDate)
        dismiss()
    }

    private func fullDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateStyle = .short
        return f.string(from: d)
    }

    private func amountString(_ v: Decimal) -> String {
        CurrencyField.format(v)
    }
}
