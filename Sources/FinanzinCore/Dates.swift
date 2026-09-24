import Foundation

public enum Dates {
    public static var calendar: Calendar { Calendar.current }

    public static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    public static func startOfMonth(year: Int, month: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    public static func endOfMonth(year: Int, month: Int) -> Date {
        let start = startOfMonth(year: year, month: month)
        let next = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return calendar.date(byAdding: .day, value: -1, to: next) ?? start
    }

    public static func competence(of date: Date) -> (year: Int, month: Int) {
        let c = calendar.dateComponents([.year, .month], from: date)
        return (c.year ?? 2000, c.month ?? 1)
    }

    public static func isInMonth(_ date: Date, year: Int, month: Int) -> Bool {
        let comp = competence(of: date)
        return comp.year == year && comp.month == month
    }

    public static func addPeriod(_ date: Date, interval: InstallmentInterval, steps: Int = 1) -> Date {
        switch interval {
        case .weekly:
            return calendar.date(byAdding: .day, value: 7 * steps, to: date) ?? date
        case .biweekly:
            return calendar.date(byAdding: .day, value: 15 * steps, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: steps, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: steps, to: date) ?? date
        }
    }

    /// Gera vencimentos de parcelas. Equivalente a `generateInstallmentDates` do Inofinancy.
    public static func installmentDates(from base: Date, count: Int, interval: InstallmentInterval) -> [Date] {
        guard count > 0 else { return [] }
        var out: [Date] = [base]
        for _ in 1 ..< count {
            out.append(addPeriod(out.last ?? base, interval: interval))
        }
        return out
    }

    public static func monthLabel(year: Int, month: Int) -> String {
        monthLabel(year: year, month: month, localeIdentifier: "pt_BR")
    }

    nonisolated(unsafe) private static var labelCache: [String: DateFormatter] = [:]
    private static let labelLock = NSLock()

    /// `DateFormatter` é caro: um por (locale, formato), reutilizado.
    public static func monthLabel(year: Int, month: Int, localeIdentifier: String) -> String {
        let date = startOfMonth(year: year, month: month)
        let key = "MMM/yy|\(localeIdentifier)"
        labelLock.lock()
        let f: DateFormatter
        if let hit = labelCache[key] {
            f = hit
        } else {
            let fresh = DateFormatter()
            fresh.locale = Locale(identifier: localeIdentifier)
            fresh.dateFormat = "MMM/yy"
            labelCache[key] = fresh
            f = fresh
        }
        labelLock.unlock()
        return f.string(from: date)
    }

    /// Nome do mês (ex.: "Janeiro"), cacheado por locale.
    public static func monthName(_ month: Int, localeIdentifier: String) -> String {
        let key = "MMMM|\(localeIdentifier)"
        labelLock.lock()
        let f: DateFormatter
        if let hit = labelCache[key] {
            f = hit
        } else {
            let fresh = DateFormatter()
            fresh.locale = Locale(identifier: localeIdentifier)
            fresh.dateFormat = "MMMM"
            labelCache[key] = fresh
            f = fresh
        }
        labelLock.unlock()
        guard (1 ... 12).contains(month) else { return "" }
        return f.string(from: startOfMonth(year: 2000, month: month)).capitalized
    }

    /// Data curta `dd/MM/yy`, cacheada por locale.
    public static func shortDate(_ date: Date, localeIdentifier: String) -> String {
        let key = "dd/MM/yy|\(localeIdentifier)"
        labelLock.lock()
        let f: DateFormatter
        if let hit = labelCache[key] {
            f = hit
        } else {
            let fresh = DateFormatter()
            fresh.locale = Locale(identifier: localeIdentifier)
            fresh.dateFormat = "dd/MM/yy"
            labelCache[key] = fresh
            f = fresh
        }
        labelLock.unlock()
        return f.string(from: date)
    }

    /// Data curta `dd/MM`, cacheada por locale (linhas de transação).
    public static func shortDayMonth(_ date: Date, localeIdentifier: String) -> String {
        let key = "dd/MM|\(localeIdentifier)"
        labelLock.lock()
        let f: DateFormatter
        if let hit = labelCache[key] {
            f = hit
        } else {
            let fresh = DateFormatter()
            fresh.locale = Locale(identifier: localeIdentifier)
            fresh.dateFormat = "dd/MM"
            labelCache[key] = fresh
            f = fresh
        }
        labelLock.unlock()
        return f.string(from: date)
    }

    /// Carimbo p/ nome de arquivo (`yyyy-MM-dd-HHmmss`), cacheado.
    public static func shortFileStamp(_ date: Date = Date()) -> String {
        let key = "fileStamp"
        labelLock.lock()
        let f: DateFormatter
        if let hit = labelCache[key] {
            f = hit
        } else {
            let fresh = DateFormatter()
            fresh.dateFormat = "yyyy-MM-dd-HHmmss"
            labelCache[key] = fresh
            f = fresh
        }
        labelLock.unlock()
        return f.string(from: date)
    }

    public static func shiftMonth(year: Int, month: Int, by offset: Int) -> (year: Int, month: Int) {
        let base = startOfMonth(year: year, month: month)
        let shifted = calendar.date(byAdding: .month, value: offset, to: base) ?? base
        return competence(of: shifted)
    }
}
