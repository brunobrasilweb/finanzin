import SwiftUI
import FinanzinCore

// MARK: - Lista de contas (multi-contas)

public struct AccountListView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var showClose: Bool = true
    @State private var showingForm = false
    @State private var editing: BankAccount?
    @State private var alertMessage: String?

    public init(showClose: Bool = true) {
        self.showClose = showClose
    }

    public var body: some View {
        NavigationStack {
            // Saldos e contagens uma vez por `body` (mesmo padrão de Fundos).
            let balances = store.accountBalances()
            let counts = Dictionary(grouping: store.transactions.compactMap(\.accountID), by: { $0 })
                .mapValues(\.count)
            VStack(spacing: FinSpacing.md) {
                ScreenHeader(store.t(.accountTitle)) {
                    if showClose {
                        HeaderButton("xmark") { dismiss() }
                    }
                    PrivacyEyeButton()
                    HeaderButton("plus") { showingForm = true }
                }
                if store.accounts.isEmpty {
                    EmptyStateView(
                        title: store.t(.accountEmptyTitle),
                        subtitle: store.t(.accountEmptySubtitle),
                        icon: "banknote"
                    )
                } else {
                    List {
                        ForEach(sorted) { account in
                            AccountCardRow(
                                icon: account.icon,
                                tintHex: account.color,
                                title: account.name,
                                movementsText: String(format: store.t(.fundMovementsCount), counts[account.id] ?? 0),
                                balanceText: store.maskedAmount(balances[account.id] ?? account.initialBalance),
                                archivedText: account.isActive ? nil : store.t(.accountArchived)
                            )
                                .finCleanRow()
                                .padding(.vertical, 2)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        do { try store.deleteAccount(id: account.id) }
                                        catch Store.AccountError.hasTransactions {
                                            alertMessage = String(format: store.t(.accountDeleteBlocked), account.name)
                                        } catch Store.AccountError.lastAccount {
                                            alertMessage = store.t(.accountLastBlocked)
                                        } catch {
                                            alertMessage = store.t(.couldNotSave)
                                        }
                                    } label: {
                                        Label(store.t(.delete), systemImage: "trash")
                                    }
                                    .tint(.red)
                                    Button {
                                        editing = account
                                    } label: {
                                        Label(store.t(.edit), systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        do { try store.setAccountActive(id: account.id, active: !account.isActive) }
                                        catch {
                                            alertMessage = store.t(.accountLastBlocked)
                                        }
                                    } label: {
                                        Label(
                                            account.isActive ? store.t(.accountArchive) : store.t(.accountUnarchive),
                                            systemImage: account.isActive ? "archivebox" : "archivebox.fill"
                                        )
                                    }
                                    .tint(account.isActive ? .orange : .green)
                                }
                                .onTapGesture { editing = account }
                        }
                    }
                    .finCleanList()
                }
            }
            .finBackground()
            .finHideNavBar()
            .sheet(isPresented: $showingForm) { AccountFormView().environmentObject(store) }
            .sheet(item: $editing) { account in AccountFormView(editing: account).environmentObject(store) }
            .alert(store.t(.fundAttention), isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )) {
                Button(store.t(.ok)) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
    }

    private var sorted: [BankAccount] {
        store.accounts.sorted {
            $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending
        }
    }
}

// MARK: - Linha estreita da conta (só `let`s)

struct AccountCardRow: View {
    let icon: String
    let tintHex: String
    let title: String
    let movementsText: String
    let balanceText: String
    let archivedText: String?

    var body: some View {
        HStack(spacing: FinSpacing.md) {
            TintedIcon(icon, tint: VercelTheme.hex(tintHex), size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(VercelTheme.textPrimary)
                Text(movementsText)
                    .font(.caption).foregroundStyle(VercelTheme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(balanceText)
                    .font(.subheadline.bold()).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
                if let archivedText {
                    Text(archivedText)
                        .font(.caption2.bold())
                        .foregroundStyle(VercelTheme.textTertiary)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(VercelTheme.textTertiary)
                }
            }
        }
        .opacity(archivedText == nil ? 1 : 0.6)
    }
}

// MARK: - Formulário de conta

public struct AccountFormView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss
    var editing: BankAccount?

    @State private var name: String
    @State private var initialBalance: Decimal
    @State private var color: String
    @State private var icon: String
    @State private var isActive: Bool
    @State private var errorMessage: String?
    private enum Field { case name }
    @FocusState private var focusedField: Field?

