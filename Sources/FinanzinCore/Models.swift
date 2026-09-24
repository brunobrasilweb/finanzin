import Foundation

// MARK: - Modelos de domínio (structs puros, sem SwiftData)
//
// Espelham `FinancialModels.swift` do admin. Persistência via `Store`
// (in-memory + JSON). A conversão para `@Model` do SwiftData acontece
// na máquina com Xcode (ver `XcodeOnly/SwiftDataModels.swift`), pois o
// macro `@Model` não resolve no CommandLineTools deste ambiente.

public struct FinanceCategory: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var type: CategoryType
    public var color: String
    public var icon: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: CategoryType = .expense,
        color: String = "#6b7280",
        icon: String = "tag",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.color = color
        self.icon = icon
        self.createdAt = createdAt
    }
}

/// Cartão de crédito para gestão de faturas (Sprint 8).
/// Dias de 1...31 (meses curtos ajustam sozinhos via clamp).
public struct CreditCard: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var closingDay: Int
    public var dueDay: Int
    public var isActive: Bool
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        closingDay: Int,
        dueDay: Int,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.closingDay = closingDay
        self.dueDay = dueDay
        self.isActive = isActive
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, closingDay, dueDay, isActive, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        closingDay = try c.decode(Int.self, forKey: .closingDay)
        dueDay = try c.decode(Int.self, forKey: .dueDay)
        // Compat: JSON antigo não tem a chave.
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

/// Conta bancária/carteira do multi-contas.
/// O saldo é virtual: `initialBalance` + lançamentos baixados (ver `AccountService`).
public struct BankAccount: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var initialBalance: Decimal
    public var color: String
    public var icon: String
    public var isActive: Bool
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        initialBalance: Decimal = 0,
        color: String = "#0ea5e9",
        icon: String = "banknote",
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.initialBalance = initialBalance
        self.color = color
        self.icon = icon
        self.isActive = isActive
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, initialBalance, color, icon, isActive, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        initialBalance = try c.decodeIfPresent(Decimal.self, forKey: .initialBalance) ?? 0
        color = try c.decodeIfPresent(String.self, forKey: .color) ?? "#0ea5e9"
        icon = try c.decodeIfPresent(String.self, forKey: .icon) ?? "banknote"
        // Compat: JSON antigo não tem a chave.
        isActive = try c.decodeIfPresent(Bool.self, forKey: .isActive) ?? true
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

public struct FinancialTransaction: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var description: String
    public var type: TransactionType
    public var recurrence: RecurrenceType
    public var categoryID: String?
    /// Conta bancária/carteira do lançamento (`nil` = sem conta, legado).
    public var accountID: String?
    public var totalAmount: Decimal
    public var amount: Decimal
    public var installmentCount: Int
    public var currentInstallment: Int?
    public var installmentInterval: InstallmentInterval?
    public var dueDate: Date
    public var paidDate: Date?
    public var status: TransactionStatus
    public var notes: String?
    public var parentID: String?
    public var fundID: String?
    public var fundMovementType: FundMovementType?
    /// Cartão da compra (`nil` = à vista/conta comum). Define a fatura via `InvoiceService`.
    public var creditCardID: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        description: String,
        type: TransactionType = .payable,
        recurrence: RecurrenceType = .unique,
        categoryID: String? = nil,
        totalAmount: Decimal? = nil,
        amount: Decimal,
        installmentCount: Int = 1,
        currentInstallment: Int? = nil,
        installmentInterval: InstallmentInterval? = nil,
        dueDate: Date = Date(),
        paidDate: Date? = nil,
        status: TransactionStatus = .pending,
        notes: String? = nil,
        parentID: String? = nil,
        fundID: String? = nil,
        fundMovementType: FundMovementType? = nil,
        creditCardID: String? = nil,
        accountID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.description = description
        self.type = type
        self.recurrence = recurrence
        self.categoryID = categoryID
        self.accountID = accountID
        self.amount = amount
        self.totalAmount = totalAmount ?? amount
        self.installmentCount = installmentCount
        self.currentInstallment = currentInstallment
        self.installmentInterval = installmentInterval
        self.dueDate = dueDate
        self.paidDate = paidDate
        self.status = status
        self.notes = notes
        self.parentID = parentID
        self.fundID = fundID
        self.fundMovementType = fundMovementType
        self.creditCardID = creditCardID
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, description, type, recurrence, categoryID, accountID, totalAmount, amount
        case installmentCount, currentInstallment, installmentInterval
        case dueDate, paidDate, status, notes, parentID, fundID, fundMovementType
        case creditCardID, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        description = try c.decode(String.self, forKey: .description)
        type = try c.decode(TransactionType.self, forKey: .type)
        recurrence = try c.decode(RecurrenceType.self, forKey: .recurrence)
        categoryID = try c.decodeIfPresent(String.self, forKey: .categoryID)
        // Compat: JSON antigo não tem a chave.
        accountID = try c.decodeIfPresent(String.self, forKey: .accountID)
        totalAmount = try c.decode(Decimal.self, forKey: .totalAmount)
        amount = try c.decode(Decimal.self, forKey: .amount)
        installmentCount = try c.decodeIfPresent(Int.self, forKey: .installmentCount) ?? 1
        currentInstallment = try c.decodeIfPresent(Int.self, forKey: .currentInstallment)
        installmentInterval = try c.decodeIfPresent(InstallmentInterval.self, forKey: .installmentInterval)
        dueDate = try c.decode(Date.self, forKey: .dueDate)
        paidDate = try c.decodeIfPresent(Date.self, forKey: .paidDate)
        status = try c.decode(TransactionStatus.self, forKey: .status)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        parentID = try c.decodeIfPresent(String.self, forKey: .parentID)
        fundID = try c.decodeIfPresent(String.self, forKey: .fundID)
        fundMovementType = try c.decodeIfPresent(FundMovementType.self, forKey: .fundMovementType)
        // Compat: JSON antigo não tem a chave.
        creditCardID = try c.decodeIfPresent(String.self, forKey: .creditCardID)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }

    public var isChild: Bool { parentID != nil }
    public var isOverdue: Bool {
        status == .pending && dueDate < Calendar.current.startOfDay(for: Date())
    }
    /// Compra no cartão (`creditCardID` preenchido).
    public var isCardPurchase: Bool { creditCardID != nil }
}

