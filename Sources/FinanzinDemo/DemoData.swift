import Foundation
import FinanzinCore

/// Massa de demonstração: 5 meses de histórico para o dashboard ter o que mostrar.
public enum DemoData {
    public static func seed(store: Store) {
        guard store.transactions.isEmpty else { return }
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.year, .month], from: now)
        let curY = comps.year ?? 2026
        let curM = comps.month ?? 9

        func day(_ year: Int, _ month: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: year, month: month, day: d)) ?? Date()
        }
        func cat(_ name: String, _ type: CategoryType) -> String? {
            store.categories.first { $0.name == name && $0.type == type }?.id
        }
        let salario = cat("Salário", .income)
        let mercado = cat("Mercado", .expense)
        let moradia = cat("Moradia", .expense)
        let transporte = cat("Transporte", .expense)
        let lazer = cat("Lazer", .expense)

        // 5 meses de salário + aluguel + mercado (para a evolução de 6 meses).
        for back in stride(from: 4, through: 0, by: -1) {
            let base = cal.date(from: DateComponents(year: curY, month: curM, day: 1)) ?? now
            let ref = cal.date(byAdding: .month, value: -back, to: base) ?? base
            let c = cal.dateComponents([.year, .month], from: ref)
            let m = TransactionEngine.CreateInput(
                description: "Salário", type: .receivable, categoryID: salario,
                amount: 6000, recurrence: .unique, dueDate: day(c.year!, c.month!, 5)
            )
            let created = store.create(m)
            for t in created { store.updateStatus(id: t.id, to: .paid) }
            let rent = TransactionEngine.CreateInput(
                description: "Aluguel", type: .payable, categoryID: moradia,
                amount: 1800, recurrence: .unique, dueDate: day(c.year!, c.month!, 10)
            )
            for t in store.create(rent) { store.updateStatus(id: t.id, to: .paid) }
            let groc = TransactionEngine.CreateInput(
                description: "Mercado semanal", type: .payable, categoryID: mercado,
                amount: 350 + Decimal(back * 20), recurrence: .unique,
                dueDate: day(c.year!, c.month!, 12)
            )
            let g = store.create(groc)
            if back > 0 { for t in g { store.updateStatus(id: t.id, to: .paid) } }
        }

        // Cartões + parcelado no cartão: iPhone 10x (uma parcela por fatura).
        let nubank = try? store.addCard(name: "Nubank", closingDay: 10, dueDay: 17)
        _ = try? store.addCard(name: "Inter", closingDay: 5, dueDay: 12)
        _ = store.create(TransactionEngine.CreateInput(
            description: "iPhone 16", type: .payable, categoryID: lazer,
            amount: 5000, recurrence: .installment, dueDate: day(curY, curM, 8),
            totalInstallments: 10, interval: .monthly,
            creditCardID: nubank?.id, card: nubank
        ))

        // Transporte pendente (próximos 7 dias) + vencido de propósito.
        _ = store.create(TransactionEngine.CreateInput(
            description: "Uber", type: .payable, categoryID: transporte,
            amount: 45, recurrence: .unique,
            dueDate: cal.date(byAdding: .day, value: 2, to: now) ?? now
        ))
        _ = store.create(TransactionEngine.CreateInput(
            description: "Estacionamento", type: .payable, categoryID: transporte,
            amount: 30, recurrence: .unique,
            dueDate: cal.date(byAdding: .day, value: -3, to: now) ?? now
        ))

        // Fundo + aporte.
        if let fund = try? store.addFund(
            name: "Viagem Japão", initialAmount: 1000,
            color: "#8b5cf6", icon: "airplane", notes: "Meta: 12 mil"
        ) {
            _ = try? store.addFundMovement(
                fundID: fund.id, movement: .application, amount: 400,
                description: "Aporte Viagem Japão", dueDate: day(curY, curM, 15)
            )
        }

        // Orçamento do mês.
        if let mercado {
            _ = try? store.saveBudget(categoryID: mercado, month: curM, year: curY, limitAmount: 1500)
        }
        if let lazer {
            _ = try? store.saveBudget(categoryID: lazer, month: curM, year: curY, limitAmount: 800)
        }

        // Lista de desejos.
        if let lista = try? store.addWishlist(name: "Setup", color: "#0ea5e9", icon: "star") {
            _ = try? store.addItem(
                wishlistID: lista.id, name: "Monitor 4K", price: 2200,
                priority: .high, categoryID: lazer, notes: nil
            )
            _ = try? store.addItem(
                wishlistID: lista.id, name: "Teclado mecânico", price: 600,
                priority: .medium, categoryID: lazer, notes: nil
            )
        }

        print("[FinanzinDemo] \(store.transactions.count) transações, \(store.funds.count) fundos, \(store.budgets.count) orçamentos, \(store.wishlists.count) listas")
    }
}
