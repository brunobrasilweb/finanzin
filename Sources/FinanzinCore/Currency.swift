import Foundation

public enum Currency {
    nonisolated(unsafe) private static var cache: [String: NumberFormatter] = [:]
    private static let cacheLock = NSLock()

    /// Formatter parametrizado (Sprint 7: moeda configurável).
    /// Cacheado por (currencyCode, locale): `NumberFormatter` é caro para
    /// criar e `maskedAmount`/`AmountText` o chamam por linha no `body`.
    public static func formatter(currencyCode: String, localeIdentifier: String) -> NumberFormatter {
        let key = "\(currencyCode)|\(localeIdentifier)"
        cacheLock.lock()
        if let hit = cache[key] {
            cacheLock.unlock()
            return hit
        }
        let f = NumberFormatter()
        f.locale = Locale(identifier: localeIdentifier)
        f.numberStyle = .currency
        f.currencyCode = currencyCode
        cache[key] = f
        cacheLock.unlock()
        return f
    }

    public static func format(_ value: Decimal, currencyCode: String, localeIdentifier: String) -> String {
        formatter(currencyCode: currencyCode, localeIdentifier: localeIdentifier)
            .string(from: value as NSDecimalNumber)
            ?? "\(currencyCode) 0.00"
    }

    public static var brl: NumberFormatter {
        formatter(currencyCode: "BRL", localeIdentifier: "pt_BR")
    }

    public static func format(_ value: Decimal) -> String {
        format(value, currencyCode: "BRL", localeIdentifier: "pt_BR")
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
