import Foundation
import FinanzinCore

// Mini-framework de testes (mesmo padrão do InoovexaAdmin: sem XCTest,
// pois o CommandLineTools deste ambiente não fornece o módulo XCTest).
// Executar com: swift run FinanzinCoreTests

nonisolated(unsafe) var failures: [String] = []

func check(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        let msg = "FAIL \(file.split(separator: "/").last ?? "?"):\(line) — \(message)"
        failures.append(msg)
        print(msg)
    }
}

func eq(_ a: Decimal, _ b: Double, accuracy: Double = 0.01, _ message: String) {
    let d = (a as NSDecimalNumber).doubleValue
    check(abs(d - b) <= accuracy, "\(message) (esperado \(b), obtido \(d))")
}

func D(_ y: Int, _ m: Int, _ d: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: y, month: m, day: d))!
}

// MARK: - TransactionEngine

func testSplitAbsorbsRoundingOnLast() {
    let parts = Currency.split(Decimal(100), into: 3)
    check(parts.count == 3, "split count == 3")
    eq(parts.reduce(Decimal(0), +), 100, "soma das parcelas == total")
    eq(parts[2], 33.34, "última parcela absorve centavos")
}

func testUniqueCreatesSingle() {
    let items = TransactionEngine.expand(.init(
        description: "Aluguel", type: .payable, amount: 1500,
        recurrence: .unique, dueDate: D(2026, 10, 5)
    ))
    check(items.count == 1, "única gera 1 item")
    check(items[0].status == .pending, "status inicial pending")
}

func testInstallmentGeneratesChildrenWithLinkage() {
    let items = TransactionEngine.expand(.init(
        description: "iPhone", type: .payable, amount: 3000,
        recurrence: .installment, dueDate: D(2026, 10, 10),
        totalInstallments: 3, interval: .monthly
    ))
    check(items.count == 3, "3 parcelas geradas")
    check(items[0].currentInstallment == 1, "parcela 1 numerada")
    check(items[1].currentInstallment == 2, "parcela 2 numerada")
    check(items[2].currentInstallment == 3, "parcela 3 numerada")
    check(items[1].parentID == items[0].id, "filha vinculada à raiz")
    eq(items.reduce(Decimal(0)) { $0 + $1.amount }, 3000, "soma == total")
    let cal = Calendar.current
    check(cal.component(.month, from: items[1].dueDate) == 11, "2ª parcela em nov")
    check(cal.component(.month, from: items[2].dueDate) == 12, "3ª parcela em dez")
}

func testFixedGeneratesHorizon() {
    let items = TransactionEngine.expand(.init(
        description: "Internet", type: .payable, amount: 120,
        recurrence: .fixed, dueDate: D(2026, 10, 1)
    ))
    check(items.count == 1 + TransactionEngine.recurringHorizonMonths, "fixa gera raiz + 24")
    check(items.dropFirst().allSatisfy { $0.parentID == items[0].id }, "futuras vinculadas")
}

func testFilterByMonthAndSearch() {
    let a = FinancialTransaction(description: "Mercado outubro", type: .payable, amount: 400, dueDate: D(2026, 10, 12))
    let b = FinancialTransaction(description: "Mercado novembro", type: .payable, amount: 400, dueDate: D(2026, 11, 12))
    let out = TransactionEngine.filter([a, b], year: 2026, month: 10, search: "outubro")
    check(out.count == 1 && out[0].description == "Mercado outubro", "filtro mês + busca")
}

func testScopeResolution() {
    let root = TransactionEngine.expand(.init(
        description: "Curso", type: .payable, amount: 900,
        recurrence: .installment, dueDate: D(2026, 10, 1),
        totalInstallments: 3, interval: .monthly
    ))
    guard let child2 = root.first(where: { $0.currentInstallment == 2 }) else {
        check(false, "parcela 2 existe"); return
    }
    let future = TransactionEngine.resolveScopeIDs(all: root, targetID: child2.id, scope: .future)
    check(Set(future).count == 2, "future pega 2 e 3")
    let all = TransactionEngine.resolveScopeIDs(all: root, targetID: child2.id, scope: .all)
    check(all.count == 3, "all pega 3")
    let one = TransactionEngine.resolveScopeIDs(all: root, targetID: child2.id, scope: .thisOne)
    check(one == [child2.id], "thisOne pega só 1")
}

// MARK: - Métricas / Fundos / Orçamento

func testMonthlyMetrics() {
    let tx: [FinancialTransaction] = [
        .init(description: "Salário", type: .receivable, amount: 5000, dueDate: D(2026, 10, 5), status: .paid),
        .init(description: "Aluguel", type: .payable, amount: 1500, dueDate: D(2026, 10, 5), status: .paid),
        .init(description: "Mercado", type: .payable, amount: 400, dueDate: D(2026, 10, 12), status: .pending),
    ]
    let m = MetricsService.monthly(tx, year: 2026, month: 10)
    eq(m.totalIncome, 5000, "receitas pagas")
    eq(m.totalExpense, 1500, "despesas pagas")
    eq(m.balance, 3500, "balanço")
    eq(m.pendingPayable, 400, "pendente a pagar")
}

func testFundBalance() {
    let fund = Fund(name: "Viagem", initialAmount: 500)
    let tx: [FinancialTransaction] = [
        .init(description: "Aporte", type: .payable, amount: 200, dueDate: D(2026, 10, 1), status: .paid, fundID: fund.id, fundMovementType: .application),
        .init(description: "Saque", type: .payable, amount: 100, dueDate: D(2026, 10, 2), status: .paid, fundID: fund.id, fundMovementType: .withdrawal),
    ]
    eq(FundService.balance(fund: fund, transactions: tx), 600, "saldo = 500 + 200 − 100")
}

func testBudgetRows() {
    let cat = FinanceCategory(name: "Mercado", type: .expense)
    let limits = [BudgetLimit(categoryID: cat.id, month: 10, year: 2026, limitAmount: 1500)]
    let tx: [FinancialTransaction] = [
        .init(description: "M1", type: .payable, categoryID: cat.id, amount: 400, dueDate: D(2026, 10, 3), status: .paid),
        .init(description: "M2", type: .payable, categoryID: cat.id, amount: 200, dueDate: D(2026, 10, 20), status: .pending),
    ]
    let rows = BudgetService.rows(limits: limits, transactions: tx, year: 2026, month: 10)
    check(rows.count == 1, "1 linha de orçamento")
    eq(rows[0].used, 600, "utilizado soma paga + pendente")
    check(!rows[0].isOver, "não estourou")
}

func testStoreUpsertBudget() {
    let store = Store(seedIfEmpty: false)
    let cat = FinanceCategory(name: "X", type: .expense)
    store.categories = [cat]
    store.upsertBudget(BudgetLimit(categoryID: cat.id, month: 10, year: 2026, limitAmount: 100))
    store.upsertBudget(BudgetLimit(categoryID: cat.id, month: 10, year: 2026, limitAmount: 200))
    check(store.budgets.count == 1, "upsert não duplica")
    eq(store.budgets[0].limitAmount, 200, "upsert atualiza valor")
}

// MARK: - Sprint 1: validação, categorias, baixa

func testValidation() {
    check(!TransactionEngine.validate(description: "Aluguel", amount: 100).isEmpty == false, "válido sem erros")
    check(TransactionEngine.validate(description: "Aluguel", amount: 0).isEmpty, "valor zero permitido")
    check(TransactionEngine.validate(description: "  ", amount: 100) == ["Descrição é obrigatória."], "descrição obrigatória")
    check(TransactionEngine.validate(description: "X", amount: -1) == ["Valor não pode ser negativo."], "valor negativo inválido")
    check(TransactionEngine.validate(description: "", amount: -5).count == 2, "dois erros juntos")
}

