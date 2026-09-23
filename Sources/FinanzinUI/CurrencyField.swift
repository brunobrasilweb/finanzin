import SwiftUI
import Foundation
import FinanzinCore

/// Campo monetário com máscara em tempo real, na moeda configurada.
/// Digite apenas números e o valor é formatado (ex.: "R$ 1.234,56").
/// Uso: `CurrencyField(value: $amountDecimal)` onde amount é `Decimal`.
public struct CurrencyField: View {
    @Binding var value: Decimal
    /// Placeholder manual; `nil` = zero formatado na moeda ativa.
    var placeholder: String?
    /// Mostra o botão OK sobre o teclado. Desligue quando o formulário
    /// já tem um OK próprio (para não duplicar).
    var showKeyboardToolbar: Bool = true
    var okTitle: String = "OK"
    var currencyCode: String = "BRL"
    var localeIdentifier: String = "pt_BR"

    @State private var text: String = ""
    @State private var didInit = false
    @FocusState private var isFocused: Bool

    public init(
        value: Binding<Decimal>, placeholder: String? = nil,
        showKeyboardToolbar: Bool = true, okTitle: String = "OK",
        currencyCode: String = "BRL", localeIdentifier: String = "pt_BR"
    ) {
        _value = value
        self.placeholder = placeholder
        self.showKeyboardToolbar = showKeyboardToolbar
        self.okTitle = okTitle
        self.currencyCode = currencyCode
        self.localeIdentifier = localeIdentifier
    }

    private var effectivePlaceholder: String {
        placeholder ?? Self.format(0, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
    }

    public var body: some View {
        TextField(effectivePlaceholder, text: $text)
            .focused($isFocused)
            .monospacedDigit()
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
            .onAppear {
                if !didInit {
                    text = Self.format(value, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
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
                let formatted = Self.format(newDecimal, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
                if formatted != newValue {
                    text = formatted
                }
            }
            .onChange(of: value) { _, newValue in
                // Sincroniza quando o valor muda de fora (ex.: edição) e o campo não está focado.
                if !isFocused {
                    let formatted = Self.format(newValue, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
                    if formatted != text {
                        text = formatted
                    }
                }
            }
            .toolbar {
                #if os(iOS)
                    if showKeyboardToolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button(okTitle) { isFocused = false }
                        }
                    }
                #endif
            }
    }

    public static func format(_ value: Decimal) -> String {
        format(value, currencyCode: "BRL", localeIdentifier: "pt_BR")
    }

    public static func format(_ value: Decimal, currencyCode: String, localeIdentifier: String) -> String {
        Currency.format(value, currencyCode: currencyCode, localeIdentifier: localeIdentifier)
    }
}

/// Variante grande e destacada para o formulário de transação.
public struct ProminentCurrencyField: View {
    @Binding var value: Decimal
    var tint: Color
    var showKeyboardToolbar: Bool = true
    var okTitle: String = "OK"
    var currencyCode: String = "BRL"
    var localeIdentifier: String = "pt_BR"

    public init(
        value: Binding<Decimal>, tint: Color, showKeyboardToolbar: Bool = true,
        okTitle: String = "OK",
        currencyCode: String = "BRL", localeIdentifier: String = "pt_BR"
    ) {
        _value = value
        self.tint = tint
        self.showKeyboardToolbar = showKeyboardToolbar
        self.okTitle = okTitle
        self.currencyCode = currencyCode
        self.localeIdentifier = localeIdentifier
    }

    public var body: some View {
        CurrencyField(
            value: $value, showKeyboardToolbar: showKeyboardToolbar,
            okTitle: okTitle,
            currencyCode: currencyCode, localeIdentifier: localeIdentifier
        )
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(tint)
            .tint(tint)
            .frame(maxWidth: .infinity, minHeight: 44)
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
