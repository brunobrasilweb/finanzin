import SwiftUI
import FinanzinCore

// MARK: - Tela de Configurações (Sprint 7)
//
// Acesso via engrenagem no header (a dock mantém 2+2 + botão + central).
// Todas as prefs vivem em `Store.settings` (UserDefaults) e aplicam na hora.

public struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var notificationsGranted = false
    @State private var permissionDenied = false
    @State private var showingResetConfirm = false

    public init() {}

    private var lang: AppLanguage { store.settings.language }
    private func t(_ key: L10nKey) -> String { L10n.t(key, lang) }

    public var body: some View {
        NavigationStack {
            Form {
                Section(t(.languageSection)) {
                    Picker(t(.languageSection), selection: languageBinding) {
                        ForEach(AppLanguage.allCases, id: \.self) { l in
                            Text("\(l.flag)  \(l.label)").tag(l)
                        }
                    }
                    .pickerStyle(.inline)
                    Text(t(.languageFootnote))
                        .font(.footnote)
                        .foregroundStyle(VercelTheme.textSecondary)
                }

                Section(t(.currencySection)) {
                    Picker(t(.currencySection), selection: currencyBinding) {
                        ForEach(AppCurrency.allCases, id: \.self) { c in
                            Text("\(c.flag)  \(c.label)").tag(c)
                        }
                    }
                    .pickerStyle(.inline)
                    HStack {
                        Text(t(.preview))
                            .foregroundStyle(VercelTheme.textSecondary)
                        Spacer()
                        Text(store.maskedAmount(Decimal(string: "1234.56") ?? 0))
                            .font(.headline).monospacedDigit()
                            .foregroundStyle(VercelTheme.textPrimary)
                    }
                    Text(t(.currencyFootnote))
                        .font(.footnote)
                        .foregroundStyle(VercelTheme.textSecondary)
                }

                Section(t(.notificationsSection)) {
                    Toggle(t(.notifMaster), isOn: masterBinding)
                    if permissionDenied {
                        Text(t(.notifDenied))
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    Toggle(isOn: prefsBinding(\.overdueDailyEnabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(.notifOverdue))
                            Text(t(.notifOverdueDesc))
                                .font(.caption)
                                .foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    .disabled(!notificationsGranted)
                    Toggle(isOn: prefsBinding(\.payDueDayEnabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(.notifPayDue))
                            Text(t(.notifPayDueDesc))
                                .font(.caption)
                                .foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    .disabled(!notificationsGranted)
                    Toggle(isOn: prefsBinding(\.receiveDueDayEnabled)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(.notifReceiveDue))
                            Text(t(.notifReceiveDueDesc))
                                .font(.caption)
                                .foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                    .disabled(!notificationsGranted)
                    DatePicker(t(.notifTime), selection: timeBinding, displayedComponents: .hourAndMinute)
                        .disabled(!notificationsGranted)
                }

                Section(t(.appearanceSection)) {
                    Picker(t(.appearanceSection), selection: themeBinding) {
                        ForEach(ThemeMode.allCases, id: \.self) { m in
                            Text(m.label(language: lang)).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(t(.dataSection)) {
                    Button(role: .destructive) {                        showingResetConfirm = true
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t(.startFresh))
                            Text(t(.startFreshDesc))
                                .font(.caption)
                                .foregroundStyle(VercelTheme.textSecondary)
                        }
                    }
                }

                Section(t(.aboutSection)) {
                    HStack {
                        Text(t(.version))
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(VercelTheme.textSecondary)
                    }
                    Button(t(.restoreDefaults), role: .destructive) {
                        store.resetSettings()
                        reschedule()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VercelTheme.card)
            .navigationTitle(t(.settingsTitle))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(t(.done)) { dismiss() }
                }
            }
            .confirmationDialog(
                t(.startFreshTitle),
                isPresented: $showingResetConfirm
            ) {
                Button(t(.startFreshConfirm), role: .destructive) {
                    store.resetToDefaults()
                    reschedule()
                }
                Button(t(.cancel), role: .cancel) {}
            } message: {
                Text(t(.startFreshMessage))
            }
        }
        .task { await refreshPermission() }
    }

    // MARK: - Bindings

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { store.settings.language },
            set: { store.updateLanguage($0) }
        )
    }

    private var currencyBinding: Binding<AppCurrency> {
        Binding(
            get: { store.settings.currency },
            set: { store.updateCurrency($0) }
        )
    }

    private var themeBinding: Binding<ThemeMode> {
        Binding(
            get: { store.settings.theme },
            set: { store.updateTheme($0) }
        )
    }

    private func prefsBinding(_ keyPath: WritableKeyPath<NotificationPrefs, Bool>) -> Binding<Bool> {
        Binding(
            get: { store.settings.notifications[keyPath: keyPath] },
            set: {
                var prefs = store.settings.notifications
                prefs[keyPath: keyPath] = $0
                store.updateNotifications(prefs)
                reschedule()
            }
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                let prefs = store.settings.notifications
                return Calendar.current.date(
                    from: DateComponents(hour: prefs.hour, minute: prefs.minute)
                ) ?? Date()
            },
            set: {
                let comps = Calendar.current.dateComponents([.hour, .minute], from: $0)
                var prefs = store.settings.notifications
                prefs.hour = comps.hour ?? 9
                prefs.minute = comps.minute ?? 0
                store.updateNotifications(prefs)
                reschedule()
            }
        )
    }

    private var masterBinding: Binding<Bool> {
        Binding(
            get: { notificationsGranted },
            set: { _ in Task { await toggleMaster() } }
        )
    }

    // MARK: - Permissão + reagendamento

    private func refreshPermission() async {
        #if canImport(UserNotifications)
        let status = await NotificationService.authorizationStatus()
        await MainActor.run {
            #if os(iOS)
            notificationsGranted = (status == .authorized || status == .provisional || status == .ephemeral)
            #else
            notificationsGranted = (status == .authorized || status == .provisional)
            #endif
            permissionDenied = (status == .denied)
        }
        #else
        await MainActor.run { notificationsGranted = false }
        #endif
    }

    private func toggleMaster() async {
        #if canImport(UserNotifications)
        if notificationsGranted {
            await MainActor.run { notificationsGranted = false }
            NotificationService.cancelAll(transactions: store.transactions)
        } else {
            let granted = await NotificationService.requestAuthorization()
            await MainActor.run {
                notificationsGranted = granted
                permissionDenied = !granted
            }
            if granted { await MainActor.run { reschedule() } }
        }
        #endif
    }

    private func reschedule() {
        #if canImport(UserNotifications)
        NotificationService.rescheduleAll(transactions: store.transactions, settings: store.settings)
        #endif
    }
}

/// Engrenagem do header: abre as Configurações em sheet.
/// Uso: `ScreenHeader(...) { SettingsGearButton(); PrivacyEyeButton() }`.
public struct SettingsGearButton: View {
    @EnvironmentObject var store: Store
    @State private var showing = false

    public init() {}

    public var body: some View {
        HeaderButton("gearshape") { showing = true }
            .accessibilityLabel(store.t(.settingsAcc))
            .sheet(isPresented: $showing) { SettingsView() }
    }
}
