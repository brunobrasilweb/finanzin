import Foundation

// MARK: - Leitura de recibo (OCR → rascunho de transação)
//
// O OCR em si (Vision, on-device) vive em `FinanzinUI/ReceiptScanner.swift`.
// Aqui fica só a interpretação das linhas reconhecidas: regras puras,
// sem Vision/UIKit, testáveis no `FinanzinCoreTests` (CLT).
//
// Campos extraídos de cupons/notas BR:
// - `amount`: prioriza linhas com TOTAL/VALOR (ignora TROCO/DESCONTO);
//   sem linha de total, usa o maior valor — nunca falha silencioso,
//   `confidence` indica o quanto confiar.
// - `merchantName`: primeira linha "nome de loja" (ignora cabeçalhos
//   fiscais como CNPJ/CUPOM FISCAL/DANFE).
// - `date`: primeiro `dd/MM/yyyy` (com hora opcional) válido.

public struct ReceiptScanResult: Hashable, Sendable {
    public var amount: Decimal?
    public var merchantName: String?
    public var date: Date?
    /// Texto cru do OCR (vai para `notes` quando útil depurar).
    public var rawText: String
    /// 0...1: 0,5 valor + 0,25 estabelecimento + 0,25 data.
    public var confidence: Double

    public init(
        amount: Decimal? = nil, merchantName: String? = nil,
        date: Date? = nil, rawText: String = "", confidence: Double = 0
    ) {
        self.amount = amount
        self.merchantName = merchantName
        self.date = date
        self.rawText = rawText
        self.confidence = confidence
    }
}

public enum ReceiptParser {
    // MARK: - Normalização

