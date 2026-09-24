import Foundation

// MARK: - Prompt/voz → rascunho de transação (IA local por regras)
//
// "IA embarcada" sem API e sem custo: parsing 100% on-device com regex +
// palavras-chave pt-BR, testável no `FinanzinCoreTests` (CLT). A voz entra
// como texto via `SpeechTranscriber` (UI, iOS) e cai neste mesmo parser.
// Nada é salvo sem revisão manual no sheet de IA.
//
// Exemplos: "paguei 45 na padaria ontem", "recebi 5000 do salário hoje",
// "comprei iphone 3000 em 3x", "gastei 128,90 no assai dia 12".

public struct NLParseResult: Hashable, Sendable {
    public var amount: Decimal?
    public var description: String?
    public var date: Date
    /// Data explícita no texto (ontem, dia 12, ...). Falso = hoje (default).
    public var dateExplicit: Bool
    public var type: TransactionType
    public var categoryID: String?
    /// Parcelas detectadas ("em 3x"). Nil = conta única.
    public var installmentCount: Int?
    /// "todo mês"/"mensal"/"toda semana" → recorrência (`.unique` = avulsa).
    public var recurrence: RecurrenceType
    /// Intervalo da recorrente (nil quando `.unique`/`.fixed`/`.installment`).
    public var interval: InstallmentInterval?
    /// Cartão citado ("cartão nubank") ou único ativo ("no cartão").
    public var creditCardID: String?
    /// Verdadeiro quando o texto indica pagamento no cartão sem citar qual
    /// (o formulário pede para escolher).
    public var payOnCard: Bool
    /// 0...1: 0,4 valor + 0,3 descrição + 0,15 data explícita + 0,15 categoria.
    public var confidence: Double
    public var rawText: String

    public init(
        amount: Decimal? = nil, description: String? = nil, date: Date = Date(),
        dateExplicit: Bool = false, type: TransactionType = .payable,
        categoryID: String? = nil, installmentCount: Int? = nil,
        recurrence: RecurrenceType = .unique,
        interval: InstallmentInterval? = nil,
        creditCardID: String? = nil, payOnCard: Bool = false,
        confidence: Double = 0, rawText: String = ""
    ) {
        self.amount = amount
        self.description = description
        self.date = date
        self.dateExplicit = dateExplicit
        self.type = type
        self.categoryID = categoryID
        self.installmentCount = installmentCount
        self.recurrence = recurrence
        self.interval = interval
        self.creditCardID = creditCardID
        self.payOnCard = payOnCard
        self.confidence = confidence
        self.rawText = rawText
    }

    /// Converte para o rascunho do formulário (todos os campos detectados).
    public func toDraft() -> TransactionDraft {
        TransactionDraft(
            amount: amount, description: description, date: date,
            type: type, categoryID: categoryID,
            installmentCount: installmentCount,
            recurrence: recurrence == .unique ? nil : recurrence,
            interval: interval, creditCardID: creditCardID,
            payOnCard: payOnCard
        )
    }
}

public enum TransactionNLParser {
    // MARK: - Entrada principal

