import SwiftUI
import Charts
import FinanzinCore

public struct RootTabView: View {
    @StateObject private var store: Store
    @State private var year: Int = Calendar.current.component(.year, from: Date())
    @State private var month: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedTab = 0
    @State private var dashboardCategory: String?
    @State private var showTxForm = false
    @State private var showBudgetForm = false
    @State private var showWishlistForm = false

    public init(store: Store? = nil) {
        // No app iOS, persiste em Application Support; demo/previews injetam Store() em memória.
        _store = StateObject(wrappedValue: store ?? Store(persistTo: Store.defaultFileURL()))
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView(year: $year, month: $month) { categoryID in
                    dashboardCategory = categoryID
                    selectedTab = 1
                } onSelectBudgets: {
                    selectedTab = 2
                }
                .hideSystemTabBar()
                .tabItem { Image(systemName: "chart.bar.fill") }
                .tag(0)
                TransactionListView(year: $year, month: $month, categoryID: $dashboardCategory)
                    .hideSystemTabBar()
                    .tabItem { Image(systemName: "arrow.left.arrow.right") }
                    .tag(1)
                BudgetListView(year: $year, month: $month)
                    .hideSystemTabBar()
                    .tabItem { Image(systemName: "gauge.with.dots.needle.67percent") }
                    .tag(2)
                WishlistListView()
                    .hideSystemTabBar()
                    .tabItem { Image(systemName: "heart.fill") }
                    .tag(3)
            }
            #if os(iOS)
            .toolbar(.hidden, for: .tabBar)
            .padding(.bottom, 60)
            #endif
            .hideSystemTabBar()
            #if os(iOS)
            bottomDock
            #else
            // macOS mantém o botão flutuante sobre as abas do sistema.
            Button(action: fabTap) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 60, height: 60)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Adicionar")
            .padding(.bottom, 42)
            #endif
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .finTabChrome()
        .environmentObject(store)
        .sheet(isPresented: $showTxForm) {
            TransactionFormView(year: year, month: month)
                .environmentObject(store)
        }
        .sheet(isPresented: $showBudgetForm) {
            BudgetFormView(year: year, month: month)
                .environmentObject(store)
        }
        .sheet(isPresented: $showWishlistForm) {
            WishlistFormView()
                .environmentObject(store)
        }
    }

    /// Ação do + central: abre o cadastro da aba atual
    /// (Resumo e Transações → transação; Orçamento → limite; Desejos → lista).
    private func fabTap() {
        switch selectedTab {
        case 2: showBudgetForm = true
        case 3: showWishlistForm = true
        default: showTxForm = true
        }
    }

    #if os(iOS)
    /// Dock colada na borda inferior (sem vão preto abaixo), ícones
    /// rebaixados e botão + centralizado na metade do menu.
    private var bottomDock: some View {
        ZStack(alignment: .top) {
            // Fundo com encaixe circular no centro: a borda desce em arco
            // ao redor da bola do + (anel de ~7pt), e desce até a borda
            // da tela (sem vão preto abaixo do menu).
            VStack(spacing: 0) {
                DockNotchShape()
                    .fill(VercelTheme.bg)
                    .frame(height: 54)
                VercelTheme.bg
                    .frame(height: 30)
            }
            .ignoresSafeArea(edges: .bottom)
            DockNotchEdge()
                .stroke(VercelTheme.border, lineWidth: 1)
                .frame(height: 54)

            // Ícones baixos, colados na tela (bloco de 40pt encostado
            // no fundo da dock de 54pt).
            HStack(spacing: 0) {
                dockTab(index: 0, icon: "chart.bar.fill")
                dockTab(index: 1, icon: "arrow.left.arrow.right")
                Spacer().frame(width: 96)
                dockTab(index: 2, icon: "gauge.with.dots.needle.67percent")
                dockTab(index: 3, icon: "heart.fill")
            }
            .frame(height: 40)
            .padding(.top, 12)

            // Centro na metade do menu: 30pt acima da borda e 30pt
            // dentro da barra (botão de 60pt, offset = -30).
            Button(action: fabTap) {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 60, height: 60)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.45), radius: 10, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Adicionar")
            .offset(y: -30)
        }
        .frame(height: 54)
    }

    private func dockTab(index: Int, icon: String) -> some View {
        Button { selectedTab = index } label: {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(selectedTab == index ? Color.white : VercelTheme.textTertiary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    #endif
}

private struct FinTabChrome: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
            content
                .toolbarBackground(VercelTheme.bg, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
        #else
            content
        #endif
    }
}

private extension View {
    func finTabChrome() -> some View { modifier(FinTabChrome()) }
}

#if os(iOS)
// MARK: - Dock com encaixe circular (borda ao redor da bola do +)

/// Encaixe circular de raio 37 ao redor do botão + (raio 30):
/// forma um anel de ~7pt contornando a metade de baixo da bola,
/// com ombros suaves que emendam no topo reto da dock.
private enum DockNotch {
    static let radius: CGFloat = 37
    /// Meio-ângulo onde o arco encontra o ombro (20° acima do equador).
    static let phi: CGFloat = .pi / 9
    /// Extensão horizontal do ombro além do raio.
    static let shoulder: CGFloat = 14
}

/// Silhueta cheia da dock (preenchimento).
private struct DockNotchShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = rect.minY
        let cx = rect.midX
        let R = DockNotch.radius
        let c = cos(DockNotch.phi)
        let s = sin(DockNotch.phi)
        let t = tan(DockNotch.phi)
        // Pontos do arco (esquerda, fundo, direita).
        let ql = CGPoint(x: cx - R * c, y: top + R * s)
        let b = CGPoint(x: cx, y: top + R)
        let qr = CGPoint(x: cx + R * c, y: top + R * s)
        // Ombros: início no topo reto, controle na interseção das
        // tangentes (emenda perfeitamente lisa com o arco).
        let sl = CGPoint(x: cx - R - DockNotch.shoulder, y: top)
        let kl = CGPoint(x: cx - R * (c + t * s), y: top)
        let sr = CGPoint(x: cx + R + DockNotch.shoulder, y: top)
        let kr = CGPoint(x: cx + R * (c + t * s), y: top)
        // Controles do arco em 2 cubics de 70° (L = 4/3·tan(17.5°)·R).
        let L = 4 / 3 * tan(.pi * 70 / 180 / 4) * R
        let d = CGPoint(x: s, y: c) // direção de viagem em Ql
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: top))
        p.addLine(to: sl)
        p.addQuadCurve(to: ql, control: kl)
        p.addCurve(
            to: b,
            control1: CGPoint(x: ql.x + L * d.x, y: ql.y + L * d.y),
            control2: CGPoint(x: b.x - L, y: b.y)
        )
        p.addCurve(
            to: qr,
            control1: CGPoint(x: b.x + L, y: b.y),
            control2: CGPoint(x: qr.x - L * d.x, y: qr.y + L * d.y)
        )
        p.addQuadCurve(to: sr, control: kr)
        p.addLine(to: CGPoint(x: rect.maxX, y: top))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

