import Foundation

// MARK: - Planos: Free limitado x Pro ilimitado
//
// Separação dev x loja por flag de compilação:
// - Dev (SPM/CLT/Demo e Xcode Debug no iPhone/simulador, SEM `FIN_STORE_BUILD`):
//   `isPro == true`, tudo liberado.
// - Loja (Xcode Release/Archive COM `-D FIN_STORE_BUILD`, ver `project.yml`):
//   paywall via StoreKit (`EntitlementService` atualiza `Store.isPro`).
//
// Limites do Free (definidos pelo dono do produto):
// - 1 conta, 1 cartão, transações ilimitadas, 2 orçamentos,
//   sem fundos, sem desejos, sem criar categorias (só edita),
//   sem notificações.

/// Recurso sujeito a teto no plano básico.
public enum PlanFeature: String, CaseIterable, Sendable {
    case accounts
    case cards
    case budgets
    case funds
    case wishlists
    case categories
    case notifications
}

public enum PlanLimits {
    public static let maxAccounts = 1
    public static let maxCards = 1
    /// 2 registros totais de `BudgetLimit` (não 2/mês).
    public static let maxBudgets = 2
}

/// Erro lançado pelos métodos do `Store` quando o plano básico
/// atinge o teto. As telas convertem em abertura do paywall
/// (`store.requestUpgrade()`), nunca em "couldNotSave" genérico.
public enum PlanError: Error, Equatable {
    case limitReached(PlanFeature)
}

// MARK: - Cupons de desconto
//
// Códigos oficiais (fonte única — usados na validação e nos testes):
// - 10% → 5c8e · 20% → 3e5t · 50% → 7hu2 · 100% → 5t6w
// Nota: por estarem no fonte, são extraíveis do binário. A proteção
// real contra reuso em escala é o Offer Code one-time-use da Apple
// (App Store Connect); aqui vale a prévia de preço + resgate na sheet.
// Para rotacionar: troque os literais abaixo (exige update do app).

public enum CouponTier: String, CaseIterable, Sendable {
    case p10
    case p20
    case p50
    case p100

    public var percent: Int {
        switch self {
        case .p10: 10
        case .p20: 20
        case .p50: 50
        case .p100: 100
        }
    }

    /// Código literal do tier (já normalizado: minúsculas, sem espaços).
    public var code: String {
        switch self {
        case .p10: "5c8e"
        case .p20: "3e5t"
        case .p50: "7hu2"
        case .p100: "5t6w"
        }
    }
}

public enum CouponPolicy {
    /// Tentativas erradas consecutivas antes do bloqueio temporário.
    public static let maxFails = 5
    public static let lockoutSeconds: TimeInterval = 60

    public static func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Compara em tempo constante (sem early-exit por byte).
    private static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8)
        let y = Array(b.utf8)
        guard x.count == y.count else { return false }
        var diff: UInt8 = 0
        for i in x.indices { diff |= x[i] ^ y[i] }
        return diff == 0
    }

    /// Tier do código, ou `nil` se inválido.
    public static func tier(for code: String) -> CouponTier? {
        let norm = normalize(code)
        guard !norm.isEmpty else { return nil }
        return CouponTier.allCases.first {
            constantTimeEqual(norm, $0.code)
        }
    }

    /// Prévia do preço com desconto (só exibição; a cobrança real
    /// é a oferta resgatada na sheet da Apple).
    public static func preview(base: Decimal, percent: Int) -> Decimal {
        base * Decimal(100 - percent) / 100
    }
}