    public init(editing: BankAccount? = nil) {
        self.editing = editing
        _name = State(initialValue: editing?.name ?? "")
        _initialBalance = State(initialValue: editing?.initialBalance ?? 0)
        _color = State(initialValue: editing?.color ?? "#0ea5e9")
        _icon = State(initialValue: editing?.icon ?? "banknote")
        _isActive = State(initialValue: editing?.isActive ?? true)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section(store.t(.dataSection)) {
                    TextField(store.t(.accountNamePh), text: $name)
                        .focused($focusedField, equals: .name)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }
                    CurrencyField(
                        value: $initialBalance, showKeyboardToolbar: false,
                        currencyCode: store.settings.currency.currencyCode,
                        localeIdentifier: store.settings.currency.localeIdentifier
                    )
                    Text(store.t(.accountInitialBalance))
                        .font(.footnote).foregroundStyle(VercelTheme.textSecondary)
                    if editing != nil {
                        Toggle(store.t(.accountActive), isOn: $isActive)
                    }
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
            .navigationTitle(editing == nil ? store.t(.accountNewTitle) : store.t(.accountEditTitle))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
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
                edit.initialBalance = initialBalance
                edit.color = color
                edit.icon = icon
                edit.isActive = isActive
                try store.updateAccount(edit)
            } else {
                try store.addAccount(
                    name: name, initialBalance: initialBalance,
                    color: color, icon: icon
                )
            }
            dismiss()
        } catch Store.AccountError.emptyName {
            errorMessage = store.t(.nameRequired)
        } catch Store.AccountError.duplicateName {
            errorMessage = store.t(.accountErrDuplicate)
        } catch Store.AccountError.invalidAmount {
            errorMessage = store.t(.accountErrAmount)
        } catch Store.AccountError.lastAccount {
            errorMessage = store.t(.accountLastBlocked)
        } catch {
            errorMessage = store.t(.couldNotSave)
        }
    }
}

// MARK: - Filtro global (Todas as contas ou uma específica)

/// Seletor global de conta: vale para Resumo, Transações e Orçamento de uma
/// vez (lê/escreve `store.selectedAccountID`). Inclui atalho para gerenciar.
public struct AccountFilterBar: View {
    @EnvironmentObject var store: Store
    @State private var showingManage = false

    public init() {}

    public var body: some View {
        if !store.accounts.isEmpty {
            // Saldos uma vez por `body` para exibir ao lado do nome.
            let balances = store.accountBalances()
            let selectedID = store.selectedAccountID.flatMap { id in
                store.accounts.contains(where: { $0.id == id }) ? id : nil
            }
            let balanceText: String = {
                if let selectedID {
                    return store.maskedAmount(balances[selectedID] ?? 0)
                }
                return store.maskedAmount(balances.values.reduce(Decimal(0), +))
            }()
            Menu {
                Button { store.setSelectedAccount(nil) } label: {
                    optionRow(store.t(.accountAll), active: selectedID == nil)
                }
                ForEach(sorted) { account in
                    Button { store.setSelectedAccount(account.id) } label: {
                        optionRow(account.name, active: selectedID == account.id)
                    }
                }
                Section {
                    Button { showingManage = true } label: {
                        Label(store.t(.accountManage), systemImage: "banknote")
                    }
                }
            } label: {
                HStack(spacing: FinSpacing.sm) {
                    Image(systemName: "banknote")
                        .font(.subheadline.bold())
                        .foregroundStyle(VercelTheme.textSecondary)
                    Text(currentName)
                        .font(.subheadline.bold())
                        .foregroundStyle(VercelTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(balanceText)
                        .font(.subheadline.bold()).monospacedDigit()
                        .foregroundStyle(VercelTheme.textSecondary)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2)
                        .foregroundStyle(VercelTheme.textTertiary)
                }
                .padding(.horizontal, FinSpacing.md)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(VercelTheme.inset)
                .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingManage) {
                AccountListView()
                    .environmentObject(store)
            }
        }
    }

    private var sorted: [BankAccount] {
        store.accounts.sorted {
            $0.name.compare($1.name, options: .caseInsensitive) == .orderedAscending
        }
    }

    private var currentName: String {
        if let id = store.selectedAccountID,
           let account = store.accounts.first(where: { $0.id == id })
        {
            return account.name
        }
        return store.t(.accountAll)
    }

    private func optionRow(_ title: String, active: Bool) -> some View {
        HStack {
            Text(title)
            if active {
                Image(systemName: "checkmark")
            }
        }
    }
}

// MARK: - Campo de conta para os formulários

/// Seletor de conta do lançamento (usa só ativas + "Sem conta").
public struct AccountPickerField: View {
    @EnvironmentObject var store: Store
    @Binding var accountID: String?

    public init(accountID: Binding<String?>) {
        _accountID = accountID
    }

    public var body: some View {
        Menu {
            Button { accountID = nil } label: {
                if accountID == nil {
                    Label(store.t(.accountNoAccount), systemImage: "checkmark")
                } else {
                    Text(store.t(.accountNoAccount))
                }
            }
            ForEach(store.activeAccounts) { account in
                Button { accountID = account.id } label: {
                    if accountID == account.id {
                        Label(account.name, systemImage: "checkmark")
                    } else {
                        Text(account.name)
                    }
                }
            }
        } label: {
            HStack(spacing: FinSpacing.sm) {
                if let sel = store.activeAccounts.first(where: { $0.id == accountID })
                    ?? store.accounts.first(where: { $0.id == accountID })
                {
                    Circle().fill(VercelTheme.hex(sel.color)).frame(width: 10, height: 10)
                    Text(sel.name).foregroundStyle(VercelTheme.textPrimary)
                } else {
                    Image(systemName: "banknote").foregroundStyle(VercelTheme.textTertiary)
                    Text(store.t(.accountNoAccount)).foregroundStyle(VercelTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(VercelTheme.textTertiary)
            }
            .padding(.horizontal, FinSpacing.md)
            .padding(.vertical, 10)
            .background(VercelTheme.inset)
            .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
        }
    }
}