    /// Interpreta um prompt ou transcrição de voz em pt-BR (com mínimo de EN).
    /// Detecta valor, descrição, categoria, data, recorrência e cartão.
    public static func parse(
        text: String,
        categories: [FinanceCategory]? = nil,
        cards: [CreditCard]? = nil,
        referenceDate: Date = Date()
    ) -> NLParseResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return NLParseResult(date: referenceDate, rawText: text)
        }
        let upper = trimmed.uppercased()
        let amount = parseAmount(in: trimmed)
        let type = parseType(in: upper)
        let (date, dateExplicit) = parseDate(in: upper, reference: referenceDate)
        let installments = parseInstallments(in: upper)
        let (recurrence, interval) = parseRecurrence(in: upper)
        let description = parseDescription(
            in: trimmed, amount: amount, installments: installments)
        let (cardID, payOnCard) = cards.map {
            parseCard(in: trimmed, installments: installments, cards: $0)
        } ?? (nil, false)
        var result = NLParseResult(
            amount: amount, description: description, date: date,
            dateExplicit: dateExplicit, type: type,
            installmentCount: installments, recurrence: recurrence,
            interval: interval, creditCardID: cardID,
            payOnCard: payOnCard, rawText: trimmed
        )
        if let categories {
            result.categoryID = suggestCategoryID(
                type: type, description: description,
                rawText: trimmed, categories: categories
            )
        }
        var confidence = 0.0
        if amount != nil { confidence += 0.4 }
        if let description, !description.isEmpty { confidence += 0.3 }
        if dateExplicit { confidence += 0.15 }
        if result.categoryID != nil { confidence += 0.15 }
        result.confidence = confidence
        return result
    }

    // MARK: - Valor

    /// Primeiro tenta decimais (`1.234,56`, `128,90`, `250.00`, `R$ 45,00`);
    /// sem decimal, aceita inteiro avulso ("paguei 45 na padaria"),
    /// ignorando datas, horas, anos e o número de parcelas ("3x").
    static func parseAmount(in text: String) -> Decimal? {
        let decimalPattern = #"R\$\s*\d[\d.\s]*,\d{2}|\d[\d.\s]*,\d{2}|\d+\.\d{2}"#
        if let regex = try? NSRegularExpression(pattern: decimalPattern) {
            let range = NSRange(text.startIndex..., in: text)
            let values = regex.matches(in: text, range: range).compactMap { m -> Decimal? in
                guard let r = Range(m.range, in: text) else { return nil }
                let token = String(text[r])
                if token.contains("/") || token.contains(":") { return nil }
                return ReceiptParser.normalizeAmount(token)
            }
            if let best = values.max(by: {
                ($0 as NSDecimalNumber).doubleValue < ($1 as NSDecimalNumber).doubleValue
            }) {
                return best
            }
        }
        // Fallback: inteiro sem centavos ("45", "3000").
        let intPattern = #"\b\d[\d.]*\b"#
        guard let regex = try? NSRegularExpression(pattern: intPattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let upper = text.uppercased()
        var best: Decimal?
        for m in regex.matches(in: text, range: range) {
            guard let r = Range(m.range, in: text) else { continue }
            let token = String(text[r])
            // Pula datas ("12/09"), horas ("14:32") e o "3" de "3x/3 parcelas".
            let after = String(text[r.upperBound...].prefix(12)).uppercased()
            if after.hasPrefix("/") || after.hasPrefix(":") { continue }
            if after.hasPrefix("X") || after.hasPrefix(" x") { continue }
            let before = String(text[..<r.lowerBound].suffix(12)).uppercased()
            if before.hasSuffix("/") || before.hasSuffix(":") { continue }
            if upper.contains("\(token) PARCELA") { continue }
            if token.count == 4, let year = Int(token), (1900...2100).contains(year) { continue }
            guard let value = Decimal(string: token.replacingOccurrences(of: ".", with: "")) else { continue }
            if let current = best {
                if (value as NSDecimalNumber).doubleValue > (current as NSDecimalNumber).doubleValue {
                    best = value
                }
            } else {
                best = value
            }
        }
        return best
    }

    // MARK: - Tipo (receita x despesa)

    private static let incomeWords = [
        "RECEBI", "GANHEI", "SALARIO", "SALÁRIO", "FREELANCE", "FREELA",
        "RECEBIMENTO", "RECEITA", "ENTROU", "PAGAMENTO RECEBIDO",
        "RECEIVED", "GOT", "EARNED", "SALARY", "PAYCHECK", "WAGE",
        "INCOME", "FREELANCER", "REVENUE",
    ]

    /// Só verbos fortes de gasto: o default já é despesa, então aqui só
    /// importa para anular uma marca de receita ("recebi e gastei").
    /// Palavras como PIX/CONTA/FATURA não entram (ex.: "recebi via pix"
    /// é receita).
    private static let expenseWords = [
        "PAGUEI", "GASTEI", "COMPREI", "COMPRA",
        "PAID", "SPENT", "BOUGHT", "PURCHASE",
    ]

    static func parseType(in upper: String) -> TransactionType {
        let hasIncome = incomeWords.contains { upper.contains($0) }
        let hasExpense = expenseWords.contains { upper.contains($0) }
        if hasIncome, !hasExpense { return .receivable }
        return .payable
    }

    /// Match por palavra inteira (evita "TER" casar com "Inter").
    static func containsWord(in upper: String, _ alternatives: [String]) -> Bool {
        let pattern = "\\b(?:\(alternatives.joined(separator: "|")))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.firstMatch(
            in: upper, range: NSRange(upper.startIndex..., in: upper)) != nil
    }

    // MARK: - Data relativa/absoluta

    /// Devolve (data, explícita?). Sem menção de data → hoje, não explícita.
    static func parseDate(in upper: String, reference: Date) -> (Date, Bool) {
        let cal = Calendar.current
        if upper.contains("ANTEONTEM") {
            return (cal.date(byAdding: .day, value: -2, to: reference) ?? reference, true)
        }
        if upper.contains("ONTEM") {
            return (cal.date(byAdding: .day, value: -1, to: reference) ?? reference, true)
        }
        if upper.contains("AMANHA") || upper.contains("AMANHÃ") {
            return (cal.date(byAdding: .day, value: 1, to: reference) ?? reference, true)
        }
        if upper.contains("HOJE") {
            return (reference, true)
        }
        if containsWord(in: upper, ["TODAY"]) {
            return (reference, true)
        }
        if containsWord(in: upper, ["YESTERDAY"]) {
            return (cal.date(byAdding: .day, value: -1, to: reference) ?? reference, true)
        }
        if containsWord(in: upper, ["TOMORROW"]) {
            return (cal.date(byAdding: .day, value: 1, to: reference) ?? reference, true)
        }
        // "dia 12[/09[/2026]]" — mês/ano ausentes = mês da referência.
        let dayPattern = #"\bDIA\s+(\d{1,2})(?:/(\d{1,2})(?:/(\d{2,4}))?)?\b"#
        if let regex = try? NSRegularExpression(pattern: dayPattern),
           let m = regex.firstMatch(in: upper, range: NSRange(upper.startIndex..., in: upper))
        {
            func group(_ i: Int) -> Int? {
                guard m.range(at: i).location != NSNotFound,
                      let r = Range(m.range(at: i), in: upper)
                else { return nil }
                return Int(String(upper[r]))
            }
            if let day = group(1), (1...31).contains(day) {
                let refMonth = cal.component(.month, from: reference)
                let refYear = cal.component(.year, from: reference)
                var month = group(2) ?? refMonth
                var year = group(3) ?? refYear
                guard (1...12).contains(month) else { return (reference, false) }
                if year < 100 { year += 2000 }
                var comps = DateComponents(year: year, month: month, day: day, hour: 12)
                if let date = cal.date(from: comps) { return (date, true) }
            }
        }
        // Data absoluta reaproveita o parser do cupom (dd/MM/yyyy).
        if let absolute = ReceiptParser.parseDate(lines: [upper]) {
            // Ano ausente no texto → parser do cupom não casa; tenta dd/MM.
            return (absolute, true)
        }
        let shortPattern = #"\b(\d{1,2})/(\d{1,2})\b"#
        if let regex = try? NSRegularExpression(pattern: shortPattern),
           let m = regex.firstMatch(in: upper, range: NSRange(upper.startIndex..., in: upper)),
           let dr = Range(m.range(at: 1), in: upper),
           let mr = Range(m.range(at: 2), in: upper),
           let day = Int(String(upper[dr])), let month = Int(String(upper[mr])),
           (1...31).contains(day), (1...12).contains(month)
        {
            let year = cal.component(.year, from: reference)
            if let date = cal.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) {
                return (date, true)
            }
        }
        // Mês por extenso: "12 de setembro", "sept 12" (PT/EN).
        if let dated = parseMonthName(in: upper, reference: reference) {
            return (dated, true)
        }
        // Dia da semana por palavra inteira ("sexta", "segunda passada",
        // "last friday", "next monday"). Fronteira evita "TER" casar "Inter".
        let weekdays: [(value: Int, aliases: [String])] = [
            (1, ["DOMINGO", "DOM", "SUNDAY", "SUN"]),
            (2, ["SEGUNDA", "SEG", "MONDAY", "MON"]),
            (3, ["TERÇA", "TERCA", "TER", "TUESDAY", "TUES", "TUE"]),
            (4, ["QUARTA", "QUA", "WEDNESDAY", "WED"]),
            (5, ["QUINTA", "QUI", "THURSDAY", "THURS", "THUR", "THU"]),
            (6, ["SEXTA", "SEX", "FRIDAY", "FRI"]),
            (7, ["SÁBADO", "SABADO", "SAB", "SATURDAY", "SAT"]),
        ]
        let past = upper.contains("PASSAD") || containsWord(in: upper, ["LAST"])
        let coming = containsWord(in: upper, ["NEXT"])
        for day in weekdays {
            if containsWord(in: upper, day.aliases) {
                if let date = recentWeekday(
                    day.value, reference: reference,
                    previousWeek: past, nextWeek: coming && !past
                ) {
                    return (date, true)
                }
            }
        }
        return (reference, false)
    }

    /// "12 de setembro" / "sept 12" → data no ano da referência.
    static func parseMonthName(in upper: String, reference: Date) -> Date? {
        let cal = Calendar.current
        let year = cal.component(.year, from: reference)
        for entry in months {
            let alt = entry.names.joined(separator: "|")
            for pattern in [
                "\\b(?:\(alt))\\s+(\\d{1,2})\\b",
                "\\b(\\d{1,2})\\s+(?:DE\\s+)?(?:\(alt))\\b",
            ] {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let m = regex.firstMatch(
                          in: upper, range: NSRange(upper.startIndex..., in: upper)),
                      m.range(at: 1).location != NSNotFound,
                      let r = Range(m.range(at: 1), in: upper),
                      let day = Int(String(upper[r])), (1...31).contains(day),
                      let date = cal.date(from: DateComponents(
                          year: year, month: entry.month, day: day, hour: 12))
                else { continue }
                return date
            }
        }
        return nil
    }

    /// Ocorrência mais recente do dia da semana (inclui hoje se for o dia).
    /// "passada/last" só volta 7 dias quando hoje É o dia (senão a
    /// ocorrência mais recente já é da semana passada); "next" espelha
    /// para frente.
    private static func recentWeekday(
        _ weekday: Int, reference: Date, previousWeek: Bool, nextWeek: Bool = false
    ) -> Date? {
        let cal = Calendar.current
        let current = cal.component(.weekday, from: reference)
        if nextWeek {
            var delta = (weekday - current + 7) % 7
            if delta == 0 { delta = 7 }
            return cal.date(byAdding: .day, value: delta, to: reference)
        }
        var delta = (current - weekday + 7) % 7
        if previousWeek, delta == 0 { delta = 7 }
        return cal.date(byAdding: .day, value: -delta, to: reference)
    }

    /// Compat: nome antigo usado nos testes.
    private static func mostRecent(weekday: Int, reference: Date, previousWeek: Bool) -> Date? {
        recentWeekday(weekday, reference: reference, previousWeek: previousWeek)
    }

    // MARK: - Parcelas

    /// "em 3x", "3x", "em 10 vezes", "12 parcelas" → 2...48. Nil = única.
    static func parseInstallments(in upper: String) -> Int? {
        let patterns = [
            #"EM\s+(\d{1,2})\s*X\b"#,
            #"IN\s+(\d{1,2})\s*X\b"#,
            #"\b(\d{1,2})\s*X\b"#,
            #"EM\s+(\d{1,2})\s+VEZES?\b"#,
            #"\b(\d{1,2})\s+PARCELAS?\b"#,
            #"\b(\d{1,2})\s+INSTALLMENTS?\b"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let m = regex.firstMatch(in: upper, range: NSRange(upper.startIndex..., in: upper)),
                  m.range(at: 1).location != NSNotFound,
                  let r = Range(m.range(at: 1), in: upper),
                  let count = Int(String(upper[r])), (2...48).contains(count)
            else { continue }
            return count
        }
        return nil
    }

    // MARK: - Descrição

    /// Verbos, datas e parcelas: sempre removidos.
    private static let hardFillers = [
        "PAGUEI", "GASTEI", "COMPREI", "COMPRA", "PAGO",
        "RECEBI", "GANHEI",
        "HOJE", "ONTEM", "ANTEONTEM", "AMANHÃ", "AMANHA", "DIA",
        "PASSADA", "PASSADO", "VEZES", "PARCELAS", "PARCELA",
        "SEGUNDA", "TERÇA", "TERCA", "QUARTA", "QUINTA", "SEXTA",
        "SÁBADO", "SABADO", "DOMINGO", "SEG", "TER", "QUA", "QUI",
        "SEX", "SAB", "DOM",
        "NO", "NA", "NOS", "NAS", "EM", "UM", "UMA", "POR",
        "AO", "AOS", "À", "O", "A", "OS", "AS",
        "MEU", "MINHA", "MEUS", "MINHAS", "PRO", "PRA", "R$",
        // Marcadores de recorrência nunca são descrição.
        "TODO", "TODA", "MES", "MÊS", "ANO", "SEMANA",
        "FIXO", "FIXA", "MENSAL", "MENSALIDADE", "ANUAL",
        "SEMANAL", "QUINZENAL", "RECORRENTE", "ASSINATURA",
        "DIARIO", "DIÁRIO",
        // Inglês: verbos, datas e dias da semana.
        "PAID", "SPENT", "BOUGHT", "RECEIVED", "GOT", "EARNED",
        "TODAY", "YESTERDAY", "TOMORROW", "EVERY", "LAST", "NEXT",
        "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY",
        "SATURDAY", "SUNDAY", "MON", "TUE", "TUES", "WED", "THU",
        "THUR", "THURS", "FRI", "SAT", "SUN",
        "AT", "ON", "IN", "THE", "A", "AN", "TO", "FOR", "OF", "MY",
        "FIXED", "MONTHLY", "YEARLY", "WEEKLY", "SUBSCRIPTION",
        "DAY", "WEEK", "MONTH", "YEAR",
    ]

    /// Meio de pagamento/moeda: removido sempre ("cartão nubank" → "Nubank").
    private static let instrumentFillers = [
        "REAIS", "REAL", "PIX",
        "CARTÃO", "CARTAO", "DÉBITO", "DEBITO", "CRÉDITO", "CREDITO",
        "PAGAMENTO", "RECEBIMENTO", "RECEITA", "VALOR",
        "DOLLARS", "DOLLAR", "BUCKS", "CARD", "CREDIT", "DEBIT",
        "CASH", "PAYMENT", "FEE", "TIP",
    ]

    /// "Conta/fatura/boleto": removido só se sobrar algo relevante
    /// ("fatura nubank" → "Nubank", mas "conta de luz" → "Conta de Luz").
    private static let documentFillers = [
        "CONTA", "FATURA", "BOLETO",
        "BILL", "INVOICE", "RECEIPT", "STATEMENT",
    ]

    /// Conectores mantidos no meio ("Conta de Luz", "Padaria Pão Dourado"),
    /// aparados nas pontas ("do mercado" → "Mercado").
    private static let connectors: Set<String> = [
        "DE", "DA", "DO", "DAS", "DOS", "E", "COM",
        "NO", "NA", "NOS", "NAS", "EM", "AO", "AOS", "À", "ÀS",
        "O", "A", "OS", "AS", "UM", "UMA", "POR", "PARA", "PRA",
    ]

    /// Remove valor, datas, verbos e parcelas; sobra o "o quê".
    /// "paguei 45 na padaria ontem" → "Padaria".
    /// "paguei conta de luz 150" → "Conta de Luz".
    static func parseDescription(
        in text: String, amount: Decimal?, installments: Int?
    ) -> String? {
        var work = " \(text) "
        // Remove o token do valor (decimal ou inteiro).
        let moneyPattern = #"R\$\s*\d[\d.\s]*,\d{2}|\d[\d.\s]*,\d{2}|\d+\.\d{2}|\b\d[\d.]*\b"#
        if let regex = try? NSRegularExpression(pattern: moneyPattern, options: .caseInsensitive) {
            let matches = regex.matches(in: work, range: NSRange(work.startIndex..., in: work))
            // Remove de trás para frente para não invalidar os ranges.
            for m in matches.reversed() {
                guard let r = Range(m.range, in: work) else { continue }
                let token = String(work[r])
                // Não remove o número de parcelas ("3x") nem datas ("12/09").
                let after = String(work[r.upperBound...].prefix(3))
                if after.hasPrefix("x") || after.hasPrefix("X") { continue }
                if token.contains("/") || token.contains(":") { continue }
                if token.count == 4, let year = Int(token), (1900...2100).contains(year) { continue }
                work.replaceSubrange(r, with: " ")
            }
        }
        let upper = work.uppercased()
        let hard = cleanPrompt(upper, extra: [])
        let mid = cleanPrompt(upper, extra: instrumentFillers)
        let base = mid.isEmpty ? hard : mid
        guard !base.isEmpty else { return nil }
        let slim = cleanPrompt(upper, extra: instrumentFillers + documentFillers)
        let slimWords = slim.split(separator: " ")
        let baseWords = base.split(separator: " ")
        // Prefere sem "conta/fatura" ("Fatura Nubank"), mas mantém quando
        // só restaria uma palavra solta ("Conta de Luz", não "Luz").
        let chosen: String
        if !slimWords.isEmpty, slimWords.count > 1 || baseWords.count <= 1 {
            chosen = slimWords.joined(separator: " ")
        } else {
            chosen = base
        }
        guard !chosen.isEmpty else { return nil }
        // Reconstrói com as palavras originais (preserva acentos) na ordem,
        // casando cada palavra limpa com a entrada — nunca carrega sobras
        // já removidas ("padaria ontem" → "padaria").
        let originalWords = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ").map(String.init)
        var remaining = originalWords
        var picked: [String] = []
        for token in chosen.split(separator: " ").map(String.init) {
            if let i = remaining.firstIndex(where: { $0.uppercased() == token }) {
                picked.append(remaining[i])
                remaining.removeSubrange(...i)
            } else {
                picked.append(token.lowercased())
            }
        }
        let candidate = String(picked.joined(separator: " ").prefix(40))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .init(charactersIn: "-–—*,.;: "))
        guard !candidate.isEmpty else { return nil }
        return titlecasedPT(candidate)
    }

    /// Meses PT/EN (extenso + abreviação) para strip e parse de data.
    private static let months: [(month: Int, names: [String])] = [
        (1, ["JANUARY", "JANEIRO", "JAN"]),
        (2, ["FEBRUARY", "FEVEREIRO", "FEV", "FEB"]),
        (3, ["MARCH", "MARÇO", "MARCO", "MAR"]),
        (4, ["APRIL", "ABRIL", "ABR", "APR"]),
        (5, ["MAY", "MAIO", "MAI"]),
        (6, ["JUNE", "JUNHO", "JUN"]),
        (7, ["JULY", "JULHO", "JUL"]),
        (8, ["AUGUST", "AGOSTO", "AGO", "AUG"]),
        (9, ["SEPTEMBER", "SETEMBRO", "SET", "SEP", "SEPT"]),
        (10, ["OCTOBER", "OUTUBRO", "OUT", "OCT"]),
        (11, ["NOVEMBER", "NOVEMBRO", "NOV"]),
        (12, ["DECEMBER", "DEZEMBRO", "DEZ", "DEC"]),
    ]

    private static var monthAlternation: String {
        months.flatMap(\.names).joined(separator: "|")
    }

    /// Limpa preenchedores + meses + datas curtas e apara conectores.
    private static func cleanPrompt(_ upper: String, extra: [String]) -> String {
        var s = " \(upper) "
        for filler in hardFillers + extra {
            let escaped = NSRegularExpression.escapedPattern(for: filler)
            s = s.replacingOccurrences(
                of: "\\b\(escaped)\\b", with: " ",
                options: .regularExpression)
        }
        // Meses por extenso ("12 de setembro", "sept 12").
        s = s.replacingOccurrences(
            of: "\\b(?:\(monthAlternation))\\b", with: " ",
            options: .regularExpression)
        // Datas curtas restantes ("12/09", "12-09") e cifrão avulso.
        s = s.replacingOccurrences(
            of: #"\b\d{1,2}[/\-.]\d{1,2}([/\-.]\d{2,4})?\b"#,
            with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: "R$", with: " ")
        s = s.replacingOccurrences(of: "$", with: " ")
        var words = s.split(separator: " ").map(String.init)
        while let first = words.first, connectors.contains(first) { words.removeFirst() }
        while let last = words.last, connectors.contains(last) { words.removeLast() }
        return words.joined(separator: " ")
    }

    /// Título pt-BR: primeira letra de cada palavra, conectores minúsculos.
    /// "conta de luz" → "Conta de Luz"; "padaria pão dourado" → "Padaria Pão Dourado".
    public static func titlecasedPT(_ s: String) -> String {
        let words = s.lowercased().split(separator: " ").map(String.init)
        guard !words.isEmpty else { return s }
        return words.enumerated().map { i, w in
            if i > 0, connectors.contains(w.uppercased()) { return w }
            return w.prefix(1).uppercased() + w.dropFirst()
        }.joined(separator: " ")
    }

    // MARK: - Recorrência

    /// "todo mês"/"fixo" → fixa; "mensal"/"assinatura" → recorrente mensal;
    /// "toda semana" → semanal; "todo ano" → anual. "Todo dia" não tem
    /// intervalo no app — volta avulsa em vez de chutar errado.
    static func parseRecurrence(in upper: String) -> (RecurrenceType, InstallmentInterval?) {
        let f = ReceiptParser.fold(" \(upper) ")
        if f.contains("TODO DIA") || f.contains("DIARIO")
            || f.contains("TODOS OS DIAS") || f.contains("EVERY DAY") {
            return (.unique, nil)
        }
        if f.contains("TODA SEMANA") || f.contains("SEMANAL")
            || f.contains("EVERY WEEK") || f.contains("WEEKLY") {
            return (.recurring, .weekly)
        }
        if f.contains("QUINZENAL") || f.contains("BIWEEKLY")
            || f.contains("FORTNIGHTLY") {
            return (.recurring, .biweekly)
        }
        if f.contains("TODO ANO") || f.contains("ANUAL")
            || f.contains("EVERY YEAR") || f.contains("YEARLY")
            || f.contains("ANNUAL") {
            return (.recurring, .yearly)
        }
        if f.contains("TODO MES") || f.contains("FIXA") || f.contains("FIXO")
            || f.contains("FIXED") {
            return (.fixed, nil)
        }
        if f.contains("MENSAL") || f.contains("RECORRENTE")
            || f.contains("ASSINATURA") || f.contains("EVERY MONTH")
            || f.contains("MONTHLY") || f.contains("SUBSCRIPTION") {
            return (.recurring, .monthly)
        }
        return (.unique, nil)
    }

    // MARK: - Cartão

    /// Nome do cartão citado ("cartão nubank") ou menção genérica
    /// ("no cartão", "no crédito", "fatura"). Parcelado sem marcador de
    /// débito/dinheiro também indica cartão. Débito/pix/dinheiro = à vista.
    /// Com um único cartão ativo e menção genérica, seleciona ele;
    /// com vários, devolve `payOnCard` para o formulário pedir qual.
    static func parseCard(
        in text: String, installments: Int?, cards: [CreditCard]
    ) -> (String?, Bool) {
        guard !cards.isEmpty else { return (nil, false) }
        let folded = ReceiptParser.fold(" \(text) ")
        let active = cards.filter { $0.isActive }
        // 1) Nome citado (sem acento, nos dois sentidos).
        for card in cards {
            let name = ReceiptParser.fold(card.name)
                .trimmingCharacters(in: .whitespaces)
            guard name.count >= 3 else { continue }
            if folded.contains(name) { return (card.id, true) }
            for word in folded.split(separator: " ").map(String.init)
            where word.count >= 4 && name.contains(word) {
                return (card.id, true)
            }
        }
        let hasCredit = ["CARTAO", "CREDITO", "FATURA", "PARCELA",
                         "CARD", "CREDIT", "INVOICE", "INSTALLMENT"]
            .contains(where: folded.contains)
        let hasCash = ["DEBITO", "DINHEIRO", "ESPECIE", "BOLETO", "PIX",
                       "CASH"]
            .contains(where: folded.contains)
        if hasCash, !hasCredit { return (nil, false) }
        if hasCredit || installments != nil {
            if active.count == 1, let only = active.first {
                return (only.id, true)
            }
            return (nil, true)
        }
        return (nil, false)
    }

    // MARK: - Categoria

    /// Despesa reaproveita o mapa do cupom (`assai` → Mercado);
    /// receita procura o nome (exato ou parcial: "freela" → Freelance).
    static func suggestCategoryID(
        type: TransactionType, description: String?,
        rawText: String, categories: [FinanceCategory]
    ) -> String? {
        /// Apelidos em inglês para as categorias de receita padrão.
        let incomeAliases: [(names: [String], words: [String])] = [
            (["SALARIO"], ["SALARY", "PAYCHECK", "WAGE"]),
            (["FREELANCE"], ["FREELANCER", "GIG"]),
        ]
        if type == .receivable {
            let hay = ReceiptParser.fold(" \(rawText) \(description ?? "") ")
            let income = categories.filter { $0.type == .income }
            if let named = income.first(where: {
                !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
                    && hay.contains(ReceiptParser.fold($0.name))
            }) {
                return named.id
            }
            for alias in incomeAliases
            where alias.words.contains(where: { hay.contains($0) }) {
                if let match = income.first(where: {
                    alias.names.contains(ReceiptParser.fold($0.name))
                }) { return match.id }
            }
            for word in hay.split(separator: " ").map(String.init)
            where word.count >= 4 {
                if let match = income.first(where: {
                    ReceiptParser.fold($0.name).contains(word)
                }) { return match.id }
            }
            return income.first?.id
        }
        let scan = ReceiptScanResult(
            merchantName: description, rawText: rawText, confidence: 0)
        return ReceiptParser.suggestCategoryID(in: categories, scan: scan)
    }
}

// MARK: - Rascunho a partir do parse

public extension TransactionDraft {
    init(nl result: NLParseResult) {
        self.init(
            amount: result.amount, description: result.description,
            date: result.date, type: result.type,
            categoryID: result.categoryID,
            installmentCount: result.installmentCount,
            recurrence: result.recurrence == .unique ? nil : result.recurrence,
            interval: result.interval, creditCardID: result.creditCardID,
            payOnCard: result.payOnCard
        )
    }
}
