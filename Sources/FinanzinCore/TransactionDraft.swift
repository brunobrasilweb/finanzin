import Foundation

// MARK: - Rascunho de transação via deep link / App Intent
//
// Permite abrir o app já no formulário pré-preenchido logo após pagar
// no NFC/Apple Pay (a Wallet não expõe API pública para terceiros lerem
// a compra — ver FinanceKit: só Apple Card/Cash/Savings, US/UK).
// Esquema: finanzin://nova-transacao?valor=12,90&descricao=Padaria&data=2026-09-23
// Atalhos/Siri/Botão de Ação montam essa URL via `RegistrarGastoIntent`.

public struct TransactionDraft: Hashable, Sendable {
    public var amount: Decimal?
    public var description: String?
    public var date: Date?
    /// Tipo sugerido pela IA local (prompt/voz). Deep link/Siri não enviam.
    public var type: TransactionType?
    /// Categoria sugerida pela IA local (id do Store).
    public var categoryID: String?
    /// Parcelas detectadas no prompt ("em 3x"). Nil = conta única.
    public var installmentCount: Int?
    /// Recorrência detectada ("todo mês"). Nil = avulsa.
    public var recurrence: RecurrenceType?
    /// Intervalo da recorrente (nil quando avulsa/fixa/parcelada).
    public var interval: InstallmentInterval?
    /// Cartão citado ou único ativo ("cartão nubank", "no cartão").
    public var creditCardID: String?
    /// Menção genérica ao cartão sem identificar qual (o form pede).
    public var payOnCard: Bool

    public init(
        amount: Decimal? = nil, description: String? = nil, date: Date? = nil,
        type: TransactionType? = nil, categoryID: String? = nil,
        installmentCount: Int? = nil, recurrence: RecurrenceType? = nil,
        interval: InstallmentInterval? = nil, creditCardID: String? = nil,
        payOnCard: Bool = false
    ) {
        self.amount = amount
        self.description = description
        self.date = date
        self.type = type
        self.categoryID = categoryID
        self.installmentCount = installmentCount
        self.recurrence = recurrence
        self.interval = interval
        self.creditCardID = creditCardID
        self.payOnCard = payOnCard
    }

    // MARK: - Parse da URL

    /// Aceita hosts `nova-transacao` e `new-transaction`, qualquer scheme.
    /// Nunca falha: query inválida vira campo `nil` (o form abre zerado).
    public static func from(url: URL) -> TransactionDraft? {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = comps.host?.lowercased(),
              host == "nova-transacao" || host == "new-transaction"
        else { return nil }
        let items = comps.queryItems ?? []
        func first(_ names: String...) -> String? {
            for n in names {
                if let v = items.first(where: { $0.name.lowercased() == n })?.value,
                   !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return v
                }
            }
            return nil
        }
        var draft = TransactionDraft()
        if let raw = first("valor", "value", "amount") {
            draft.amount = parseAmount(raw)
        }
        if let raw = first("descricao", "description", "desc") {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            draft.description = trimmed.isEmpty ? nil : trimmed
        }
        if let raw = first("data", "date") {
            draft.date = parseDate(raw)
        }
        return draft
    }

    // MARK: - Construção da URL (usada pelo Intent/Atalhos)

    public static func url(amount: Decimal? = nil, description: String? = nil, date: Date = Date()) -> URL? {
        var comps = URLComponents()
        comps.scheme = "finanzin"
        comps.host = "nova-transacao"
        var items: [URLQueryItem] = []
        if let amount {
            items.append(URLQueryItem(name: "valor", value: "\(NSDecimalNumber(decimal: amount))"))
        }
        if let description, !description.isEmpty {
            items.append(URLQueryItem(name: "descricao", value: description))
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        items.append(URLQueryItem(name: "data", value: f.string(from: date)))
        comps.queryItems = items.isEmpty ? nil : items
        return comps.url
    }

    // MARK: - Parsers

    /// Aceita `12,90`, `12.90` e `1.234,56` (separador de milhar pt-BR).
    public static func parseAmount(_ raw: String) -> Decimal? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.contains(",") {
            let noThousands = s.replacingOccurrences(of: ".", with: "")
            let normalized = noThousands.replacingOccurrences(of: ",", with: ".")
            return Decimal(string: normalized)
        }
        return Decimal(string: s)
    }

    /// Aceita `yyyy-MM-dd` (formato do Intent) e `dd/MM/yyyy`.
    public static func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = DateFormatter()
        iso.locale = Locale(identifier: "en_US_POSIX")
        iso.dateFormat = "yyyy-MM-dd"
        if let d = iso.date(from: s) { return d }
        let br = DateFormatter()
        br.locale = Locale(identifier: "pt_BR")
        br.dateFormat = "dd/MM/yyyy"
        return br.date(from: s)
    }
}
