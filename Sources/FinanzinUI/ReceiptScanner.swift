import SwiftUI
import FinanzinCore
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ImageIO)
import ImageIO
#endif

// MARK: - OCR on-device (Vision → linhas de texto)
//
// Grátis, offline e privado: nada sai do aparelho. O Vision devolve
// blocos de texto; `ReceiptParser` (Core, testável) interpreta valor,
// estabelecimento, data e categoria sugerida.

public enum ReceiptScanError: Error, Sendable {
    case unreadableImage
    case noTextFound
    case unavailable
}

public enum ReceiptScannerService {
    /// Reconhece o texto da foto e devolve as linhas em ordem de
    /// leitura (topo → base). Roda fora da main thread (chame via `Task`).
    public static func recognizeLines(in imageData: Data) async throws -> [String] {
        #if canImport(Vision)
        guard let cgImage = ReceiptScannerService.cgImage(from: imageData) else {
            throw ReceiptScanError.unreadableImage
        }
        return try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<[String], any Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Vision usa origem no canto inferior: ordena do topo à base.
                let sorted = observations.sorted {
                    if abs($0.boundingBox.minY - $1.boundingBox.minY) > 0.02 {
                        return $0.boundingBox.minY > $1.boundingBox.minY
                    }
                    return $0.boundingBox.minX < $1.boundingBox.minX
                }
                let lines = sorted.compactMap { $0.topCandidates(1).first?.string }
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["pt-BR", "en-US"]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
        #else
        throw ReceiptScanError.unavailable
        #endif
    }

    #if canImport(Vision)
    private static func cgImage(from data: Data) -> CGImage? {
        #if canImport(ImageIO)
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
        #else
        return nil
        #endif
    }
    #endif
}

// MARK: - Conferência do scan (sempre com revisão manual)

/// Foto do recibo → leitura → campos editáveis. Nada é aplicado ao
/// formulário sem o usuário tocar em "Usar estes dados": o OCR erra
/// vírgula/ponto com frequência e a conferência é obrigatória.
public struct ReceiptScanSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let imageData: Data
    var onConfirm: (Decimal, String, Date, String?, Data) -> Void

    @State private var isReading = true
    @State private var errorMessage: String?
    @State private var amount: Decimal = 0
    @State private var merchant: String = ""
    @State private var date = Date()
    @State private var categoryID: String?
    @State private var foundSomething = false
    @State private var scanConfidence = 0.0

    public init(
        imageData: Data,
        onConfirm: @escaping (Decimal, String, Date, String?, Data) -> Void
    ) {
        self.imageData = imageData
        self.onConfirm = onConfirm
    }

    public var body: some View {
        NavigationStack {
            Group {
                if isReading {
                    readingView
                } else {
                    reviewForm
                }
            }
            .finBackground()
            .navigationTitle(store.t(.txScanTitle))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(.close)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(.txScanUse)) { confirm() }
                        .bold()
                        .disabled(isReading)
                }
            }
            .task { await read() }
        }
    }

    private var readingView: some View {
        VStack(spacing: FinSpacing.lg) {
            Spacer()
            ScanImagePreview(data: imageData)
            ProgressView(store.t(.txScanReading))
                .foregroundStyle(VercelTheme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var reviewForm: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    ScanImagePreview(data: imageData)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            reviewNotice
            Section(store.t(.txValueSection)) {
                ProminentCurrencyField(
                    value: $amount,
                    tint: .red.opacity(0.9),
                    showKeyboardToolbar: false,
                    currencyCode: store.settings.currency.currencyCode,
                    localeIdentifier: store.settings.currency.localeIdentifier
                )
            }
            Section(store.t(.dataSection)) {
                TextField(store.t(.descriptionField), text: $merchant)
                Picker(store.t(.categoryLabel), selection: $categoryID) {
                    Text(store.t(.noCategory)).tag(nil as String?)
                    ForEach(store.categories.filter { $0.type == .expense }) { cat in
                        Text(cat.name).tag(cat.id as String?)
                    }
                }
                FormDateField(
                    store.t(.txDueDate), date: $date,
                    localeIdentifier: store.lang.localeIdentifier,
                    okTitle: store.t(.ok)
                )
            }
            Section {
                Text(store.t(.txScanHint))
                    .font(.footnote)
                    .foregroundStyle(VercelTheme.textSecondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VercelTheme.card)
    }

    @ViewBuilder
    private var reviewNotice: some View {
        if let errorMessage {
            Section {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        } else if !foundSomething {
            Section {
                Text(store.t(.txScanEmpty))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        } else if scanConfidence < 0.5 {
            // Leitura incerta (ex.: sem total claro): reforça a conferência.
            Section {
                Text(store.t(.txScanHint))
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func read() async {
        do {
            let lines = try await ReceiptScannerService.recognizeLines(in: imageData)
            let scan = ReceiptParser.parse(lines: lines)
            await MainActor.run {
                amount = scan.amount ?? 0
                merchant = scan.merchantName ?? ""
                date = scan.date ?? Date()
                categoryID = ReceiptParser.suggestCategoryID(
                    in: store.categories, scan: scan)
                foundSomething = scan.amount != nil || scan.merchantName != nil
                scanConfidence = scan.confidence
                if lines.isEmpty {
                    errorMessage = store.t(.txScanEmpty)
                }
                isReading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = store.t(.txScanFailed)
                isReading = false
            }
        }
    }

    private func confirm() {
        let trimmed = merchant.trimmingCharacters(in: .whitespacesAndNewlines)
        onConfirm(amount, trimmed, date, categoryID, imageData)
        dismiss()
    }
}

// MARK: - Preview da foto escaneada

struct ScanImagePreview: View {
    let data: Data

    var body: some View {
        Group {
            #if os(iOS)
            if let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(VercelTheme.textTertiary)
            }
            #else
            if let ns = NSImage(data: data) {
                Image(nsImage: ns)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(VercelTheme.textTertiary)
            }
            #endif
        }
        .frame(maxHeight: 220)
        .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
    }
}
