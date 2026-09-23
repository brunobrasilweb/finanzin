import SwiftUI
import FinanzinCore
import FinanzinUI

// Entry point do app iOS. Requer Xcode com iOS 17 SDK.
// Como criar o .xcodeproj (na máquina com Xcode):
//   1. Xcode → File → New → Project → iOS → App → nome Finanzin,
//      interface SwiftUI, storage SwiftData, bundle br.inoovexa.finanzin.
//   2. Arraste Sources/FinanzinCore + Sources/FinanzinUI para o projeto
//      (ou adicione via File → Add Files), mantendo este arquivo como entry.
//   3. Troque o Store em memória por SwiftData: ver
//      XcodeOnly/SwiftDataModels.swift para o mapeamento 1:1 dos structs.
//   4. Rode no simulador iPhone 16 (iOS 17+), appearance Dark.

@main
struct FinanzinApp: App {
    var body: some Scene {
        WindowGroup {
            // Tema/idioma vêm de `Store.settings` (RootTabView aplica).
            RootTabView()
        }
    }
}