public struct Fund: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var initialAmount: Decimal
    public var color: String
    public var icon: String
    public var notes: String?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        initialAmount: Decimal = 0,
        color: String = "#8b5cf6",
        icon: String = "chart.pie.fill",
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.initialAmount = initialAmount
        self.color = color
        self.icon = icon
        self.notes = notes
        self.createdAt = createdAt
    }
}

public struct BudgetLimit: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var categoryID: String
    public var month: Int
    public var year: Int
    public var limitAmount: Decimal
    /// `true` = vale todos os meses a partir de (month/year); `false` = só o mês.
    public var isRecurring: Bool
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        categoryID: String,
        month: Int,
        year: Int,
        limitAmount: Decimal,
        isRecurring: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.categoryID = categoryID
        self.month = month
        self.year = year
        self.limitAmount = limitAmount
        self.isRecurring = isRecurring
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, categoryID, month, year, limitAmount, isRecurring, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        categoryID = try c.decode(String.self, forKey: .categoryID)
        month = try c.decode(Int.self, forKey: .month)
        year = try c.decode(Int.self, forKey: .year)
        limitAmount = try c.decode(Decimal.self, forKey: .limitAmount)
        // Compat: JSON antigo não tem a chave.
        isRecurring = try c.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
    }
}

/// Diferença vs admin: múltiplas listas (admin tem tabela única `financial_wishlist`).
public struct Wishlist: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var name: String
    public var color: String
    public var icon: String
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        color: String = "#6366f1",
        icon: String = "heart",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.createdAt = createdAt
    }
}

public struct WishlistItem: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var wishlistID: String
    public var name: String
    public var estimatedPrice: Decimal
    public var priority: WishlistPriority
    public var categoryID: String?
    public var notes: String?
    public var purchased: Bool
    public var purchasedDate: Date?
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        wishlistID: String,
        name: String,
        estimatedPrice: Decimal,
        priority: WishlistPriority = .medium,
        categoryID: String? = nil,
        notes: String? = nil,
        purchased: Bool = false,
        purchasedDate: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.wishlistID = wishlistID
        self.name = name
        self.estimatedPrice = estimatedPrice
        self.priority = priority
        self.categoryID = categoryID
        self.notes = notes
        self.purchased = purchased
        self.purchasedDate = purchasedDate
        self.createdAt = createdAt
    }
}

// MARK: - Agregações (espelham `metrics.service.ts`)

public struct MonthlyMetrics: Hashable, Codable, Sendable {
    public var totalIncome: Decimal
    public var totalExpense: Decimal
    public var balance: Decimal
    public var savingsRate: Double
    public var pendingReceivable: Decimal
    public var pendingPayable: Decimal
    public var overdueAmount: Decimal

    public init(
        totalIncome: Decimal = 0, totalExpense: Decimal = 0,
        pendingReceivable: Decimal = 0, pendingPayable: Decimal = 0,
        overdueAmount: Decimal = 0
    ) {
        self.totalIncome = totalIncome
        self.totalExpense = totalExpense
        self.balance = totalIncome - totalExpense
        let income = (totalIncome as NSDecimalNumber).doubleValue
        let bal = ((totalIncome - totalExpense) as NSDecimalNumber).doubleValue
        self.savingsRate = income > 0 ? (bal / income) * 100 : 0
        self.pendingReceivable = pendingReceivable
        self.pendingPayable = pendingPayable
        self.overdueAmount = overdueAmount
    }
}

public struct CategoryBreakdown: Hashable, Codable, Sendable {
    public var categoryID: String
    public var categoryName: String
    public var categoryColor: String
    public var total: Decimal
    public var percentage: Double
}

public struct MonthlyEvolution: Hashable, Codable, Sendable {
    public var month: Int
    public var year: Int
    public var label: String
    public var income: Decimal
    public var expense: Decimal

    /// Identidade estável p/ `Chart`/`ForEach` (o `label` muda com o locale).
    public var stableID: String { "\(year)-\(month)" }
}