/// Só o contorno superior (com o encaixe) para a linha de borda.
private struct DockNotchEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let top = rect.minY
        let cx = rect.midX
        let R = DockNotch.radius
        let c = cos(DockNotch.phi)
        let s = sin(DockNotch.phi)
        let t = tan(DockNotch.phi)
        let ql = CGPoint(x: cx - R * c, y: top + R * s)
        let b = CGPoint(x: cx, y: top + R)
        let qr = CGPoint(x: cx + R * c, y: top + R * s)
        let sl = CGPoint(x: cx - R - DockNotch.shoulder, y: top)
        let kl = CGPoint(x: cx - R * (c + t * s), y: top)
        let sr = CGPoint(x: cx + R + DockNotch.shoulder, y: top)
        let kr = CGPoint(x: cx + R * (c + t * s), y: top)
        let L = 4 / 3 * tan(.pi * 70 / 180 / 4) * R
        let d = CGPoint(x: s, y: c)
        p.move(to: CGPoint(x: rect.minX, y: top))
        p.addLine(to: sl)
        p.addQuadCurve(to: ql, control: kl)
        p.addCurve(
            to: b,
            control1: CGPoint(x: ql.x + L * d.x, y: ql.y + L * d.y),
            control2: CGPoint(x: b.x - L, y: b.y)
        )
        p.addCurve(
            to: qr,
            control1: CGPoint(x: b.x + L, y: b.y),
            control2: CGPoint(x: qr.x - L * d.x, y: qr.y + L * d.y)
        )
        p.addQuadCurve(to: sr, control: kr)
        p.addLine(to: CGPoint(x: rect.maxX, y: top))
        return p
    }
}
#endif

/// Esconde a tab bar do sistema (a dock customizada assume o lugar).
/// Precisa ser aplicado DENTRO do conteúdo de cada aba (é a barra que
/// envolve as abas que é escondida). iOS 18+: `toolbarVisibility`, pois
/// o Liquid Glass ignora o `toolbar hidden` legado.
private extension View {
    @ViewBuilder
    func hideSystemTabBar() -> some View {
        #if os(iOS)
        if #available(iOS 18, *) {
            self
                .toolbar(.hidden, for: .tabBar)
                .toolbarVisibility(.hidden, for: .tabBar)
        } else {
            self.toolbar(.hidden, for: .tabBar)
        }
        #else
        self
        #endif
    }
}