func testCategoryDuplicatePerType() {
    let store = Store(seedIfEmpty: false)
    do {
        _ = try store.addCategory(name: "Mercado", type: .expense, color: "#fff", icon: "cart")
        _ = try store.addCategory(name: "mercado", type: .expense, color: "#fff", icon: "cart")
        check(false, "duplicada deveria lançar")
    } catch Store.CategoryError.duplicateName {
        check(true, "duplicada lança duplicateName")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    // Mesmo nome em tipo diferente é permitido.
    do {
        _ = try store.addCategory(name: "Mercado", type: .income, color: "#fff", icon: "cart")
        check(true, "nome igual em tipo diferente ok")
    } catch {
        check(false, "não deveria lançar: \(error)")
    }
}

func testDeleteCategoryReassigns() {
    let store = Store(seedIfEmpty: false)
    let cat = try! store.addCategory(name: "Lazer", type: .expense, color: "#fff", icon: "star")
    let items = store.create(.init(description: "Cinema", type: .payable, categoryID: cat.id, amount: 50, dueDate: D(2026, 10, 3)))
    check(items[0].categoryID == cat.id, "transação vinculada")
    store.deleteCategory(id: cat.id)
    check(store.categories.isEmpty, "categoria removida")
    check(store.transactions[0].categoryID == nil, "transação solta para sem categoria")
}

// MARK: - Sprint 2: séries, escopos, cascade

func testValidateSeries() {
    check(!TransactionEngine.validateSeries(recurrence: .installment, count: 10, interval: .monthly).isEmpty == false, "parcelada válida")
    check(!TransactionEngine.validateSeries(recurrence: .installment, count: 1, interval: .monthly).isEmpty, "1 parcela inválida")
    check(!TransactionEngine.validateSeries(recurrence: .installment, count: 3, interval: nil).isEmpty, "sem intervalo inválido")
    check(TransactionEngine.validateSeries(recurrence: .fixed, count: nil, interval: nil).isEmpty, "fixa sem requisitos")
}

func testRecurringWeeklySteps() {
    let items = TransactionEngine.expand(.init(
        description: "Mesada", type: .receivable, amount: 100,
        recurrence: .recurring, dueDate: D(2026, 10, 1), interval: .weekly
    ))
    check(items.count == 1 + TransactionEngine.recurringHorizonMonths, "recorrente gera raiz + 24")
    let cal = Calendar.current
    let diff = cal.dateComponents([.day], from: items[0].dueDate, to: items[1].dueDate).day ?? 0
    check(diff == 7, "passo semanal de 7 dias (obtido \(diff))")
}

func testApplySeriesEditFuturePreservesDueDates() {
    let store = Store(seedIfEmpty: false)
    let items = store.create(.init(
        description: "Curso", type: .payable, amount: 900,
        recurrence: .installment, dueDate: D(2026, 10, 1),
        totalInstallments: 3, interval: .monthly
    ))
    let before = Dictionary(uniqueKeysWithValues: store.transactions.map { ($0.id, $0.dueDate) })
    let child2 = items.first { $0.currentInstallment == 2 }!
    store.applySeriesEdit(targetID: child2.id, scope: .future, edit: .init(
        description: "Curso novo", categoryID: nil, amount: 100, notes: nil
    ))
    let head = store.transactions.first { $0.currentInstallment == 1 }!
    check(head.description == "Curso", "1ª parcela intacta")
    for t in store.transactions where t.currentInstallment ?? 0 >= 2 {
        check(t.description == "Curso novo", "futuras renomeadas")
        eq(t.amount, 100, "valor aplicado ao escopo")
        check(t.dueDate == before[t.id], "vencimento preservado")
    }
}

func testDeleteSeriesFutureKeepsHead() {
    let store = Store(seedIfEmpty: false)
    let items = store.create(.init(
        description: "Seguro", type: .payable, amount: 1200,
        recurrence: .installment, dueDate: D(2026, 10, 1),
        totalInstallments: 4, interval: .monthly
    ))
    let child2 = items.first { $0.currentInstallment == 2 }!
    store.deleteSeries(targetID: child2.id, scope: .future)
    check(store.transactions.count == 1, "restou só a 1ª (obtido \(store.transactions.count))")
    check(store.transactions[0].currentInstallment == 1, "cabeça preservada")
}

func testDeleteRootCascadesChildren() {
    let store = Store(seedIfEmpty: false)
    let items = store.create(.init(
        description: "TV", type: .payable, amount: 2000,
        recurrence: .installment, dueDate: D(2026, 10, 1),
        totalInstallments: 2, interval: .monthly
    ))
    // Excluir a raiz (esta) não pode deixar filhas órfãs.
    store.deleteTransactions(ids: [items[0].id])
    check(store.transactions.isEmpty, "raiz + filhas removidas")
}

// MARK: - Sprint 3: fundos

func testFundMovementFlow() {
    let store = Store(seedIfEmpty: false)
    let fund = try! store.addFund(name: "Viagem", initialAmount: 500, color: "#8b5cf6", icon: "chart.pie.fill", notes: nil)
    try! store.addFundMovement(fundID: fund.id, movement: .application, amount: 200, description: "Aporte Viagem", dueDate: D(2026, 10, 1))
    try! store.addFundMovement(fundID: fund.id, movement: .withdrawal, amount: 100, description: "Saque", dueDate: D(2026, 10, 2))
    eq(store.balance(of: fund.id) ?? -1, 600, "saldo = 500 + 200 − 100")
    // Movimentação é conta a pagar vinculada.
    let linked = store.transactions.filter { $0.fundID == fund.id }
    check(linked.count == 2, "2 transações vinculadas")
    check(linked.allSatisfy { $0.type == .payable }, "aportes como conta a pagar")
    check(store.fundTransactions(fundID: fund.id).count == 2, "extrato retorna 2")
}

func testWithdrawalAboveBalanceThrows() {
    let store = Store(seedIfEmpty: false)
    let fund = try! store.addFund(name: "Reserva", initialAmount: 100, color: "#fff", icon: "x", notes: nil)
    do {
        try store.addFundMovement(fundID: fund.id, movement: .withdrawal, amount: 150, description: "Saque", dueDate: D(2026, 10, 1))
        check(false, "saque acima do saldo deveria lançar")
    } catch Store.FundError.insufficientBalance {
        check(true, "lança insufficientBalance")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    eq(store.balance(of: fund.id) ?? -1, 100, "saldo inalterado após falha")
}

func testDeleteFundBlockedWithMovements() {
    let store = Store(seedIfEmpty: false)
    let withMoves = try! store.addFund(name: "A", initialAmount: 0, color: "#fff", icon: "x", notes: nil)
    try! store.addFundMovement(fundID: withMoves.id, movement: .application, amount: 50, description: "Aporte", dueDate: D(2026, 10, 1))
    do {
        try store.deleteFund(id: withMoves.id)
        check(false, "exclusão com movimentações deveria lançar")
    } catch Store.FundError.hasMovements {
        check(true, "bloqueia com hasMovements")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    let empty = try! store.addFund(name: "B", initialAmount: 10, color: "#fff", icon: "x", notes: nil)
    do {
        try store.deleteFund(id: empty.id)
        check(store.funds.allSatisfy { $0.id != empty.id }, "fundo vazio excluído")
    } catch {
        check(false, "fundo vazio deveria excluir: \(error)")
    }
}

func testFundValidation() {
    let store = Store(seedIfEmpty: false)
    do {
        _ = try store.addFund(name: "  ", initialAmount: 0, color: "#fff", icon: "x", notes: nil)
        check(false, "nome vazio deveria lançar")
    } catch Store.FundError.emptyName {
        check(true, "nome obrigatório")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    do {
        _ = try store.addFund(name: "X", initialAmount: -1, color: "#fff", icon: "x", notes: nil)
        check(false, "valor negativo deveria lançar")
    } catch Store.FundError.invalidAmount {
        check(true, "inicial não negativo")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
}

// MARK: - Sprint 6: agregações do dashboard

func testBreakdownPercentages() {
    let food = FinanceCategory(name: "Mercado", type: .expense, color: "#10b981", icon: "cart")
    let tx: [FinancialTransaction] = [
        .init(description: "M1", type: .payable, categoryID: food.id, amount: 300, dueDate: D(2026, 10, 3), status: .paid),
        .init(description: "M2", type: .payable, categoryID: food.id, amount: 100, dueDate: D(2026, 10, 4), status: .pending),
        .init(description: "Sem cat", type: .payable, amount: 100, dueDate: D(2026, 10, 5), status: .paid),
        .init(description: "Salário", type: .receivable, categoryID: food.id, amount: 9999, dueDate: D(2026, 10, 5), status: .paid),
    ]
    let out = MetricsService.breakdown(tx, categories: [food], year: 2026, month: 10)
    check(out.count == 2, "2 grupos (Mercado + sem categoria), receitas fora")
    let top = out[0]
    check(top.categoryName == "Mercado", "maior primeiro")
    eq(top.total, 400, "soma paga + pendente")
    check(abs(top.percentage - 80) < 0.01, "400/500 = 80%")
    check(out[1].categoryID == "none" && out[1].categoryColor == "#64748b", "fallback sem categoria")
}

func testEvolutionEndsAtBaseMonth() {
    let tx: [FinancialTransaction] = [
        .init(description: "Out", type: .payable, amount: 100, dueDate: D(2026, 10, 3), status: .paid),
        .init(description: "Set", type: .receivable, amount: 200, dueDate: D(2026, 9, 3), status: .paid),
    ]
    let out = MetricsService.evolution(tx, months: 6, base: D(2026, 10, 15))
    check(out.count == 6, "6 competências")
    check(out.last?.month == 10 && out.last?.year == 2026, "termina no mês base")
    check(out[0].month == 5, "começa 5 meses antes")
    eq(out.last?.expense ?? -1, 100, "despesa de outubro")
    eq(out[4].income, 200, "receita de setembro")
}

func testUpcomingWindow() {
    let today = Dates.startOfDay(Date())
    let cal = Calendar.current
    func plus(_ days: Int) -> Date { cal.date(byAdding: .day, value: days, to: today)! }
    let tx: [FinancialTransaction] = [
        .init(description: "Amanhã", type: .payable, amount: 10, dueDate: plus(1), status: .pending),
        .init(description: "Daqui 30d", type: .payable, amount: 10, dueDate: plus(30), status: .pending),
        .init(description: "Paga", type: .payable, amount: 10, dueDate: plus(1), status: .paid),
    ]
    let out = MetricsService.upcoming(tx, days: 7, base: Date())
    check(out.count == 1 && out[0].description == "Amanhã", "só pendente na janela de 7 dias")
}

// MARK: - Sprint 5: desejos

func testWishlistCascadeDelete() {
    let store = Store(seedIfEmpty: false)
    let list = try! store.addWishlist(name: "Setup", color: "#fff", icon: "star")
    try! store.addItem(wishlistID: list.id, name: "Teclado", price: 500, priority: .high, categoryID: nil, notes: nil)
    try! store.addItem(wishlistID: list.id, name: "Mouse", price: 200, priority: .low, categoryID: nil, notes: nil)
    check(store.items(of: list.id).count == 2, "2 itens na lista")
    // Ordenação: alta primeiro.
    check(store.items(of: list.id)[0].name == "Teclado", "prioridade alta primeiro")
    store.deleteWishlist(id: list.id)
    check(store.wishlists.isEmpty, "lista removida")
    check(store.wishlistItems.isEmpty, "itens em cascata")
}

func testPurchaseAndTotals() {
    let store = Store(seedIfEmpty: false)
    let list = try! store.addWishlist(name: "Viagem", color: "#fff", icon: "x")
    let a = try! store.addItem(wishlistID: list.id, name: "Passagem", price: 2000, priority: .high, categoryID: nil, notes: nil)
    try! store.addItem(wishlistID: list.id, name: "Hotel", price: 1500, priority: .medium, categoryID: nil, notes: nil)
    eq(store.pendingTotal(wishlistID: list.id), 3500, "total pendente soma tudo")
    store.setPurchased(id: a.id, purchased: true)
    check(store.wishlistItems.first { $0.id == a.id }?.purchasedDate != nil, "data de compra preenchida")
    eq(store.pendingTotal(wishlistID: list.id), 1500, "comprado sai do total")
    // Comprados vão para o fim.
    check(store.items(of: list.id).last?.id == a.id, "comprado por último")
    store.setPurchased(id: a.id, purchased: false)
    check(store.wishlistItems.first { $0.id == a.id }?.purchasedDate == nil, "reabrir limpa data")
}

func testGeneratePayableFromItem() {
    let store = Store(seedIfEmpty: false)
    let cat = FinanceCategory(name: "Lazer", type: .expense)
    store.categories = [cat]
    let list = try! store.addWishlist(name: "Setup", color: "#fff", icon: "x")
    let item = try! store.addItem(wishlistID: list.id, name: "Monitor", price: 1800, priority: .high, categoryID: cat.id, notes: nil)
    let tx = try! store.generatePayable(itemID: item.id, dueDate: D(2026, 11, 5))
    check(tx.type == .payable && tx.recurrence == .unique, "gera pagar único")
    eq(tx.amount, 1800, "mesmo preço")
    check(tx.categoryID == cat.id, "mesma categoria")
}

func testWishlistItemValidation() {
    let store = Store(seedIfEmpty: false)
    let list = try! store.addWishlist(name: "X", color: "#fff", icon: "x")
    do {
        try store.addItem(wishlistID: list.id, name: "  ", price: 10, priority: .low, categoryID: nil, notes: nil)
        check(false, "nome vazio deveria lançar")
    } catch Store.WishlistError.emptyName {
        check(true, "nome obrigatório")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    do {
        try store.addItem(wishlistID: list.id, name: "Y", price: 0, priority: .low, categoryID: nil, notes: nil)
        check(false, "preço zero deveria lançar")
    } catch Store.WishlistError.invalidPrice {
        check(true, "preço > 0")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    do {
        try store.addItem(wishlistID: "inexistente", name: "Z", price: 10, priority: .low, categoryID: nil, notes: nil)
        check(false, "lista inexistente deveria lançar")
    } catch Store.WishlistError.listNotFound {
        check(true, "lista precisa existir")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
}

// MARK: - Sprint 4: orçamentos

func testSaveBudgetValidation() {
    let store = Store(seedIfEmpty: false)
    do {
        try store.saveBudget(categoryID: nil, month: 10, year: 2026, limitAmount: 100)
        check(false, "sem categoria deveria lançar")
    } catch Store.BudgetError.categoryRequired {
        check(true, "categoria obrigatória")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    let cat = FinanceCategory(name: "Mercado", type: .expense)
    store.categories = [cat]
    do {
        try store.saveBudget(categoryID: cat.id, month: 10, year: 2026, limitAmount: 0)
        check(false, "limite zero deveria lançar")
    } catch Store.BudgetError.invalidAmount {
        check(true, "limite > 0")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
}

func testSaveBudgetUpsertAndDelete() {
    let store = Store(seedIfEmpty: false)
    let cat = FinanceCategory(name: "Mercado", type: .expense)
    store.categories = [cat]
    try! store.saveBudget(categoryID: cat.id, month: 10, year: 2026, limitAmount: 1000)
    try! store.saveBudget(categoryID: cat.id, month: 10, year: 2026, limitAmount: 1500)
    check(store.budgets.count == 1, "upsert não duplica")
    eq(store.budgets[0].limitAmount, 1500, "atualiza valor")
    store.deleteBudget(id: store.budgets[0].id)
    check(store.budgets.isEmpty, "exclui limite")
}

func testBudgetRowFlags() {
    let cat = FinanceCategory(name: "Lazer", type: .expense)
    let limits = [BudgetLimit(categoryID: cat.id, month: 10, year: 2026, limitAmount: 100)]
    let over = BudgetService.rows(
        limits: limits,
        transactions: [.init(description: "Show", type: .payable, categoryID: cat.id, amount: 130, dueDate: D(2026, 10, 3), status: .paid)],
        year: 2026, month: 10
    )
    check(over[0].isOver, "130/100 estourou")
    check(!over[0].isWarning, "estourado não é só alerta")
    eq(over[0].remaining, -30, "restante negativo")
    let warn = BudgetService.rows(
        limits: limits,
        transactions: [.init(description: "Cinema", type: .payable, categoryID: cat.id, amount: 85, dueDate: D(2026, 10, 3), status: .pending)],
        year: 2026, month: 10
    )
    check(!warn[0].isOver && warn[0].isWarning, "85/100 é alerta (pendente conta)")
}

func testStoreCreateUniqueAndToggle() {
    let store = Store(seedIfEmpty: false)
    let items = store.create(.init(description: "Salário", type: .receivable, amount: 5000, dueDate: D(2026, 10, 5)))
    check(items.count == 1, "à vista cria 1")
    store.updateStatus(id: items[0].id, to: .paid)
    check(store.transactions[0].status == .paid, "baixa para pago")
    check(store.transactions[0].paidDate != nil, "paidDate preenchida")
    store.updateStatus(id: items[0].id, to: .pending)
    check(store.transactions[0].paidDate == nil, "reabrir limpa paidDate")
}

// MARK: - Sprint 7: configurações

func testAppSettingsDefaults() {
    let s = AppSettings.defaults
    check(s.language == .ptBR, "idioma default pt-BR")
    check(s.currency == .BRL, "moeda default BRL")
    check(s.theme == .system, "tema default sistema")
    check(!s.notifications.isAnyEnabled, "notificações default desligadas")
    check(s.notifications.hour == 9 && s.notifications.minute == 0, "hora default 09:00")
}

func testAppSettingsRoundTrip() {
    let s = AppSettings(
        language: .en, currency: .JPY, theme: .dark,
        notifications: NotificationPrefs(
            overdueDailyEnabled: true, payDueDayEnabled: true,
            receiveDueDayEnabled: true, hour: 20, minute: 30
        )
    )
    let data = try! JSONEncoder().encode(s)
    let back = try! JSONDecoder().decode(AppSettings.self, from: data)
    check(back == s, "settings sobrevive ao JSON round-trip")
}

func testStoreSettingsUpdateAndReset() {
    let store = Store(seedIfEmpty: false)
    let original = store.settings
    store.updateCurrency(.EUR)
    check(store.settings.currency == .EUR, "moeda atualiza")
    store.updateLanguage(.en)
    check(store.settings.language == .en, "idioma atualiza")
    store.updateTheme(.light)
    check(store.settings.theme == .light, "tema atualiza")
    store.resetSettings()
    check(store.settings == .defaults, "reset volta aos padrões")
    store.replaceSettings(original)
}

func testCurrencyFiveFormats() {
    let v = Decimal(string: "1234.56") ?? 0
    for c in AppCurrency.allCases {
        let s = Currency.format(v, currencyCode: c.currencyCode, localeIdentifier: c.localeIdentifier)
        check(s.contains(c.symbol), "\(c.rawValue) contém \(c.symbol) (obtido \(s))")
    }
}

func testL10nCoverage() {
    for key in L10nKey.allCases {
        let pt = L10n.t(key, .ptBR)
        let en = L10n.t(key, .en)
        check(!pt.isEmpty && !en.isEmpty, "\(key.rawValue) traduzido nos 2 idiomas")
    }
    check(L10n.t(.settingsTitle, .ptBR) != L10n.t(.settingsTitle, .en), "título difere entre idiomas")
    check(TransactionType.payable.label(language: .en) == "Payable", "enum traduzido")
    check(ThemeMode.dark.label(language: .en) == "Dark", "tema traduzido")
}

func testNotificationPlannerOff() {
    let tx = [FinancialTransaction(description: "X", type: .payable, amount: 10, dueDate: D(2026, 10, 1))]
    check(NotificationPlanner.plans(transactions: tx, settings: .defaults).isEmpty, "tudo desligado → vazio")
}

func testValidateEnglish() {
    check(TransactionEngine.validate(description: "  ", amount: 10, language: .en) == ["Description is required."], "erro EN descrição")
    check(TransactionEngine.validate(description: "X", amount: -1, language: .en) == ["Amount cannot be negative."], "erro EN valor")
    check(TransactionEngine.validate(description: "  ", amount: 10) == ["Descrição é obrigatória."], "default segue PT")
    check(!TransactionEngine.validateSeries(recurrence: .installment, count: 1, interval: nil, language: .en).isEmpty, "série EN tem erros")
    check(TransactionEngine.validateSeries(recurrence: .installment, count: 1, interval: nil, language: .en)[0].contains("Installments"), "série EN traduzida")
    check(TransactionEngine.validateSettle(amount: -1, language: .en) == ["Settlement amount cannot be negative."], "baixa EN")
}

func testEvolutionLocale() {
    let tx: [FinancialTransaction] = [
        .init(description: "Out", type: .payable, amount: 100, dueDate: D(2026, 10, 3), status: .paid),
    ]
    let pt = MetricsService.evolution(tx, months: 1, base: D(2026, 10, 15))
    let en = MetricsService.evolution(tx, months: 1, base: D(2026, 10, 15), localeIdentifier: "en_US")
    check(pt[0].label != en[0].label, "rótulo do mês muda com locale (\(pt[0].label) vs \(en[0].label))")
    check(en[0].label.contains("Oct"), "EN usa Oct (obtido \(en[0].label))")
}

func testResetToDefaults() {
    let store = Store(seedIfEmpty: false)
    let cat = try! store.addCategory(name: "Minha", type: .expense, color: "#fff", icon: "x")
    _ = store.create(.init(description: "Conta", type: .payable, categoryID: cat.id, amount: 10, dueDate: D(2026, 10, 1)))
    let fund = try! store.addFund(name: "F", initialAmount: 5, color: "#fff", icon: "x", notes: nil)
    try! store.saveBudget(categoryID: cat.id, month: 10, year: 2026, limitAmount: 100)
    let list = try! store.addWishlist(name: "L", color: "#fff", icon: "x")
    try! store.addItem(wishlistID: list.id, name: "I", price: 10, priority: .low, categoryID: nil, notes: nil)
    _ = try! store.addCard(name: "N", closingDay: 10, dueDay: 17)
    _ = try! store.addAccount(name: "Extra", initialBalance: 10, color: "#fff", icon: "x")
    let settingsBefore = store.settings
    store.resetToDefaults()
    check(store.transactions.isEmpty, "transações apagadas")
    check(store.creditCards.isEmpty, "cartões apagados")
    check(store.funds.isEmpty, "fundos apagados")
    check(store.budgets.isEmpty, "orçamentos apagados")
    check(store.wishlists.isEmpty && store.wishlistItems.isEmpty, "listas apagadas")
    check(store.categories.count == 8, "só as 8 categorias padrão (obtido \(store.categories.count))")
    check(store.accounts.count == 1 && store.accounts[0].name == "Carteira", "só a conta padrão Carteira")
    check(store.settings == settingsBefore, "preferências preservadas")
}

func testNotificationPlannerKinds() {    let cal = Calendar.current
    let today = cal.startOfDay(for: Date())
    func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }
    let tx = [
        FinancialTransaction(description: "Vencida", type: .payable, amount: 100, dueDate: day(-5)),
        FinancialTransaction(description: "Boleto hoje", type: .payable, amount: 50, dueDate: today),
        FinancialTransaction(description: "Salário hoje", type: .receivable, amount: 200, dueDate: today),
        FinancialTransaction(description: "Quitada", type: .payable, amount: 10, dueDate: today, status: .paid),
        FinancialTransaction(description: "Distante", type: .payable, amount: 10, dueDate: day(90)),
    ]
    var s = AppSettings.defaults
    s.notifications = NotificationPrefs(
        overdueDailyEnabled: true, payDueDayEnabled: true,
        receiveDueDayEnabled: true, hour: 9, minute: 0
    )
    let plans = NotificationPlanner.plans(transactions: tx, settings: s, now: Date())
    let kinds = Set(plans.map(\.kind))
    check(kinds == [.overdueDaily, .payDueDay, .receiveDueDay], "3 tipos planejados")
    check(plans.filter { $0.kind == .overdueDaily }.count == 1, "1 resumo diário recorrente")
    check(plans.first { $0.kind == .overdueDaily }?.repeats == true, "resumo repete")
    check(!plans.contains { $0.body.contains("Quitada") }, "paga fora")
    check(!plans.contains { $0.body.contains("Distante") }, "fora do horizonte fora")
    check(!plans.contains { $0.body.contains("Vencida") && $0.kind != .overdueDaily }, "vencida só no resumo")
}

func testDraftParsesFullURL() {
    let url = URL(string: "finanzin://nova-transacao?valor=12,90&descricao=Padaria&data=2026-09-23")!
    guard let draft = TransactionDraft.from(url: url) else {
        check(false, "deep link válido gera draft"); return
    }
    eq(draft.amount ?? 0, 12.90, "valor com vírgula")
    check(draft.description == "Padaria", "descrição preservada")
    let cal = Calendar.current
    check(cal.component(.year, from: draft.date ?? Date()) == 2026, "ano do draft")
    check(cal.component(.month, from: draft.date ?? Date()) == 9, "mês do draft")
    check(cal.component(.day, from: draft.date ?? Date()) == 23, "dia do draft")
}

func testDraftParsesThousandsAndENHost() {
    let url = URL(string: "finanzin://new-transaction?value=1.234,56")!
    guard let draft = TransactionDraft.from(url: url) else {
        check(false, "host EN gera draft"); return
    }
    eq(draft.amount ?? 0, 1234.56, "milhar pt-BR (obtido \(draft.amount ?? 0))")
    check(draft.description == nil, "sem descrição → nil")
}

func testDraftRejectsOtherHost() {
    check(TransactionDraft.from(url: URL(string: "finanzin://outra-coisa?valor=10")!) == nil, "host estranho → nil")
    let empty = TransactionDraft.from(url: URL(string: "finanzin://nova-transacao")!)
    check(empty != nil, "sem query ainda abre o form")
    check(empty?.amount == nil && empty?.description == nil, "sem query → campos nil")
}

func testDraftRoundTrip() {
    let date = D(2026, 9, 23)
    guard let url = TransactionDraft.url(amount: Decimal(string: "42.5") ?? 0, description: "Uber", date: date),
          let back = TransactionDraft.from(url: url) else {
        check(false, "round-trip gera URL parseável"); return
    }
    eq(back.amount ?? 0, 42.5, "valor sobrevive ao round-trip")
    check(back.description == "Uber", "descrição sobrevive ao round-trip")
    let cal = Calendar.current
    check(cal.component(.day, from: back.date ?? Date()) == 23, "data sobrevive ao round-trip")
}

func testDraftParsesBRDate() {
    let url = URL(string: "finanzin://nova-transacao?data=23/09/2026")!
    let day = Calendar.current.component(.day, from: TransactionDraft.from(url: url)?.date ?? Date())
    check(day == 23, "data dd/MM/yyyy aceita")
}

// MARK: - Comprovantes (anexos)

func testAttachmentsDir() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("FinanzinTest-\(UUID().uuidString)", isDirectory: true)
}

func testAttachmentAcceptsImageAndPDF() {
    let store = Store(seedIfEmpty: false, attachmentsDirectory: testAttachmentsDir())
    let items = store.create(.init(
        description: "Mercado", type: .payable, amount: 100, dueDate: D(2026, 10, 3)))
    let id = items[0].id
    let img = try! store.addAttachment(to: id, fileName: "nota.jpg", data: Data([0xFF, 0xD8, 0x01]))
    check(img.mimeType == "image/jpeg", "jpg mapeia image/jpeg")
    let pdf = try! store.addAttachment(to: id, fileName: "boleto.PDF", data: Data([0x25, 0x50, 0x44]))
    check(pdf.isPDF, "PDF detectado (ext maiúscula)")
    check(store.attachmentCount(for: id) == 2, "2 anexos na parcela")
    check(store.attachmentFileURL(img) != nil, "arquivo da imagem existe em disco")
    do {
        try store.addAttachment(to: id, fileName: "planilha.zip", data: Data([0x01]))
        check(false, "zip deveria lançar")
    } catch AttachmentError.unsupportedType {
        check(true, "zip lança unsupportedType")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    do {
        try store.addAttachment(to: "inexistente", fileName: "x.jpg", data: Data([0x01]))
        check(false, "transação inexistente deveria lançar")
    } catch AttachmentError.transactionNotFound {
        check(true, "lança transactionNotFound")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
}

func testAttachmentDeleteRemovesFile() {
    let dir = testAttachmentsDir()
    let store = Store(seedIfEmpty: false, attachmentsDirectory: dir)
    let items = store.create(.init(
        description: "Conta", type: .payable, amount: 50, dueDate: D(2026, 10, 3)))
    let att = try! store.addAttachment(to: items[0].id, fileName: "n.jpg", data: Data([0x01, 0x02]))
    let path = dir.appendingPathComponent(att.storedFileName).path
    check(FileManager.default.fileExists(atPath: path), "arquivo gravado")
    store.removeAttachment(id: att.id)
    check(store.attachments.isEmpty, "metadado removido")
    check(!FileManager.default.fileExists(atPath: path), "arquivo removido do disco")
    // Excluir a transação limpa os anexos restantes em cascata.
    let att2 = try! store.addAttachment(to: items[0].id, fileName: "m.png", data: Data([0x03]))
    let path2 = dir.appendingPathComponent(att2.storedFileName).path
    store.deleteTransactions(ids: [items[0].id])
    check(store.attachments.isEmpty, "cascata limpa metadados")
    check(!FileManager.default.fileExists(atPath: path2), "cascata apaga arquivo")
}

func testAttachmentSnapshotRoundTrip() {
    let dir = testAttachmentsDir()
    let json = dir.appendingPathComponent("finanzin.json")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let store = Store(persistTo: json, seedIfEmpty: false, attachmentsDirectory: dir)
    let items = store.create(.init(
        description: "Aluguel", type: .payable, amount: 1500, dueDate: D(2026, 10, 5)))
    _ = try! store.addAttachment(to: items[0].id, fileName: "recibo.jpg", data: Data([0x09, 0x08]))
    store.flush() // `save()` é debounced em background: grava antes de reabrir.
    let reopened = Store(persistTo: json, seedIfEmpty: false, attachmentsDirectory: dir)
    check(reopened.attachments.count == 1, "metadado sobrevive ao JSON")
    check(reopened.attachments[0].transactionID == items[0].id, "vínculo preservado")
    check(reopened.attachmentFileURL(reopened.attachments[0]) != nil, "arquivo resolvido após reload")
}

func testAttachmentSnapshotCompatOldJSON() {
    // JSON antigo (sem chave `attachments`) abre sem anexos.
    let raw = """
    {"categories":[],"transactions":[],"funds":[],"budgets":[],"wishlists":[],"wishlistItems":[]}
    """
    let decoded = try! JSONDecoder().decode(
        [String: [String]].self, from: Data(raw.utf8))
    check(decoded["attachments"] == nil, "json antigo não tem anexos")
    let store = Store(seedIfEmpty: false, attachmentsDirectory: testAttachmentsDir())
    check(store.attachments.isEmpty, "store novo começa sem anexos")
}

func testSeriesEditKeepsAttachmentsPerParcel() {
    let store = Store(seedIfEmpty: false, attachmentsDirectory: testAttachmentsDir())
    let items = store.create(.init(
        description: "Curso", type: .payable, amount: 900,
        recurrence: .installment, dueDate: D(2026, 10, 1),
        totalInstallments: 3, interval: .monthly
    ))
    let child2 = items.first { $0.currentInstallment == 2 }!
    _ = try! store.addAttachment(to: child2.id, fileName: "comp2.jpg", data: Data([0x07]))
    store.applySeriesEdit(targetID: child2.id, scope: .future, edit: .init(
        description: "Curso novo", categoryID: nil, amount: 100, notes: nil
    ))
    check(store.attachmentCount(for: child2.id) == 1, "anexo fica na parcela 2")
    let child3 = store.transactions.first { $0.currentInstallment == 3 }!
    check(store.attachmentCount(for: child3.id) == 0, "parcela 3 não herda anexo")
    let head = store.transactions.first { $0.currentInstallment == 1 }!
    check(store.attachmentCount(for: head.id) == 0, "cabeça intacta sem anexo")
}

// MARK: - Leitura de recibo (OCR → rascunho)

func testReceiptParsesTotalWithMerchantAndDate() {
    let scan = ReceiptParser.parse(lines: [
        "PAO DE ACUCAR - MOEMA",
        "CNPJ 12.345.678/0001-90",
        "CUPOM FISCAL 000123",
        "Pao frances kg        8,90",
        "Leite integral        5,49",
        "TOTAL R$ 128,90",
        "23/09/2026 14:32",
    ])
    eq(scan.amount ?? 0, 128.90, "total do cupom")
    check(scan.merchantName == "PAO DE ACUCAR - MOEMA", "estabelecimento (obtido \(scan.merchantName ?? "nil"))")
    let cal = Calendar.current
    check(cal.component(.day, from: scan.date ?? Date()) == 23, "dia do cupom")
    check(cal.component(.month, from: scan.date ?? Date()) == 9, "mês do cupom")
    check(scan.confidence == 1.0, "confiança cheia")
}

func testReceiptPrefersTotalOverTroco() {
    let scan = ReceiptParser.parse(lines: [
        "MERCADINHO DO ZE",
        "TOTAL 250,00",
        "DINHEIRO 300,00",
        "TROCO 50,00",
    ])
    eq(scan.amount ?? 0, 250.00, "TOTAL vence TROCO maior? não — TROCO ignorado (obtido \(scan.amount ?? 0))")
}

func testReceiptParsesThousands() {
    let scan = ReceiptParser.parse(lines: [
        "LOJAS RENNER",
        "VALOR TOTAL R$ 1.234,56",
    ])
    eq(scan.amount ?? 0, 1234.56, "milhar pt-BR (obtido \(scan.amount ?? 0))")
}

func testReceiptFallbackLargestWithoutTotal() {
    let scan = ReceiptParser.parse(lines: [
        "CANTINA DA PRACA",
        "Prato feito   32,90",
        "Suco          9,50",
    ])
    eq(scan.amount ?? 0, 32.90, "sem TOTAL usa o maior valor")
    check(scan.confidence == 0.75, "confiança sem data (obtido \(scan.confidence))")
}

func testReceiptSkipsFiscalHeaders() {
    let scan = ReceiptParser.parse(lines: [
        "CUPOM FISCAL ELETRONICO",
        "CNPJ 98.765.432/0001-10",
        "POSTO SHELL IPIRANGA",
        "GASOLINA COMUM 200,00",
    ])
    check(scan.merchantName == "POSTO SHELL IPIRANGA", "pula cabeçalho fiscal (obtido \(scan.merchantName ?? "nil"))")
}

func testReceiptSuggestsCategory() {
    let cats = [
        FinanceCategory(name: "Mercado", type: .expense),
        FinanceCategory(name: "Transporte", type: .expense),
        FinanceCategory(name: "Saúde", type: .expense),
        FinanceCategory(name: "Salário", type: .income),
    ]
    let posto = ReceiptParser.parse(lines: ["POSTO SHELL", "GASOLINA 200,00"])
    let postoID = ReceiptParser.suggestCategoryID(in: cats, scan: posto)
    check(cats.first { $0.id == postoID }?.name == "Transporte", "posto → Transporte")
    let farma = ReceiptParser.parse(lines: ["DROGASIL", "TOTAL 89,90"])
    let farmaID = ReceiptParser.suggestCategoryID(in: cats, scan: farma)
    check(cats.first { $0.id == farmaID }?.name == "Saúde", "drogaria → Saúde")
    let unknown = ReceiptParser.parse(lines: ["XYZ INFORMATICA", "TOTAL 10,00"])
    check(ReceiptParser.suggestCategoryID(in: cats, scan: unknown) == nil, "sem match → nil")
}

func testReceiptDraftMapping() {
    let scan = ReceiptScanResult(
        amount: Decimal(string: "42.5"), merchantName: "Padaria",
        date: D(2026, 9, 23), rawText: "x", confidence: 1)
    let draft = TransactionDraft(scan: scan)
    eq(draft.amount ?? 0, 42.5, "valor vira draft")
    check(draft.description == "Padaria", "descrição vira draft")
    check(Calendar.current.component(.day, from: draft.date ?? Date()) == 23, "data vira draft")
}

func testReceiptNormalizeAmounts() {
    eq(ReceiptParser.normalizeAmount("R$ 1.234,56") ?? 0, 1234.56, "R$ + milhar")
    eq(ReceiptParser.normalizeAmount("12,90") ?? 0, 12.90, "vírgula simples")
    eq(ReceiptParser.normalizeAmount("250.00") ?? 0, 250.00, "ponto decimal")
    check(ReceiptParser.normalizeAmount("  ") == nil, "vazio → nil")
}

// MARK: - IA local: prompt/voz → rascunho (TransactionNLParser)

func nlCats() -> [FinanceCategory] {
    let store = Store(seedIfEmpty: false)
    Seed.apply(to: store)
    return store.categories
}

func testNLParsesBasicExpense() {
    let r = TransactionNLParser.parse(
        text: "paguei 45 na padaria ontem",
        categories: nlCats(), referenceDate: D(2026, 9, 24))
    eq(r.amount ?? 0, 45, "valor inteiro avulso")
    check(r.type == .payable, "paguei → despesa")
    check(r.description == "Padaria", "descrição limpa (obtido \(r.description ?? "?"))")
    check(Calendar.current.component(.day, from: r.date) == 23, "ontem = dia 23")
    check(r.dateExplicit, "data explícita")
    check(r.confidence >= 0.8, "confiança alta com valor+descrição+data")
}

func testNLParsesDecimalAndCategory() {
    let cats = nlCats()
    let r = TransactionNLParser.parse(
        text: "gastei 128,90 no assai",
        categories: cats, referenceDate: D(2026, 9, 24))
    eq(r.amount ?? 0, 128.90, "decimal com vírgula")
    check(cats.first { $0.id == r.categoryID }?.name == "Mercado", "assai → Mercado")
}

func testNLParsesThousands() {
    let r = TransactionNLParser.parse(
        text: "comprei iphone por R$ 1.234,56",
        referenceDate: D(2026, 9, 24))
    eq(r.amount ?? 0, 1234.56, "milhar pt-BR")
    check((r.description ?? "").lowercased().contains("iphone"), "mantém o produto")
}

func testNLParsesIncome() {
    let cats = nlCats()
    let r = TransactionNLParser.parse(
        text: "recebi 5000 do salário hoje",
        categories: cats, referenceDate: D(2026, 9, 24))
    eq(r.amount ?? 0, 5000, "valor da receita")
    check(r.type == .receivable, "recebi → receita")
    check(cats.first { $0.id == r.categoryID }?.name == "Salário", "salário → categoria")
}

func testNLParsesInstallments() {
    let r = TransactionNLParser.parse(
        text: "comprei iphone 3000 em 3x",
        referenceDate: D(2026, 9, 24))
    eq(r.amount ?? 0, 3000, "valor não confunde com 3x")
    check(r.installmentCount == 3, "3x → 3 parcelas")
    let r2 = TransactionNLParser.parse(
        text: "gastei 1200 em 12 parcelas", referenceDate: D(2026, 9, 24))
    check(r2.installmentCount == 12, "12 parcelas por extenso")
}

func testNLParsesExplicitDay() {
    let r = TransactionNLParser.parse(
        text: "paguei 80 no mercado dia 12",
        referenceDate: D(2026, 9, 24))
    let comps = Calendar.current.dateComponents([.day, .month], from: r.date)
    check(comps.day == 12 && comps.month == 9, "dia 12 do mês atual")
    check(r.dateExplicit, "dia explícito")
}

func testNLParsesWeekday() {
    // 24/09/2026 é quinta: "sexta passada" = 18/09.
    let r = TransactionNLParser.parse(
        text: "gastei 60 no uber sexta passada",
        referenceDate: D(2026, 9, 24))
    let comps = Calendar.current.dateComponents([.day, .month], from: r.date)
    check(comps.day == 18 && comps.month == 9, "sexta passada = 18/09 (obtido \(comps.day ?? 0))")
}

func testNLDefaultsTodayWithoutDate() {
    let r = TransactionNLParser.parse(
        text: "gastei 20 no café", referenceDate: D(2026, 9, 24))
    check(!r.dateExplicit, "sem data → hoje implícito")
    check(Calendar.current.component(.day, from: r.date) == 24, "data = referência")
}

func testNLEmptyText() {
    let r = TransactionNLParser.parse(text: "   ", referenceDate: D(2026, 9, 24))
    check(r.amount == nil && r.confidence == 0, "vazio → sem valor e confiança 0")
}

func testNLWithoutValueLowConfidence() {
    let r = TransactionNLParser.parse(
        text: "paguei a padaria", referenceDate: D(2026, 9, 24))
    check(r.amount == nil, "sem número → sem valor")
    check((r.description ?? "").lowercased().contains("padaria"), "descrição preservada")
    check(r.confidence < 0.5, "confiança baixa sem valor")
}

func testNLToDraftMapping() {
    let cats = nlCats()
    let r = TransactionNLParser.parse(
        text: "recebi 200 do freelance ontem",
        categories: cats, referenceDate: D(2026, 9, 24))
    let draft = r.toDraft()
    eq(draft.amount ?? 0, 200, "draft leva valor")
    check(draft.type == .receivable, "draft leva tipo")
    check(draft.categoryID == r.categoryID, "draft leva categoria")
    check(Calendar.current.component(.day, from: draft.date ?? Date()) == 23, "draft leva data")
}

func testNLIgnoresYearLikeNumbers() {
    let r = TransactionNLParser.parse(
        text: "paguei 90 no mercado 12/09",
        referenceDate: D(2026, 9, 24))
    eq(r.amount ?? 0, 90, "data não vira valor")
    let comps = Calendar.current.dateComponents([.day, .month], from: r.date)
    check(comps.day == 12 && comps.month == 9, "12/09 vira data")
}

func testNLDescriptionQuality() {
    var r = TransactionNLParser.parse(
        text: "paguei conta de luz 150", referenceDate: D(2026, 9, 24))
    check(r.description == "Conta de Luz", "conta de X preservada (obtido \(r.description ?? "?"))")
    r = TransactionNLParser.parse(
        text: "comprei pao de acucar 200", referenceDate: D(2026, 9, 24))
    check(r.description == "Pao de Acucar", "nome composto (obtido \(r.description ?? "?"))")
    r = TransactionNLParser.parse(
        text: "paguei 45 na padaria do centro ontem", referenceDate: D(2026, 9, 24))
    check(r.description == "Padaria do Centro", "lugar composto (obtido \(r.description ?? "?"))")
    r = TransactionNLParser.parse(
        text: "corte de cabelo 80", referenceDate: D(2026, 9, 24))
    check(r.description == "Corte de Cabelo", "serviço (obtido \(r.description ?? "?"))")
    r = TransactionNLParser.parse(
        text: "gastei 30 com uber", referenceDate: D(2026, 9, 24))
    check(r.description == "Uber", "conector no meio sai das pontas (obtido \(r.description ?? "?"))")
}

func testNLSuggestsEverydayCategories() {
    let cats = nlCats()
    let cases: [(String, String)] = [
        ("gastei 60 no ifood", "Lazer"),
        ("paguei 120 academia", "Saúde"),
        ("netflix 55 mensal", "Lazer"),
        ("paguei ipva 800", "Transporte"),
        ("paguei conta de luz 150", "Moradia"),
        ("corte de cabelo 80", "Saúde"),
        ("comprei passagem 300", "Lazer"),
        ("feira 35", "Mercado"),
        ("paguei onibus 5,50", "Transporte"),
        ("paguei 200 escola das crianças", "Educação"),
    ]
    for (text, expected) in cases {
        let r = TransactionNLParser.parse(
            text: text, categories: cats, referenceDate: D(2026, 9, 24))
        let name = cats.first { $0.id == r.categoryID }?.name ?? "nil"
        check(name == expected, "'\(text)' → \(expected) (obtido \(name))")
    }
}

func testNLRecurrenceDetection() {
    var r = TransactionNLParser.parse(
        text: "paguei 150 conta de luz todo mês", referenceDate: D(2026, 9, 24))
    check(r.recurrence == .fixed && r.interval == nil, "todo mês → fixa")
    check(r.description == "Conta de Luz", "recorrência sai da descrição")
    r = TransactionNLParser.parse(
        text: "netflix 55 mensal", referenceDate: D(2026, 9, 24))
    check(r.recurrence == .recurring && r.interval == .monthly, "mensal → recorrente mensal")
    check(r.description == "Netflix", "mensal sai da descrição")
    r = TransactionNLParser.parse(
        text: "curso 200 toda semana", referenceDate: D(2026, 9, 24))
    check(r.recurrence == .recurring && r.interval == .weekly, "toda semana → semanal")
    r = TransactionNLParser.parse(
        text: "aluguel 1500", referenceDate: D(2026, 9, 24))
    check(r.recurrence == .unique && r.interval == nil, "sem marcador → avulsa")
    r = TransactionNLParser.parse(
        text: "comprei iphone 3000 em 3x", referenceDate: D(2026, 9, 24))
    check(r.installmentCount == 3 && r.recurrence == .unique, "3x é parcela, não recorrência")
}

func nlCards() -> [CreditCard] {
    [
        CreditCard(name: "Nubank", closingDay: 10, dueDay: 17),
        CreditCard(name: "Inter", closingDay: 5, dueDay: 12),
    ]
}

func testNLCardDetection() {
    let cards = nlCards()
    let nubank = cards[0].id
    var r = TransactionNLParser.parse(
        text: "paguei 500 no cartão nubank", cards: cards,
        referenceDate: D(2026, 9, 24))
    check(r.creditCardID == nubank && r.payOnCard, "nome citado seleciona")
    // Genérico com 2 ativos: indica cartão, deixa escolher no form.
    r = TransactionNLParser.parse(
        text: "paguei 200 no cartão", cards: cards,
        referenceDate: D(2026, 9, 24))
    check(r.creditCardID == nil && r.payOnCard, "genérico com 2 cartões → payOnCard sem id")
    // Genérico com 1 ativo: seleciona o único.
    r = TransactionNLParser.parse(
        text: "paguei 200 no crédito", cards: [cards[0]],
        referenceDate: D(2026, 9, 24))
    check(r.creditCardID == nubank && r.payOnCard, "genérico com 1 cartão → ele")
    r = TransactionNLParser.parse(
        text: "paguei 100 no débito", cards: cards,
        referenceDate: D(2026, 9, 24))
    check(r.creditCardID == nil && !r.payOnCard, "débito é à vista")
    r = TransactionNLParser.parse(
        text: "comprei 900 em 3x", cards: [cards[0]],
        referenceDate: D(2026, 9, 24))
    check(r.creditCardID == nubank && r.payOnCard, "parcelado indica cartão")
    r = TransactionNLParser.parse(
        text: "paguei 50 no pix", cards: cards,
        referenceDate: D(2026, 9, 24))
    check(r.creditCardID == nil && !r.payOnCard, "pix é à vista")
    r = TransactionNLParser.parse(
        text: "gastei 30 na padaria", cards: nil,
        referenceDate: D(2026, 9, 24))
    check(r.creditCardID == nil && !r.payOnCard, "sem cartões → à vista")
}

func testNLFreelaIncome() {
    let cats = nlCats()
    let r = TransactionNLParser.parse(
        text: "recebi 200 do freela", categories: cats,
        referenceDate: D(2026, 9, 24))
    check(r.type == .receivable, "recebi → receita")
    check(cats.first { $0.id == r.categoryID }?.name == "Freelance", "freela → Freelance")
}

func testNLEnglishBasic() {
    let r = TransactionNLParser.parse(
        text: "paid 45 at the bakery yesterday",
        referenceDate: D(2026, 9, 24))
    eq(r.amount ?? 0, 45, "valor EN")
    check(r.description == "Bakery", "descrição EN (obtido \(r.description ?? "?"))")
    check(r.type == .payable, "paid → despesa")
    check(Calendar.current.component(.day, from: r.date) == 23, "yesterday = dia 23")
    check(r.dateExplicit, "data explícita")
}

func testNLEnglishIncome() {
    let cats = nlCats()
    let r = TransactionNLParser.parse(
        text: "received 5000 salary today",
        categories: cats, referenceDate: D(2026, 9, 24))
    eq(r.amount ?? 0, 5000, "valor da receita EN")
    check(r.type == .receivable, "received → receita")
    check(cats.first { $0.id == r.categoryID }?.name == "Salário", "salary → Salário")
}

func testNLEnglishRecurrenceAndCategories() {
    let cats = nlCats()
    var r = TransactionNLParser.parse(
        text: "netflix 55 every month",
        categories: cats, referenceDate: D(2026, 9, 24))
    check(r.recurrence == .recurring && r.interval == .monthly, "every month → mensal")
    check(cats.first { $0.id == r.categoryID }?.name == "Lazer", "netflix → Lazer")
    r = TransactionNLParser.parse(
        text: "grocery 120", categories: cats,
        referenceDate: D(2026, 9, 24))
    check(r.description == "Grocery", "descrição EN")
    check(cats.first { $0.id == r.categoryID }?.name == "Mercado", "grocery → Mercado")
    r = TransactionNLParser.parse(
        text: "gym monday 100", categories: cats,
        referenceDate: D(2026, 9, 24))
    check(cats.first { $0.id == r.categoryID }?.name == "Saúde", "gym → Saúde")
    let comps = Calendar.current.dateComponents([.day, .month], from: r.date)
    check(comps.day == 21 && comps.month == 9, "monday antes da quinta 24 → dia 21")
    r = TransactionNLParser.parse(
        text: "dentist 200 sept 12", categories: cats,
        referenceDate: D(2026, 9, 24))
    check(cats.first { $0.id == r.categoryID }?.name == "Saúde", "dentist → Saúde")
    let c2 = Calendar.current.dateComponents([.day, .month], from: r.date)
    check(c2.day == 12 && c2.month == 9, "sept 12 vira data")
}

/// Guarda thread-safe para testar provider async no runner síncrono.
final class NLResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: NLParseResult?
    var value: NLParseResult? {
        get { lock.lock(); defer { lock.unlock() }; return stored }
        set { lock.lock(); defer { lock.unlock() }; stored = newValue }
    }
}

func testNLProviderParity() {
    let box = NLResultBox()
    let sem = DispatchSemaphore(value: 0)
    Task {
        box.value = await RuleBasedNLParser().parse(
            text: "paguei 45 na padaria ontem",
            categories: nlCats(), cards: [],
            referenceDate: D(2026, 9, 24)
        )
        sem.signal()
    }
    sem.wait()
    eq(box.value?.amount ?? 0, 45, "provider devolve valor")
    check(box.value?.description == "Padaria", "provider devolve descrição")
    check(box.value?.type == .payable, "provider devolve tipo")
}

func testNLDraftCarriesAll() {
    let cats = nlCats()
    let cards = nlCards()
    let r = TransactionNLParser.parse(
        text: "paguei 150 conta de luz todo mês no cartão",
        categories: cats, cards: [cards[0]], referenceDate: D(2026, 9, 24))
    let draft = r.toDraft()
    eq(draft.amount ?? 0, 150, "draft leva valor")
    check(draft.description == "Conta de Luz", "draft leva descrição")
    check(cats.first { $0.id == draft.categoryID }?.name == "Moradia", "draft leva categoria")
    check(draft.recurrence == .fixed, "draft leva recorrência")
    check(draft.creditCardID == cards[0].id && draft.payOnCard, "draft leva cartão")
}

// MARK: - Sprint 8: cartões de crédito e faturas

func testInvoiceSameOrNext() {
    let card = CreditCard(name: "Nubank", closingDay: 10, dueDay: 17)
    let same = InvoiceService.invoiceFor(purchaseDate: D(2026, 9, 8), card: card)
    check(same.year == 2026 && same.month == 9, "dia 8 (<= fechamento 10) cai na fatura atual")
    check(Calendar.current.component(.day, from: same.dueDate) == 17, "fatura atual vence dia 17")
    let edge = InvoiceService.invoiceFor(purchaseDate: D(2026, 9, 10), card: card)
    check(edge.month == 9, "no dia do fechamento ainda é a fatura atual")
    let next = InvoiceService.invoiceFor(purchaseDate: D(2026, 9, 12), card: card)
    check(next.year == 2026 && next.month == 10, "dia 12 (> fechamento) vai para a próxima")
    let yearEnd = InvoiceService.invoiceFor(purchaseDate: D(2026, 12, 20), card: card)
    check(yearEnd.year == 2027 && yearEnd.month == 1, "dezembro após fechamento vira jan/27")
}

func testInvoiceDueDayClamp() {
    let due = InvoiceService.invoiceDueDate(year: 2026, month: 2, dueDay: 28)
    let comps = Calendar.current.dateComponents([.month, .day], from: due)
    check(comps.month == 2 && comps.day == 28, "fev/26 vence dia 28 sem estourar")
}

func testInvoiceClosed() {
    let card = CreditCard(name: "N", closingDay: 10, dueDay: 17)
    check(InvoiceService.isClosed(card: card, year: 2026, month: 9, now: D(2026, 9, 11)), "dia 11 > fechamento 10 = fechada")
    check(!InvoiceService.isClosed(card: card, year: 2026, month: 9, now: D(2026, 9, 10)), "no dia do fechamento ainda aberta")
}

func testCardValidation() {
    check(InvoiceService.validateCard(name: "  ", closingDay: 10, dueDay: 17) == ["Nome do cartão é obrigatório."], "nome obrigatório")
    check(InvoiceService.validateCard(name: "X", closingDay: 0, dueDay: 17) == ["Fechamento e vencimento devem ser entre 1 e 31."], "dia 0 inválido")
    check(InvoiceService.validateCard(name: "X", closingDay: 10, dueDay: 32) == ["Fechamento e vencimento devem ser entre 1 e 31."], "dia 32 inválido")
    check(InvoiceService.validateCard(name: "X", closingDay: 30, dueDay: 5).isEmpty, "dias 29-31 valem (clamp)")
    check(InvoiceService.validateCard(name: "Nubank", closingDay: 10, dueDay: 17).isEmpty, "cartão válido sem erros")
    check(InvoiceService.validateCard(name: "  ", closingDay: 10, dueDay: 17, language: .en) == ["Card name is required."], "erro EN nome")
}

func testInvoiceDueBeforeClosingGoesNext() {
    // Cartão que fecha dia 28 e vence dia 10: compra 24/09 cai na fatura
    // de OUTUBRO (vence 10/10) — nunca na de setembro, já fechada/vencida.
    let card = CreditCard(name: "X", closingDay: 28, dueDay: 10)
    let inv = InvoiceService.invoiceFor(purchaseDate: D(2026, 9, 24), card: card)
    check(inv.year == 2026 && inv.month == 10, "24/09 vai para a fatura de out (obtido \(inv.month))")
    check(Calendar.current.component(.day, from: inv.dueDate) == 10, "vence dia 10")
    // Dia do fechamento ainda é da fatura que está fechando (vence 10/10);
    // dia seguinte já é da próxima (vence 10/11).
    let edge = InvoiceService.invoiceFor(purchaseDate: D(2026, 9, 28), card: card)
    check(edge.month == 10, "28/09 (fechamento) ainda vence 10/10")
    let after = InvoiceService.invoiceFor(purchaseDate: D(2026, 9, 29), card: card)
    check(after.month == 11, "29/09 já vence 10/11")
}

func testInvoiceClosingDay30() {
    // Fecha dia 30, vence dia 5: 24/09 vai para a fatura de outubro.
    let card = CreditCard(name: "X", closingDay: 30, dueDay: 5)
    let inv = InvoiceService.invoiceFor(purchaseDate: D(2026, 9, 24), card: card)
    check(inv.year == 2026 && inv.month == 10, "24/09 com fechamento 30 vai para out")
    check(Calendar.current.component(.day, from: inv.dueDate) == 5, "vence dia 5")
    let edge = InvoiceService.invoiceFor(purchaseDate: D(2026, 9, 30), card: card)
    check(edge.month == 10, "no dia do fechamento ainda é a mesma fatura")
    let after = InvoiceService.invoiceFor(purchaseDate: D(2026, 10, 1), card: card)
    check(after.year == 2026 && after.month == 11, "01/10 já é a fatura de nov")
}

func testCardInstallmentsDueBeforeClosing() {
    // 2x de 24/09 no cartão fecha-28/vence-10 → vencimentos 10/10 e 10/11.
    let store = Store(seedIfEmpty: false)
    let card = try! store.addCard(name: "X", closingDay: 28, dueDay: 10)
    let items = store.create(.init(
        description: "TV", type: .payable, amount: 2000,
        recurrence: .installment, dueDate: D(2026, 9, 24),
        totalInstallments: 2, interval: .monthly,
        creditCardID: card.id, card: card
    ))
    let cal = Calendar.current
    let months = items.map { cal.component(.month, from: $0.dueDate) }
    check(months == [10, 11], "parcelas em out/nov (obtido \(months))")
    check(items.allSatisfy { cal.component(.day, from: $0.dueDate) == 10 }, "todas vencem dia 10")
}

func testCardCRUD() {
    let store = Store(seedIfEmpty: false)
    let card = try! store.addCard(name: "Nubank", closingDay: 10, dueDay: 17)
    check(store.activeCards.count == 1, "1 cartão ativo")
    do {
        _ = try store.addCard(name: "nubank", closingDay: 1, dueDay: 2)
        check(false, "nome duplicado deveria lançar")
    } catch Store.CardError.duplicateName {
        check(true, "duplicado lança duplicateName")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    do {
        _ = try store.addCard(name: "Outro", closingDay: 0, dueDay: 5)
        check(false, "dia 0 deveria lançar")
    } catch Store.CardError.invalidDay {
        check(true, "lança invalidDay")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    // Arquivar some do form mas mantém o cadastro.
    store.setCardActive(id: card.id, active: false)
    check(store.activeCards.isEmpty, "arquivado some dos ativos")
    check(store.card(id: card.id)?.isActive == false, "flag persiste")
    // Exclusão com lançamentos vinculados é bloqueada.
    _ = store.create(.init(
        description: "Compra", type: .payable, amount: 100,
        dueDate: D(2026, 9, 8), creditCardID: card.id, card: store.card(id: card.id)
    ))
    do {
        try store.deleteCard(id: card.id)
        check(false, "com lançamentos deveria lançar")
    } catch Store.CardError.hasTransactions {
        check(true, "bloqueia com hasTransactions")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    // Cartão sem lançamentos exclui normal.
    let clean = try! store.addCard(name: "Limpo", closingDay: 1, dueDay: 2)
    try! store.deleteCard(id: clean.id)
    check(store.card(id: clean.id) == nil, "cartão vazio excluído")
}

func testCardPurchaseUniqueGoesToInvoice() {
    let store = Store(seedIfEmpty: false)
    let card = try! store.addCard(name: "Nubank", closingDay: 10, dueDay: 17)
    let items = store.create(.init(
        description: "Farmácia", type: .payable, amount: 90,
        dueDate: D(2026, 9, 12), creditCardID: card.id, card: card
    ))
    check(items.count == 1, "à vista gera 1 item")
    let cal = Calendar.current
    check(cal.component(.month, from: items[0].dueDate) == 10, "dia 12 cai na fatura de out")
    check(cal.component(.day, from: items[0].dueDate) == 17, "vence dia 17")
    check(items[0].creditCardID == card.id, "vínculo com o cartão")
}

func testCardInstallmentsAcrossInvoices() {
    let store = Store(seedIfEmpty: false)
    let card = try! store.addCard(name: "Nubank", closingDay: 10, dueDay: 17)
    let items = store.create(.init(
        description: "TV", type: .payable, amount: 3000,
        recurrence: .installment, dueDate: D(2026, 9, 12),
        totalInstallments: 3, interval: .monthly,
        creditCardID: card.id, card: card
    ))
    check(items.count == 3, "3 parcelas geradas")
    let cal = Calendar.current
    let months = items.map { cal.component(.month, from: $0.dueDate) }
    check(months == [10, 11, 12], "uma parcela por fatura: out/nov/dez (obtido \(months))")
    check(items.allSatisfy { cal.component(.day, from: $0.dueDate) == 17 }, "todas vencem dia 17")
    eq(items.reduce(Decimal(0)) { $0 + $1.amount }, 3000, "soma == total")
    check(items.allSatisfy { $0.creditCardID == card.id }, "vínculo propagado às filhas")
}

func testPayInvoice() {
    let store = Store(seedIfEmpty: false)
    let card = try! store.addCard(name: "Nubank", closingDay: 10, dueDay: 17)
    _ = store.create(.init(description: "A", type: .payable, amount: 100, dueDate: D(2026, 9, 8), creditCardID: card.id, card: card))
    _ = store.create(.init(description: "B", type: .payable, amount: 50, dueDate: D(2026, 9, 9), creditCardID: card.id, card: card))
    _ = store.create(.init(description: "Outro mês", type: .payable, amount: 70, dueDate: D(2026, 9, 20), creditCardID: card.id, card: card))
    // A e B vencem 17/09; "Outro mês" (dia 20 > fechamento) vence 17/10.
    let sept = store.invoiceTransactions(cardID: card.id, year: 2026, month: 9)
    check(sept.count == 2, "fatura de set tem 2 (obtido \(sept.count))")
    eq(store.invoiceTotal(cardID: card.id, year: 2026, month: 9), 150, "total da fatura")
    let paid = store.payInvoice(cardID: card.id, year: 2026, month: 9, paidDate: D(2026, 9, 17))
    check(paid == 2, "baixa única quita 2 contas")
    check(InvoiceService.isPaid(store.invoiceTransactions(cardID: card.id, year: 2026, month: 9)), "fatura marcada como paga")
    let oct = store.invoiceTransactions(cardID: card.id, year: 2026, month: 10)
    check(oct.count == 1 && oct[0].status == .pending, "fatura de out intacta e pendente")
    check(store.payInvoice(cardID: card.id, year: 2026, month: 9, paidDate: D(2026, 9, 17)) == 0, "pagar de novo baixa 0")
}

func testDeleteInvoiceRemovesAllEntries() {
    let store = Store(seedIfEmpty: false)
    let card = try! store.addCard(name: "Nubank", closingDay: 10, dueDay: 17)
    func add(_ desc: String, _ day: Int, _ status: TransactionStatus = .pending) {
        let items = store.create(.init(
            description: desc, type: .payable, amount: 10,
            dueDate: D(2026, 9, day), creditCardID: card.id, card: card
        ))
        if status != .pending { store.updateStatus(id: items[0].id, to: status) }
    }
    add("Pendente", 8)
    add("Paga", 9, .paid)
    add("Cancelada", 9, .canceled)
    add("Outro mês", 20)
    // Excluir a fatura de set (inclui pagos e cancelados, como o detalhe faz).
    let ids = InvoiceService.transactions(
        store.transactions, cardID: card.id, year: 2026, month: 9, includeCanceled: true
    ).map(\.id)
    check(ids.count == 3, "fatura de set tem 3 lançamentos (obtido \(ids.count))")
    store.deleteTransactions(ids: ids)
    check(store.invoiceTransactions(cardID: card.id, year: 2026, month: 9).isEmpty, "fatura de set esvaziada")
    check(store.invoiceTransactions(cardID: card.id, year: 2026, month: 10).count == 1, "outubro intacta")
}

func testMonthlyInvoicesTotalAcrossCards() {
    let store = Store(seedIfEmpty: false)
    let a = try! store.addCard(name: "A", closingDay: 10, dueDay: 17)
    let b = try! store.addCard(name: "B", closingDay: 10, dueDay: 17)
    func buy(_ desc: String, _ amount: Decimal, _ day: Int, _ card: CreditCard?) {
        _ = store.create(.init(
            description: desc, type: .payable, amount: amount,
            dueDate: D(2026, 9, day), creditCardID: card?.id, card: card
        ))
    }
    buy("A1", 100, 8, a)
    buy("A2", 50, 9, a)
    buy("B1", 200, 8, b)
    buy("À vista", 999, 8, nil)
    let total = store.creditCards.reduce(Decimal(0)) {
        $0 + store.invoiceTotal(cardID: $1.id, year: 2026, month: 9)
    }
    eq(total, 350, "soma das faturas de set (à vista fora)")
    eq(store.invoiceTotal(cardID: b.id, year: 2026, month: 9), 200, "fatura do cartão B")
}

func testFilterByCard() {
    let card = CreditCard(name: "N", closingDay: 10, dueDay: 17)
    let a = FinancialTransaction(description: "Cartão", type: .payable, amount: 10, dueDate: D(2026, 9, 17), creditCardID: card.id)
    let b = FinancialTransaction(description: "Conta", type: .payable, amount: 10, dueDate: D(2026, 9, 17))
    let out = TransactionEngine.filter([a, b], year: 2026, month: 9, creditCardID: card.id)
    check(out.count == 1 && out[0].description == "Cartão", "filtro por cartão")
    // A listagem geral exclui compras no cartão (só vivem na fatura).
    let listing = TransactionEngine.filter([a, b], year: 2026, month: 9, includeCardPurchases: false)
    check(listing.count == 1 && listing[0].description == "Conta", "listagem sem compras no cartão")
    let full = TransactionEngine.filter([a, b], year: 2026, month: 9)
    check(full.count == 2, "default inclui tudo (compat)")
}

func testCardSnapshotCompatOldJSON() {
    // JSON antigo: sem `creditCards` e sem `creditCardID` nas transações.
    let dir = testAttachmentsDir()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let json = dir.appendingPathComponent("finanzin.json")
    let raw = """
    {"categories":[],"transactions":[{"id":"t1","description":"Antiga","type":"payable","recurrence":"unique","totalAmount":10,"amount":10,"installmentCount":1,"dueDate":789123456,"status":"pending"}],"funds":[],"budgets":[],"wishlists":[],"wishlistItems":[]}
    """
    try! Data(raw.utf8).write(to: json)
    let store = Store(persistTo: json, seedIfEmpty: false, attachmentsDirectory: dir)
    check(store.creditCards.isEmpty, "JSON antigo abre sem cartões")
    // Migração: base sem contas ganha a Carteira e o lançamento vai para ela.
    check(store.accounts.count == 1, "migração cria a conta padrão")
    check(store.accounts[0].name == "Carteira", "conta padrão é a Carteira")
    check(store.transactions.count == 1, "transação antiga carrega")
    check(store.transactions[0].creditCardID == nil, "sem vínculo de cartão")
    check(store.transactions[0].accountID == store.accounts[0].id, "lançamento antigo vai para a Carteira")
}

// MARK: - Multi-contas

func testAccountCRUD() {
    let store = Store(seedIfEmpty: false)
    let acc = try! store.addAccount(name: "Nubank", initialBalance: 2500, color: "#8b5cf6", icon: "banknote")
    check(store.activeAccounts.count == 1, "1 conta ativa")
    do {
        _ = try store.addAccount(name: "nubank", initialBalance: 0, color: "#fff", icon: "x")
        check(false, "nome duplicado deveria lançar")
    } catch Store.AccountError.duplicateName {
        check(true, "duplicado lança duplicateName")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    do {
        _ = try store.addAccount(name: "Negativa", initialBalance: -1, color: "#fff", icon: "x")
        check(false, "saldo negativo deveria lançar")
    } catch Store.AccountError.invalidAmount {
        check(true, "lança invalidAmount")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    do {
        _ = try store.addAccount(name: "  ", initialBalance: 0, color: "#fff", icon: "x")
        check(false, "nome vazio deveria lançar")
    } catch Store.AccountError.emptyName {
        check(true, "lança emptyName")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    // Arquivar a única conta é bloqueado (o app nunca fica sem conta ativa).
    do {
        try store.setAccountActive(id: acc.id, active: false)
        check(false, "arquivar a última deveria lançar")
    } catch Store.AccountError.lastAccount {
        check(true, "bloqueia com lastAccount")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    // Com 2 contas, arquivar uma libera normal.
    let second = try! store.addAccount(name: "Segunda", initialBalance: 0, color: "#fff", icon: "x")
    try! store.setAccountActive(id: acc.id, active: false)
    check(store.activeAccounts.count == 1, "arquivada some das ativas")
    check(store.account(id: acc.id)?.isActive == false, "flag persiste")
    try! store.setAccountActive(id: acc.id, active: true)
    // Conta sem lançamentos exclui normal (havendo outra).
    try! store.deleteAccount(id: second.id)
    check(store.account(id: second.id) == nil, "conta vazia excluída")
    // Excluir a última conta é bloqueado, mesmo vazia.
    do {
        try store.deleteAccount(id: acc.id)
        check(false, "excluir a última deveria lançar")
    } catch Store.AccountError.lastAccount {
        check(true, "bloqueia exclusão da última")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    // Desativar a última ativa pelo form (update) também bloqueia.
    var archived = acc
    archived.isActive = false
    do {
        try store.updateAccount(archived)
        check(false, "update desativando a última deveria lançar")
    } catch Store.AccountError.lastAccount {
        check(true, "update bloqueia com lastAccount")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
}

func testAccountDeleteBlockedWithTransactions() {
    let store = Store(seedIfEmpty: false)
    let acc = try! store.addAccount(name: "Nubank", initialBalance: 0, color: "#fff", icon: "x")
    _ = store.create(.init(
        description: "Compra", type: .payable, amount: 100,
        dueDate: D(2026, 9, 8), accountID: acc.id
    ))
    do {
        try store.deleteAccount(id: acc.id)
        check(false, "com lançamentos deveria lançar")
    } catch Store.AccountError.hasTransactions {
        check(true, "bloqueia com hasTransactions")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
    // Excluir a conta selecionada no filtro volta para Todas.
    store.setSelectedAccount(acc.id)
    store.deleteTransactions(ids: store.transactions.map(\.id))
    let other = try! store.addAccount(name: "Outra", initialBalance: 0, color: "#fff", icon: "x")
    try! store.deleteAccount(id: acc.id)
    check(store.account(id: acc.id) == nil, "conta excluída")
    check(store.selectedAccountID == nil, "filtro volta para Todas")
    // E a que sobrou virou a última: não sai mais.
    do {
        try store.deleteAccount(id: other.id)
        check(false, "excluir a última deveria lançar")
    } catch Store.AccountError.lastAccount {
        check(true, "última conta protegida")
    } catch {
        check(false, "erro inesperado: \(error)")
    }
}

func testAccountBalance() {
    let acc = BankAccount(name: "N", initialBalance: 1000)
    let tx: [FinancialTransaction] = [
        .init(description: "Salário", type: .receivable, amount: 500, dueDate: D(2026, 10, 5), status: .paid, accountID: acc.id),
        .init(description: "Aluguel", type: .payable, amount: 300, dueDate: D(2026, 10, 5), status: .paid, accountID: acc.id),
        .init(description: "Pendente", type: .payable, amount: 999, dueDate: D(2026, 10, 6), status: .pending, accountID: acc.id),
        .init(description: "Cancelada", type: .payable, amount: 999, dueDate: D(2026, 10, 6), status: .canceled, accountID: acc.id),
        .init(description: "Outra conta", type: .payable, amount: 999, dueDate: D(2026, 10, 6), status: .paid, accountID: "outra"),
        .init(description: "Sem conta", type: .payable, amount: 999, dueDate: D(2026, 10, 6), status: .paid),
    ]
    eq(AccountService.balance(account: acc, transactions: tx), 1200, "saldo = 1000 + 500 − 300 (pendente/cancelada/outras fora)")
}

func testAccountBalancesBatch() {
    let store = Store(seedIfEmpty: false)
    let a = try! store.addAccount(name: "A", initialBalance: 100, color: "#fff", icon: "x")
    let b = try! store.addAccount(name: "B", initialBalance: 0, color: "#fff", icon: "x")
    _ = store.create(.init(description: "In", type: .receivable, amount: 50, dueDate: D(2026, 10, 1), accountID: a.id))
    for t in store.transactions { store.updateStatus(id: t.id, to: .paid) }
    _ = store.create(.init(description: "Out", type: .payable, amount: 20, dueDate: D(2026, 10, 2), accountID: b.id))
    for t in store.transactions where t.status == .pending { store.updateStatus(id: t.id, to: .paid) }
    let balances = store.accountBalances()
    eq(balances[a.id] ?? -1, 150, "saldo A em lote")
    eq(balances[b.id] ?? -1, -20, "saldo B em lote")
    eq(store.balance(ofAccount: a.id) ?? -1, 150, "balance(ofAccount:) confere")
    check(store.balance(ofAccount: "inexistente") == nil, "conta inexistente → nil")
}

func testAccountPropagatesToSeries() {
    let store = Store(seedIfEmpty: false)
    let acc = try! store.addAccount(name: "N", initialBalance: 0, color: "#fff", icon: "x")
    let items = store.create(.init(
        description: "TV", type: .payable, amount: 3000,
        recurrence: .installment, dueDate: D(2026, 9, 8),
        totalInstallments: 3, interval: .monthly, accountID: acc.id
    ))
    check(items.count == 3, "3 parcelas geradas")
    check(items.allSatisfy { $0.accountID == acc.id }, "conta propagada às filhas")
    let fixed = store.create(.init(
        description: "Net", type: .payable, amount: 100,
        recurrence: .fixed, dueDate: D(2026, 9, 8), accountID: acc.id
    ))
    check(fixed.allSatisfy { $0.accountID == acc.id }, "conta propagada à série fixa")
}

func testFilterByAccount() {
    let a = FinancialTransaction(description: "A", type: .payable, amount: 10, dueDate: D(2026, 9, 8), accountID: "acc-a")
    let b = FinancialTransaction(description: "B", type: .payable, amount: 10, dueDate: D(2026, 9, 8), accountID: "acc-b")
    let c = FinancialTransaction(description: "C", type: .payable, amount: 10, dueDate: D(2026, 9, 8))
    let out = TransactionEngine.filter([a, b, c], year: 2026, month: 9, accountID: "acc-a")
    check(out.count == 1 && out[0].description == "A", "filtro por conta")
    let full = TransactionEngine.filter([a, b, c], year: 2026, month: 9)
    check(full.count == 3, "sem filtro inclui tudo (compat)")
}

func testVisibleTransactionsFilter() {
    let store = Store(seedIfEmpty: false)
    defer { store.setSelectedAccount(nil) }
    let acc = try! store.addAccount(name: "N", initialBalance: 0, color: "#fff", icon: "x")
    _ = store.create(.init(description: "Na conta", type: .payable, amount: 10, dueDate: D(2026, 10, 1), accountID: acc.id))
    _ = store.create(.init(description: "Fora", type: .payable, amount: 10, dueDate: D(2026, 10, 1)))
    check(store.visibleTransactions.count == 2, "sem seleção mostra tudo")
    store.setSelectedAccount(acc.id)
    let vis = store.visibleTransactions
    check(vis.count == 1 && vis[0].description == "Na conta", "filtro global isola a conta")
    // Métricas obedecem ao filtro.
    let m = MetricsService.monthly(store.visibleTransactions, year: 2026, month: 10)
    eq(m.pendingPayable, 10, "métrica só da conta")
    // Seleção órfã (conta removida) cai para Todas em vez de vazio.
    store.setSelectedAccount("inexistente")
    check(store.visibleTransactions.count == 2, "seleção órfã mostra tudo")
}

func testGeneratePayableUsesSelectedAccount() {
    let store = Store(seedIfEmpty: false)
    defer { store.setSelectedAccount(nil) }
    let acc = try! store.addAccount(name: "N", initialBalance: 0, color: "#fff", icon: "x")
    let list = try! store.addWishlist(name: "L", color: "#fff", icon: "x")
    let item = try! store.addItem(wishlistID: list.id, name: "I", price: 10, priority: .low, categoryID: nil, notes: nil)
    store.setSelectedAccount(acc.id)
    let tx = try! store.generatePayable(itemID: item.id)
    check(tx.accountID == acc.id, "desejo gera conta na conta selecionada")
}

func testSeedCreatesDefaultAccount() {
    let store = Store(seedIfEmpty: false)
    check(store.accounts.isEmpty, "sem seed não há contas")
    Seed.apply(to: store)
    check(store.accounts.count == 1, "seed cria 1 conta padrão (obtido \(store.accounts.count))")
    check(store.accounts[0].name == "Carteira", "conta padrão é a Carteira")
    Seed.apply(to: store)
    check(store.accounts.count == 1, "re-seed não duplica a conta")
}

func testAccountSnapshotRoundTrip() {
    let dir = testAttachmentsDir()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let json = dir.appendingPathComponent("finanzin.json")
    let store = Store(persistTo: json, seedIfEmpty: false, attachmentsDirectory: dir)
    let acc = try! store.addAccount(name: "N", initialBalance: 42, color: "#fff", icon: "x")
    _ = store.create(.init(description: "T", type: .payable, amount: 10, dueDate: D(2026, 10, 1), accountID: acc.id))
    store.flush()
    let reopened = Store(persistTo: json, seedIfEmpty: false, attachmentsDirectory: dir)
    check(reopened.accounts.count == 1 && reopened.accounts[0].name == "N", "conta persiste no JSON")
    eq(reopened.accounts[0].initialBalance, 42, "saldo inicial persiste")
    check(reopened.transactions.first?.accountID == acc.id, "vínculo persiste")
}

func testMigrateOldBaseToDefaultAccount() {
    // Base antiga: contas inexistentes, lançamentos sem conta.
    let dir = testAttachmentsDir()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let json = dir.appendingPathComponent("finanzin.json")
    let raw = """
    {"categories":[],"transactions":[{"id":"t1","description":"A","type":"payable","recurrence":"unique","totalAmount":10,"amount":10,"installmentCount":1,"dueDate":789123456,"status":"paid"},{"id":"t2","description":"B","type":"receivable","recurrence":"unique","totalAmount":50,"amount":50,"installmentCount":1,"dueDate":789123456,"status":"paid"}],"funds":[],"budgets":[],"wishlists":[],"wishlistItems":[]}
    """
    try! Data(raw.utf8).write(to: json)
    let store = Store(persistTo: json, seedIfEmpty: false, attachmentsDirectory: dir)
    check(store.accounts.count == 1, "migração cria exatamente 1 conta")
    let carteirinha = store.accounts[0].id
    check(store.transactions.allSatisfy { $0.accountID == carteirinha }, "tudo vai para a Carteira")
    // Saldo da Carteira contabiliza os antigos (50 − 10 sobre inicial 0).
    eq(store.balance(ofAccount: carteirinha) ?? -999, 40, "balanço inclui registros migrados")
    // Reabrir não duplica nem move de novo.
    let reopened = Store(persistTo: json, seedIfEmpty: false, attachmentsDirectory: dir)
    check(reopened.accounts.count == 1, "reabertura não duplica a conta")
}

@main
struct TestRunner {
    static func main() {
        let tests: [(String, () -> Void)] = [
            ("testSplitAbsorbsRoundingOnLast", testSplitAbsorbsRoundingOnLast),
            ("testUniqueCreatesSingle", testUniqueCreatesSingle),
            ("testInstallmentGeneratesChildrenWithLinkage", testInstallmentGeneratesChildrenWithLinkage),
            ("testFixedGeneratesHorizon", testFixedGeneratesHorizon),
            ("testFilterByMonthAndSearch", testFilterByMonthAndSearch),
            ("testScopeResolution", testScopeResolution),
            ("testMonthlyMetrics", testMonthlyMetrics),
            ("testFundBalance", testFundBalance),
            ("testBudgetRows", testBudgetRows),
            ("testStoreUpsertBudget", testStoreUpsertBudget),
            ("testValidation", testValidation),
            ("testCategoryDuplicatePerType", testCategoryDuplicatePerType),
            ("testDeleteCategoryReassigns", testDeleteCategoryReassigns),
            ("testStoreCreateUniqueAndToggle", testStoreCreateUniqueAndToggle),
            ("testValidateSeries", testValidateSeries),
            ("testRecurringWeeklySteps", testRecurringWeeklySteps),
            ("testApplySeriesEditFuturePreservesDueDates", testApplySeriesEditFuturePreservesDueDates),
            ("testDeleteSeriesFutureKeepsHead", testDeleteSeriesFutureKeepsHead),
            ("testDeleteRootCascadesChildren", testDeleteRootCascadesChildren),
            ("testFundMovementFlow", testFundMovementFlow),
            ("testWithdrawalAboveBalanceThrows", testWithdrawalAboveBalanceThrows),
            ("testDeleteFundBlockedWithMovements", testDeleteFundBlockedWithMovements),
            ("testFundValidation", testFundValidation),
            ("testSaveBudgetValidation", testSaveBudgetValidation),
            ("testSaveBudgetUpsertAndDelete", testSaveBudgetUpsertAndDelete),
            ("testBudgetRowFlags", testBudgetRowFlags),
            ("testWishlistCascadeDelete", testWishlistCascadeDelete),
            ("testPurchaseAndTotals", testPurchaseAndTotals),
            ("testGeneratePayableFromItem", testGeneratePayableFromItem),
            ("testWishlistItemValidation", testWishlistItemValidation),
            ("testBreakdownPercentages", testBreakdownPercentages),
            ("testEvolutionEndsAtBaseMonth", testEvolutionEndsAtBaseMonth),
            ("testUpcomingWindow", testUpcomingWindow),
            ("testAppSettingsDefaults", testAppSettingsDefaults),
            ("testAppSettingsRoundTrip", testAppSettingsRoundTrip),
            ("testStoreSettingsUpdateAndReset", testStoreSettingsUpdateAndReset),
            ("testCurrencyFiveFormats", testCurrencyFiveFormats),
            ("testL10nCoverage", testL10nCoverage),
            ("testNotificationPlannerOff", testNotificationPlannerOff),
            ("testNotificationPlannerKinds", testNotificationPlannerKinds),
            ("testValidateEnglish", testValidateEnglish),
            ("testEvolutionLocale", testEvolutionLocale),
            ("testResetToDefaults", testResetToDefaults),
            ("testDraftParsesFullURL", testDraftParsesFullURL),
            ("testDraftParsesThousandsAndENHost", testDraftParsesThousandsAndENHost),
            ("testDraftRejectsOtherHost", testDraftRejectsOtherHost),
            ("testDraftRoundTrip", testDraftRoundTrip),
            ("testDraftParsesBRDate", testDraftParsesBRDate),
            ("testAttachmentAcceptsImageAndPDF", testAttachmentAcceptsImageAndPDF),
            ("testAttachmentDeleteRemovesFile", testAttachmentDeleteRemovesFile),
            ("testAttachmentSnapshotRoundTrip", testAttachmentSnapshotRoundTrip),
            ("testAttachmentSnapshotCompatOldJSON", testAttachmentSnapshotCompatOldJSON),
            ("testSeriesEditKeepsAttachmentsPerParcel", testSeriesEditKeepsAttachmentsPerParcel),
            ("testReceiptParsesTotalWithMerchantAndDate", testReceiptParsesTotalWithMerchantAndDate),
            ("testReceiptPrefersTotalOverTroco", testReceiptPrefersTotalOverTroco),
            ("testReceiptParsesThousands", testReceiptParsesThousands),
            ("testReceiptFallbackLargestWithoutTotal", testReceiptFallbackLargestWithoutTotal),
            ("testReceiptSkipsFiscalHeaders", testReceiptSkipsFiscalHeaders),
            ("testReceiptSuggestsCategory", testReceiptSuggestsCategory),
            ("testReceiptDraftMapping", testReceiptDraftMapping),
            ("testReceiptNormalizeAmounts", testReceiptNormalizeAmounts),
            ("testNLParsesBasicExpense", testNLParsesBasicExpense),
            ("testNLParsesDecimalAndCategory", testNLParsesDecimalAndCategory),
            ("testNLParsesThousands", testNLParsesThousands),
            ("testNLParsesIncome", testNLParsesIncome),
            ("testNLParsesInstallments", testNLParsesInstallments),
            ("testNLParsesExplicitDay", testNLParsesExplicitDay),
            ("testNLParsesWeekday", testNLParsesWeekday),
            ("testNLDefaultsTodayWithoutDate", testNLDefaultsTodayWithoutDate),
            ("testNLEmptyText", testNLEmptyText),
            ("testNLWithoutValueLowConfidence", testNLWithoutValueLowConfidence),
            ("testNLToDraftMapping", testNLToDraftMapping),
            ("testNLIgnoresYearLikeNumbers", testNLIgnoresYearLikeNumbers),
            ("testNLDescriptionQuality", testNLDescriptionQuality),
            ("testNLSuggestsEverydayCategories", testNLSuggestsEverydayCategories),
            ("testNLRecurrenceDetection", testNLRecurrenceDetection),
            ("testNLCardDetection", testNLCardDetection),
            ("testNLFreelaIncome", testNLFreelaIncome),
            ("testNLEnglishBasic", testNLEnglishBasic),
            ("testNLEnglishIncome", testNLEnglishIncome),
            ("testNLEnglishRecurrenceAndCategories", testNLEnglishRecurrenceAndCategories),
            ("testNLProviderParity", testNLProviderParity),
            ("testNLDraftCarriesAll", testNLDraftCarriesAll),
            ("testInvoiceSameOrNext", testInvoiceSameOrNext),
            ("testInvoiceDueDayClamp", testInvoiceDueDayClamp),
            ("testInvoiceDueBeforeClosingGoesNext", testInvoiceDueBeforeClosingGoesNext),
            ("testInvoiceClosingDay30", testInvoiceClosingDay30),
            ("testCardInstallmentsDueBeforeClosing", testCardInstallmentsDueBeforeClosing),
            ("testInvoiceClosed", testInvoiceClosed),
            ("testCardValidation", testCardValidation),
            ("testCardCRUD", testCardCRUD),
            ("testCardPurchaseUniqueGoesToInvoice", testCardPurchaseUniqueGoesToInvoice),
            ("testCardInstallmentsAcrossInvoices", testCardInstallmentsAcrossInvoices),
            ("testPayInvoice", testPayInvoice),
            ("testFilterByCard", testFilterByCard),
            ("testMonthlyInvoicesTotalAcrossCards", testMonthlyInvoicesTotalAcrossCards),
            ("testDeleteInvoiceRemovesAllEntries", testDeleteInvoiceRemovesAllEntries),
            ("testCardSnapshotCompatOldJSON", testCardSnapshotCompatOldJSON),
            ("testAccountCRUD", testAccountCRUD),
            ("testAccountDeleteBlockedWithTransactions", testAccountDeleteBlockedWithTransactions),
            ("testAccountBalance", testAccountBalance),
            ("testAccountBalancesBatch", testAccountBalancesBatch),
            ("testAccountPropagatesToSeries", testAccountPropagatesToSeries),
            ("testFilterByAccount", testFilterByAccount),
            ("testVisibleTransactionsFilter", testVisibleTransactionsFilter),
            ("testGeneratePayableUsesSelectedAccount", testGeneratePayableUsesSelectedAccount),
            ("testSeedCreatesDefaultAccount", testSeedCreatesDefaultAccount),
            ("testAccountSnapshotRoundTrip", testAccountSnapshotRoundTrip),
            ("testMigrateOldBaseToDefaultAccount", testMigrateOldBaseToDefaultAccount),
        ]
        for (name, fn) in tests {
            print("▶ \(name)")
            fn()
        }
        if failures.isEmpty {
            print("✅ \(tests.count)/\(tests.count) testes passaram")
        } else {
            print("❌ \(failures.count) falha(s)")
            exit(1)
        }
    }
}
