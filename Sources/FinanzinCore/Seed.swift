import Foundation

/// Categorias padrão do fresh install.
public enum Seed {
    public static func apply(to store: Store) {
        let defaults: [(String, CategoryType, String, String)] = [
            ("Mercado", .expense, "#10b981", "cart"),
            ("Moradia", .expense, "#6366f1", "house"),
            ("Transporte", .expense, "#f59e0b", "car"),
            ("Saúde", .expense, "#ef4444", "heart"),
            ("Lazer", .expense, "#8b5cf6", "star"),
            ("Educação", .expense, "#0ea5e9", "book"),
            ("Salário", .income, "#22c55e", "dollarsign"),
            ("Freelance", .income, "#14b8a6", "briefcase"),
        ]
        store.categories = defaults.map { name, type, color, icon in
            FinanceCategory(name: name, type: type, color: color, icon: icon)
        }
        store.save()
    }
}
