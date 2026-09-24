import SwiftUI
import UniformTypeIdentifiers
import FinanzinCore
#if os(iOS)
import UIKit
#endif

// MARK: - Lista mensal com filtros + baixa

public struct TransactionListView: View {
    @EnvironmentObject var store: Store
    @Binding var year: Int
    @Binding var month: Int

    @State private var showingCategories = false
    @State private var showingCards = false
    @State private var editing: FinancialTransaction?
    @State private var settling: FinancialTransaction?
    @State private var pendingDelete: FinancialTransaction?
    @State private var typeFilter: TransactionType?
    @State private var statusFilter: TransactionStatus?
    @State private var cardFilter: String?
    @State private var selectedInvoice: CreditCard?
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
            // Avaliados uma vez por `body`: filtro, faturas e mapas p/ linhas.
            // (Antes: `filtered`/`invoiceEntries` rodavam 2x e cada linha
            // refazia `category/card/attachmentCount` → O(N) queries por row.)
            let items = filtered
            let entries = invoiceEntries
            let cats = Dictionary(uniqueKeysWithValues: store.categories.map { ($0.id, $0) })
            let cards = Dictionary(uniqueKeysWithValues: store.creditCards.map { ($0.id, $0) })
            let attachCounts = store.attachmentCounts()
            VStack(spacing: FinSpacing.sm) {
                ScreenHeader(store.t(.txTitle)) {
                    PrivacyEyeButton()
                    HeaderButton("creditcard") { showingCards = true }
                    HeaderButton("tag") { showingCategories = true }
                }
                MonthPicker(
                    year: $year, month: $month,
                    localeIdentifier: store.lang.localeIdentifier
                )
                    .padding(.horizontal, FinSpacing.lg)

                HStack(spacing: FinSpacing.sm) {
                    searchField
                    filterButton
                }
                .padding(.horizontal, FinSpacing.lg)

                Picker(store.t(.txTypeFilter), selection: $typeFilter) {
                    Text(store.t(.all)).tag(nil as TransactionType?)
                    Text(TransactionType.payable.label(language: store.lang)).tag(TransactionType.payable as TransactionType?)
                    Text(TransactionType.receivable.label(language: store.lang)).tag(TransactionType.receivable as TransactionType?)
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

                if items.isEmpty && entries.isEmpty {
                        EmptyStateView(
                            title: store.t(.txEmptyTitle),
                            subtitle: store.t(.txEmptySubtitle),
                            icon: "arrow.left.arrow.right"
                        )
                    } else {
                        List {
                            if !entries.isEmpty {
                                Section(store.t(.invoiceSection)) {
                                    ForEach(entries, id: \.card.id) { entry in
                                        InvoiceTxRow(
                                            title: String(format: store.t(.invoiceOf), entry.card.name),
                                            subtitle: "\(String(format: store.t(.invoiceDueOn), shortDate(InvoiceService.invoiceDueDate(year: year, month: month, dueDay: entry.card.dueDay)))) • \(invoiceStatusLabel(entry))",
                                            totalText: store.maskedAmount(entry.total),
                                            statusLabel: invoiceStatusLabel(entry)
                                        )
                                            .listRowBackground(Color.clear)
                                            .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
                                            .listRowSeparatorTint(VercelTheme.border.opacity(0.6))
                                            .onTapGesture { selectedInvoice = entry.card }
                                    }
                                }
                            }
                            ForEach(items) { t in
                                TransactionRow(
                                    isPayable: t.type == .payable,
                                    isIncome: t.type == .receivable,
                                    title: t.description,
                                    metaText: Self.metaText(for: t, cats: cats, cards: cards, language: store.lang, locale: store.lang.localeIdentifier),
                                    attachCount: attachCounts[t.id] ?? 0,
                                    amountText: store.maskedAmount(t.amount),
                                    status: Self.statusInfo(for: t, language: store.lang)
                                )
                                    .listRowBackground(Color.clear)
                                    .listRowInsets(EdgeInsets(top: 9, leading: 16, bottom: 9, trailing: 16))
                                    .listRowSeparatorTint(VercelTheme.border.opacity(0.6))
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            pendingDelete = t
                                        } label: {
                                            Label(store.t(.delete), systemImage: "trash")
                                        }
                                        .tint(.red)
                                        Button {
                                            editing = t
                                        } label: {
                                            Label(store.t(.edit), systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .swipeActions(edge: .leading) {
                                        if t.status == .paid {
                                            Button(store.t(.txReopen)) { store.updateStatus(id: t.id, to: .pending) }
                                                .tint(.orange)
                                        } else {
                                            Button(store.t(.txSettle)) { settling = t }
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
                    Button(store.t(.ok)) { searchFocused = false }
                }
            }
            #endif
            .sheet(isPresented: $showingCategories) {
                CategoryListView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingCards) {
                CreditCardListView()
                    .environmentObject(store)
            }
            .navigationDestination(item: $selectedInvoice) { card in
                if store.card(id: card.id) != nil {
                    InvoiceDetailView(card: card, year: year, month: month)
                }
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
                store.t(.txDeleteAccount),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
                presenting: pendingDelete
            ) { t in
                if store.isSeriesMember(t) {
                    Button("\(EditScope.thisOne.label(language: store.lang)) (1)", role: .destructive) {
                        store.deleteSeries(targetID: t.id, scope: .thisOne)
                    }
                    Button("\(EditScope.future.label(language: store.lang)) (\(store.scopeCount(targetID: t.id, scope: .future)))", role: .destructive) {
                        store.deleteSeries(targetID: t.id, scope: .future)
                    }
                    Button("\(EditScope.all.label(language: store.lang)) (\(store.scopeCount(targetID: t.id, scope: .all)))", role: .destructive) {
                        store.deleteSeries(targetID: t.id, scope: .all)
                    }
                } else {
                    Button(store.t(.delete), role: .destructive) {
                        store.deleteTransactions(ids: [t.id])
                    }
                }
                Button(store.t(.cancel), role: .cancel) {}
            } message: { t in
                Text(store.isSeriesMember(t)
                    ? String(
                        format: store.t(.txDeleteConfirmSeries),
                        t.description,
                        t.recurrence.label(language: store.lang).lowercased(),
                        store.seriesMembers(targetID: t.id).count
                    )
                    : String(format: store.t(.txDeleteConfirmSingle), t.description))
            }
        }
    }

    private var hasActiveFilters: Bool {
        statusFilter != nil || categoryID != nil || cardFilter != nil
    }

    // MARK: - Faturas do mês (uma linha por cartão → detalhe)

    private struct InvoiceEntry {
        var card: CreditCard
        var items: [FinancialTransaction]
        var total: Decimal
    }

    /// Uma linha "Fatura do {cartão}" por cartão com lançamentos no mês.
    /// Escondida com busca/filtro de status (totais sairiam do contexto) e
    /// no filtro "A receber" (cartão só gera conta a pagar).
    private var invoiceEntries: [InvoiceEntry] {
        guard search.isEmpty, statusFilter == nil, typeFilter != .receivable else { return [] }
        return store.creditCards
            .filter { cardFilter == nil || $0.id == cardFilter }
            .sorted { $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending }
            .compactMap { card in
                let items = store.invoiceTransactions(cardID: card.id, year: year, month: month)
                guard !items.isEmpty else { return nil }
                return InvoiceEntry(card: card, items: items, total: InvoiceService.total(items))
            }
    }

    private func invoiceStatusLabel(_ entry: InvoiceEntry) -> String {
        if InvoiceService.isPaid(entry.items) { return store.t(.invoicePaid) }
        if InvoiceService.isClosed(card: entry.card, year: year, month: month) {
            return store.t(.invoiceClosed)
        }
        return store.t(.invoiceOpen)
    }

    private var searchField: some View {
        HStack(spacing: FinSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(VercelTheme.textTertiary)
            TextField(store.t(.search), text: $search)
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
            Section(store.t(.txStatusMenu)) {
                Button { statusFilter = nil } label: {
                    statusOption(store.t(.all), active: statusFilter == nil)
                }
                Button { statusFilter = .pending } label: {
                    statusOption(TransactionStatus.pending.label(language: store.lang), active: statusFilter == .pending)
                }
                Button { statusFilter = .paid } label: {
                    statusOption(TransactionStatus.paid.label(language: store.lang), active: statusFilter == .paid)
                }
            }
            if categoryID != nil {
                Section(store.t(.txCategoryMenu)) {
                    Button(role: .destructive) { categoryID = nil } label: {
                        Label(store.t(.txClearFilter), systemImage: "xmark")
                    }
                }
            }
            if !store.creditCards.isEmpty {
                Section(store.t(.cardFilter)) {
                    Button { cardFilter = nil } label: {
                        statusOption(store.t(.all), active: cardFilter == nil)
                    }
                    ForEach(store.creditCards.sorted {
                        $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending
                    }) { card in
                        Button { cardFilter = card.id } label: {
                            statusOption(card.name, active: cardFilter == card.id)
                        }
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
        // Compras no cartão fora da listagem: só aparecem no detalhe da fatura.
        TransactionEngine.filter(
            store.transactions, year: year, month: month,
            type: typeFilter, status: statusFilter,
            categoryID: categoryID,
            search: search.isEmpty ? nil : search,
            includeCardPurchases: false
        )
    }

    static func metaText(
        for t: FinancialTransaction,
        cats: [String: FinanceCategory],
        cards: [String: CreditCard],
        language: AppLanguage,
        locale: String
    ) -> String {
        var parts: [String] = []
        if let cat = t.categoryID.flatMap({ cats[$0] }) {
            parts.append(cat.name)
        }
        if let card = t.creditCardID.flatMap({ cards[$0] }) {
            parts.append(card.name)
        }
        parts.append(Dates.shortDayMonth(t.dueDate, localeIdentifier: locale))
        if let n = t.currentInstallment, t.recurrence == .installment {
            parts.append("\(n)/\(t.installmentCount)")
        } else if t.recurrence == .fixed || t.recurrence == .recurring {
            parts.append(t.recurrence.label(language: language))
        }
        return parts.joined(separator: " • ")
    }

    static func statusInfo(for t: FinancialTransaction, language: AppLanguage) -> TransactionStatusRow {
        if t.isOverdue {
            return TransactionStatusRow(label: TransactionStatus.overdue.label(language: language), color: .red)
        }
        switch t.status {
        case .pending: return TransactionStatusRow(label: TransactionStatus.pending.label(language: language), color: .orange)
        case .paid: return TransactionStatusRow(label: TransactionStatus.paid.label(language: language), color: nil)
        case .canceled: return TransactionStatusRow(label: TransactionStatus.canceled.label(language: language), color: .gray)
        case .overdue: return TransactionStatusRow(label: TransactionStatus.overdue.label(language: language), color: .red)
        }
    }

    private func shortDate(_ d: Date) -> String {
        Dates.shortDayMonth(d, localeIdentifier: store.lang.localeIdentifier)
    }
}

// MARK: - Linhas estreitas (só `let`s: a lista agrupa mapas uma vez por `body`)

/// Status com cor opcional (`nil` = terciária do tema).
struct TransactionStatusRow {
    let label: String
    let color: Color?
}

struct TransactionRow: View {
    let isPayable: Bool
    let isIncome: Bool
    let title: String
    let metaText: String
    let attachCount: Int
    let amountText: String
    let status: TransactionStatusRow

    var body: some View {
        HStack(spacing: FinSpacing.md) {
            Image(systemName: isPayable ? "arrow.up.right" : "arrow.down.left")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isPayable ? .red.opacity(0.9) : .green)
                .frame(width: 32, height: 32)
                .background(VercelTheme.inset)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(metaText)
                        .font(.caption)
                        .foregroundStyle(VercelTheme.textTertiary)
                        .lineLimit(1)
                    if attachCount > 0 {
                        Image(systemName: "paperclip")
                            .font(.caption2.bold())
                            .foregroundStyle(VercelTheme.textTertiary)
                        Text("\(attachCount)")
                            .font(.caption2.bold())
                            .foregroundStyle(VercelTheme.textTertiary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(isIncome ? .green : VercelTheme.textPrimary)
                HStack(spacing: 4) {
                    Circle().fill(status.color ?? VercelTheme.textTertiary).frame(width: 6, height: 6)
                    Text(status.label).font(.caption2).foregroundStyle(status.color ?? VercelTheme.textTertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

struct InvoiceTxRow: View {
    let title: String
    let subtitle: String
    let totalText: String
    let statusLabel: String

    var body: some View {
        HStack(spacing: FinSpacing.md) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 32, height: 32)
                .background(VercelTheme.inset)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(VercelTheme.textTertiary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(totalText)
                    .font(.subheadline.bold())
                    .monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(VercelTheme.textTertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityHint(statusLabel)
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
    @State private var payOnCard: Bool
    @State private var cardID: String?
    @State private var showingScopeConfirm = false
    @State private var isQuickAdd = false
    @State private var errors: [String] = []
    // Comprovantes: edição grava direto no Store; criação acumula em
    // `pending` e anexa na primeira parcela após o `create()`.
    @State private var pending: [PendingAttachment] = []
    @State private var showingFileImporter = false
    @State private var showingCamera = false
    @State private var showingLibrary = false
    // Leitura de recibo: a foto passa pelo OCR e pré-preenche o form.
    @State private var capturePurpose: CapturePurpose = .attach
    @State private var showingScanChoice = false
    @State private var scanPayload: ScanPayload?
    @State private var previewURLs: [URL] = []
    @State private var previewIndex: Int = 0
    @State private var showingPreview = false
    @State private var attachmentError: String?
    private enum Field { case description, notes }
    /// Para onde vai a foto da câmera/galeria: só anexar ou ler no OCR.
    private enum CapturePurpose { case attach, scan }
    /// Foto aguardando leitura no OCR. Sheet por item (nunca some no meio
    /// da apresentação — evita modal vazio ao confirmar).
    private struct ScanPayload: Identifiable {
        let id = UUID().uuidString
        let data: Data
    }
    @FocusState private var focusedField: Field?

    public init(
        editing: FinancialTransaction? = nil, year: Int, month: Int,
        draft: TransactionDraft? = nil, pendingPhoto: Data? = nil
    ) {
        self.editing = editing
        self.year = year
        self.month = month
        // Cadastro rápido (deep link/Siri) ou IA (prompt/voz/foto):
        // pré-preenche valor/descrição/data/tipo/categoria; quitado quando
        // a data é hoje ou passada, pendente quando futura.
        _description = State(initialValue: editing?.description ?? draft?.description ?? "")
        _type = State(initialValue: editing?.type ?? draft?.type ?? .payable)
        _amount = State(initialValue: editing?.amount ?? draft?.amount ?? 0)
        _categoryID = State(initialValue: editing?.categoryID ?? draft?.categoryID)
        _dueDate = State(initialValue: editing?.dueDate ?? draft?.date ?? Date())
        _status = State(initialValue: {
            if let editing {
                return editing.status == .paid ? .paid : .pending
            }
            if let date = draft?.date,
               date > Calendar.current.startOfDay(for: Date())
               && Calendar.current.startOfDay(for: date)
                != Calendar.current.startOfDay(for: Date()) {
                return .pending
            }
            return draft != nil ? .paid : .pending
        }())
        _notes = State(initialValue: editing?.notes ?? "")
        _recurrence = State(initialValue: {
            if let editing { return editing.recurrence }
            // "em 3x" manda em parcelada; senão usa a recorrência da IA.
            if (draft?.installmentCount ?? 1) >= 2 { return .installment }
            return draft?.recurrence ?? .unique
        }())
        _installmentCount = State(initialValue: max(
            editing?.installmentCount ?? draft?.installmentCount ?? 2, 2))
        _interval = State(initialValue:
            editing?.installmentInterval ?? draft?.interval ?? .monthly)
        _payOnCard = State(initialValue:
            editing?.creditCardID != nil
                || draft?.payOnCard == true
                || draft?.creditCardID != nil)
        _cardID = State(initialValue: editing?.creditCardID ?? draft?.creditCardID)
        _isQuickAdd = State(initialValue: editing == nil && draft != nil)
        // Foto vinda do scan da IA: entra como pendente (anexa no create).
        _pending = State(initialValue: {
            guard editing == nil, let photo = pendingPhoto, !photo.isEmpty else { return [] }
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd-HHmmss"
            return [PendingAttachment(
                fileName: "recibo-\(f.string(from: Date())).jpg", data: photo)]
        }())
    }

    private var editingIsSeries: Bool {
        editing.map { store.isSeriesMember($0) } ?? false
    }

    public var body: some View {
        NavigationStack {
            Form {
                    if isQuickAdd {
                        Section {
                            Text(store.t(.quickAddHint))
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    Section(store.t(.txAccountType)) {
                        Picker(store.t(.typeLabel), selection: $type) {
                            Label(TransactionType.payable.label(language: store.lang), systemImage: "arrow.up.circle.fill").tag(TransactionType.payable)
                            Label(TransactionType.receivable.label(language: store.lang), systemImage: "arrow.down.circle.fill").tag(TransactionType.receivable)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: type) { categoryID = nil }
                    }
                    Section(store.t(.txValueSection)) {
                        ProminentCurrencyField(
                            value: $amount,
                            tint: type == .payable ? .red.opacity(0.9) : .green,
                            showKeyboardToolbar: false,
                            currencyCode: store.settings.currency.currencyCode,
                            localeIdentifier: store.settings.currency.localeIdentifier
                        )
                    }
                    if editing == nil, type == .payable {
                        Section(store.t(.payMethod)) {
                            Picker(store.t(.payMethod), selection: $payOnCard) {
                                Text(store.t(.payCash)).tag(false)
                                Text(store.t(.payCard)).tag(true)
                            }
                            .pickerStyle(.segmented)
                            if payOnCard {
                                if store.activeCards.isEmpty {
                                    Text(store.t(.payNoCard))
                                        .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                                } else {
                                    Picker(store.t(.cardFilter), selection: $cardID) {
                                        Text(store.t(.select)).tag(nil as String?)
                                        ForEach(store.activeCards) { card in
                                            Text(card.name).tag(card.id as String?)
                                        }
                                    }
                                    if let card = store.card(id: cardID) {
                                        let invoice = InvoiceService.invoiceFor(purchaseDate: dueDate, card: card)
                                        Text(String(
                                            format: store.t(.invoiceGoesTo),
                                            Dates.monthLabel(
                                                year: invoice.year, month: invoice.month,
                                                localeIdentifier: store.lang.localeIdentifier)
                                        ))
                                            .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    Section(store.t(.dataSection)) {
                        TextField(store.t(.descriptionField), text: $description)
                            .focused($focusedField, equals: .description)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .notes }
                        Picker(store.t(.categoryLabel), selection: $categoryID) {
                            Text(store.t(.noCategory)).tag(nil as String?)
                            ForEach(store.categories.filter { $0.type == (type == .payable ? .expense : .income) }) { cat in
                                Text(cat.name).tag(cat.id as String?)
                            }
                        }
                    }
                    Section(store.t(.txDueAndStatus)) {
                        FormDateField(
                            store.t(.txDueDate), date: $dueDate,
                            localeIdentifier: store.lang.localeIdentifier,
                            okTitle: store.t(.ok)
                        )
                        Picker(store.t(.statusLabel), selection: $status) {
                            Text(TransactionStatus.pending.label(language: store.lang)).tag(TransactionStatus.pending)
                            Text(TransactionStatus.paid.label(language: store.lang)).tag(TransactionStatus.paid)
                        }
                        TextField(store.t(.notesField), text: $notes)
                            .focused($focusedField, equals: .notes)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                        if editingIsSeries {
                            Text(store.t(.txSeriesFootnote))
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    Section(store.t(.txReceipts)) {
                        if displayItems.isEmpty {
                            Text(store.t(.txAttachEmpty))
                                .font(.footnote)
                                .foregroundStyle(VercelTheme.textSecondary)
                        } else {
                            ForEach(displayItems) { item in
                                AttachmentRow(
                                    item: item,
                                    hidden: store.valuesHidden,
                                    localeIdentifier: store.lang.localeIdentifier,
                                    onPreview: { openPreview(item) },
                                    onDelete: { deleteDisplayItem(item) }
                                )
                            }
                        }
                        #if os(iOS)
                        Button {
                            showingScanChoice = true
                        } label: {
                            Label(store.t(.txScanReceipt), systemImage: "doc.text.viewfinder")
                        }
                        Button {
                            capturePurpose = .attach
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showingCamera = true
                            } else {
                                showingLibrary = true
                            }
                        } label: {
                            Label(store.t(.txTakePhoto), systemImage: "camera")
                        }
                        Button {
                            capturePurpose = .attach
                            showingLibrary = true
                        } label: {
                            Label(store.t(.txChoosePhoto), systemImage: "photo")
                        }
                        #endif
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label(store.t(.txAttachFile), systemImage: "paperclip")
                        }
                        if editingIsSeries {
                            Text(store.t(.txSeriesAttachNote))
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                        if editing == nil, !pending.isEmpty {
                            Text(store.t(.txSaveToAttach))
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                        if let attachmentError {
                            Text(attachmentError).foregroundStyle(.red)
                        }
                    }
                    if editing == nil {
                        Section(store.t(.txRecurrence)) {
                            Picker(store.t(.typeLabel), selection: $recurrence) {
                                Text(RecurrenceType.unique.label(language: store.lang)).tag(RecurrenceType.unique)
                                Text(RecurrenceType.installment.label(language: store.lang)).tag(RecurrenceType.installment)
                                Text(RecurrenceType.fixed.label(language: store.lang)).tag(RecurrenceType.fixed)
                                Text(RecurrenceType.recurring.label(language: store.lang)).tag(RecurrenceType.recurring)
                            }
                            if recurrence == .installment {
                                Stepper(
                                    String(format: store.t(.txInstallments), installmentCount),
                                    value: $installmentCount, in: 2 ... 48
                                )
                                Picker(store.t(.txInterval), selection: $interval) {
                                    Text(InstallmentInterval.weekly.label(language: store.lang)).tag(InstallmentInterval.weekly)
                                    Text(InstallmentInterval.biweekly.label(language: store.lang)).tag(InstallmentInterval.biweekly)
                                    Text(InstallmentInterval.monthly.label(language: store.lang)).tag(InstallmentInterval.monthly)
                                    Text(InstallmentInterval.yearly.label(language: store.lang)).tag(InstallmentInterval.yearly)
                                }
                            }
                            if recurrence == .recurring {
                                Picker(store.t(.txInterval), selection: $interval) {
                                    Text(InstallmentInterval.weekly.label(language: store.lang)).tag(InstallmentInterval.weekly)
                                    Text(InstallmentInterval.biweekly.label(language: store.lang)).tag(InstallmentInterval.biweekly)
                                    Text(InstallmentInterval.monthly.label(language: store.lang)).tag(InstallmentInterval.monthly)
                                    Text(InstallmentInterval.yearly.label(language: store.lang)).tag(InstallmentInterval.yearly)
                                }
                                Text(store.t(.txGenerates24))
                                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                            }
                            if recurrence == .fixed {
                                Text(store.t(.txGenerates24Monthly))
                                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                            }
                        }
                    }
                    if editingIsSeries, let seriesTarget = editing {
                        Section(store.t(.txSeriesAccount)) {
                            Text(String(
                                format: store.t(.txSeriesMessage),
                                seriesTarget.recurrence.label(language: store.lang).lowercased(),
                                store.seriesMembers(targetID: seriesTarget.id).count
                            ))
                                .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    if !errors.isEmpty {
                        Section {
                            ForEach(Array(errors.enumerated()), id: \.offset) { _, e in
                                Text(e).foregroundStyle(.red)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(VercelTheme.card)
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
            .navigationTitle(editing == nil ? (isQuickAdd ? store.t(.quickAddTitle) : store.t(.txNewTitle)) : store.t(.txEditTitle))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(.close)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(.save)) { requestSave() }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t(.ok)) { dismissKeyboard() }
                }
                #endif
            }
            .confirmationDialog(
                store.t(.txEditSeriesTitle),
                isPresented: $showingScopeConfirm,
                presenting: editing
            ) { target in
                Button("\(EditScope.thisOne.label(language: store.lang)) (1)") {
                    performSave(scope: .thisOne)
                }
                Button("\(EditScope.future.label(language: store.lang)) (\(store.scopeCount(targetID: target.id, scope: .future)))") {
                    performSave(scope: .future)
                }
                Button("\(EditScope.all.label(language: store.lang)) (\(store.scopeCount(targetID: target.id, scope: .all)))") {
                    performSave(scope: .all)
                }
                Button(store.t(.cancel), role: .cancel) {}
            } message: { target in
                Text(String(
                    format: store.t(.txEditSeriesMessage),
                    target.description,
                    target.recurrence.label(language: store.lang).lowercased()
                ))
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.image, .pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls): addPickedFiles(urls)
                case .failure: attachmentError = store.t(.txAttachFailed)
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showingCamera) {
                PhotoCaptureView(
                    source: .camera,
                    onPick: { addCapturedData($0, fileName: $1) },
                    onCancel: { showingCamera = false }
                )
            }
            .sheet(isPresented: $showingLibrary) {
                PhotoCaptureView(
                    source: .library,
                    onPick: { addCapturedData($0, fileName: $1) },
                    onCancel: { showingLibrary = false }
                )
            }
            .confirmationDialog(
                store.t(.txScanReceipt),
                isPresented: $showingScanChoice
            ) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button(store.t(.txTakePhoto)) {
                        capturePurpose = .scan
                        showingCamera = true
                    }
                }
                Button(store.t(.txChoosePhoto)) {
                    capturePurpose = .scan
                    showingLibrary = true
                }
                Button(store.t(.cancel), role: .cancel) {}
            }
            .sheet(item: $scanPayload) { payload in
                ReceiptScanSheet(imageData: payload.data) { amount, desc, date, catID, image in
                    applyScan(
                        amount: amount, description: desc, date: date,
                        categoryID: catID, imageData: image)
                }
                .environmentObject(store)
            }
            #endif
            #if !os(iOS)
            // iOS apresenta o QuickLook via UIKit (ver AttachmentPreviewPresenter).
            .sheet(isPresented: $showingPreview) {
                NavigationStack {
                    AttachmentPreview(urls: previewURLs, index: previewIndex)
                        .navigationTitle(store.t(.txReceipts))
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(store.t(.close)) { showingPreview = false }
                            }
                        }
                }
            }
            #endif
        }
    }

    // MARK: - Comprovantes

    /// Linhas da seção: salvos do Store (edição) ou pendentes (criação).
    private var displayItems: [AttachmentDisplay] {
        if let edit = editing {
            return store.attachments(for: edit.id).map { att in
                AttachmentDisplay(
                    id: att.id, fileName: att.fileName,
                    sizeText: att.formattedSize, createdAt: att.createdAt,
                    isPDF: att.isPDF,
                    fileURL: store.attachmentFileURL(att)
                )
            }
        }
        return pending.map { p in
            AttachmentDisplay(
                id: p.id, fileName: p.fileName, sizeText: p.sizeText,
                createdAt: Date(), isPDF: p.isPDF, imageData: p.data
            )
        }
    }

    private func addPickedFiles(_ urls: [URL]) {
        attachmentError = nil
        for url in urls {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                attachmentError = store.t(.txAttachFailed)
                continue
            }
            addData(data, fileName: url.lastPathComponent)
        }
    }

    private func addCapturedData(_ data: Data, fileName: String) {
        attachmentError = nil
        #if os(iOS)
        showingCamera = false
        showingLibrary = false
        #endif
        // Fluxo do scan: a foto vai para o OCR em vez de anexar direto.
        // O anexo acontece no `applyScan`, junto com o pré-preenchimento.
        if capturePurpose == .scan {
            capturePurpose = .attach
            // Apresenta no próximo ciclo: o sheet da câmera ainda está
            // sendo dispensado e trocar dois sheets na mesma transação
            // deixa modal zumbi (vazio) na pilha.
            DispatchQueue.main.async {
                scanPayload = ScanPayload(data: data)
            }
            return
        }
        addData(data, fileName: fileName)
    }

    /// Aplica o resultado conferido do OCR: vira conta a pagar com valor,
    /// descrição, data e categoria sugeridas; a foto vira comprovante
    /// (pendente na criação, direto no Store na edição).
    private func applyScan(
        amount: Decimal, description: String, date: Date,
        categoryID: String?, imageData: Data
    ) {
        type = .payable
        self.amount = amount
        self.description = description
        dueDate = date
        self.categoryID = categoryID
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        addData(imageData, fileName: "recibo-\(f.string(from: Date())).jpg")
    }

    private func addData(_ data: Data, fileName: String) {
        guard AttachmentValidator.isSupported(fileName: fileName) else {
            attachmentError = store.t(.txAttachUnsupported)
            return
        }
        guard !data.isEmpty else {
            attachmentError = store.t(.txAttachFailed)
            return
        }
        if let edit = editing {
            do {
                try store.addAttachment(to: edit.id, fileName: fileName, data: data)
            } catch AttachmentError.unsupportedType {
                attachmentError = store.t(.txAttachUnsupported)
            } catch {
                attachmentError = store.t(.txAttachFailed)
            }
        } else {
            pending.append(PendingAttachment(fileName: AttachmentValidator.displayName(
                for: fileName, fallback: "comprovante"), data: data))
        }
    }

    private func deleteDisplayItem(_ item: AttachmentDisplay) {
        if editing != nil {
            store.removeAttachment(id: item.id)
        } else {
            pending.removeAll { $0.id == item.id }
        }
    }

    /// Resolve a URL para o QuickLook (pendente é materializado no temp).
    private func resolvePreviewURL(_ item: AttachmentDisplay) -> URL? {
        if let url = item.fileURL { return url }
        guard let p = pending.first(where: { $0.id == item.id }) else { return nil }
        // Nome seguro para o temp (sem ":" do ISO8601, inválido em path).
        let safe = p.fileName.replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(p.id)-\(safe)")
        if !FileManager.default.fileExists(atPath: url.path) {
            try? p.data.write(to: url, options: .atomic)
        }
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    private func openPreview(_ item: AttachmentDisplay) {
        attachmentError = nil
        var urls: [URL] = []
        var index = 0
        for d in displayItems {
            guard let url = resolvePreviewURL(d) else { continue }
            if d.id == item.id { index = urls.count }
            urls.append(url)
        }
        guard !urls.isEmpty else {
            attachmentError = store.t(.txAttachFailed)
            return
        }
        #if os(iOS)
        AttachmentPreviewPresenter.present(urls: urls, index: index)
        #else
        previewURLs = urls
        previewIndex = index
        showingPreview = true
        #endif
    }

    private func dismissKeyboard() {
        focusedField = nil
        KeyboardDismisser.dismiss()
    }

    private func requestSave() {
        let amountDecimal = amount
        errors = TransactionEngine.validate(description: description, amount: amountDecimal, language: store.lang)
        if editing == nil {
            errors += TransactionEngine.validateSeries(
                recurrence: recurrence,
                count: recurrence == .installment ? installmentCount : nil,
                interval: recurrence == .installment ? interval : nil,
                language: store.lang
            )
            if type == .payable, payOnCard, store.card(id: cardID) == nil {
                errors.append(store.t(.payNoCard))
            }
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
        errors = TransactionEngine.validate(description: description, amount: amountDecimal, language: store.lang)
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
            let card = (type == .payable && payOnCard) ? store.card(id: cardID) : nil
            let input = TransactionEngine.CreateInput(
                description: description, type: type, categoryID: categoryID,
                amount: amountDecimal, recurrence: recurrence, dueDate: dueDate,
                notes: notesValue,
                totalInstallments: recurrence == .installment ? installmentCount : nil,
                interval: recurrence == .installment || recurrence == .recurring ? interval : nil,
                creditCardID: card?.id, card: card
            )
            let items = store.create(input)
            // Pendentes (foto/arquivo escolhidos antes de salvar) vão para a
            // primeira parcela; demais parcelas recebem os próprios depois.
            if let first = items.first {
                for p in pending {
                    _ = try? store.addAttachment(
                        to: first.id, fileName: p.fileName, data: p.data)
                }
                if status == .paid {
                    store.updateStatus(id: first.id, to: .paid)
                }
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
                            Text(String(
                                format: store.t(.txDueLine),
                                fullDate(transaction.dueDate),
                                transaction.type.label(language: store.lang)
                            ))
                                .font(.caption)
                                .foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    Section(store.t(.txPaidValue)) {
                        ProminentCurrencyField(
                            value: $amount,
                            tint: transaction.type == .payable ? .red.opacity(0.9) : .green,
                            okTitle: store.t(.ok),
                            currencyCode: store.settings.currency.currencyCode,
                            localeIdentifier: store.settings.currency.localeIdentifier
                        )
                        if amount != transaction.amount {
                            Text(String(format: store.t(.txOriginalValue), store.maskedAmount(transaction.amount)))
                                .font(.footnote)
                                .foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    Section(store.t(.txSettleDate)) {
                        FormDateField(
                            store.t(.txPaidOn), date: $paidDate,
                            localeIdentifier: store.lang.localeIdentifier,
                            okTitle: store.t(.ok)
                        )
                    }
                    if !errors.isEmpty {
                        Section {
                            ForEach(Array(errors.enumerated()), id: \.offset) { _, e in
                                Text(e).foregroundStyle(.red)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(VercelTheme.card)
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
            .navigationTitle(store.t(.txSettleTitle))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(.cancel)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(transaction.type == .receivable ? store.t(.txReceive) : store.t(.txPay)) { confirm() }
                        .bold()
                }
            }
        }
    }

    private func confirm() {
        errors = TransactionEngine.validateSettle(amount: amount, language: store.lang)
        guard errors.isEmpty else { return }
        store.settle(id: transaction.id, amount: amount, paidDate: paidDate)
        dismiss()
    }

    private func fullDate(_ d: Date) -> String {
        Format.shortStyle(d, localeIdentifier: store.lang.localeIdentifier)
    }

    private func amountString(_ v: Decimal) -> String {
        CurrencyField.format(
            v,
            currencyCode: store.settings.currency.currencyCode,
            localeIdentifier: store.settings.currency.localeIdentifier
        )
    }
}
