import SwiftUI
import Foundation

/// Campo monetário com máscara BRL em tempo real (pt-BR).
/// Digite apenas números e o valor é formatado como "R$ 1.234,56".
/// Uso: `CurrencyField(value: $amountDecimal)` onde amount é `Decimal`.
public struct CurrencyField: View {
    @Binding var value: Decimal
    var placeholder: String = "R$ 0,00"

    @State private var text: String = ""
    @State private var didInit = false
    @FocusState private var isFocused: Bool

    public init(value: Binding<Decimal>, placeholder: String = "R$ 0,00") {
        _value = value
        self.placeholder = placeholder
    }

    public var body: some View {
        TextField(placeholder, text: $text)
            .focused($isFocused)
            .monospacedDigit()
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
            .onAppear {
                if !didInit {
                    text = Self.format(value)
                    didInit = true
                }
            }
            .onChange(of: text) { _, newValue in
                let digits = newValue.filter(\.isWholeNumber)
                if digits.isEmpty {
                    value = 0
                    if newValue != "" {
                        text = ""
                    }
                    return
                }
                // Limita a 12 dígitos (até ~9 bilhões) para evitar overflow.
                let trimmed = String(digits.suffix(12))
                let cents = Int(trimmed) ?? 0
                let newDecimal = Decimal(cents) / 100
                value = newDecimal
                let formatted = Self.format(newDecimal)
                if formatted != newValue {
                    text = formatted
                }
            }
            .onChange(of: value) { _, newValue in
                // Sincroniza quando o valor muda de fora (ex.: edição) e o campo não está focado.
                if !isFocused {
                    let formatted = Self.format(newValue)
                    if formatted != text {
                        text = formatted
                    }
                }
            }
            .toolbar {
                #if os(iOS)
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("OK") { isFocused = false }
                    }
                #endif
            }
    }

    public static func format(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.numberStyle = .currency
        f.currencyCode = "BRL"
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f.string(from: value as NSDecimalNumber) ?? "R$ 0,00"
    }
}

/// Variante grande e destacada para o formulário de transação.
public struct ProminentCurrencyField: View {
    @Binding var value: Decimal
    var tint: Color

    public init(value: Binding<Decimal>, tint: Color) {
        _value = value
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            CurrencyField(value: $value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(tint)
                .tint(tint)
                .frame(maxWidth: .infinity)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tint.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(tint.opacity(0.25), lineWidth: 1)
                )
        )
    }
}
