import Combine
import Foundation

/// Armazenamento em memória com persistência JSON em arquivo.
/// Contrato estável para futura troca por SwiftData sem mudar as Views.
public final class Store: ObservableObject {
    @Published public var categories: [FinanceCategory] = []
    @Published public var transactions: [FinancialTransaction] = []
    @Published public var funds: [Fund] = []
    @Published public var budgets: [BudgetLimit] = []
    @Published public var wishlists: [Wishlist] = []
    @Published public var wishlistItems: [WishlistItem] = []

    /// Preferência de privacidade (olho no topo): esconde valores monetários.
    /// Persistida em UserDefaults, fora do Snapshot JSON.
    private static let valuesHiddenKey = "finValuesHidden"
    @Published public var valuesHidden: Bool = UserDefaults.standard.bool(forKey: "finValuesHidden") {
        didSet { UserDefaults.standard.set(valuesHidden, forKey: Self.valuesHiddenKey) }
    }

    public func setValuesHidden(_ hidden: Bool) {
        valuesHidden = hidden
    }

    /// Texto de valor respeitando o modo privado ("••••••" quando oculto).
    public func maskedAmount(_ value: Decimal) -> String {
        valuesHidden ? "••••••" : Currency.format(value)
    }

    private let fileURL: URL?

    public init(persistTo fileURL: URL? = nil, seedIfEmpty: Bool = true) {
        self.fileURL = fileURL
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
        let items = TransactionEngine.expand(input)
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
        public var amount: Decimal
        public var notes: String?
        public var status: TransactionStatus?

        public init(description: String, type: TransactionType? = nil, categoryID: String?, amount: Decimal, notes: String?, status: TransactionStatus? = nil) {
            self.description = description
            self.type = type
            self.categoryID = categoryID
            self.amount = amount
            self.notes = notes
            self.status = status
        }
    }

    /// Aplica edição ao escopo. Valor/descrição/tipo/categoria/obs vão para todas
    /// do escopo; vencimento é preservado por parcela (cada uma mantém sua data).
    public func applySeriesEdit(targetID: String, scope: EditScope, edit: SeriesEdit) {
        let ids = Set(resolveScope(targetID: targetID, scope: scope))
        for i in transactions.indices where ids.contains(transactions[i].id) {
            transactions[i].description = edit.description
            if let type = edit.type { transactions[i].type = type }
            transactions[i].categoryID = edit.categoryID
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
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FundError.emptyName }
        guard (initialAmount as NSDecimalNumber).doubleValue >= 0 else { throw FundError.invalidAmount }
        let fund = Fund(name: trimmed, initialAmount: initialAmount, color: color, icon: icon, notes: notes?.isEmpty == true ? nil : notes)
        funds.append(fund)
        save()
        return fund
    }

    public func updateFund(_ fund: Fund) throws {
        let trimmed = fund.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FundError.emptyName }
        guard (fund.initialAmount as NSDecimalNumber).doubleValue >= 0 else { throw FundError.invalidAmount }
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
        notes: String? = nil
    ) throws -> FinancialTransaction {
        guard let fund = funds.first(where: { $0.id == fundID }) else { throw FundError.fundNotFound }
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FundError.emptyName }
        guard (amount as NSDecimalNumber).doubleValue > 0 else { throw FundError.invalidAmount }
        if movement == .withdrawal {
            let bal = (FundService.balance(fund: fund, transactions: transactions) as NSDecimalNumber).doubleValue
            guard (amount as NSDecimalNumber).doubleValue <= bal else { throw FundError.insufficientBalance }
        }
        let items = create(TransactionEngine.CreateInput(
            description: trimmed, type: .payable, amount: amount,
            recurrence: .unique, dueDate: dueDate,
            notes: notes?.isEmpty == true ? nil : notes,
            fundID: fundID, fundMovementType: movement
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
        guard (limitAmount as NSDecimalNumber).doubleValue > 0 else { throw BudgetError.invalidAmount }
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
        guard (limitAmount as NSDecimalNumber).doubleValue > 0 else { throw BudgetError.invalidAmount }
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
        guard (price as NSDecimalNumber).doubleValue > 0 else { throw WishlistError.invalidPrice }
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
        guard (item.estimatedPrice as NSDecimalNumber).doubleValue > 0 else { throw WishlistError.invalidPrice }
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
            return ($0.estimatedPrice as NSDecimalNumber).doubleValue > ($1.estimatedPrice as NSDecimalNumber).doubleValue
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
    @discardableResult
    public func generatePayable(itemID: String, dueDate: Date = Date()) throws -> FinancialTransaction {
        guard let item = wishlistItems.first(where: { $0.id == itemID }) else { throw WishlistError.listNotFound }
        let items = create(TransactionEngine.CreateInput(
            description: item.name, type: .payable, categoryID: item.categoryID,
            amount: item.estimatedPrice, recurrence: .unique, dueDate: dueDate,
            notes: "Gerado da lista de desejos"
        ))
        return items[0]
    }

    // MARK: - Persistência JSON

    private struct Snapshot: Codable {
        var categories: [FinanceCategory]
        var transactions: [FinancialTransaction]
        var funds: [Fund]
        var budgets: [BudgetLimit]
        var wishlists: [Wishlist]
        var wishlistItems: [WishlistItem]
    }

    public func save() {
        guard let url = fileURL else { return }
        let snap = Snapshot(
            categories: categories, transactions: transactions, funds: funds,
            budgets: budgets, wishlists: wishlists, wishlistItems: wishlistItems
        )
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
            funds = snap.funds
            budgets = snap.budgets
            wishlists = snap.wishlists
            wishlistItems = snap.wishlistItems
        } catch {
            // Arquivo ausente na primeira execução: começa vazio e faz seed.
        }
    }
}
