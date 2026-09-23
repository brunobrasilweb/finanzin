import SwiftUI
import FinanzinCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Design tokens (adaptativos light/dark, estilo Vercel)
//
// Cada token resolve conforme o `colorScheme` ativo (que segue
// `Store.settings.theme`). Nada de `.white`/`.black` fixo nas Views —
// use os tokens, senão o modo claro quebra.

public enum VercelTheme {
    #if os(iOS)
    private static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }

    private static func bw(_ white: Double, alpha: Double) -> Color {
        dynamic(
            light: UIColor(white: 0, alpha: alpha),
            dark: UIColor(white: white, alpha: alpha)
        )
    }
    #else
    private static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(NSColor(name: nil) { $0.name == .darkAqua ? dark : light })
    }

    private static func bw(_ white: Double, alpha: Double) -> Color {
        dynamic(
            light: NSColor(white: 0, alpha: alpha),
            dark: NSColor(white: white, alpha: alpha)
        )
    }
    #endif

    /// Fundo: branco puro no light, preto OLED no dark.
    public static var bg: Color {
        #if os(iOS)
        return dynamic(
            light: UIColor(white: 1, alpha: 1),
            dark: UIColor(red: 0.02, green: 0.02, blue: 0.024, alpha: 1)
        )
        #else
        return dynamic(
            light: NSColor(white: 1, alpha: 1),
            dark: NSColor(red: 0.02, green: 0.02, blue: 0.024, alpha: 1)
        )
        #endif
    }

    /// Superfície elevada (cards): cinza claro no light, #131316 no dark.
    public static var card: Color {
        #if os(iOS)
        return dynamic(
            light: UIColor(red: 0.945, green: 0.945, blue: 0.957, alpha: 1),
            dark: UIColor(red: 0.075, green: 0.075, blue: 0.085, alpha: 1)
        )
        #else
        return dynamic(
            light: NSColor(red: 0.945, green: 0.945, blue: 0.957, alpha: 1),
            dark: NSColor(red: 0.075, green: 0.075, blue: 0.085, alpha: 1)
        )
        #endif
    }

    /// Superfície embutida (pills, inputs inativos).
    public static var inset: Color { bw(1, alpha: 0.06) }
    public static var border: Color { bw(1, alpha: 0.09) }
    public static var borderStrong: Color { bw(1, alpha: 0.16) }
    public static var textPrimary: Color { bw(1, alpha: 1) }
    public static var textSecondary: Color { bw(1, alpha: 0.55) }
    public static var textTertiary: Color { bw(1, alpha: 0.35) }
    public static var accent: Color { bw(1, alpha: 1) }

    /// Trilho das barras de progresso (orçamento/resumo).
    public static var track: Color { bw(1, alpha: 0.08) }

    /// Sombra dos cards (mais leve no light).
    public static var shadow: Color {
        #if os(iOS)
        return dynamic(
            light: UIColor(white: 0, alpha: 0.12),
            dark: UIColor(white: 0, alpha: 0.35)
        )
        #else
        return dynamic(
            light: NSColor(white: 0, alpha: 0.12),
            dark: NSColor(white: 0, alpha: 0.35)
        )
        #endif
    }

    /// Brilho sutil no topo das telas (profundidade).
    public static var topGlow: LinearGradient {
        LinearGradient(
            colors: [bw(1, alpha: 0.07), Color.clear],
            startPoint: .top, endPoint: .center
        )
    }

    /// Destaque de borda do card-herói (brilho claro no dark, sombra no light).
    public static var edgeHighlight: LinearGradient {
        LinearGradient(
            colors: [bw(1, alpha: 0.22), bw(1, alpha: 0.05)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    }

    public static func hex(_ hex: String) -> Color {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        h = h.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >> 8) & 0xFF) / 255
        let b = Double(rgb & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}

public enum FinSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let xxl: CGFloat = 28
}

public enum FinRadius {
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 20
}

// MARK: - Modificadores

public struct FinCardStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(FinSpacing.lg)
            .background(VercelTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: FinRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FinRadius.lg, style: .continuous)
                    .stroke(VercelTheme.border, lineWidth: 1)
            )
            .shadow(color: VercelTheme.shadow, radius: 12, y: 6)
    }
}

public struct FinRowStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, FinSpacing.lg)
            .padding(.vertical, FinSpacing.md)
            .background(VercelTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous)
                    .stroke(VercelTheme.border, lineWidth: 1)
            )
    }
}

