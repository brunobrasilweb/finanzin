import SwiftUI
import FinanzinCore

// MARK: - Lista de cartões (gestão de faturas)

public struct CreditCardListView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var showClose: Bool = true
    @State private var showingForm = false
    @State private var editing: CreditCard?
    @State private var alertMessage: String?

    public init(showClose: Bool = true) {
        self.showClose = showClose
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: FinSpacing.md) {
                ScreenHeader(store.t(.cardTitle)) {
                    if showClose {
                        HeaderButton("xmark") { dismiss() }
                    }
                    PrivacyEyeButton()
                    HeaderButton("plus") { showingForm = true }
                }
                if store.creditCards.isEmpty {
                    EmptyStateView(
                        title: store.t(.cardEmptyTitle),
                        subtitle: store.t(.cardEmptySubtitle),
                        icon: "creditcard"
                    )
                } else {
                    List {
                        ForEach(sorted) { card in
                            row(card)
                                .finCleanRow()
                                .padding(.vertical, 2)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        do { try store.deleteCard(id: card.id) }
                                        catch Store.CardError.hasTransactions {
                                            alertMessage = String(format: store.t(.cardDeleteBlocked), card.name)
                                        } catch {
                                            alertMessage = store.t(.couldNotSave)
                                        }
                                    } label: {
                                        Label(store.t(.delete), systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button {
                                        editing = card
                                    } label: {
                                        Label(store.t(.edit), systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        store.setCardActive(id: card.id, active: !card.isActive)
                                    } label: {
                                        Label(
                                            card.isActive ? store.t(.cardArchive) : store.t(.cardUnarchive),
                                            systemImage: card.isActive ? "archivebox" : "archivebox.fill"
                                        )
                                    }
                                    .tint(card.isActive ? .orange : .green)
                                }
                                .onTapGesture { editing = card }
                        }
                    }
                    .finCleanList()
                }
            }
            .finBackground()
            .finHideNavBar()
            .sheet(isPresented: $showingForm) { CreditCardFormView().environmentObject(store) }
            .sheet(item: $editing) { card in CreditCardFormView(editing: card).environmentObject(store) }
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

    private var sorted: [CreditCard] {
        store.creditCards.sorted {
            $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending
        }
    }

    private func row(_ card: CreditCard) -> some View {
        HStack(spacing: FinSpacing.md) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(card.isActive ? .blue : VercelTheme.textTertiary)
                .frame(width: 32, height: 32)
                .background(VercelTheme.inset)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(card.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                Text("\(store.t(.cardClosingDay)): \(card.closingDay) • \(store.t(.cardDueDay)): \(card.dueDay)")
                    .font(.caption)
                    .foregroundStyle(VercelTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            if !card.isActive {
                Text(store.t(.cardArchived))
                    .font(.caption2.bold())
                    .foregroundStyle(VercelTheme.textTertiary)
            }
        }
        .opacity(card.isActive ? 1 : 0.6)
    }
}

// MARK: - Formulário de cartão

public struct CreditCardFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var editing: CreditCard?

    @State private var name: String
    @State private var closingDay: Int
    @State private var dueDay: Int
    @State private var isActive: Bool
    @State private var errorMessage: String?

    public init(editing: CreditCard? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _closingDay = State(initialValue: editing?.closingDay ?? 10)
        _dueDay = State(initialValue: editing?.dueDay ?? 17)
        _isActive = State(initialValue: editing?.isActive ?? true)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(store.t(.dataSection)) {
                    TextField(store.t(.cardNamePh), text: $name)
                        .submitLabel(.done)
                    Stepper("\(store.t(.cardClosingDay)): \(closingDay)", value: $closingDay, in: 1 ... 31)
                    Stepper("\(store.t(.cardDueDay)): \(dueDay)", value: $dueDay, in: 1 ... 31)
                    Text(store.t(.cardDayFootnote))
                        .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                    if editing != nil {
                        Toggle(store.t(.cardActive), isOn: $isActive)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VercelTheme.card)
            .navigationTitle(editing == nil ? store.t(.cardNewTitle) : store.t(.cardEditTitle))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
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

    private func save() {
        errorMessage = nil
        do {
            if var edit = editing {
                edit.name = name
                edit.closingDay = closingDay
                edit.dueDay = dueDay
                edit.isActive = isActive
                try store.updateCard(edit)
            } else {
                _ = try store.addCard(name: name, closingDay: closingDay, dueDay: dueDay)
            }
            dismiss()
        } catch Store.CardError.emptyName {
            errorMessage = store.t(.nameRequired)
        } catch Store.CardError.duplicateName {
            errorMessage = store.t(.cardErrDuplicate)
        } catch Store.CardError.invalidDay {
            errorMessage = store.t(.cardErrDay)
        } catch {
            errorMessage = store.t(.couldNotSave)
        }
    }
}

// MARK: - Detalhe da fatura (lançamentos + pagar/excluir)

public struct InvoiceDetailView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var card: CreditCard
    var year: Int
    var month: Int

    @State private var editingTx: FinancialTransaction?
    @State private var confirmingPay = false
    @State private var confirmingDelete = false

    public init(card: CreditCard, year: Int, month: Int) {
        self.card = card
        self.year = year
        self.month = month
    }

    private var items: [FinancialTransaction] {
        store.invoiceTransactions(cardID: card.id, year: year, month: month)
    }

    private var pending: [FinancialTransaction] {
        items.filter { $0.status == .pending }
    }

    public var body: some View {
        VStack(spacing: FinSpacing.md) {
            if store.card(id: card.id) == nil {
                EmptyStateView(
                    title: store.t(.cardEmptyTitle),
                    subtitle: store.t(.cardEmptySubtitle),
                    icon: "creditcard"
                )
            } else if items.isEmpty {
                EmptyStateView(
                    title: String(format: store.t(.invoiceOf), card.name),
                    subtitle: store.t(.invoiceEmpty),
                    icon: "creditcard"
                )
            } else {
                List {
                    Section {
                        VStack(spacing: FinSpacing.sm) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(.blue)
                            Text(store.maskedAmount(InvoiceService.total(items)))
                                .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                                .foregroundStyle(VercelTheme.textPrimary)
                            Text("\(dueText) • \(statusText)")
                                .font(.caption).foregroundStyle(statusColor)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .finCleanRow()
                        .listRowSeparator(.hidden)
                    }
                    Section(header:
                        Text(store.t(.invoiceEntries))
                            .font(.caption.bold())
                            .foregroundStyle(VercelTheme.textTertiary)
                            .textCase(.uppercase)
                    ) {
                        ForEach(items) { t in
                            entryRow(t)
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
                    Section {
                        if !pending.isEmpty {
                            Button(store.t(.invoicePay)) { confirmingPay = true }
                                .bold()
                                .foregroundStyle(.green)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .finCleanRow()
                                .confirmationDialog(
                                    store.t(.invoicePayTitle),
                                    isPresented: $confirmingPay
                                ) {
                                    Button(store.t(.invoicePay)) { pay() }
                                    Button(store.t(.cancel), role: .cancel) {}
                                } message: {
                                    Text(String(
                                        format: store.t(.invoicePayMessage),
                                        pending.count,
                                        store.maskedAmount(InvoiceService.total(pending))
                                    ))
                                }
                        }
                        Button(role: .destructive) { confirmingDelete = true } label: {
                            Text(store.t(.invoiceDelete))
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .finCleanRow()
                        .confirmationDialog(
                            store.t(.invoiceDelete),
                            isPresented: $confirmingDelete
                        ) {
                            Button(store.t(.delete), role: .destructive) { deleteInvoice() }
                            Button(store.t(.cancel), role: .cancel) {}
                        } message: {
                            Text(String(
                                format: store.t(.invoiceDeleteMessage),
                                InvoiceService.transactions(
                                    store.transactions, cardID: card.id,
                                    year: year, month: month, includeCanceled: true
                                ).count
                            ))
                        }
                    }
                }
                .finCleanList()
                .sheet(item: $editingTx) { tx in
                    let comp = Dates.competence(of: tx.dueDate)
                    TransactionFormView(editing: tx, year: comp.year, month: comp.month)
                        .environmentObject(store)
                }
            }
        }
        .finBackground()
        .finDetailChrome()
        .navigationTitle(String(format: store.t(.invoiceOf), card.name))
    }

    private var due: Date {
        InvoiceService.invoiceDueDate(year: year, month: month, dueDay: card.dueDay)
    }

    private var dueText: String {
        String(format: store.t(.invoiceDueOn), Format.shortDate(due, localeIdentifier: store.lang.localeIdentifier))
    }

    private var statusText: String {
        if InvoiceService.isPaid(items) { return store.t(.invoicePaid) }
        if InvoiceService.isClosed(card: card, year: year, month: month) { return store.t(.invoiceClosed) }
        return store.t(.invoiceOpen)
    }

    private var statusColor: Color {
        if InvoiceService.isPaid(items) { return .green }
        if InvoiceService.isClosed(card: card, year: year, month: month) { return .orange }
        return .blue
    }

    private func entryRow(_ t: FinancialTransaction) -> some View {
        HStack(spacing: FinSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(t.description)
                    .font(.subheadline.bold())
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                Text(entryMeta(t))
                    .font(.caption)
                    .foregroundStyle(VercelTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(store.maskedAmount(t.amount))
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
                statusDot(t)
            }
        }
    }

    private func entryMeta(_ t: FinancialTransaction) -> String {
        var parts = [Format.shortDate(t.dueDate, localeIdentifier: store.lang.localeIdentifier)]
        if let n = t.currentInstallment, t.recurrence == .installment {
            parts.append("\(n)/\(t.installmentCount)")
        }
        return parts.joined(separator: " • ")
    }

    private func statusDot(_ t: FinancialTransaction) -> some View {
        let color: Color = {
            if t.isOverdue { return .red }
            switch t.status {
            case .pending: return .orange
            case .paid: return .green
            case .canceled: return .gray
            case .overdue: return .red
            }
        }()
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(t.status.label(language: store.lang)).font(.caption2).foregroundStyle(color)
        }
    }

    private func pay() {
        _ = store.payInvoice(cardID: card.id, year: year, month: month, paidDate: due)
    }

    /// Exclui a fatura inteira: todos os lançamentos do cartão na
    /// competência (inclui pagos e cancelados).
    private func deleteInvoice() {
        let ids = InvoiceService.transactions(
            store.transactions, cardID: card.id,
            year: year, month: month, includeCanceled: true
        ).map(\.id)
        store.deleteTransactions(ids: ids)
        dismiss()
    }
}
