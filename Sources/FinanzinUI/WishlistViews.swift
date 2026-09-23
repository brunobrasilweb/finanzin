import SwiftUI
import FinanzinCore

// MARK: - Listas de desejo

public struct WishlistListView: View {
    @EnvironmentObject var store: Store
    @State private var editing: Wishlist?
    @State private var selectedID: String?

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: FinSpacing.md) {
                ScreenHeader("Desejos")
                if store.wishlists.isEmpty {
                    EmptyStateView(
                        title: "Sem listas",
                        subtitle: "Crie listas (ex.: Viagem, Setup) e priorize seus desejos.",
                        icon: "heart.fill"
                    )
                } else {
                    List {
                        ForEach(store.wishlists.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) { list in
                            card(list)
                                .finRow()
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        store.deleteWishlist(id: list.id)
                                    } label: {
                                        Label("Excluir", systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button {
                                        editing = list
                                    } label: {
                                        Label("Editar", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .onTapGesture { selectedID = list.id }
                        }
                    }
                    .finList()
                }
            }
            .finBackground()
            .finHideNavBar()
            .sheet(item: $editing) { list in WishlistFormView(editing: list) }
            .navigationDestination(item: $selectedID) { id in
                if store.wishlists.first(where: { $0.id == id }) != nil {
                    WishlistDetailView(wishlistID: id)
                }
            }
        }
    }

    private func card(_ list: Wishlist) -> some View {
        let items = store.items(of: list.id)
        let pending = items.filter { !$0.purchased }
        return HStack(spacing: FinSpacing.md) {
            TintedIcon(list.icon, tint: VercelTheme.hex(list.color), size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(VercelTheme.textPrimary)
                Text(pending.isEmpty
                    ? "Tudo comprado 🎉"
                    : "\(pending.count) pendente(s) · \(Format.currency(store.pendingTotal(wishlistID: list.id)))")
                    .font(.caption).foregroundStyle(VercelTheme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(VercelTheme.textTertiary)
        }
    }
}

// MARK: - Form de lista

public struct WishlistFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var editing: Wishlist?

    @State private var name: String
    @State private var color: String
    @State private var icon: String
    @State private var errorMessage: String?

    public init(editing: Wishlist? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _color = State(initialValue: editing?.color ?? "#6366f1")
        _icon = State(initialValue: editing?.icon ?? "heart.fill")
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VercelTheme.bg.ignoresSafeArea()
                Form {
                    Section("Dados") {
                        TextField("Nome (ex.: Setup)", text: $name)
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
            .navigationTitle(editing == nil ? "Nova lista" : "Editar lista")
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
                edit.color = color
                edit.icon = icon
                try store.updateWishlist(edit)
            } else {
                try store.addWishlist(name: name, color: color, icon: icon)
            }
            dismiss()
        } catch {
            errorMessage = "Nome é obrigatório."
        }
    }
}

// MARK: - Detalhe da lista + itens

public struct WishlistDetailView: View {
    @EnvironmentObject var store: Store
    var wishlistID: String

    @State private var showingItemForm = false
    @State private var editingItem: WishlistItem?

    public init(wishlistID: String) { self.wishlistID = wishlistID }

    public var body: some View {
        VStack(spacing: FinSpacing.md) {
            if let list = store.wishlists.first(where: { $0.id == wishlistID }) {
                let items = store.items(of: list.id)
                if items.isEmpty {
                    EmptyStateView(title: "Lista vazia", subtitle: "Adicione o primeiro desejo.", icon: "gift")
                } else {
                    List {
                        Section { totalsCard(list).finRow() }
                        Section("Itens") {
                            ForEach(items) { item in
                                itemRow(item)
                                    .finRow()
                                    .swipeActions(edge: .leading) {
                                        if item.purchased {
                                            Button("Reabrir") { store.setPurchased(id: item.id, purchased: false) }
                                                .tint(.orange)
                                        } else {
                                            Button("Comprar") { store.setPurchased(id: item.id, purchased: true) }
                                                .tint(.green)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            store.deleteItem(id: item.id)
                                        } label: {
                                            Label("Excluir", systemImage: "trash")
                                        }
                                        .tint(.red)
                                        Button {
                                            editingItem = item
                                        } label: {
                                            Label("Editar", systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .onTapGesture { editingItem = item }
                            }
                        }
                    }
                    .finList()
                }
            } else {
                EmptyStateView(title: "Lista removida", subtitle: "Volte para as listas.", icon: "heart.fill")
            }
        }
        .finBackground()
        .finDetailChrome()
        .navigationTitle(store.wishlists.first(where: { $0.id == wishlistID })?.name ?? "Desejos")
        .toolbar {
            Button { showingItemForm = true } label: { Image(systemName: "plus") }
        }
        .sheet(isPresented: $showingItemForm) {
            WishlistItemFormView(wishlistID: wishlistID)
        }
        .sheet(item: $editingItem) { item in
            WishlistItemFormView(wishlistID: item.wishlistID, editing: item)
        }
    }

    private func totalsCard(_ list: Wishlist) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("Falta juntar").font(.caption).foregroundStyle(VercelTheme.textSecondary)
                Text(Format.currency(store.pendingTotal(wishlistID: list.id)))
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text("Comprados").font(.caption).foregroundStyle(VercelTheme.textSecondary)
                let done = store.items(of: list.id).filter(\.purchased).count
                let total = store.items(of: list.id).count
                Text("\(done)/\(total)")
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            }
        }
    }

    private func itemRow(_ item: WishlistItem) -> some View {
        HStack(spacing: FinSpacing.md) {
            Image(systemName: item.purchased ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(item.purchased ? .green : VercelTheme.textTertiary)
                .onTapGesture { store.setPurchased(id: item.id, purchased: !item.purchased) }
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(VercelTheme.textPrimary)
                    .strikethrough(item.purchased)
                HStack(spacing: 6) {
                    StatusPill(item.priority.label, color: priorityColor(item.priority))
                    if let cat = store.category(id: item.categoryID) {
                        Text(cat.name).font(.caption).foregroundStyle(VercelTheme.textSecondary)
                    }
                }
            }
            Spacer()
            Text(Format.currency(item.estimatedPrice))
                .font(.subheadline.bold())
                .monospacedDigit()
                .foregroundStyle(VercelTheme.textPrimary)
        }
        .opacity(item.purchased ? 0.55 : 1)
    }

    private func priorityColor(_ p: WishlistPriority) -> Color {
        p == .high ? .red : p == .medium ? .orange : .gray
    }
}

// MARK: - Form de item + gerar pagar

public struct WishlistItemFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var wishlistID: String
    var editing: WishlistItem?

    @State private var name: String
    @State private var price: Decimal
    @State private var priority: WishlistPriority
    @State private var categoryID: String?
    @State private var notes: String
    @State private var errorMessage: String?
    @State private var generatedMessage: String?

    public init(wishlistID: String, editing: WishlistItem? = nil) {
        self.wishlistID = wishlistID
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _price = State(initialValue: editing?.estimatedPrice ?? 0)
        _priority = State(initialValue: editing?.priority ?? .medium)
        _categoryID = State(initialValue: editing?.categoryID)
        _notes = State(initialValue: editing?.notes ?? "")
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                VercelTheme.bg.ignoresSafeArea()
                Form {
                    Section("Desejo") {
                        TextField("Nome", text: $name)
                        CurrencyField(value: $price)
                        Picker("Prioridade", selection: $priority) {
                            Text("Baixa").tag(WishlistPriority.low)
                            Text("Média").tag(WishlistPriority.medium)
                            Text("Alta").tag(WishlistPriority.high)
                        }
                        Picker("Categoria", selection: $categoryID) {
                            Text("Sem categoria").tag(nil as String?)
                            ForEach(store.categories.filter { $0.type == .expense }) { cat in
                                Text(cat.name).tag(cat.id as String?)
                            }
                        }
                        TextField("Observações", text: $notes)
                    }
                    if editing != nil {
                        Section("Compra") {
                            Button("Gerar conta a pagar") { generate() }
                            if let generatedMessage {
                                Text(generatedMessage).font(.footnote).foregroundStyle(.green)
                            } else {
                                Text("Cria um “a pagar” único com nome, preço e categoria do item.")
                                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                            }
                        }
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(editing == nil ? "Novo desejo" : "Editar desejo")
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
                edit.estimatedPrice = price
                edit.priority = priority
                edit.categoryID = categoryID
                edit.notes = notes.isEmpty ? nil : notes
                try store.updateItem(edit)
            } else {
                try store.addItem(
                    wishlistID: wishlistID, name: name, price: price,
                    priority: priority, categoryID: categoryID, notes: notes
                )
            }
            dismiss()
        } catch Store.WishlistError.emptyName {
            errorMessage = "Nome é obrigatório."
        } catch Store.WishlistError.invalidPrice {
            errorMessage = "Preço deve ser maior que zero."
        } catch {
            errorMessage = "Não foi possível salvar."
        }
    }

    private func generate() {
        guard let edit = editing else { return }
        // Salva alterações pendentes do item antes de gerar, sem fechar.
        var copy = edit
        copy.name = name
        copy.estimatedPrice = price
        copy.priority = priority
        copy.categoryID = categoryID
        copy.notes = notes.isEmpty ? nil : notes
        do {
            try store.updateItem(copy)
            _ = try store.generatePayable(itemID: copy.id)
            generatedMessage = "Conta a pagar criada em Transações ✅"
        } catch {
            errorMessage = "Não foi possível gerar a conta."
        }
    }
}
