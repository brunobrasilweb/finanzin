import Foundation
import FinanzinCore

// MARK: - Interpretação híbrida (LLM quando há, regras sempre)
//
// A UI usa as regras ao vivo por tecla (instantâneo, grátis) e o LLM sob
// demanda (botão ✨). `enhance` nunca falha: sem Apple Intelligence, sem
// modelo ou com qualquer erro, devolve o resultado das regras.

public enum SmartNLParser {
    /// Verdadeiro em iPhone 15 Pro+ com iOS 26 e Apple Intelligence pronta.
    public static var isFoundationAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            return FoundationModelsNLParser.isAvailable
        }
        #endif
        return false
    }

    /// Tenta o LLM on-device; qualquer falha cai nas regras.
    public static func enhance(
        text: String, categories: [FinanceCategory], cards: [CreditCard],
        language: AppLanguage, referenceDate: Date = Date()
    ) async -> NLParseResult {
        #if canImport(FoundationModels)
        if #available(iOS 26, macOS 26, *) {
            if FoundationModelsNLParser.isAvailable {
                return await FoundationModelsNLParser(language: language).parse(
                    text: text, categories: categories, cards: cards,
                    referenceDate: referenceDate
                )
            }
        }
        #endif
        return TransactionNLParser.parse(
            text: text, categories: categories, cards: cards,
            referenceDate: referenceDate
        )
    }
}

#if canImport(FoundationModels)
import FoundationModels

/// LLM on-device da Apple (iOS 26+, iPhone 15 Pro+). Sugere os campos em
/// texto livre; tudo é validado contra regex e contra as entidades reais
/// do Store antes de virar `NLParseResult` — nome de categoria/cartão
/// alucinado simplesmente não casa e cai no fallback das regras.
@available(iOS 26, macOS 26, *)
public struct FoundationModelsNLParser: NLParseProvider {
    private let language: AppLanguage

    public init(language: AppLanguage = .ptBR) {
        self.language = language
    }

    public static var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    public func parse(
        text: String, categories: [FinanceCategory], cards: [CreditCard],
        referenceDate: Date
    ) async -> NLParseResult {
        // Regras primeiro: fallback pronto + referência para validar o LLM.
        let rules = TransactionNLParser.parse(
            text: text, categories: categories, cards: cards,
            referenceDate: referenceDate
        )
        do {
            let session = LanguageModelSession(instructions: Self.instructions(
                language: language, categories: categories, cards: cards,
                referenceDate: referenceDate
            ))
            let response = try await session.respond(
                to: Self.prompt(text: text, language: language),
                generating: LLMTransaction.self
            )
            return Self.merged(
                llm: response.content, text: text, rules: rules,
                categories: categories, cards: cards
            )
        } catch {
            return rules
        }
    }

    // MARK: - Saída guiada

    @Generable
    struct LLMTransaction {
        @Guide(description: "Amount as a number, e.g. 45.9. Use 0 if not mentioned.")
        var amount: Double
        @Guide(description: "Short description or merchant, e.g. Bakery. Empty string if unclear.")
        var details: String
        @Guide(description: "Transaction date in yyyy-MM-dd format.")
        var date: String
        @Guide(description: "Either 'expense' or 'income'.")
        var kind: String
        @Guide(description: "Category name copied exactly from the provided list, or empty string.")
        var category: String
        @Guide(description: "One of: once, installments, fixed, weekly, monthly, yearly.")
        var recurrence: String
        @Guide(description: "Number of installments, or 0 when not an installment purchase.")
        var installments: Int
        @Guide(description: "Card name copied exactly from the provided list, or empty string.")
        var card: String
    }

    // MARK: - Prompt bilíngue

