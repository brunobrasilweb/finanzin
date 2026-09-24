import Combine
import Foundation

/// Armazenamento em memória com persistência JSON em arquivo.
/// Contrato estável para futura troca por SwiftData sem mudar as Views.
public final class Store: ObservableObject {
    @Published public var categories: [FinanceCategory] = []
    @Published public var transactions: [FinancialTransaction] = []
    @Published public var creditCards: [CreditCard] = []
    @Published public var accounts: [BankAccount] = []
    @Published public var funds: [Fund] = []
    @Published public var budgets: [BudgetLimit] = []
    @Published public var wishlists: [Wishlist] = []
    @Published public var wishlistItems: [WishlistItem] = []
    /// Metadados dos comprovantes (bytes em `attachmentsDir`, fora do JSON).
    @Published public var attachments: [TransactionAttachment] = []

    /// Preferência de privacidade (olho no topo): esconde valores monetários.
    /// Persistida em UserDefaults, fora do Snapshot JSON.
    private static let valuesHiddenKey = "finValuesHidden"
    @Published public var valuesHidden: Bool = UserDefaults.standard.bool(forKey: "finValuesHidden") {
        didSet { UserDefaults.standard.set(valuesHidden, forKey: Self.valuesHiddenKey) }
    }

    public func setValuesHidden(_ hidden: Bool) {
        valuesHidden = hidden
    }

    // MARK: - Plano (Free x Pro)

    #if FIN_STORE_BUILD
    /// Build da loja: pago via StoreKit (`EntitlementService` sincroniza).
    /// Cacheado para abrir o app offline no plano certo.
    private static let isProKey = "finIsProCached"
    @Published public var isPro: Bool = UserDefaults.standard.bool(forKey: "finIsProCached") {
        didSet { UserDefaults.standard.set(isPro, forKey: Self.isProKey) }
    }
    #else
    /// Dev (SPM/CLT/Demo): tudo liberado, sem persistência.
    @Published public var isPro: Bool = true
    #endif

    public func setPro(_ pro: Bool) {
        isPro = pro
    }

    /// Onboarding de planos exibido uma única vez (primeira abertura).
    /// Persistido em UserDefaults, fora do Snapshot JSON (como `valuesHidden`).
    private static let seenPlansKey = "finHasSeenPlans"
    @Published public var hasSeenPlans: Bool = UserDefaults.standard.bool(forKey: "finHasSeenPlans") {
        didSet { UserDefaults.standard.set(hasSeenPlans, forKey: Self.seenPlansKey) }
    }

    public func markPlansSeen() {
        hasSeenPlans = true
    }

    /// Qualquer tela pede o paywall: a raiz apresenta `PlansView(.upgrade)`.
    /// Evita um `@State` de sheet em cada tela com gate.
    @Published public var upgradeRequested = false

    public func requestUpgrade() {
        upgradeRequested = true
    }

    // MARK: - Cupons (validação local p/ prévia; desconto real via Apple)

    private static let couponsRedeemedKey = "finCouponsRedeemed"
    private static let couponFailsKey = "finCouponFails"
    private static let couponLockoutKey = "finCouponLockoutUntil"

    /// Cupom aplicado na sessão (prévia de preço). Não persiste:
    /// o resgate real vira entitlement do StoreKit.
    @Published public var appliedCoupon: CouponTier?

    public enum CouponResult: Equatable {
        case applied(CouponTier)
        case invalid
        case locked(TimeInterval)
        case alreadyRedeemed(CouponTier)
    }

