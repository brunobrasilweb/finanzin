import SwiftUI
import FinanzinCore
import FinanzinUI

// Demo macOS (nesta máquina sem Xcode): abre a UI real com dados de exemplo.
// Rodar com: swift run FinanzinDemo
// No Xcode, o entry oficial do iOS é FinanzinApp/FinanzinApp.swift.

@main
struct FinanzinDemoApp: App {
    @StateObject private var store: Store = {
        let s = Store(seedIfEmpty: true)
        DemoData.seed(store: s)
        return s
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView(store: store)
        }
        #if os(macOS)
            .defaultSize(width: 950, height: 720)
        #endif
    }
}
