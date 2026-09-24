import Foundation
import SwiftUI
#if canImport(Speech)
import Speech
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - Ditado on-device (voz → texto do parser local)
//
// Grátis, sem API key: grava com `AVAudioRecorder` num `.m4a` temporário
// e transcreve o arquivo com `SFSpeechRecognizer(pt-BR)`
// (`SFSpeechURLRecognitionRequest`, on-device quando o aparelho oferece).
// De propósito SEM `AVAudioEngine`/streaming: tap em thread de áudio +
// `append`/`endAudio`/`cancel` concorrentes derrubavam o Speech com
// assert de dispatch queue. Aqui há um único task por vez e o waiter é
// liberado em todo caminho (resultado, erro ou cancelamento).
// O texto final cai no `TransactionNLParser` — o mesmo do prompt.

public enum SpeechTranscriberError: Error, Sendable {
    case unsupported
    case deniedMic
    case deniedSpeech
    case noSpeech
    case failed
}

#if canImport(Speech) && canImport(AVFoundation)
/// ObservableObject no MainActor: `start()` grava, `stop()` para e
/// transcreve (mostre `isTranscribing` enquanto isso).
@MainActor
public final class SpeechTranscriber: ObservableObject {
    @Published public var isRecording = false
    @Published public var isTranscribing = false
    /// Falha no meio do caminho (a UI mostra `aiNoSpeech`). Nil = ok.
    @Published public var streamError: SpeechTranscriberError?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "pt-BR"))
    private var recorder: AVAudioRecorder?
    private var task: SFSpeechRecognitionTask?
    private var recordURL: URL?
    /// Invalida callbacks de gerações antigas (stop/cancel no meio).
    private var generation = 0
    private var pendingResume: ((String) -> Void)?
    private var transcribeGen = 0

    public init() {}

    /// O aparelho oferece pt-BR (on-device ou não).
    public var isSupported: Bool {
        recognizer?.isAvailable ?? false
    }

    /// Começa a gravar num arquivo temporário. `async` para não travar a
    /// main enquanto o sistema exibe o alerta de permissão.
    public func start() async throws {
        guard let recognizer, recognizer.isAvailable else {
            throw SpeechTranscriberError.unsupported
        }
        guard await micAuthorized() else { throw SpeechTranscriberError.deniedMic }
        guard await speechAuthorized() else { throw SpeechTranscriberError.deniedSpeech }
        try configureAudioSession()
        // Derruba captura/transcrição anterior e libera quem espera.
        generation += 1
        task?.cancel()
        task = nil
        if let finish = pendingResume { pendingResume = nil; finish("") }
        recorder?.stop()
        recorder = nil
        if let url = recordURL {
            recordURL = nil
            try? FileManager.default.removeItem(at: url)
        }
        streamError = nil
        isTranscribing = false

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ia-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        let recorder: AVAudioRecorder
        do {
            recorder = try AVAudioRecorder(url: url, settings: settings)
        } catch {
            deactivateAudioSession()
            throw SpeechTranscriberError.failed
        }
        guard recorder.record() else {
            try? FileManager.default.removeItem(at: url)
            deactivateAudioSession()
            throw SpeechTranscriberError.failed
        }
        self.recorder = recorder
        recordURL = url
        isRecording = true
    }

    /// Para de gravar, transcreve o arquivo e devolve o texto. Nunca
    /// trava: sem texto ou com erro, devolve "" (a UI mostra `aiNoSpeech`).
    public func stop() async -> String {
        generation += 1
        recorder?.stop()
        recorder = nil
        isRecording = false
        deactivateAudioSession()
        guard let url = recordURL else { return "" }
        recordURL = nil
        let text = await transcribe(url: url)
        try? FileManager.default.removeItem(at: url)
        return text
    }

    public func cancel() {
        generation += 1
        if let finish = pendingResume { pendingResume = nil; finish("") }
        recorder?.stop()
        recorder = nil
        task?.cancel()
        task = nil
        if let url = recordURL {
            recordURL = nil
            try? FileManager.default.removeItem(at: url)
        }
        isRecording = false
        isTranscribing = false
        deactivateAudioSession()
    }

    // MARK: - Privado

    /// Transcrição de arquivo. O waiter é liberado em todo caminho, então
    /// o `await` nunca pendura o "Transcrevendo...".
    private func transcribe(url: URL) async -> String {
        guard let recognizer, recognizer.isAvailable else {
            streamError = .failed
            return ""
        }
        let gen = generation
        isTranscribing = true
        defer { isTranscribing = false }
        return await withCheckedContinuation { cont in
            pendingResume = { [weak self] text in
                self?.task = nil
                self?.pendingResume = nil
                cont.resume(returning: text)
            }
            transcribeGen = gen
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request.shouldReportPartialResults = false
            task = recognizer.recognitionTask(with: request) { [weak self] result, _ in
                // Lê o texto ainda na fila de entrega; o salto ao MainActor
                // carrega só String (Sendable) + self.
                let text = result?.bestTranscription.formattedString
                let failed = result == nil
                Task { @MainActor [weak self] in
                    self?.completeTranscription(text: text, failed: failed)
                }
            }
        }
    }

    private func completeTranscription(text: String?, failed: Bool) {
        guard let finish = pendingResume else { return }
        pendingResume = nil
        task = nil
        guard transcribeGen == generation else {
            finish("")
            return
        }
        if failed { streamError = .failed }
        finish(text ?? "")
    }

    // MARK: - Sessão de áudio (iOS)

    private func configureAudioSession() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechTranscriberError.failed
        }
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance()
            .setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func micAuthorized() async -> Bool {
        #if os(iOS)
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted: return true
        case .denied: return false
        case .undetermined:
            return await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { ok in
                    cont.resume(returning: ok)
                }
            }
        @unknown default: return false
        }
        #else
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: .audio) { ok in
                    cont.resume(returning: ok)
                }
            }
        @unknown default: return false
        }
        #endif
    }

    private func speechAuthorized() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: return true
        case .denied, .restricted: return false
        case .notDetermined:
            return await withCheckedContinuation { cont in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    cont.resume(returning: newStatus == .authorized)
                }
            }
        @unknown default: return false
        }
    }
}
#else
/// Stub quando `Speech`/`AVFoundation` não existem (nunca deve aparecer:
/// o botão de ditar some quando `isSupported == false`).
@MainActor
public final class SpeechTranscriber: ObservableObject {
    @Published public var isRecording = false
    @Published public var isTranscribing = false
    @Published public var streamError: SpeechTranscriberError?

    public init() {}

    public var isSupported: Bool { false }

    public func start() async throws {
        throw SpeechTranscriberError.unsupported
    }

    public func stop() async -> String { "" }

    public func cancel() {}
}
#endif
