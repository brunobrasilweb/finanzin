import SwiftUI
import FinanzinCore
#if os(iOS)
import UIKit
#endif

// MARK: - Registro com IA (texto + voz + foto, tudo on-device)
//
// Sem API e sem custo: o prompt digitado ou ditado cai no
// `TransactionNLParser` (Core, regras pt-BR); a foto passa pelo OCR do
// `Vision` (`ReceiptScanSheet`). O botão Salvar grava direto no Store
// (com a foto como comprovante) e avisa a data salva para a lista pular
// para o mês certo. Sem tela intermediária.

public struct AIRegistrationSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    /// Chamado com a data salva (a lista ajusta ano/mês).
    var onSaved: (Date) -> Void

    @StateObject private var speech = SpeechTranscriber()

    // Entrada
    @State private var prompt = ""
    @State private var speechError: String?
    @State private var recordStart: Date?
    @State private var aiWorking = false
    @State private var aiGeneration = 0
    // Campos editáveis (auto-preenchidos até o primeiro toque manual).
    @State private var parse: NLParseResult?
    @State private var autoFill = true
    @State private var amount: Decimal = 0
    @State private var desc = ""
    @State private var type: TransactionType = .payable
    @State private var date = Date()
    @State private var categoryID: String?
    @State private var parcelCount: Int?
    // Recorrência e cartão detectados (só exibição; edição no formulário).
    @State private var aiRecurrence: RecurrenceType = .unique
    @State private var aiInterval: InstallmentInterval = .monthly
    @State private var aiCardID: String?
    @State private var aiPayOnCard = false
    // Último valor aplicado pelo parser: o `onChange` dos campos dispara
    // também para o preenchimento automático — só conta como edição
    // manual (e desliga o `autoFill`) o que diverge do aplicado.
    @State private var appliedAmount: Decimal = 0
    @State private var appliedDesc = ""
    @State private var appliedType: TransactionType = .payable
    @State private var appliedDate = Date()
    @State private var appliedCategoryID: String?
    @State private var appliedParcels: Int?
    // Foto (iOS): scan preenche os campos; o anexo viaja no confirm.
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var scanPayload: ScanPayload?
    @State private var pendingPhoto: Data?
    @State private var photoNote: String?
    @State private var errors: [String] = []

    private struct ScanPayload: Identifiable {
        let id = UUID().uuidString
        let data: Data
    }

    public init(onSaved: @escaping (Date) -> Void) {
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            Form {
                promptSection
                if parse != nil {
                    resultSection
                }
                if !errors.isEmpty {
                    Section {
                        ForEach(errors, id: \.self) { e in
                            Text(e).foregroundStyle(.red)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VercelTheme.card)
            .finBackground()
            .navigationTitle(store.t(.aiTitle))
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(store.t(.close)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(store.t(.save)) { confirm() }
                        .bold()
                        .disabled(
                            !canConfirm || speech.isRecording
                                || speech.isTranscribing || aiWorking
                        )
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showingCamera) {
                PhotoCaptureView(
                    source: .camera,
                    onPick: { data, _ in
                        showingCamera = false
                        scanPayload = ScanPayload(data: data)
                    },
                    onCancel: { showingCamera = false }
                )
            }
            .sheet(isPresented: $showingLibrary) {
                PhotoCaptureView(
                    source: .library,
                    onPick: { data, _ in
                        showingLibrary = false
                        scanPayload = ScanPayload(data: data)
                    },
                    onCancel: { showingLibrary = false }
                )
            }
            .sheet(item: $scanPayload) { payload in
                ReceiptScanSheet(imageData: payload.data) { amount, desc, date, catID, image in
                    applyScan(
                        amount: amount, description: desc, date: date,
                        categoryID: catID, imageData: image)
                }
                .environmentObject(store)
            }
            #endif
        }
        .onChange(of: prompt) { _, new in reparse(new) }
        .onChange(of: speech.streamError) { _, new in
            if new != nil { speechError = store.t(.aiNoSpeech) }
        }
        .onDisappear { speech.cancel() }
    }

    // MARK: - Entrada estilo prompt (texto + ícones de voz e foto)

    private var promptSection: some View {
        Section {
            TextField(store.t(.aiPromptPh), text: $prompt, axis: .vertical)
                .lineLimit(2...4)
                .submitLabel(.done)
                .disabled(speech.isRecording || speech.isTranscribing || aiWorking)
            // Barra de ícones: gravar, interpretar com IA, foto, câmera.
            HStack(spacing: 28) {
                recordIcon
                if SmartNLParser.isFoundationAvailable,
                   !speech.isRecording, !speech.isTranscribing, !aiWorking {
                    Button { enhanceWithAI() } label: {
                        Image(systemName: "sparkles")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.purple)
                    .accessibilityLabel(store.t(.entryAI))
                }
                #if os(iOS)
                Button { showingLibrary = true } label: {
                    Image(systemName: "photo.on.rectangle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(VercelTheme.textSecondary)
                .accessibilityLabel(store.t(.txChoosePhoto))
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showingCamera = true } label: {
                        Image(systemName: "camera.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(VercelTheme.textSecondary)
                    .accessibilityLabel(store.t(.txTakePhoto))
                }
                #endif
                Spacer()
            }
            .font(.title2)
            .padding(.top, 4)
            if speech.isRecording {
                recordingRow
            }
            if speech.isTranscribing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(store.t(.aiTranscribing))
                        .font(.footnote)
                        .foregroundStyle(VercelTheme.textSecondary)
                }
            }
            if aiWorking {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(store.t(.aiEnhancing))
                        .font(.footnote)
                        .foregroundStyle(VercelTheme.textSecondary)
                }
            }
            if let speechError {
                Text(speechError)
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
        } footer: {
            Text(store.t(.aiEmpty))
                .font(.footnote)
        }
    }

    /// Mic parado (azul) ou stop gravando (vermelho).
    private var recordIcon: some View {
        Group {
            if speech.isRecording {
                Button { stopDictation() } label: {
                    Image(systemName: "stop.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .accessibilityLabel(store.t(.aiStop))
            } else if speech.isSupported {
                Button { Task { await startDictation() } } label: {
                    Image(systemName: "mic.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
                .accessibilityLabel(store.t(.aiListen))
                .disabled(speech.isTranscribing)
            }
        }
    }

    private var recordingRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            Text(recordStart ?? Date(), style: .timer)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(VercelTheme.textSecondary)
            Spacer()
            Button(store.t(.aiStop)) { stopDictation() }
                .font(.footnote.bold())
                .tint(.red)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        Section(store.t(.txValueSection)) {
            ProminentCurrencyField(
                value: $amount,
                tint: type == .payable ? .red.opacity(0.9) : .green,
                showKeyboardToolbar: false,
                currencyCode: store.settings.currency.currencyCode,
                localeIdentifier: store.settings.currency.localeIdentifier
            )
            .onChange(of: amount) { _, new in
                if new != appliedAmount { autoFill = false }
            }
            Picker(store.t(.typeLabel), selection: $type) {
                Label(
                    TransactionType.payable.label(language: store.lang),
                    systemImage: "arrow.up.circle.fill"
                ).tag(TransactionType.payable)
                Label(
                    TransactionType.receivable.label(language: store.lang),
                    systemImage: "arrow.down.circle.fill"
                ).tag(TransactionType.receivable)
            }
            .pickerStyle(.segmented)
            .onChange(of: type) { _, new in
                if new != appliedType {
                    autoFill = false
                    categoryID = nil
                    // Cartão só vale para conta a pagar.
                    aiCardID = nil
                    aiPayOnCard = false
                }
            }
        }
        Section(store.t(.dataSection)) {
            TextField(store.t(.descriptionField), text: $desc)
                .onChange(of: desc) { _, new in
                    if new != appliedDesc { autoFill = false }
                }
            Picker(store.t(.categoryLabel), selection: $categoryID) {
                Text(store.t(.noCategory)).tag(nil as String?)
                ForEach(store.categories.filter {
                    $0.type == (type == .payable ? .expense : .income)
                }) { cat in
                    Text(cat.name).tag(cat.id as String?)
                }
            }
            .onChange(of: categoryID) { _, new in
                if new != appliedCategoryID { autoFill = false }
            }
            FormDateField(
                store.t(.txDueDate), date: $date,
                localeIdentifier: store.lang.localeIdentifier,
                okTitle: store.t(.ok)
            )
            .onChange(of: date) { _, new in
                if new != appliedDate { autoFill = false }
            }
            if let parcelCount {
                Stepper(
                    String(format: store.t(.txInstallments), parcelCount),
                    value: Binding(
                        get: { parcelCount },
                        set: { self.parcelCount = $0; autoFill = false }
                    ),
                    in: 2...48
                )
            }
            // Recorrência e cartão detectados: conferência aqui, edição
            // fina no formulário (parcelas têm Stepper próprio acima).
            if aiRecurrence != .unique, parcelCount == nil {
                HStack {
                    Text(store.t(.txRecurrence))
                    Spacer()
                    Text(recurrenceLabel)
                        .foregroundStyle(VercelTheme.textSecondary)
                    Button { aiRecurrence = .unique } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VercelTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.t(.txClearFilter))
                }
            }
            if aiPayOnCard, type == .payable {
                HStack {
                    Picker(store.t(.cardFilter), selection: $aiCardID) {
                        Text(store.t(.select)).tag(nil as String?)
                        ForEach(store.activeCards) { card in
                            Text(card.name).tag(card.id as String?)
                        }
                    }
                    Button {
                        aiPayOnCard = false
                        aiCardID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VercelTheme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(store.t(.txClearFilter))
                }
            }
        }
        if let parse {
            Section {
                HStack {
                    Text("\(Int(parse.confidence * 100))%")
                        .font(.footnote.bold())
                        .monospacedDigit()
                        .foregroundStyle(parse.confidence < 0.5 ? .orange : .green)
                    Text(store.t(.aiLowConfidence))
                        .font(.footnote)
                        .foregroundStyle(
                            parse.confidence < 0.5
                                ? .orange : VercelTheme.textSecondary)
                }
                if let photoNote {
                    Text(photoNote)
                        .font(.footnote)
                        .foregroundStyle(VercelTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Lógica

    private var recurrenceLabel: String {
        let base = aiRecurrence.label(language: store.lang)
        if aiRecurrence == .recurring {
            return "\(base) • \(aiInterval.label(language: store.lang))"
        }
        return base
    }

    private var canConfirm: Bool {
        let trimmed = desc.trimmingCharacters(in: .whitespacesAndNewlines)
        return amount > 0 || !trimmed.isEmpty
    }

    /// Interpretação com o LLM on-device (botão ✨). Aplica só se o
    /// prompt não mudou durante a espera; qualquer falha cai nas regras.
    private func enhanceWithAI() {
        let text = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        aiGeneration += 1
        let gen = aiGeneration
        aiWorking = true
        speechError = nil
        let cats = store.categories
        let cards = store.creditCards
        let lang = store.lang
        Task {
            let result = await SmartNLParser.enhance(
                text: text, categories: cats, cards: cards, language: lang)
            aiWorking = false
            guard gen == aiGeneration,
                  prompt.trimmingCharacters(in: .whitespacesAndNewlines) == text
            else { return }
            autoFill = true
            applyResult(result, resetWhenEmptyText: false)
        }
    }

    /// Reinterpreta o prompt com as regras (só sobrescreve os campos até
    /// o usuário editar algo manualmente — `autoFill`).
    private func reparse(_ text: String) {
        guard autoFill else { return }
        let result = TransactionNLParser.parse(
            text: text, categories: store.categories,
            cards: store.creditCards)
        applyResult(
            result,
            resetWhenEmptyText: text.trimmingCharacters(
                in: .whitespacesAndNewlines).isEmpty
        )
    }

    /// Aplica um resultado aos campos editáveis (+ snapshots e IA states).
    private func applyResult(_ result: NLParseResult, resetWhenEmptyText: Bool) {
        let empty = result.amount == nil
            && (result.description ?? "").isEmpty
            && !result.dateExplicit
        parse = empty ? nil : result
        if !empty {
            amount = result.amount ?? 0
            desc = result.description ?? ""
            type = result.type
            date = result.date
            // Categoria sugerida só vale para o tipo detectado.
            categoryID = result.categoryID
            parcelCount = result.installmentCount
            aiRecurrence = result.installmentCount != nil
                ? .unique : result.recurrence
            aiInterval = result.interval ?? .monthly
            aiCardID = result.creditCardID
            aiPayOnCard = result.payOnCard
        } else if resetWhenEmptyText {
            amount = 0
            desc = ""
            parcelCount = nil
            aiRecurrence = .unique
            aiCardID = nil
            aiPayOnCard = false
        }
        // Foto do que o parser aplicou: os `onChange` acima disparam
        // também para esse preenchimento — sem o snapshot, o primeiro
        // caractere digitado matava o `autoFill` e o resto do texto
        // nunca era interpretado (a voz funcionava porque chega de uma vez).
        appliedAmount = amount
        appliedDesc = desc
        appliedType = type
        appliedDate = date
        appliedCategoryID = categoryID
        appliedParcels = parcelCount
    }

    private func startDictation() async {
        speechError = nil
        do {
            try await speech.start()
            recordStart = Date()
        } catch SpeechTranscriberError.deniedMic,
                SpeechTranscriberError.deniedSpeech {
            speechError = store.t(.aiNoPermission)
        } catch {
            speechError = store.t(.aiNoSpeech)
        }
    }

    private func stopDictation() {
        Task {
            let text = await speech.stop()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            recordStart = nil
            if text.isEmpty {
                speech.cancel()
                speechError = store.t(.aiNoSpeech)
                return
            }
            autoFill = true
            prompt = text
            reparse(text)
        }
    }

    /// Foto → OCR: preenche os campos como conta a pagar e guarda a foto
    /// para virar comprovante no `confirm()`.
    private func applyScan(
        amount: Decimal, description: String, date: Date,
        categoryID: String?, imageData: Data
    ) {
        autoFill = false
        self.amount = amount
        desc = description
        type = .payable
        self.date = date
        self.categoryID = categoryID
        aiRecurrence = .unique
        aiInterval = .monthly
        aiCardID = nil
        aiPayOnCard = false
        pendingPhoto = imageData
        photoNote = store.t(.txScanHint)
        parse = NLParseResult(
            amount: amount, description: description, date: date,
            dateExplicit: true, type: .payable, categoryID: categoryID,
            confidence: 0.75, rawText: description
        )
    }

    /// Salvar direto no Store (sem tela intermediária): valida como o
    /// form, cria (série/parcelas inclusas), anexa a foto do scan e dá
    /// baixa quando a data é hoje ou passada.
    private func confirm() {
        let recurrence: RecurrenceType =
            parcelCount != nil ? .installment : aiRecurrence
        let interval: InstallmentInterval? =
            recurrence == .installment ? .monthly
            : recurrence == .recurring ? aiInterval : nil
        errors = TransactionEngine.validate(
            description: desc, amount: amount, language: store.lang)
        errors += TransactionEngine.validateSeries(
            recurrence: recurrence,
            count: recurrence == .installment ? parcelCount : nil,
            interval: recurrence == .installment ? .monthly : interval,
            language: store.lang
        )
        let card = (type == .payable && aiPayOnCard)
            ? store.card(id: aiCardID) : nil
        if type == .payable, aiPayOnCard, card == nil {
            errors.append(store.t(.payNoCard))
        }
        guard errors.isEmpty else { return }
        let status: TransactionStatus =
            Calendar.current.startOfDay(for: date)
                > Calendar.current.startOfDay(for: Date()) ? .pending : .paid
        let input = TransactionEngine.CreateInput(
            description: desc, type: type, categoryID: categoryID,
            amount: amount, recurrence: recurrence, dueDate: date,
            notes: nil,
            totalInstallments: recurrence == .installment ? parcelCount : nil,
            interval: interval,
            creditCardID: card?.id, card: card
        )
        let items = store.create(input)
        if let first = items.first {
            if let photo = pendingPhoto, !photo.isEmpty {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd-HHmmss"
                _ = try? store.addAttachment(
                    to: first.id,
                    fileName: "recibo-\(f.string(from: Date())).jpg",
                    data: photo
                )
            }
            if status == .paid {
                store.updateStatus(id: first.id, to: .paid)
            }
        }
        onSaved(date)
        dismiss()
    }
}