public extension View {
    /// Card flutuante padrão.
    func finCard() -> some View { modifier(FinCardStyle()) }
    /// Linha flutuante (uso dentro de List com fundo transparente).
    func finRow() -> some View { modifier(FinRowStyle()) }
    /// Prepara uma List para linhas flutuantes sobre fundo dark.
    func finList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
            .listRowBackground(Color.clear)
    }
    /// Linha clean: sem fundo cinza, só separador sutil (padrão Transações).
    func finCleanRow() -> some View {
        self
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20))
            .listRowSeparatorTint(VercelTheme.border.opacity(0.6))
    }
    /// Lista clean: fundo transparente, estilo plain, sem cards.
    func finCleanList() -> some View {
        self
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
    }
    /// Fundo do tema (segue light/dark). Expansivo de borda a borda (notch do
    /// iPhone 13 Pro Max e home indicator): o fundo ignora a safe area e o
    /// conteúdo continua respeitando-a.
    func finBackground() -> some View {
        self.background {
            VercelTheme.bg.ignoresSafeArea()
            VercelTheme.topGlow.ignoresSafeArea()
        }
    }
    /// Esconde a nav bar do sistema (iOS; telas raiz usam ScreenHeader) e
    /// pinta o chrome do sistema com o fundo do tema (segue light/dark).
    func finHideNavBar() -> some View {
        modifier(FinHideNavBar())
    }
    /// Pinta o chrome do sistema com o fundo do tema sem esconder a nav bar
    /// (telas de detalhe com botão voltar).
    func finDetailChrome() -> some View {
        modifier(FinDetailChrome())
    }
}

/// Lê o `colorScheme` resolvido (abaixo do `preferredColorScheme` da raiz)
/// para o chrome acompanhar o tema em vez de forçar dark.
private struct FinChromeBase: ViewModifier {
    @Environment(\.colorScheme) var scheme
    var hidesBar: Bool

    func body(content: Content) -> some View {
        #if os(iOS)
        Group {
            if hidesBar {
                content.toolbar(.hidden, for: .navigationBar)
            } else {
                content
            }
        }
        .toolbarBackground(VercelTheme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(VercelTheme.bg, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(scheme, for: .navigationBar)
        .toolbarColorScheme(scheme, for: .tabBar)
        #else
        content
        #endif
    }
}

private struct FinHideNavBar: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(FinChromeBase(hidesBar: true))
    }
}

private struct FinDetailChrome: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(FinChromeBase(hidesBar: false))
    }
}

// MARK: - Componentes

public struct AmountText: View {
    let value: Decimal
    var style: Font = .body
    var hidden: Bool = false
    var currencyCode: String = "BRL"
    var localeIdentifier: String = "pt_BR"

    public init(
        _ value: Decimal, style: Font = .body, hidden: Bool = false,
        currencyCode: String = "BRL", localeIdentifier: String = "pt_BR"
    ) {
        self.value = value
        self.style = style
        self.hidden = hidden
        self.currencyCode = currencyCode
        self.localeIdentifier = localeIdentifier
    }

    public var body: some View {
        Text(hidden ? "••••••" : Format.currency(value, currencyCode: currencyCode, localeIdentifier: localeIdentifier))
            .font(style.bold())
            .monospacedDigit()
            .foregroundStyle((value as NSDecimalNumber).doubleValue >= 0 ? VercelTheme.textPrimary : Color.red.opacity(0.9))
    }
}

public struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let icon: String

    public init(title: String, subtitle: String, icon: String) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    public var body: some View {
        VStack(spacing: FinSpacing.md) {
            ZStack {
                Circle()
                    .fill(VercelTheme.inset)
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(VercelTheme.border, lineWidth: 1))
                Image(systemName: icon)
                    .font(.title)
                    .foregroundStyle(VercelTheme.textSecondary)
            }
            Text(title)
                .font(.headline)
                .foregroundStyle(VercelTheme.textPrimary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(VercelTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, FinSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct MonthPicker: View {
    @Binding var year: Int
    @Binding var month: Int
    var localeIdentifier: String = "pt_BR"

    public init(year: Binding<Int>, month: Binding<Int>, localeIdentifier: String = "pt_BR") {
        _year = year
        _month = month
        self.localeIdentifier = localeIdentifier
    }

    public var body: some View {
        HStack(spacing: FinSpacing.sm) {
            Button { shift(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.bold())
                    .frame(width: 32, height: 32)
                    .background(VercelTheme.inset)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            Spacer()
            Text(label)
                .font(.headline)
                .foregroundStyle(VercelTheme.textPrimary)
            Spacer()
            Button { shift(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.bold())
                    .frame(width: 32, height: 32)
                    .background(VercelTheme.inset)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(VercelTheme.textSecondary)
        .padding(.horizontal, FinSpacing.xs)
        .padding(.vertical, FinSpacing.sm)
        .background(VercelTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: FinRadius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: FinRadius.lg, style: .continuous)
                .stroke(VercelTheme.border, lineWidth: 1)
        )
    }

    private var label: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localeIdentifier)
        f.dateFormat = "MMMM yyyy"
        let d = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        return f.string(from: d).capitalized
    }

    private func shift(by offset: Int) {
        let base = Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
        let next = Calendar.current.date(byAdding: .month, value: offset, to: base) ?? base
        let c = Calendar.current.dateComponents([.year, .month], from: next)
        year = c.year ?? year
        month = c.month ?? month
    }
}

/// Ícone arredondado com tint (padrão das linhas).
public struct TintedIcon: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 38

    public init(_ systemName: String, tint: Color, size: CGFloat = 38) {
        self.systemName = systemName
        self.tint = tint
        self.size = size
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.45, weight: .semibold))
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [tint.opacity(0.28), tint.opacity(0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .stroke(tint.opacity(0.25), lineWidth: 1)
            )
    }
}

/// Badge pill de status.
public struct StatusPill: View {
    let text: String
    let color: Color

    public init(_ text: String, color: Color) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5))
    }
}

