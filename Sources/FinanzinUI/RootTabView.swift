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
                }
                .tabItem { Image(systemName: "chart.bar.fill") }
                .tag(0)
                TransactionListView(year: $year, month: $month, categoryID: $dashboardCategory)
                    .tabItem { Image(systemName: "arrow.left.arrow.right") }
                    .tag(1)
                BudgetListView(year: $year, month: $month)
                    .tabItem { Image(systemName: "gauge.with.dots.needle.67percent") }
                    .tag(2)
                WishlistListView()
                    .tabItem { Image(systemName: "heart.fill") }
                    .tag(3)
            }
            // Botão central elevado, cortando o topo do menu: cria conforme a aba atual.
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
            .sheet(isPresented: $showTxForm) {
                TransactionFormView(year: year, month: month)
            }
            .sheet(isPresented: $showBudgetForm) {
                BudgetFormView(year: year, month: month)
            }
            .sheet(isPresented: $showWishlistForm) {
                WishlistFormView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(.white)
        .finTabChrome()
        .environmentObject(store)
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
