import Foundation

// MARK: - Provedor de interpretação (prompt/voz → rascunho)
//
// Contrato único para as duas implementações:
// - `RuleBasedNLParser` (este módulo, puro): regex + palavras-chave PT/EN,
//   100% on-device, testável no `FinanzinCoreTests`. É o default e o
//   fallback de tudo.
// - `FoundationModelsNLParser` (FinanzinUI, iOS 26+): LLM on-device da
//   Apple quando disponível; qualquer erro cai nas regras.
//
// A UI (`AIRegistrationSheet`) usa as regras ao vivo por tecla e o LLM
// sob demanda (botão ✨), via `SmartNLParser`.

public protocol NLParseProvider: Sendable {
    func parse(
        text: String, categories: [FinanceCategory], cards: [CreditCard],
        referenceDate: Date
    ) async -> NLParseResult
}

/// Implementação por regras — envolve o `TransactionNLParser` síncrono.
public struct RuleBasedNLParser: NLParseProvider {
    public init() {}

    public func parse(
        text: String, categories: [FinanceCategory], cards: [CreditCard],
        referenceDate: Date
    ) async -> NLParseResult {
        TransactionNLParser.parse(
            text: text, categories: categories, cards: cards,
            referenceDate: referenceDate
        )
    }
}