/// Cabeçalho compacto das telas principais (substitui o large title do
/// sistema para o conteúdo ocupar a altura toda).
public struct ScreenHeader<Actions: View>: View {
    let title: String
    let actions: Actions

    public init(_ title: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    public var body: some View {
        HStack(spacing: FinSpacing.sm) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(VercelTheme.textPrimary)
            Spacer()
            actions
        }
        .padding(.horizontal, FinSpacing.lg)
        .padding(.top, FinSpacing.xs)
    }
}

public extension ScreenHeader where Actions == EmptyView {
    init(_ title: String) {
        self.title = title
        self.actions = EmptyView()
    }
}

/// Botão circular do cabeçalho.
public struct HeaderButton: View {
    let icon: String
    let action: () -> Void

    public init(_ icon: String, action: @escaping () -> Void) {
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .frame(width: 36, height: 36)
                .background(VercelTheme.inset)
                .foregroundStyle(VercelTheme.textPrimary)
                .clipShape(Circle())
                .overlay(Circle().stroke(VercelTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Dispensa o teclado resignando o first responder atual (iOS).
/// Cobre campos cujo `FocusState` vive dentro de outra view
/// (ex.: `CurrencyField`), que um `@FocusState` local não alcança.
public enum KeyboardDismisser {
    public static func dismiss() {
        #if os(iOS)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

/// Olho do topo: alterna o modo privado (esconde/mostra valores em todas
/// as telas). Lê o estado do `Store`, então todas as telas sincronizam.
public struct PrivacyEyeButton: View {
    @EnvironmentObject var store: Store

    public init() {}

    public var body: some View {
        HeaderButton(store.valuesHidden ? "eye.slash" : "eye") {
            store.setValuesHidden(!store.valuesHidden)
        }
        .accessibilityLabel(store.valuesHidden ? store.t(.showValues) : store.t(.hideValues))
    }
}

public enum Format {
    public static func currency(_ value: Decimal) -> String {
        Currency.format(value)
    }

    public static func currency(_ value: Decimal, currencyCode: String, localeIdentifier: String) -> String {
        Currency.format(value, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
    }

    public static func shortDate(_ date: Date) -> String {
        shortDate(date, localeIdentifier: "pt_BR")
    }

    public static func shortDate(_ date: Date, localeIdentifier: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localeIdentifier)
        f.dateFormat = "dd/MM/yy"
        return f.string(from: date)
    }
}

// MARK: - Aparência (Sprint 7: ThemeMode do Core → SwiftUI)
//
// O Core não importa SwiftUI (não resolve no CLT), então o mapeamento
// `ThemeMode → ColorScheme` vive aqui. Nota: os tokens `VercelTheme`
// são dark-hardcoded; no modo claro o fundo segue escuro até existirem
// tokens light (issue futura) — o `system` default preserva o visual atual.

public extension ThemeMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Linha de data para uso dentro de `Form`.
///
/// Por que não usar `DatePicker` inline? O `DatePicker` compacto dentro de
/// `Form` expande o calendário inline, mudando a altura do formulário de
/// forma brusca (salto + "tremor" ao rolar até o fim). Aqui a altura da
/// linha é fixa e o calendário abre em sheet, que some ao tocar no dia
/// (ou em OK / arrastar para baixo).
public struct FormDateField: View {
    let title: String
    @Binding var date: Date
    var localeIdentifier: String = "pt_BR"
    var okTitle: String = "OK"
    @State private var showingPicker = false

    public init(_ title: String, date: Binding<Date>, localeIdentifier: String = "pt_BR", okTitle: String = "OK") {
        self.title = title
        _date = date
        self.localeIdentifier = localeIdentifier
        self.okTitle = okTitle
    }

    public var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                showingPicker = true
            } label: {
                Text(Self.label(for: date, localeIdentifier: localeIdentifier))
                    .font(.body)
                    .foregroundStyle(VercelTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(VercelTheme.inset)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingPicker) {
            NavigationStack {
                DatePicker(
                    title,
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                .onChange(of: date) {
                    // Tocar num dia já fecha o calendário.
                    showingPicker = false
                }
                .navigationTitle(title)
                #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(okTitle) { showingPicker = false }
                    }
                }
            }
            #if os(iOS)
            .presentationDetents([.medium])
            #endif
        }
    }

    static func label(for date: Date) -> String {
        label(for: date, localeIdentifier: "pt_BR")
    }

    static func label(for date: Date, localeIdentifier: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: localeIdentifier)
        f.dateStyle = .short
        return f.string(from: date)
    }
}
