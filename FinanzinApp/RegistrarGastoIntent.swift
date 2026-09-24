// Atalho "Registrar gasto" (Siri / Atalhos / Botão de Ação / Spotlight).
//
// Só compila no app iOS (Xcode) — nunca entra no SPM sob CLT.
// Monta `finanzin://nova-transacao?...` e abre o app, que cai no
// `TransactionFormView` pré-preenchido via `RootTabView.onOpenURL`.
#if canImport(AppIntents)
import AppIntents
import Foundation
import FinanzinCore

#if canImport(UIKit)
import UIKit
#endif

public struct RegistrarGastoIntent: AppIntent {
    public static let title: LocalizedStringResource = "Registrar gasto"
    public static let description = IntentDescription(
        "Abre o Finanzin com o gasto pré-preenchido para conferir e salvar."
    )
    public static let openAppWhenRun: Bool = true

    @Parameter(title: "Valor", description: "Quanto foi gasto.")
    public var valor: Double?

    @Parameter(title: "O quê?", description: "Descrição curta (ex.: Padaria).")
    public var details: String?

    public init() {}

    public init(valor: Double?, details: String?) {
        self.valor = valor
        self.details = details
    }

    public func perform() async throws -> some IntentResult {
        let amount: Decimal? = {
            guard let valor else { return nil }
            return Decimal(valor)
        }()
        let trimmed = details?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = TransactionDraft.url(
            amount: amount,
            description: trimmed?.isEmpty == true ? nil : trimmed,
            date: Date()
        ) {
            #if canImport(UIKit)
            await MainActor.run {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
            #endif
        }
        return .result()
    }
}

public struct FinanzinShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RegistrarGastoIntent(),
            phrases: [
                "Registrar gasto no \(.applicationName)",
                "Lançar gasto no \(.applicationName)",
                "Log expense in \(.applicationName)",
            ],
            shortTitle: "Registrar gasto",
            systemImageName: "plus.circle.fill"
        )
    }
}
#endif
