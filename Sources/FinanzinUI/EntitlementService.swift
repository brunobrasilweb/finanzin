import SwiftUI
import FinanzinCore
#if canImport(StoreKit)
import StoreKit
#endif
#if os(iOS)
import UIKit
#endif

// MARK: - Ponte StoreKit → Store.isPro (pagamento só pela Apple)
//
// - Dev (SPM/CLT/Demo e Xcode Debug no iPhone/simulador, SEM `FIN_STORE_BUILD`):
//   tudo liberado, sem rede, sem StoreKit. Os botões de compra mostram nota de dev.
// - Loja (Xcode Release/Archive com `-D FIN_STORE_BUILD`): assinaturas via StoreKit 2.
//   NUNCA PassKit/Stripe/checkout externo para liberar o Pro (rejeição 3.1.1)
//   e NUNCA merchant ID / capability `in-app-payments` (só p/ bens físicos).
//
// Produtos (criar no App Store Connect, grupo "Finanzin Pro"):
// - `finanzin.pro.monthly` (~R$ 9,70) · `finanzin.pro.yearly` (~R$ 97).
// A UI usa `displayPrice` da Apple; os fallbacks abaixo são só prévia/dev.

public final class EntitlementService: ObservableObject, @unchecked Sendable {
    public struct PlanProduct: Identifiable {
        public let id: String
        public let price: String
        public init(id: String, price: String) {
            self.id = id
            self.price = price
        }
    }

    public static let monthlyID = "finanzin.pro.monthly"
    public static let yearlyID = "finanzin.pro.yearly"
    public static let monthlyPriceFallback = "R$ 9,70"
    public static let yearlyPriceFallback = "R$ 97,00"

    @Published public var products: [PlanProduct] = []
    @Published public var purchasing = false

    /// `true` = ambiente dev, tudo liberado (sem `FIN_STORE_BUILD`).
    public let devMode: Bool

    private let store: Store
    #if canImport(StoreKit)
    private var rawProducts: [String: Product] = [:]
    #endif

    public init(store: Store) {
        self.store = store
        #if FIN_STORE_BUILD
        self.devMode = false
        #else
        self.devMode = true
        store.setPro(true)
        #endif
    }

    public func price(for productID: String, fallback: String) -> String {
        products.first { $0.id == productID }?.price ?? fallback
    }

    /// Chamado na abertura do app (build da loja): sincroniza o entitlement
    /// e carrega preços. Em dev é no-op (já é Pro).
    public func configure() async {
        #if FIN_STORE_BUILD
        #if canImport(StoreKit)
        await refresh()
        await loadProducts()
        listen()
        #endif
        #endif
    }

    // MARK: - Loja (StoreKit 2)

    #if FIN_STORE_BUILD
    #if canImport(StoreKit)
    @MainActor
    public func refresh() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result,
               t.productID == Self.monthlyID || t.productID == Self.yearlyID
            {
                pro = true
                break
            }
        }
        store.setPro(pro)
    }

    @MainActor
    private func loadProducts() async {
        guard let fetched = try? await Product.products(for: [Self.monthlyID, Self.yearlyID]) else { return }
        for p in fetched { rawProducts[p.id] = p }
        // Anual primeiro (plano recomendado).
        products = [Self.yearlyID, Self.monthlyID].compactMap { id in
            rawProducts[id].map { PlanProduct(id: id, price: $0.displayPrice) }
        }
    }

    private func listen() {
        Task { [weak self] in
            for await _ in Transaction.updates {
                await self?.refresh()
            }
        }
    }

    /// Compra via sheet da Apple. Retorna `true` se virou Pro.
    @MainActor
    public func purchase(productID: String) async -> Bool {
        guard let product = rawProducts[productID] else { return false }
        purchasing = true
        defer { purchasing = false }
        guard let result = try? await product.purchase() else { return false }
        switch result {
        case .success(let verification):
            if case .verified(let t) = verification {
                await t.finish()
                await refresh()
                return store.isPro
            }
            return false
        default:
            return false
        }
    }

    @MainActor
    public func restore() async {
        do {
            try await AppStore.sync()
        } catch {}
        await refresh()
    }

    /// Gerenciar/cancelar assinatura (só iOS; no macOS é pelo App Store).
    @MainActor
    public func manageSubscriptions() {
        #if os(iOS)
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        Task {
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {}
        }
        #endif
    }
    #else
    // FIN_STORE_BUILD sem StoreKit (plataforma sem SDK): stubs.
    @MainActor public func refresh() async {}
    @MainActor public func purchase(productID: String) async -> Bool { false }
    @MainActor public func restore() async {}
    @MainActor public func manageSubscriptions() {}
    #endif
    #else
    // Dev: sem compra, já é Pro.
    @MainActor public func refresh() async {}
    @MainActor public func purchase(productID: String) async -> Bool { false }
    @MainActor public func restore() async {}
    @MainActor public func manageSubscriptions() {}
    #endif
}