    public func redeemedTiers() -> Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Self.couponsRedeemedKey) ?? [])
    }

    public func isCouponRedeemed(_ tier: CouponTier) -> Bool {
        redeemedTiers().contains(tier.rawValue)
    }

    public func markCouponRedeemed(_ tier: CouponTier) {
        var set = redeemedTiers()
        set.insert(tier.rawValue)
        UserDefaults.standard.set(Array(set), forKey: Self.couponsRedeemedKey)
        if appliedCoupon == tier { appliedCoupon = nil }
    }

    public func applyCoupon(_ code: String) -> CouponResult {
        if let until = UserDefaults.standard.object(forKey: Self.couponLockoutKey) as? Date,
           until > Date()
        {
            return .locked(until.timeIntervalSinceNow)
        }
        guard let tier = CouponPolicy.tier(for: code) else {
            recordCouponFail()
            if let until = UserDefaults.standard.object(forKey: Self.couponLockoutKey) as? Date,
               until > Date()
            {
                return .locked(until.timeIntervalSinceNow)
            }
            return .invalid
        }
        guard !isCouponRedeemed(tier) else { return .alreadyRedeemed(tier) }
        UserDefaults.standard.removeObject(forKey: Self.couponFailsKey)
        UserDefaults.standard.removeObject(forKey: Self.couponLockoutKey)
        appliedCoupon = tier
        return .applied(tier)
    }

    private func recordCouponFail() {
        let fails = UserDefaults.standard.integer(forKey: Self.couponFailsKey) + 1
        UserDefaults.standard.set(fails, forKey: Self.couponFailsKey)
        if fails >= CouponPolicy.maxFails {
            UserDefaults.standard.set(
                Date().addingTimeInterval(CouponPolicy.lockoutSeconds),
                forKey: Self.couponLockoutKey
            )
            UserDefaults.standard.removeObject(forKey: Self.couponFailsKey)
        }
    }

    // MARK: - Filtro global de conta (multi-contas)

    /// Conta selecionada no filtro global (`nil` = Todas as contas).
    /// Persistida em UserDefaults, fora do Snapshot JSON (como `valuesHidden`).
    /// Vale para Resumo, Transações e Orçamento de uma vez.
    private static let selectedAccountKey = "finSelectedAccountID"
    @Published public var selectedAccountID: String? = UserDefaults.standard.string(forKey: "finSelectedAccountID") {
        didSet {
            if let id = selectedAccountID {
                UserDefaults.standard.set(id, forKey: Self.selectedAccountKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.selectedAccountKey)
            }
        }
    }

    public func setSelectedAccount(_ id: String?) {
        selectedAccountID = id
    }

    /// Lançamentos visíveis pelo filtro global. Seleção para conta removida
    /// cai para Todas (em vez de lista vazia).
    public var visibleTransactions: [FinancialTransaction] {
        guard let id = selectedAccountID,
              accounts.contains(where: { $0.id == id })
        else { return transactions }
        return transactions.filter { $0.accountID == id }
    }

    // MARK: - Configurações (Sprint 7)

    /// Preferências do app (idioma/moeda/tema/notificações).
    /// Persistidas em UserDefaults, fora do Snapshot JSON (como `valuesHidden`).
    private static let settingsKey = "finAppSettings"

    @Published public var settings: AppSettings = Store.loadSettings() {
        didSet { Store.persistSettings(settings) }
    }

    private static func loadSettings() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return .defaults }
        return decoded
    }

    private static func persistSettings(_ settings: AppSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    /// Sobrescreve tudo (usado por "Restaurar padrões" e testes).
    public func replaceSettings(_ settings: AppSettings) {
        self.settings = settings
    }

    public func updateLanguage(_ language: AppLanguage) {
        settings.language = language
    }

    public func updateCurrency(_ currency: AppCurrency) {
        settings.currency = currency
    }

    public func updateTheme(_ theme: ThemeMode) {
        settings.theme = theme
    }

    public func updateNotifications(_ prefs: NotificationPrefs) {
        settings.notifications = prefs
    }

    public func resetSettings() {
        settings = .defaults
    }

    // MARK: - Recomeço (Sprint 7: Configurações → Começar do zero)

    /// Apaga TODOS os registros (transações, fundos, orçamentos, listas e
    /// categorias) e restaura só as categorias padrão do app.
    /// Preferências (`settings`, `valuesHidden`) são preservadas.
    public func resetToDefaults() {
        transactions = []
        creditCards = []
        accounts = []
        selectedAccountID = nil
        funds = []
        budgets = []
        wishlists = []
        wishlistItems = []
        categories = []
        attachments = []
        // Sessão de cupom limpa; resgates (`finCouponsRedeemed`), `isPro`
        // e `hasSeenPlans` são entitlement/preferência e sobrevivem.
        appliedCoupon = nil
        // Remove os arquivos dos comprovantes em background (metadados já
        // zerados acima); o `save()` com debounce persiste o snapshot.
        let dir = attachmentsDir
        persistQueue.async {
            if let urls = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: nil)
            {
                for url in urls { try? FileManager.default.removeItem(at: url) }
            }
        }
        Seed.apply(to: self)
    }

    /// Texto de valor respeitando moeda configurada + modo privado.
    public func maskedAmount(_ value: Decimal) -> String {
        valuesHidden ? "••••••" : Currency.format(
            value,
            currencyCode: settings.currency.currencyCode,
            localeIdentifier: settings.currency.localeIdentifier
        )
    }

    private let fileURL: URL?

    /// Pasta onde os bytes dos comprovantes são gravados.
    /// Demo/testes sem `fileURL` usam diretório temporário (sessão).
    public let attachmentsDir: URL

    public init(
        persistTo fileURL: URL? = nil,
        seedIfEmpty: Bool = true,
        attachmentsDirectory: URL? = nil
    ) {
        self.fileURL = fileURL
        if let dir = attachmentsDirectory {
            self.attachmentsDir = dir
        } else if let url = fileURL {
            self.attachmentsDir = url.deletingLastPathComponent()
                .appendingPathComponent("FinanzinAttachments", isDirectory: true)
        } else {
            self.attachmentsDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("FinanzinAttachments", isDirectory: true)
        }
        try? FileManager.default.createDirectory(
            at: attachmentsDir, withIntermediateDirectories: true)
        if let url = fileURL { load(from: url) }
        if categories.isEmpty, seedIfEmpty { Seed.apply(to: self) }
    }

    /// URL padrão de persistência (Application Support/finanzin.json).
    /// Usada pelo app iOS; `nil` = somente memória (demo, previews, testes).
    public static func defaultFileURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("finanzin.json")
    }

    // MARK: - Categorias

    public enum CategoryError: Error, Equatable {
        case emptyName
        case duplicateName
    }

    @discardableResult
    public func addCategory(name: String, type: CategoryType, color: String, icon: String) throws -> FinanceCategory {
        guard isPro else { throw PlanError.limitReached(.categories) }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryError.emptyName }
        let dup = categories.contains {
            $0.type == type && $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }
        guard !dup else { throw CategoryError.duplicateName }
        let cat = FinanceCategory(name: trimmed, type: type, color: color, icon: icon)
        categories.append(cat)
        save()
        return cat
    }

    public func updateCategory(_ cat: FinanceCategory) throws {
        let trimmed = cat.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CategoryError.emptyName }
        let dup = categories.contains {
            $0.id != cat.id && $0.type == cat.type
                && $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }
        guard !dup else { throw CategoryError.duplicateName }
        guard let i = categories.firstIndex(where: { $0.id == cat.id }) else { return }
        var copy = cat
        copy.name = trimmed
        categories[i] = copy
        save()
    }

    /// Exclui categoria e solta transações vinculadas para "sem categoria".
    public func deleteCategory(id: String) {
        categories.removeAll { $0.id == id }
        for i in transactions.indices where transactions[i].categoryID == id {
            transactions[i].categoryID = nil
        }
        save()
    }

    public func category(id: String?) -> FinanceCategory? {
        guard let id else { return nil }
        return categories.first { $0.id == id }
    }

    // MARK: - Transações

    @discardableResult
    public func create(_ input: TransactionEngine.CreateInput) -> [FinancialTransaction] {
        // Resolve o cartão quando só o ID veio (o motor precisa dos dias
        // de fechamento/vencimento para calcular a fatura).
        var resolved = input
        if resolved.creditCardID != nil, resolved.card == nil,
           let id = resolved.creditCardID
        {
            resolved.card = creditCards.first { $0.id == id }
        }
        let items = TransactionEngine.expand(resolved)
        transactions.append(contentsOf: items)
        save()
        return items
    }

    public func updateTransaction(_ updated: FinancialTransaction) {
        guard let i = transactions.firstIndex(where: { $0.id == updated.id }) else { return }
        transactions[i] = updated
        save()
    }

    public func updateStatus(id: String, to status: TransactionStatus) {
        guard let i = transactions.firstIndex(where: { $0.id == id }) else { return }
        transactions[i] = TransactionEngine.toggling(transactions[i], to: status)
        save()
    }

    /// Dá baixa com valor e data específicos (pré-preenchidos na UI com o valor
    /// e o vencimento da transação, editáveis antes de confirmar).
    public func settle(id: String, amount: Decimal, paidDate: Date) {
        guard let i = transactions.firstIndex(where: { $0.id == id }) else { return }
        transactions[i] = TransactionEngine.settling(transactions[i], amount: amount, paidDate: paidDate)
        save()
    }

    public func deleteTransactions(ids: [String]) {
        var doomed = Set(ids)
        // Cascata: filhas de raízes removidas não podem ficar órfãs.
        for t in transactions where t.parentID.map(doomed.contains) == true {
            doomed.insert(t.id)
        }
        transactions.removeAll { doomed.contains($0.id) }
        // Cascata: comprovantes das removidas. `unlink` é síncrono e barato
        // (garante "apagou, sumiu" p/ UI e testes); o snapshot JSON vai
        // com debounce em background via `save()`.
        let doomedAttachments = attachments.filter { doomed.contains($0.transactionID) }
        attachments.removeAll { doomed.contains($0.transactionID) }
        for att in doomedAttachments {
            try? FileManager.default.removeItem(
                at: attachmentsDir.appendingPathComponent(att.storedFileName))
        }
        save()
    }

    // MARK: - Séries (Sprint 2: escopos esta/futuras/todas)

    /// Indica se a transação faz parte de série (é filha ou tem filhas).
    public func isSeriesMember(_ t: FinancialTransaction) -> Bool {
        if t.parentID != nil { return true }
        return transactions.contains { $0.parentID == t.id }
    }

    public func resolveScope(targetID: String, scope: EditScope) -> [String] {
        TransactionEngine.resolveScopeIDs(all: transactions, targetID: targetID, scope: scope)
    }

    /// Todos os lançamentos da mesma série (raiz + filhas), ordenados por vencimento.
    public func seriesMembers(targetID: String) -> [FinancialTransaction] {
        guard let target = transactions.first(where: { $0.id == targetID }) else { return [] }
        let parentID = target.parentID ?? target.id
        return transactions
            .filter { $0.id == parentID || $0.parentID == parentID }
            .sorted { $0.dueDate < $1.dueDate }
    }

    public func scopeCount(targetID: String, scope: EditScope) -> Int {
        resolveScope(targetID: targetID, scope: scope).count
    }

    public struct SeriesEdit: Sendable {
        public var description: String
        public var type: TransactionType?
        public var categoryID: String?
        public var accountID: String?
        public var amount: Decimal
        public var notes: String?
        public var status: TransactionStatus?

        public init(description: String, type: TransactionType? = nil, categoryID: String?, accountID: String? = nil, amount: Decimal, notes: String?, status: TransactionStatus? = nil) {
            self.description = description
            self.type = type
            self.categoryID = categoryID
            self.accountID = accountID
            self.amount = amount
            self.notes = notes
            self.status = status
        }
    }

    /// Aplica edição ao escopo. Valor/descrição/tipo/categoria/conta/obs vão para todas
    /// do escopo; vencimento é preservado por parcela (cada uma mantém sua data).
    public func applySeriesEdit(targetID: String, scope: EditScope, edit: SeriesEdit) {
        let ids = Set(resolveScope(targetID: targetID, scope: scope))
        for i in transactions.indices where ids.contains(transactions[i].id) {
            transactions[i].description = edit.description
            if let type = edit.type { transactions[i].type = type }
            transactions[i].categoryID = edit.categoryID
            transactions[i].accountID = edit.accountID
            transactions[i].amount = edit.amount
            transactions[i].totalAmount = edit.amount
            transactions[i].notes = edit.notes
            if let status = edit.status {
                transactions[i] = TransactionEngine.toggling(transactions[i], to: status)
            }
        }
        save()
    }

    public func deleteSeries(targetID: String, scope: EditScope) {
        deleteTransactions(ids: resolveScope(targetID: targetID, scope: scope))
    }

    // MARK: - Cartões de crédito (Sprint 8: faturas)

    public enum CardError: Error, Equatable {
        case emptyName
        case duplicateName
        case invalidDay
        case hasTransactions
    }

    @discardableResult
    public func addCard(name: String, closingDay: Int, dueDay: Int) throws -> CreditCard {
        guard isPro || creditCards.count < PlanLimits.maxCards else {
            throw PlanError.limitReached(.cards)
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CardError.emptyName }
        guard (1 ... 31).contains(closingDay), (1 ... 31).contains(dueDay) else {
            throw CardError.invalidDay
        }
        let dup = creditCards.contains {
            $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }
        guard !dup else { throw CardError.duplicateName }
        let card = CreditCard(name: trimmed, closingDay: closingDay, dueDay: dueDay)
        creditCards.append(card)
        save()
        return card
    }

    public func updateCard(_ card: CreditCard) throws {
        let trimmed = card.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CardError.emptyName }
        guard (1 ... 31).contains(card.closingDay), (1 ... 31).contains(card.dueDay) else {
            throw CardError.invalidDay
        }
        let dup = creditCards.contains {
            $0.id != card.id && $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }
        guard !dup else { throw CardError.duplicateName }
        guard let i = creditCards.firstIndex(where: { $0.id == card.id }) else { return }
        var copy = card
        copy.name = trimmed
        creditCards[i] = copy
        save()
    }

    public func setCardActive(id: String, active: Bool) {
        guard let i = creditCards.firstIndex(where: { $0.id == id }) else { return }
        creditCards[i].isActive = active
        save()
    }

    /// Exclusão bloqueada quando há lançamentos vinculados (preserva histórico).
    /// Prefira arquivar (`setCardActive`) para manter o histórico e sumir do form.
    public func deleteCard(id: String) throws {
        guard transactions.allSatisfy({ $0.creditCardID != id }) else {
            throw CardError.hasTransactions
        }
        creditCards.removeAll { $0.id == id }
        save()
    }

    public func card(id: String?) -> CreditCard? {
        guard let id else { return nil }
        return creditCards.first { $0.id == id }
    }

    /// Cartões ativos (usados no form de lançamento).
    public var activeCards: [CreditCard] {
        creditCards.filter(\.isActive).sorted {
            $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending
        }
    }

    // MARK: - Contas bancárias (multi-contas)

    public enum AccountError: Error, Equatable {
        case emptyName
        case duplicateName
        case invalidAmount
        case hasTransactions
        /// O app nunca fica sem contas: nem excluir nem arquivar a última.
        case lastAccount
    }

    @discardableResult
    public func addAccount(name: String, initialBalance: Decimal, color: String, icon: String) throws -> BankAccount {
        guard isPro || accounts.count < PlanLimits.maxAccounts else {
            throw PlanError.limitReached(.accounts)
        }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AccountError.emptyName }
        guard initialBalance >= 0 else { throw AccountError.invalidAmount }
        let dup = accounts.contains {
            $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }
        guard !dup else { throw AccountError.duplicateName }
        let account = BankAccount(name: trimmed, initialBalance: initialBalance, color: color, icon: icon)
        accounts.append(account)
        save()
        return account
    }

    public func updateAccount(_ account: BankAccount) throws {
        let trimmed = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AccountError.emptyName }
        guard account.initialBalance >= 0 else { throw AccountError.invalidAmount }
        let dup = accounts.contains {
            $0.id != account.id && $0.name.compare(trimmed, options: .caseInsensitive) == .orderedSame
        }
        guard !dup else { throw AccountError.duplicateName }
        guard let i = accounts.firstIndex(where: { $0.id == account.id }) else { return }
        // Desativar a última ativa é bloqueado (o app sempre tem ≥1 conta ativa).
        if accounts[i].isActive, !account.isActive,
           !accounts.contains(where: { $0.id != account.id && $0.isActive })
        {
            throw AccountError.lastAccount
        }
        var copy = account
        copy.name = trimmed
        accounts[i] = copy
        save()
    }

    public func setAccountActive(id: String, active: Bool) throws {
        guard let i = accounts.firstIndex(where: { $0.id == id }) else { return }
        // Arquivar a última ativa é bloqueado (o app sempre tem ≥1 conta ativa).
        if !active, accounts[i].isActive,
           !accounts.contains(where: { $0.id != id && $0.isActive })
        {
            throw AccountError.lastAccount
        }
        accounts[i].isActive = active
        save()
    }

    /// Exclusão bloqueada quando há lançamentos vinculados (preserva histórico)
    /// e quando é a última conta (o app nunca fica sem contas).
    /// Prefira arquivar (`setAccountActive`) para manter o histórico e sumir do form.
    /// Se a conta excluída era a do filtro global, volta para Todas.
    public func deleteAccount(id: String) throws {
        guard transactions.allSatisfy({ $0.accountID != id }) else {
            throw AccountError.hasTransactions
        }
        guard accounts.count > 1 else {
            throw AccountError.lastAccount
        }
        accounts.removeAll { $0.id == id }
        if selectedAccountID == id { selectedAccountID = nil }
        save()
    }

    public func account(id: String?) -> BankAccount? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }
    }

    /// Contas ativas (usadas no form de lançamento e no filtro).
    public var activeAccounts: [BankAccount] {
        accounts.filter(\.isActive).sorted {
            $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending
        }
    }

    public func accountTransactions(accountID: String) -> [FinancialTransaction] {
        transactions.filter { $0.accountID == accountID }.sorted { $0.dueDate < $1.dueDate }
    }

    public func balance(ofAccount accountID: String) -> Decimal? {
        guard let account = accounts.first(where: { $0.id == accountID }) else { return nil }
        return AccountService.balance(account: account, transactions: transactions)
    }

    /// Saldos de todas as contas em passe único.
    public func accountBalances() -> [String: Decimal] {
        AccountService.balances(accounts: accounts, transactions: transactions)
    }

    // MARK: - Faturas

    /// Lançamentos da fatura (cartão + competência do vencimento).
    public func invoiceTransactions(cardID: String, year: Int, month: Int) -> [FinancialTransaction] {
        InvoiceService.transactions(transactions, cardID: cardID, year: year, month: month)
    }

    public func invoiceTotal(cardID: String, year: Int, month: Int) -> Decimal {
        InvoiceService.total(invoiceTransactions(cardID: cardID, year: year, month: month))
    }

    /// Paga a fatura inteira de uma vez (baixa única): marca como `paid`
    /// todas as pendentes do cartão na competência, com a mesma data.
    /// Retorna a quantidade baixada.
    @discardableResult
    public func payInvoice(cardID: String, year: Int, month: Int, paidDate: Date) -> Int {
        let ids = Set(InvoiceService.pendingIDs(
            invoiceTransactions(cardID: cardID, year: year, month: month)))
        guard !ids.isEmpty else { return 0 }
        var count = 0
        for i in transactions.indices where ids.contains(transactions[i].id) {
            transactions[i] = TransactionEngine.settling(transactions[i], amount: transactions[i].amount, paidDate: paidDate)
            count += 1
        }
        save()
        return count
    }

    // MARK: - Fundos (Sprint 3)

    public enum FundError: Error, Equatable {
        case emptyName
        case invalidAmount
        case fundNotFound
        case insufficientBalance
        case hasMovements
    }

    @discardableResult
    public func addFund(name: String, initialAmount: Decimal, color: String, icon: String, notes: String?) throws -> Fund {
        guard isPro else { throw PlanError.limitReached(.funds) }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FundError.emptyName }
        guard initialAmount >= 0 else { throw FundError.invalidAmount }
        let fund = Fund(name: trimmed, initialAmount: initialAmount, color: color, icon: icon, notes: notes?.isEmpty == true ? nil : notes)
        funds.append(fund)
        save()
        return fund
    }

    public func updateFund(_ fund: Fund) throws {
        let trimmed = fund.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FundError.emptyName }
        guard fund.initialAmount >= 0 else { throw FundError.invalidAmount }
        guard let i = funds.firstIndex(where: { $0.id == fund.id }) else { return }
        var copy = fund
        copy.name = trimmed
        funds[i] = copy
        save()
    }

    /// Exclusão bloqueada quando há movimentações vinculadas (preserva histórico).
    public func deleteFund(id: String) throws {
        guard transactions.allSatisfy({ $0.fundID != id }) else { throw FundError.hasMovements }
        funds.removeAll { $0.id == id }
        save()
    }

    public func fundTransactions(fundID: String) -> [FinancialTransaction] {
        transactions.filter { $0.fundID == fundID }.sorted { $0.dueDate < $1.dueDate }
    }

    public func balance(of fundID: String) -> Decimal? {
        guard let fund = funds.first(where: { $0.id == fundID }) else { return nil }
        return FundService.balance(fund: fund, transactions: transactions)
    }

    /// Aporte/saque como conta a pagar vinculada ao fundo.
    @discardableResult
    public func addFundMovement(
        fundID: String,
        movement: FundMovementType,
        amount: Decimal,
        description: String,
        dueDate: Date = Date(),
        notes: String? = nil,
        accountID: String? = nil
    ) throws -> FinancialTransaction {
        guard let fund = funds.first(where: { $0.id == fundID }) else { throw FundError.fundNotFound }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FundError.emptyName }
        guard amount > 0 else { throw FundError.invalidAmount }
        if movement == .withdrawal {
            let bal = FundService.balance(fund: fund, transactions: transactions)
            guard amount <= bal else { throw FundError.insufficientBalance }
        }
        let items = create(TransactionEngine.CreateInput(
            description: trimmed, type: .payable, amount: amount,
            recurrence: .unique, dueDate: dueDate,
            notes: notes?.isEmpty == true ? nil : notes,
            fundID: fundID, fundMovementType: movement,
            accountID: accountID ?? selectedAccountID
        ))
        return items[0]
    }

    // MARK: - Orçamentos (Sprint 4)

    public enum BudgetError: Error, Equatable {
        case categoryRequired
        case invalidAmount
    }

    /// Cria ou atualiza o limite da categoria.
    /// - Único (`isRecurring == false`): upsert por categoria/mês/ano, vale só o mês.
    /// - Mensal (`isRecurring == true`): um registro por categoria, vale todos os
    ///   meses a partir de (month/year).
    @discardableResult
    public func saveBudget(categoryID: String?, month: Int, year: Int, limitAmount: Decimal, isRecurring: Bool = false) throws -> BudgetLimit {
        guard let categoryID, !categoryID.isEmpty,
              categories.contains(where: { $0.id == categoryID })
        else { throw BudgetError.categoryRequired }
        guard limitAmount > 0 else { throw BudgetError.invalidAmount }
        // Teto do Free: 2 registros totais. Editar o existente nunca bloqueia.
        let isNewBudget: Bool = {
            if isRecurring {
                return !budgets.contains { $0.categoryID == categoryID && $0.isRecurring }
            }
            return !budgets.contains {
                $0.categoryID == categoryID && $0.month == month && $0.year == year && !$0.isRecurring
            }
        }()
        guard isPro || !isNewBudget || budgets.count < PlanLimits.maxBudgets else {
            throw PlanError.limitReached(.budgets)
        }
        if isRecurring {
            if let i = budgets.firstIndex(where: { $0.categoryID == categoryID && $0.isRecurring }) {
                budgets[i].limitAmount = limitAmount
                // Antecipa o início se o novo for anterior.
                if year * 12 + month < budgets[i].year * 12 + budgets[i].month {
                    budgets[i].month = month
                    budgets[i].year = year
                }
                save()
                return budgets[i]
            }
            let limit = BudgetLimit(categoryID: categoryID, month: month, year: year, limitAmount: limitAmount, isRecurring: true)
            budgets.append(limit)
            save()
            return limit
        }
        if let i = budgets.firstIndex(where: {
            $0.categoryID == categoryID && $0.month == month && $0.year == year && !$0.isRecurring
        }) {
            budgets[i].limitAmount = limitAmount
            save()
            return budgets[i]
        }
        let limit = BudgetLimit(categoryID: categoryID, month: month, year: year, limitAmount: limitAmount)
        budgets.append(limit)
        save()
        return limit
    }

    /// Atualiza valor e recorrência de um limite existente (usado na edição).
    public func updateBudget(id: String, limitAmount: Decimal, isRecurring: Bool) throws {
        guard limitAmount > 0 else { throw BudgetError.invalidAmount }
        guard let i = budgets.firstIndex(where: { $0.id == id }) else { return }
        budgets[i].limitAmount = limitAmount
        budgets[i].isRecurring = isRecurring
        save()
    }

    public func deleteBudget(id: String) {
        budgets.removeAll { $0.id == id }
        save()
    }

    public func upsertBudget(_ limit: BudgetLimit) {
        if let i = budgets.firstIndex(where: { $0.id == limit.id }) {
            budgets[i] = limit
        } else if let i = budgets.firstIndex(where: {
            $0.categoryID == limit.categoryID && $0.month == limit.month && $0.year == limit.year
                && $0.isRecurring == limit.isRecurring
        }) {
            budgets[i] = limit
        } else {
            budgets.append(limit)
        }
        save()
    }

    // MARK: - Listas de desejo (Sprint 5: múltiplas listas)

    public enum WishlistError: Error, Equatable {
        case emptyName
        case listNotFound
        case invalidPrice
    }

    @discardableResult
    public func addWishlist(name: String, color: String, icon: String) throws -> Wishlist {
        guard isPro else { throw PlanError.limitReached(.wishlists) }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WishlistError.emptyName }
        let list = Wishlist(name: trimmed, color: color, icon: icon)
        wishlists.append(list)
        save()
        return list
    }

    public func updateWishlist(_ list: Wishlist) throws {
        let trimmed = list.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WishlistError.emptyName }
        guard let i = wishlists.firstIndex(where: { $0.id == list.id }) else { return }
        var copy = list
        copy.name = trimmed
        wishlists[i] = copy
        save()
    }

    /// Exclui a lista e seus itens em cascata.
    public func deleteWishlist(id: String) {
        wishlists.removeAll { $0.id == id }
        wishlistItems.removeAll { $0.wishlistID == id }
        save()
    }

    @discardableResult
    public func addItem(
        wishlistID: String, name: String, price: Decimal,
        priority: WishlistPriority, categoryID: String?, notes: String?
    ) throws -> WishlistItem {
        guard wishlists.contains(where: { $0.id == wishlistID }) else { throw WishlistError.listNotFound }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WishlistError.emptyName }
        guard price > 0 else { throw WishlistError.invalidPrice }
        let item = WishlistItem(
            wishlistID: wishlistID, name: trimmed, estimatedPrice: price,
            priority: priority, categoryID: categoryID,
            notes: notes?.isEmpty == true ? nil : notes
        )
        wishlistItems.append(item)
        save()
        return item
    }

    public func updateItem(_ item: WishlistItem) throws {
        let trimmed = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw WishlistError.emptyName }
        guard item.estimatedPrice > 0 else { throw WishlistError.invalidPrice }
        guard let i = wishlistItems.firstIndex(where: { $0.id == item.id }) else { return }
        var copy = item
        copy.name = trimmed
        wishlistItems[i] = copy
        save()
    }

    public func deleteItem(id: String) {
        wishlistItems.removeAll { $0.id == id }
        save()
    }

    public func setPurchased(id: String, purchased: Bool) {
        guard let i = wishlistItems.firstIndex(where: { $0.id == id }) else { return }
        wishlistItems[i].purchased = purchased
        wishlistItems[i].purchasedDate = purchased ? Date() : nil
        save()
    }

    public func items(of wishlistID: String) -> [WishlistItem] {
        wishlistItems.filter { $0.wishlistID == wishlistID }.sorted {
            if $0.purchased != $1.purchased { return !$0.purchased }
            if $0.priority != $1.priority { return rank($0.priority) > rank($1.priority) }
            return $0.estimatedPrice > $1.estimatedPrice
        }
    }

    private func rank(_ p: WishlistPriority) -> Int {
        switch p { case .low: 0; case .medium: 1; case .high: 2 }
    }

    public func pendingTotal(wishlistID: String) -> Decimal {
        wishlistItems.filter { $0.wishlistID == wishlistID && !$0.purchased }
            .reduce(Decimal(0)) { $0 + $1.estimatedPrice }
    }

    /// Gera conta a pagar única a partir do item (nome/preço/categoria).
    /// A conta é a informada ou a do filtro global (Todas = sem conta).
    @discardableResult
    public func generatePayable(itemID: String, dueDate: Date = Date(), accountID: String? = nil) throws -> FinancialTransaction {
        guard let item = wishlistItems.first(where: { $0.id == itemID }) else { throw WishlistError.listNotFound }
        let items = create(TransactionEngine.CreateInput(
            description: item.name, type: .payable, categoryID: item.categoryID,
            amount: item.estimatedPrice, recurrence: .unique, dueDate: dueDate,
            notes: "Gerado da lista de desejos",
            accountID: accountID ?? selectedAccountID
        ))
        return items[0]
    }

    // MARK: - Comprovantes (anexos por parcela)

    /// Comprovantes de UMA parcela, ordenados por data de anexo.
    public func attachments(for transactionID: String) -> [TransactionAttachment] {
        attachments.filter { $0.transactionID == transactionID }
            .sorted { $0.createdAt < $1.createdAt }
    }

    public func attachmentCount(for transactionID: String) -> Int {
        attachmentCounts()[transactionID] ?? 0
    }

    /// Contagem de anexos por transação em passe único — passe o mapa para
    /// as linhas em vez de chamar `attachmentCount(for:)` por linha (O(A)
    /// por linha → O(N*A) na lista).
    public func attachmentCounts() -> [String: Int] {
        var out: [String: Int] = [:]
        for att in attachments { out[att.transactionID, default: 0] += 1 }
        return out
    }

    /// Saldos de todos os fundos em 2 varreduras (antes: `balance(of:)`
    /// filtrava tudo por fundo → O(F*n) nos cards).
    public func fundBalances() -> [String: Decimal] {
        var moves: [String: Decimal] = [:]
        var withdrawals: [String: Decimal] = [:]
        for t in transactions where t.fundID != nil && t.status != .canceled {
            let id = t.fundID ?? ""
            switch t.fundMovementType {
            case .withdrawal: withdrawals[id, default: 0] += t.amount
            case .application: moves[id, default: 0] += t.amount
            case nil:
                // Compat: payable vinculada sem tipo = aplicação.
                if t.type == .payable { moves[id, default: 0] += t.amount }
            }
        }
        var out: [String: Decimal] = [:]
        for fund in funds {
            out[fund.id] = fund.initialAmount
                + (moves[fund.id] ?? 0) - (withdrawals[fund.id] ?? 0)
        }
        return out
    }

    /// URL do arquivo em disco (para preview/compartilhar), se existir.
    public func attachmentFileURL(_ attachment: TransactionAttachment) -> URL? {
        let url = attachmentsDir.appendingPathComponent(attachment.storedFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Anexa bytes (imagem/PDF) a uma transação existente.
    @discardableResult
    public func addAttachment(
        to transactionID: String, fileName: String, data: Data
    ) throws -> TransactionAttachment {
        guard transactions.contains(where: { $0.id == transactionID }) else {
            throw AttachmentError.transactionNotFound
        }
        guard AttachmentValidator.isSupported(fileName: fileName) else {
            throw AttachmentError.unsupportedType
        }
        guard !data.isEmpty else { throw AttachmentError.emptyData }
        let ext = (fileName as NSString).pathExtension.lowercased()
        let attachment = TransactionAttachment(
            transactionID: transactionID,
            fileName: AttachmentValidator.displayName(
                for: fileName, fallback: "comprovante.\(ext)"),
            storedFileName: "\(UUID().uuidString).\(ext)",
            mimeType: AttachmentValidator.mimeType(for: fileName),
            size: data.count
        )
        do {
            try data.write(
                to: attachmentsDir.appendingPathComponent(attachment.storedFileName),
                options: .atomic)
        } catch {
            throw AttachmentError.writeFailed(error.localizedDescription)
        }
        attachments.append(attachment)
        save()
        return attachment
    }

    /// Remove um comprovante (`unlink` síncrono; snapshot via `save()`).
    public func removeAttachment(id: String) {
        guard let att = attachments.first(where: { $0.id == id }) else { return }
        attachments.removeAll { $0.id == id }
        try? FileManager.default.removeItem(
            at: attachmentsDir.appendingPathComponent(att.storedFileName))
        save()
    }

    // MARK: - Persistência JSON

    /// Fila serial p/ IO de persistência (fora da main) + debounce.
    private let persistQueue = DispatchQueue(label: "finanzin.store.persist", qos: .utility)
    private var pendingSave: DispatchWorkItem?
    private let pendingSaveLock = NSLock()
    private struct Snapshot: Codable {
        var categories: [FinanceCategory]
        var transactions: [FinancialTransaction]
        var creditCards: [CreditCard]
        var accounts: [BankAccount]
        var funds: [Fund]
        var budgets: [BudgetLimit]
        var wishlists: [Wishlist]
        var wishlistItems: [WishlistItem]
        var attachments: [TransactionAttachment]

        // Compat: JSON antigo não tem `attachments`, `creditCards` nem `accounts`.
        private enum Keys: String, CodingKey {
            case categories, transactions, creditCards, accounts, funds, budgets
            case wishlists, wishlistItems, attachments
        }

        init(
            categories: [FinanceCategory], transactions: [FinancialTransaction],
            creditCards: [CreditCard], accounts: [BankAccount], funds: [Fund], budgets: [BudgetLimit],
            wishlists: [Wishlist], wishlistItems: [WishlistItem],
            attachments: [TransactionAttachment]
        ) {
            self.categories = categories
            self.transactions = transactions
            self.creditCards = creditCards
            self.accounts = accounts
            self.funds = funds
            self.budgets = budgets
            self.wishlists = wishlists
            self.wishlistItems = wishlistItems
            self.attachments = attachments
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            categories = try c.decode([FinanceCategory].self, forKey: .categories)
            transactions = try c.decode([FinancialTransaction].self, forKey: .transactions)
            creditCards = try c.decodeIfPresent([CreditCard].self, forKey: .creditCards) ?? []
            accounts = try c.decodeIfPresent([BankAccount].self, forKey: .accounts) ?? []
            funds = try c.decode([Fund].self, forKey: .funds)
            budgets = try c.decode([BudgetLimit].self, forKey: .budgets)
            wishlists = try c.decode([Wishlist].self, forKey: .wishlists)
            wishlistItems = try c.decode([WishlistItem].self, forKey: .wishlistItems)
            attachments = try c.decodeIfPresent(
                [TransactionAttachment].self, forKey: .attachments) ?? []
        }
    }

    /// Agenda a gravação do snapshot com debounce (250ms) numa fila de
    /// background — mutações na UI não bloqueiam o próximo frame. Captura o
    /// snapshot na hora da chamada (CoW, barato); encode + write fora da main.
    /// Testes que precisam do arquivo em disco na sequência devem chamar
    /// `flush()` após mutar.
    public func save() {
        guard let url = fileURL else { return }
        let snap = Snapshot(
            categories: categories, transactions: transactions,
            creditCards: creditCards, accounts: accounts, funds: funds,
            budgets: budgets, wishlists: wishlists, wishlistItems: wishlistItems,
            attachments: attachments
        )
        pendingSaveLock.lock()
        pendingSave?.cancel()
        let work = DispatchWorkItem { Self.write(snap, to: url) }
        pendingSave = work
        pendingSaveLock.unlock()
        persistQueue.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    /// Grava imediatamente (cancela o debounce pendente). Uso: testes e
    /// `scenePhase(.background)` — garante o arquivo antes de suspender.
    public func flush() {
        guard let url = fileURL else { return }
        pendingSaveLock.lock()
        pendingSave?.cancel()
        pendingSave = nil
        pendingSaveLock.unlock()
        let snap = Snapshot(
            categories: categories, transactions: transactions,
            creditCards: creditCards, accounts: accounts, funds: funds,
            budgets: budgets, wishlists: wishlists, wishlistItems: wishlistItems,
            attachments: attachments
        )
        Self.write(snap, to: url)
    }

    private static func write(_ snap: Snapshot, to url: URL) {
        do {
            let data = try JSONEncoder().encode(snap)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[Finanzin] save failed: \(error)")
        }
    }

    private func load(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let snap = try JSONDecoder().decode(Snapshot.self, from: data)
            categories = snap.categories
            transactions = snap.transactions
            creditCards = snap.creditCards
            accounts = snap.accounts
            funds = snap.funds
            budgets = snap.budgets
            wishlists = snap.wishlists
            wishlistItems = snap.wishlistItems
            attachments = snap.attachments
            migrateAccountsIfNeeded()
        } catch {
            // Arquivo ausente na primeira execução: começa vazio e faz seed.
        }
    }

    /// Upgrade de bases antigas (sem multi-contas): cria a conta padrão e
    /// move para ela todos os lançamentos que estavam sem conta, para o
    /// Dashboard/Transações contabilizarem tudo desde o primeiro dia.
    /// Roda uma única vez (depois `accounts` nunca mais fica vazio).
    private func migrateAccountsIfNeeded() {
        guard accounts.isEmpty else { return }
        let fallback = BankAccount(
            name: "Carteira",
            initialBalance: 0,
            color: "#0ea5e9",
            icon: "banknote"
        )
        accounts = [fallback]
        var moved = false
        for i in transactions.indices where transactions[i].accountID == nil {
            transactions[i].accountID = fallback.id
            moved = true
        }
        if moved { save() }
    }
}
