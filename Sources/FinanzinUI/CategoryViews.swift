import SwiftUI
import FinanzinCore

public enum CategoryPalettes {
    public static let colors = [
        "#ef4444", "#f97316", "#f59e0b", "#eab308", "#84cc16",
        "#22c55e", "#10b981", "#14b8a6", "#06b6d4", "#0ea5e9",
        "#3b82f6", "#6366f1", "#8b5cf6", "#a855f7", "#d946ef",
        "#ec4899", "#f43f5e", "#78716c", "#64748b", "#6b7280",
        "#16a34a", "#0d9488", "#4f46e5", "#c026d3",
    ]
    public static let icons = [
        "tag.fill", "cart.fill", "basket.fill", "bag.fill", "fork.knife",
        "cup.and.saucer.fill", "house.fill", "bed.double.fill", "car.fill", "fuelpump.fill",
        "airplane", "tram.fill", "bicycle", "heart.fill", "star.fill",
        "gift.fill", "book.fill", "briefcase.fill", "graduationcap.fill", "cross.case.fill",
        "pill.fill", "dumbbell.fill", "gamecontroller.fill", "film.fill", "tv.fill",
        "music.note", "camera.fill", "phone.fill", "wifi", "bolt.fill",
        "drop.fill", "flame.fill", "banknote.fill", "creditcard.fill", "wallet.pass.fill",
        "piggy.bank.fill", "chart.bar.fill", "chart.pie.fill", "bag.circle.fill", "shirt.fill",
        "pawprint.fill", "leaf.fill", "wrench.fill", "paintbrush.fill", "headphones",
        "laptopcomputer", "sportscourt.fill", "dollarsign.circle.fill",
    ]
}

public struct CategoryListView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    @State private var showingForm = false
    @State private var editing: FinanceCategory?
    @State private var filter: CategoryType?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: FinSpacing.md) {
                ScreenHeader("Categorias") {
                    HeaderButton("xmark") { dismiss() }
                    HeaderButton("plus") { showingForm = true }
                }
                Picker("Tipo", selection: $filter) {
                    Text("Todas").tag(nil as CategoryType?)
                    Text("Despesas").tag(CategoryType.expense as CategoryType?)
                    Text("Receitas").tag(CategoryType.income as CategoryType?)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, FinSpacing.lg)

                if filtered.isEmpty {
                    EmptyStateView(
                        title: "Sem categorias",
                        subtitle: "Toque em + para criar a primeira.",
                        icon: "tag"
                    )
                } else {
                    List {
                        ForEach(filtered) { cat in
                            HStack(spacing: FinSpacing.md) {
                                TintedIcon(cat.icon, tint: VercelTheme.hex(cat.color))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.name)
                                        .font(.subheadline.bold())
                                        .foregroundStyle(VercelTheme.textPrimary)
                                    Text(cat.type.label)
                                        .font(.caption)
                                        .foregroundStyle(VercelTheme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.bold())
                                    .foregroundStyle(VercelTheme.textTertiary)
                            }
                            .finRow()
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    store.deleteCategory(id: cat.id)
                                } label: {
                                    Label("Excluir", systemImage: "trash")
                                }
                                .tint(.red)
                                Button {
                                    editing = cat
                                } label: {
                                    Label("Editar", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                    .finList()
                }
            }
            .finBackground()
            .finHideNavBar()
            .sheet(isPresented: $showingForm) {
                CategoryFormView { _ in }
            }
            .sheet(item: $editing) { cat in
                CategoryFormView(editing: cat) { _ in }
            }
        }
    }

    private var filtered: [FinanceCategory] {
        store.categories
            .filter { filter == nil || $0.type == filter }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }
}

public struct CategoryFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var editing: FinanceCategory?
    var onSaved: (FinanceCategory) -> Void

    @State private var name: String
    @State private var type: CategoryType
    @State private var color: String
    @State private var icon: String
    @State private var errorMessage: String?

    public init(editing: FinanceCategory? = nil, onSaved: @escaping (FinanceCategory) -> Void) {
        self.editing = editing
        self.onSaved = onSaved
        _name = State(initialValue: editing?.name ?? "")
        _type = State(initialValue: editing?.type ?? .expense)
        _color = State(initialValue: editing?.color ?? "#6366f1")
        _icon = State(initialValue: editing?.icon ?? "tag.fill")
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VercelTheme.bg.ignoresSafeArea()
                Form {
                    Section("Dados") {
                        TextField("Nome", text: $name)
                        Picker("Tipo", selection: $type) {
                            Text("Despesa").tag(CategoryType.expense)
                            Text("Receita").tag(CategoryType.income)
                        }
                    }
                    Section("Cor (\(CategoryPalettes.colors.count) cores)") {
                        ColorOptionsGrid(selection: $color)
                    }
                    Section("Ícone (\(CategoryPalettes.icons.count) ícones)") {
                        IconOptionsGrid(selection: $icon, tintHex: color)
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(editing == nil ? "Nova categoria" : "Editar categoria")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fechar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salvar") { save() }
                }
            }
        }
    }

    private func save() {
        do {
            if var edit = editing {
                edit.name = name
                edit.type = type
                edit.color = color
                edit.icon = icon
                try store.updateCategory(edit)
                onSaved(edit)
            } else {
                let cat = try store.addCategory(name: name, type: type, color: color, icon: icon)
                onSaved(cat)
            }
            dismiss()
        } catch Store.CategoryError.emptyName {
            errorMessage = "Nome é obrigatório."
        } catch Store.CategoryError.duplicateName {
            errorMessage = "Já existe uma categoria com esse nome para este tipo."
        } catch {
            errorMessage = "Não foi possível salvar."
        }
    }
}

// MARK: - Seletores reutilizáveis (categorias, listas, fundos)

public struct ColorOptionsGrid: View {
    @Binding var selection: String

    public init(selection: Binding<String>) {
        _selection = selection
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
            ForEach(CategoryPalettes.colors, id: \.self) { hex in
                let isSelected = selection == hex
                ZStack {
                    Circle()
                        .fill(VercelTheme.hex(hex))
                        .frame(width: 36, height: 36)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 2.5 : 0)
                        .frame(width: 42, height: 42)
                )
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .onTapGesture { selection = hex }
                .accessibilityLabel(hex)
            }
        }
        .padding(.vertical, 4)
    }
}

public struct IconOptionsGrid: View {
    @Binding var selection: String
    var tintHex: String?

    public init(selection: Binding<String>, tintHex: String? = nil) {
        _selection = selection
        self.tintHex = tintHex
    }

    public var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 8) {
            ForEach(CategoryPalettes.icons, id: \.self) { name in
                let isSelected = selection == name
                Image(systemName: name)
                    .font(.system(size: 17, weight: isSelected ? .bold : .regular))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(isSelected ? .white : VercelTheme.textSecondary)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected
                                ? (tintHex.map(VercelTheme.hex) ?? Color.white.opacity(0.25))
                                : Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(isSelected ? Color.white.opacity(0.6) : VercelTheme.border, lineWidth: 1)
                            )
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selection = name }
            }
        }
        .padding(.vertical, 4)
    }
}
