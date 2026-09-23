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
                ScreenHeader(store.t(.wishlist)) {
                    PrivacyEyeButton()
                }
                if store.wishlists.isEmpty {
                    EmptyStateView(
                        title: store.t(.wishEmptyTitle),
                        subtitle: store.t(.wishEmptySubtitle),
                        icon: "heart.fill"
                    )
                } else {
                    List {
                        ForEach(store.wishlists.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) { list in
                            card(list)
                                .finCleanRow()
                                .padding(.vertical, 2)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        store.deleteWishlist(id: list.id)
                                    } label: {
                                        Label(store.t(.delete), systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button {
                                        editing = list
                                    } label: {
                                        Label(store.t(.edit), systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .onTapGesture { selectedID = list.id }
                        }
                    }
                    .finCleanList()
                }
            }
            .finBackground()
            .finHideNavBar()
            .sheet(item: $editing) { list in WishlistFormView(editing: list)
                .environmentObject(store)
            }
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
                    ? store.t(.wishAllBought)
                    : String(
                        format: store.t(.wishPendingSummary),
                        pending.count, store.maskedAmount(store.pendingTotal(wishlistID: list.id))
                    ))
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
    @FocusState private var nameFocused: Bool

    public init(editing: Wishlist? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _color = State(initialValue: editing?.color ?? "#6366f1")
        _icon = State(initialValue: editing?.icon ?? "heart.fill")
    }

    public var body: some View {
        NavigationStack {
            Form {
                    Section(store.t(.dataSection)) {
                        TextField(store.t(.wishNamePh), text: $name)
                            .focused($nameFocused)
                            .submitLabel(.done)
                            .onSubmit { nameFocused = false }
                    }
                    Section(String(format: store.t(.colorsCount), CategoryPalettes.colors.count)) {
                        ColorOptionsGrid(selection: $color)
                    }
                    Section(String(format: store.t(.iconsCount), CategoryPalettes.icons.count)) {
                        IconOptionsGrid(selection: $icon, tintHex: color)
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(VercelTheme.card)
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
            .navigationTitle(editing == nil ? store.t(.wishNewList) : store.t(.wishEditList))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(.close)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(.save)) { save() }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t(.ok)) {
                        nameFocused = false
                        KeyboardDismisser.dismiss()
                    }
                }
                #endif
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
            errorMessage = store.t(.nameRequired)
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
                    EmptyStateView(title: store.t(.wishEmptyListTitle), subtitle: store.t(.wishEmptyListSubtitle), icon: "gift")
                } else {
                    List {
                        Section {
                            totalsCard(list)
                                .finCleanRow()
                                .listRowSeparator(.hidden)
                        }
                        Section(header:
                            Text(store.t(.wishItems))
                                .font(.caption.bold())
                                .foregroundStyle(VercelTheme.textTertiary)
                                .textCase(.uppercase)
                        ) {
                            ForEach(items) { item in
                                itemRow(item)
                                    .finCleanRow()
                                    .padding(.vertical, 2)
                                    .swipeActions(edge: .leading) {
                                        if item.purchased {
                                            Button(store.t(.wishReopen)) { store.setPurchased(id: item.id, purchased: false) }
                                                .tint(.orange)
                                        } else {
                                            Button(store.t(.wishBuy)) { store.setPurchased(id: item.id, purchased: true) }
                                                .tint(.green)
                                        }
                                    }
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            store.deleteItem(id: item.id)
                                        } label: {
                                            Label(store.t(.delete), systemImage: "trash")
                                        }
                                        .tint(.red)
                                        Button {
                                            editingItem = item
                                        } label: {
                                            Label(store.t(.edit), systemImage: "pencil")
                                        }
                                        .tint(.blue)
                                    }
                                    .onTapGesture { editingItem = item }
                            }
                        }
                    }
                    .finCleanList()
                }
            } else {
                EmptyStateView(title: store.t(.wishRemovedTitle), subtitle: store.t(.wishRemovedSubtitle), icon: "heart.fill")
            }
        }
        .finBackground()
        .finDetailChrome()
        .navigationTitle(store.wishlists.first(where: { $0.id == wishlistID })?.name ?? store.t(.wishlist))
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    store.setValuesHidden(!store.valuesHidden)
                } label: {
                    Image(systemName: store.valuesHidden ? "eye.slash" : "eye")
                }
                .accessibilityLabel(store.valuesHidden ? store.t(.showValues) : store.t(.hideValues))
                Button { showingItemForm = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingItemForm) {
            WishlistItemFormView(wishlistID: wishlistID)
                .environmentObject(store)
        }
        .sheet(item: $editingItem) { item in
            WishlistItemFormView(wishlistID: item.wishlistID, editing: item)
                .environmentObject(store)
        }
    }

    private func totalsCard(_ list: Wishlist) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(store.t(.wishToGo)).font(.caption).foregroundStyle(VercelTheme.textSecondary)
                Text(store.maskedAmount(store.pendingTotal(wishlistID: list.id)))
                    .font(.headline).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(store.t(.wishBought)).font(.caption).foregroundStyle(VercelTheme.textSecondary)
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
                    StatusPill(item.priority.label(language: store.lang), color: priorityColor(item.priority))
                    if let cat = store.category(id: item.categoryID) {
                        Text(cat.name).font(.caption).foregroundStyle(VercelTheme.textSecondary)
                    }
                }
            }
            Spacer()
            Text(store.maskedAmount(item.estimatedPrice))
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
    private enum Field { case name, notes }
    @FocusState private var focusedField: Field?
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
            Form {
                    Section(store.t(.wishDesire)) {
                        TextField(store.t(.nameField), text: $name)
                            .focused($focusedField, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .notes }
                        CurrencyField(
                            value: $price, showKeyboardToolbar: false,
                            currencyCode: store.settings.currency.currencyCode,
                            localeIdentifier: store.settings.currency.localeIdentifier
                        )
                        Picker(store.t(.wishPriority), selection: $priority) {
                            Text(WishlistPriority.low.label(language: store.lang)).tag(WishlistPriority.low)
                            Text(WishlistPriority.medium.label(language: store.lang)).tag(WishlistPriority.medium)
                            Text(WishlistPriority.high.label(language: store.lang)).tag(WishlistPriority.high)
                        }
                        Picker(store.t(.categoryLabel), selection: $categoryID) {
                            Text(store.t(.noCategory)).tag(nil as String?)
                            ForEach(store.categories.filter { $0.type == .expense }) { cat in
                                Text(cat.name).tag(cat.id as String?)
                            }
                        }
                        TextField(store.t(.notesField), text: $notes)
                            .focused($focusedField, equals: .notes)
                            .submitLabel(.done)
                            .onSubmit { focusedField = nil }
                    }
                    if editing != nil {
                        Section(store.t(.wishPurchaseSection)) {
                            Button(store.t(.wishGenerate)) { generate() }
                            if let generatedMessage {
                                Text(generatedMessage).font(.footnote).foregroundStyle(.green)
                            } else {
                                Text(store.t(.wishGenerateFootnote))
                                    .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                            }
                        }
                    }
                    if let errorMessage {
                        Section { Text(errorMessage).foregroundStyle(.red) }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(VercelTheme.card)
                #if os(iOS)
                .scrollDismissesKeyboard(.interactively)
                #endif
            .navigationTitle(editing == nil ? store.t(.wishNewItem) : store.t(.wishEditItem))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(.close)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(.save)) { save() }
                }
                #if os(iOS)
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(store.t(.ok)) {
                        focusedField = nil
                        KeyboardDismisser.dismiss()
                    }
                }
                #endif
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
            errorMessage = store.t(.nameRequired)
        } catch Store.WishlistError.invalidPrice {
            errorMessage = store.t(.wishErrPrice)
        } catch {
            errorMessage = store.t(.couldNotSave)
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
            generatedMessage = store.t(.wishGenerated)
        } catch {
            errorMessage = store.t(.wishErrGenerate)
        }
    }
}