    /// Maiúsculas sem acento para comparar chaves e nomes
    /// ("saúde" == "SAUDE", "assai" == "ASSAÍ").
    public static func fold(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: Locale(identifier: "pt_BR"))
            .uppercased()
    }

    // MARK: - Entrada principal

    /// Interpreta as linhas do OCR (ordem de leitura, topo → base).
    public static func parse(lines: [String]) -> ReceiptScanResult {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let rawText = cleaned.joined(separator: "\n")
        let amount = parseAmount(lines: cleaned)
        let merchant = parseMerchant(lines: cleaned)
        let date = parseDate(lines: cleaned)
        var confidence = 0.0
        if amount != nil { confidence += 0.5 }
        if merchant != nil { confidence += 0.25 }
        if date != nil { confidence += 0.25 }
        return ReceiptScanResult(
            amount: amount, merchantName: merchant,
            date: date, rawText: rawText, confidence: confidence
        )
    }

    // MARK: - Valor

    /// Palavras que indicam a linha do total a pagar.
    private static let totalKeywords = [
        "TOTAL", "VALOR TOTAL", "VALOR A PAGAR", "TOTAL A PAGAR",
        "VALOR PAGO", "TOTAL GERAL", "VALOR DA COMPRA", "A PAGAR",
    ]

    /// Linhas que contêm valores mas NÃO são o total (troco, desconto,
    /// documentos) — ignoradas na busca do valor.
    private static let ignoredLineKeywords = [
        "TROCO", "DESCONTO", "CNPJ", "CPF", "INSC",
    ]

    /// Extrai o valor: prioriza linhas de TOTAL, senão o maior valor.
    /// Aceita `R$ 1.234,56`, `128,90` e `250.00`.
    public static func parseAmount(lines: [String]) -> Decimal? {
        var totalLineValues: [Decimal] = []
        var otherValues: [Decimal] = []
        for line in lines {
            let upper = line.uppercased()
            if ignoredLineKeywords.contains(where: { upper.contains($0) }) { continue }
            let values = extractMoneyValues(from: line)
            guard !values.isEmpty else { continue }
            if totalKeywords.contains(where: { upper.contains($0) }) {
                totalLineValues.append(contentsOf: values)
            } else {
                otherValues.append(contentsOf: values)
            }
        }
        let pool = totalLineValues.isEmpty ? otherValues : totalLineValues
        return pool.max(by: { ($0 as NSDecimalNumber).doubleValue < ($1 as NSDecimalNumber).doubleValue })
    }

    /// Todos os valores monetários de uma linha (ignora datas/horas).
    static func extractMoneyValues(from line: String) -> [Decimal] {
        // `1.234,56` | `128,90` | `250.00` | `R$ 12,90`
        let pattern = #"\d[\d.\s]*,\d{2}|\d+\.\d{2}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(line.startIndex..., in: line)
        return regex.matches(in: line, range: range).compactMap { m in
            guard let r = Range(m.range, in: line) else { return nil }
            let token = String(line[r])
            // Evita confundir data/hora (`23/09/2026`, `14:32`) com valor.
            if token.contains("/") || token.contains(":") { return nil }
            return normalizeAmount(token)
        }
    }

    /// Normaliza `1.234,56` → 1234.56, `12,90` → 12.90, `250.00` → 250.00.
    /// Mesma regra de `TransactionDraft.parseAmount`, mais prefixo `R$`.
    public static func normalizeAmount(_ raw: String) -> Decimal? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        s = s.replacingOccurrences(of: "R$", with: "")
            .replacingOccurrences(of: " ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if s.contains(",") {
            let noThousands = s.replacingOccurrences(of: ".", with: "")
            return Decimal(string: noThousands.replacingOccurrences(of: ",", with: "."))
        }
        return Decimal(string: s)
    }

    // MARK: - Data

    /// Primeira data `dd/MM/yyyy` (ano 2 ou 4 dígitos, hora opcional).
    public static func parseDate(lines: [String]) -> Date? {
        let pattern = #"(\d{2})[/\-.](\d{2})[/\-.](\d{2,4})(?:\s+(\d{2}):(\d{2}))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let cal = Calendar.current
        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            guard let m = regex.firstMatch(in: line, range: range) else { continue }
            func group(_ i: Int) -> String? {
                guard m.range(at: i).location != NSNotFound,
                      let r = Range(m.range(at: i), in: line)
                else { return nil }
                return String(line[r])
            }
            guard let dd = group(1).flatMap(Int.init),
                  let mm = group(2).flatMap(Int.init),
                  var yy = group(3).flatMap(Int.init),
                  (1...31).contains(dd), (1...12).contains(mm)
            else { continue }
            if yy < 100 { yy += 2000 }
            guard (2000...2100).contains(yy) else { continue }
            var comps = DateComponents(year: yy, month: mm, day: dd)
            comps.hour = group(4).flatMap(Int.init) ?? 12
            comps.minute = group(5).flatMap(Int.init) ?? 0
            if let date = cal.date(from: comps) { return date }
        }
        return nil
    }

    // MARK: - Estabelecimento

    /// Cabeçalhos fiscais que nunca são nome de loja.
    private static let headerKeywords = [
        "CUPOM", "NOTA FISCAL", "NOTA", "DANFE", "NFC", "NFE", "SAT",
        "CNPJ", "CPF", "INSCRICAO", "INSCRIÇÃO", "EXTRATO",
        "COMPROVANTE", "RECIBO", "PEDIDO", "ORCAMENTO", "ORÇAMENTO",
        "DOCUMENTO", "AUXILIAR", "VENDA", "CAIXA", "OPERADOR",
        "LOJA", "FILIAL", "UNIDADE", "ENDERECO", "ENDEREÇO",
        "TELEFONE", "FONE", "CEP", "CIDADE", " ESTADO",
    ]

    /// Nome da loja: primeira linha com letras que não seja cabeçalho
    /// fiscal, endereço ou só números. Corta sufixos (`- CNPJ ...`).
    public static func parseMerchant(lines: [String]) -> String? {
        for line in lines.prefix(6) {
            var candidate = line
            // Corta sufixos comuns de cabeçalho na mesma linha.
            for sep in [" - CNPJ", " CNPJ", "  CNPJ", " | "] {
                if let r = candidate.uppercased().range(of: sep) {
                    candidate = String(candidate[..<r.lowerBound])
                }
            }
            candidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: .init(charactersIn: "-–—* "))
            let upper = candidate.uppercased()
            guard candidate.count >= 3 else { continue }
            guard candidate.rangeOfCharacter(from: .letters) != nil else { continue }
            // Pula linhas que são só números/documentos/endereço.
            let letters = candidate.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
            guard letters >= 3 else { continue }
            if headerKeywords.contains(where: { upper.contains($0) }) { continue }
            if candidate.allSatisfy({ $0.isNumber || " .,-/".contains($0) }) { continue }
            return String(candidate.prefix(40))
        }
        return nil
    }

    // MARK: - Sugestão de categoria

    /// Palavra do recibo → nome da categoria padrão (`Seed`).
    /// Listas separadas por categoria (literal pequeno cada) para o
    /// type-checker não precisar inferir a tabela inteira de uma vez.
    private static let mercadoWords: [String] = [
        "SUPERMERCADO", "MERCADO", "ATACADAO", "ATACADÃO", "ASSAI",
        "CARREFOUR", "PAO DE ACUCAR", "PÃO DE AÇÚCAR", "EXTRA",
        "HIPERMERCADO", "MERCEARIA", "PADARIA", "PANIFICADORA",
        "ACOUGUE", "AÇOUGUE", "HORTIFRUTI", "SACOLAO", "SACOLÃO",
        "FEIRA", "VAREJAO", "VAREJÃO", "EMPORIO", "EMPÓRIO",
        "MARKET", "GROCERY", "SUPERMARKET", "BAKERY", "BUTCHER",
        "GREENGROCER", "DELI",
    ]
    private static let moradiaWords: [String] = [
        "ALUGUEL", "IMOBILIARIA", "IMOBILIÁRIA", "CONDOMINIO",
        "CONDOMÍNIO", "ENEL", "ELETROPAULO", "SABESP", "COPEL",
        "ENERGIA ELETRICA", "ENERGIA ELÉTRICA", "INTERNET",
        " CLARO", " VIVO", " TIM ", "NET ",
        "LUZ", "AGUA", "ÁGUA", "ESGOTO", "GAS", "GÁS",
        "BOTIJAO", "BOTIJÃO", "IPTU", "LAVANDERIA", "DIARISTA",
        "FAXINA", "ELETRICISTA", "ENCANADOR", "PEDREIRO", "REFORMA",
        "RENT", "HOME", "HOUSE", "APARTMENT", "UTILITY", "UTILITIES",
        "ELECTRICITY", "ELECTRIC", "WATER", "PHONE", "MORTGAGE",
        "CONDO",
    ]
    private static let transporteWords: [String] = [
        "POSTO", "COMBUSTIVEL", "COMBUSTÍVEL", "GASOLINA", "ETANOL",
        "ALCOOL", "ÁLCOOL", "DIESEL", "SHELL", "IPIRANGA",
        "PETROBRAS", "UBER", " 99 ", "TAXI", "TÁXI", "CABIFY",
        "ESTACIONAMENTO", "PEDAGIO", "PEDÁGIO", "OFICINA",
        "MECANICA", "MECÂNICA", "PNEU", "ONIBUS", "ÔNIBUS",
        "METRO", "METRÔ", "TREM", "GNV", "LAVAGEM", "LAVA JATO",
        "OLEO", "ÓLEO", "REVISAO", "REVISÃO", "MULTA", "DETRAN",
        "IPVA", "LICENCIAMENTO", "CNH", "MOTO",
        "FUEL", "TRANSIT", "SUBWAY", "BUS", "TRAIN", "PARKING",
        "TOLL", "LYFT", "CAR WASH", "OIL CHANGE", "DMV",
    ]
    private static let saudeWords: [String] = [
        "FARMACIA", "FARMÁCIA", "DROGARIA", "DROGASIL",
        "PAGUE MENOS", "HOSPITAL", "CLINICA", "CLÍNICA", "ODONTO",
        "LABORATORIO", "LABORATÓRIO", "PLANO DE SAUDE",
        "PLANO DE SAÚDE", "MEDICO", "MÉDICO", "DENTISTA",
        "EXAME", "CONSULTA", "REMEDIO", "REMÉDIO", "ACADEMIA",
        "CROSSFIT", "NATACAO", "NATAÇÃO", "PILATES", "MUSCULACAO",
        "MUSCULAÇÃO", "YOGA", "SALAO", "SALÃO", "BARBEARIA",
        "CABELO", "CABELEIREIRO", "MANICURE", "PEDICURE",
        "ESTETICA", "ESTÉTICA", "MASSAGEM", "FISIOTERAPIA",
        "PSICOLOGO", "PSICÓLOGO", "TERAPIA", "OCULOS", "ÓCULOS",
        "OTICA", "ÓTICA",
        "PHARMACY", "DRUGSTORE", "DOCTOR", "CLINIC", "DENTIST",
        "GYM", "FITNESS", "THERAPY",
    ]
    private static let lazerWords: [String] = [
        "RESTAURANTE", "LANCHONETE", " BAR ", "PIZZARIA",
        "HAMBURGUERIA", "CAFETERIA", "CAFE", "CAFÉ", "CINEMA",
        "TEATRO", "SHOW", "PARQUE", "HOTEL", "POUSADA", "VIAGEM",
        "AEREA", "AÉREA", " GOL ", "LATAM", " AZUL ",
        "IFOOD", "RAPPI", "DELIVERY", "LANCHE", "PIZZA",
        "HAMBURGUER", "SUSHI", "ACAI", "AÇAÍ", "SORVETE",
        "CHURRASCO", "MARMITA", "CERVEJA", "CHOPP", "ADEGA",
        "BALADA", "SHOPPING", "NETFLIX", "SPOTIFY", "DISNEY",
        "PRIME VIDEO", "HBO", "YOUTUBE", "DEEZER", "STREAMING",
        "JOGO", "GAME", "STEAM", "PLAYSTATION", "XBOX", "NINTENDO",
        "PRESENTE", "ROUPA", "CALCADO", "CALÇADO", "SAPATO",
        "VESTUARIO", "VESTUÁRIO", "FESTA", "ANIVERSARIO",
        "ANIVERSÁRIO", "MUSEU", "PASSAGEM", "AIRBNB",
        "RESTAURANT", "FOOD", "FAST FOOD", "DINER", "PUB",
        "MOVIE", "THEATER", "CONCERT", "TRAVEL", "TRIP", "FLIGHT",
        "HOSTEL", "COFFEE", "ICE CREAM", "BURGER", "CLOTHES",
        "SHOES", "GIFT",
    ]
    private static let educacaoWords: [String] = [
        "ESCOLA", "CURSO", "FACULDADE", "UNIVERSIDADE",
        "LIVRARIA", "PAPELARIA", "AULA", "CRECHE", "MENSALIDADE",
        "VESTIBULAR", "CONCURSO",
        "SCHOOL", "COURSE", "COLLEGE", "UNIVERSITY", "BOOKSTORE",
        "CLASS", "TUITION", "LESSON",
    ]
    private static let categoryKeywords: [(name: String, words: [String])] = [
        ("Mercado", mercadoWords),
        ("Moradia", moradiaWords),
        ("Transporte", transporteWords),
        ("Saúde", saudeWords),
        ("Lazer", lazerWords),
        ("Educação", educacaoWords),
    ]

    /// Sugere o `id` da categoria: match por palavra-chave no texto
    /// (cupom ou prompt de voz), senão pelo nome da categoria de despesa.
    /// Comparação sem acento; chaves curtas (GAS, BAR, 99) exigem fronteira
    /// de palavra para não capturar "GASTEI"/"BARBEARIA".
    /// Só sugere despesa (recibo = conta a pagar).
    public static func suggestCategoryID(
        in categories: [FinanceCategory], scan: ReceiptScanResult
    ) -> String? {
        let haystack = fold(" \(scan.rawText) \(scan.merchantName ?? "") ")
        let expenses = categories.filter { $0.type == .expense }
        for entry in categoryKeywords {
            let hit = entry.words.contains { keyword in
                let fkw = fold(keyword).trimmingCharacters(in: .whitespaces)
                guard !fkw.isEmpty else { return false }
                // Curta: fronteira de palavra. Longa: substring (pega
                // "SUPERMERCADO" via "MERCADO").
                return fkw.count <= 3
                    ? haystack.contains(" \(fkw) ")
                    : haystack.contains(fkw)
            }
            if hit, let match = expenses.first(where: {
                fold($0.name) == fold(entry.name)
            }) {
                return match.id
            }
        }
        // Fallback 1: nome da categoria citado (ex. "Mercado Dia").
        for cat in expenses where !cat.name.trimmingCharacters(in: .whitespaces).isEmpty {
            if haystack.contains(fold(cat.name)) { return cat.id }
        }
        // Fallback 2: palavra do texto contida no nome (cobre categorias
        // custom: "mercado" casa com "Supermercado Dia").
        for word in haystack.split(separator: " ").map(String.init)
        where word.count >= 4 {
            if let match = expenses.first(where: {
                fold($0.name).contains(word)
            }) { return match.id }
        }
        return nil
    }
}

// MARK: - Rascunho a partir do scan

public extension TransactionDraft {
    /// Converte o resultado do OCR em rascunho do formulário
    /// (valor/descrição/data); categoria o form resolve via
    /// `ReceiptParser.suggestCategoryID` com as categorias do Store.
    init(scan: ReceiptScanResult) {
        self.init(amount: scan.amount, description: scan.merchantName, date: scan.date ?? Date())
    }
}
