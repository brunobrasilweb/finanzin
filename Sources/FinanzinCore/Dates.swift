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

    public static func monthLabel(year: Int, month: Int, localeIdentifier: String) -> String {
        let date = startOfMonth(year: year, month: month)
        let f = DateFormatter()
        f.locale = Locale(identifier: localeIdentifier)
        f.dateFormat = "MMM/yy"
        return f.string(from: date)
    }

    public static func shiftMonth(year: Int, month: Int, by offset: Int) -> (year: Int, month: Int) {
        let base = startOfMonth(year: year, month: month)
        let shifted = calendar.date(byAdding: .month, value: offset, to: base) ?? base
        return competence(of: shifted)
    }
}