    private static func instructions(
        language: AppLanguage, categories: [FinanceCategory],
        cards: [CreditCard], referenceDate: Date
    ) -> String {
        let day: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            return f.string(from: referenceDate)
        }()
        let expenses = categories
            .filter { $0.type == .expense }.map(\.name).joined(separator: ", ")
        let income = categories
            .filter { $0.type == .income }.map(\.name).joined(separator: ", ")
        let cardNames = cards.map(\.name).joined(separator: ", ")
        if language == .en {
            return """
            You extract structured data from a personal finance note in \
            Portuguese or English. Today is \(day). Expense categories: \
            \(expenses). Income categories: \(income). Cards: \(cardNames). \
            Amount uses a dot as decimal separator. If something was not \
            mentioned, use 0, an empty string or 'once'. Category and card \
            must be copied exactly from the lists. Example: "paid 45 at the \
            bakery yesterday" gives amount 45, details "Bakery", kind \
            "expense", category "Mercado", recurrence "once", installments 0.
            """
        }
        return """
        Você extrai dados estruturados de uma anotação financeira em \
        português ou inglês. Hoje é \(day). Categorias de despesa: \
        \(expenses). Categorias de receita: \(income). Cartões: \(cardNames). \
        Valor usa ponto como decimal. O que não foi mencionado vira 0, texto \
        vazio ou 'once'. Categoria e cartão copiados exatamente das listas. \
        Exemplo: "paguei 45 na padaria ontem" dá amount 45, details \
        "Padaria", kind "expense", category "Mercado", recurrence "once", \
        installments 0.
        """
    }

    private static func prompt(text: String, language: AppLanguage) -> String {
        language == .en ? "Note: \"\(text)\"" : "Anotação: \"\(text)\""
    }

    // MARK: - Fusão com validação

    /// Junta LLM + regras: número e data preferem o determinístico;
    /// nomes só valem se casarem com entidades reais.
    static func merged(
        llm: LLMTransaction, text: String, rules: NLParseResult,
        categories: [FinanceCategory], cards: [CreditCard]
    ) -> NLParseResult {
        let details = llm.details.trimmingCharacters(in: .whitespacesAndNewlines)
        let categoryName = llm.category.trimmingCharacters(in: .whitespacesAndNewlines)
        let cardName = llm.card.trimmingCharacters(in: .whitespacesAndNewlines)
        let validInstallments = (2...48).contains(llm.installments)
            ? llm.installments : nil
        // LLM sem nada aproveitável → regras (sem carimbar confiança alta).
        guard llm.amount > 0 || !details.isEmpty || !categoryName.isEmpty
            || validInstallments != nil
        else { return rules }

        let kind = llm.kind.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let type: TransactionType = kind == "income" ? .receivable
            : kind == "expense" ? .payable : rules.type
        let date: Date
        let dateExplicit: Bool
        if let parsed = TransactionDraft.parseDate(llm.date) {
            date = parsed
            dateExplicit = true
        } else {
            date = rules.date
            dateExplicit = rules.dateExplicit
        }
        let (recurrence, interval) = mapRecurrence(llm.recurrence, fallback: rules)
        return NLParseResult(
            amount: rules.amount ?? (llm.amount > 0 ? Decimal(llm.amount) : nil),
            description: details.isEmpty
                ? rules.description : TransactionNLParser.titlecasedPT(details),
            date: date, dateExplicit: dateExplicit, type: type,
            categoryID: matchCategory(
                name: categoryName, type: type, in: categories
            ) ?? rules.categoryID,
            installmentCount: validInstallments ?? rules.installmentCount,
            recurrence: recurrence, interval: interval,
            creditCardID: matchCard(name: cardName, in: cards)
                ?? rules.creditCardID,
            payOnCard: matchCard(name: cardName, in: cards) != nil
                || rules.payOnCard,
            confidence: 0.85, rawText: text
        )
    }

    private static func mapRecurrence(
        _ raw: String, fallback: NLParseResult
    ) -> (RecurrenceType, InstallmentInterval?) {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "fixed": return (.fixed, nil)
        case "weekly": return (.recurring, .weekly)
        case "monthly": return (.recurring, .monthly)
        case "yearly": return (.recurring, .yearly)
        default: return (fallback.recurrence, fallback.interval)
        }
    }

    /// Nome do LLM contra entidades reais (sem acento); alucinação → nil.
    private static func matchCategory(
        name: String, type: TransactionType, in categories: [FinanceCategory]
    ) -> String? {
        let target = ReceiptParser.fold(name)
            .trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return nil }
        let pool = categories.filter {
            $0.type == (type == .payable ? .expense : .income)
        }
        if let exact = pool.first(where: {
            ReceiptParser.fold($0.name) == target
        }) { return exact.id }
        if target.count >= 4, let partial = pool.first(where: {
            ReceiptParser.fold($0.name).contains(target)
        }) { return partial.id }
        return nil
    }

    private static func matchCard(name: String, in cards: [CreditCard]) -> String? {
        let target = ReceiptParser.fold(name)
            .trimmingCharacters(in: .whitespaces)
        guard target.count >= 3 else { return nil }
        if let exact = cards.first(where: {
            ReceiptParser.fold($0.name) == target
        }) { return exact.id }
        return cards.first(where: {
            ReceiptParser.fold($0.name).contains(target)
        })?.id
    }
}
#endif
