import Foundation

public enum Currency {
    public static var brl: NumberFormatter {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.numberStyle = .currency
        f.currencyCode = "BRL"
        return f
    }

    public static func format(_ value: Decimal) -> String {
        brl.string(from: value as NSDecimalNumber) ?? "R$ 0,00"
    }

    /// Divide valor em N parcelas com ajuste de centavos na última.
    /// Portado de `transaction.service.ts` (perAmount + diff na última).
    public static func split(_ total: Decimal, into count: Int) -> [Decimal] {
        guard count > 0 else { return [] }
        guard count > 1 else { return [total] }
        let totalCents = Int(((total * 100) as NSDecimalNumber).doubleValue.rounded())
        let base = totalCents / count
        var out = Array(repeating: Decimal(base) / 100, count: count)
        let sumBase = base * count
        let diff = totalCents - sumBase
        if diff != 0 {
            out[count - 1] = Decimal(base + diff) / 100
        }
        return out
    }
}
