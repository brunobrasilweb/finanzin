import SwiftUI
import FinanzinCore
import ImageIO
#if os(iOS)
import QuickLook
import UIKit
import CoreGraphics
#else
import AppKit
import CoreGraphics
import QuickLookUI
#endif

// MARK: - Modelo de exibição (cobre anexo salvo + pendente)

/// Pendente: foto/arquivo escolhido no form de NOVA transação, ainda sem
/// ID de transação — gravado no `Store` logo após o `create()`.
public struct PendingAttachment: Identifiable, Sendable {
    public let id: String
    public let fileName: String
    public let data: Data

    public init(id: String = UUID().uuidString, fileName: String, data: Data) {
        self.id = id
        self.fileName = fileName
        self.data = data
    }

    public var isPDF: Bool {
        (fileName as NSString).pathExtension.lowercased() == "pdf"
    }

    public var sizeText: String {
        ByteCountCache.string(for: data.count)
    }
}

/// `ByteCountFormatter` cacheado (um por estilo): era um por linha.
private enum ByteCountCache {
    nonisolated(unsafe) private static var cached: ByteCountFormatter?
    private static let lock = NSLock()

    static func string(for bytes: Int) -> String {
        lock.lock()
        let f: ByteCountFormatter
        if let hit = cached {
            f = hit
        } else {
            let fresh = ByteCountFormatter()
            fresh.countStyle = .file
            cached = fresh
            f = fresh
        }
        lock.unlock()
        return f.string(fromByteCount: Int64(bytes))
    }
}

/// Linha uniforme para salvo (com `fileURL`) e pendente (com `imageData`).
public struct AttachmentDisplay: Identifiable {
    public let id: String
    public let fileName: String
    public let sizeText: String
    public let createdAt: Date
    public let isPDF: Bool
    public let fileURL: URL?
    public let imageData: Data?

    public init(
        id: String, fileName: String, sizeText: String, createdAt: Date,
        isPDF: Bool, fileURL: URL? = nil, imageData: Data? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.sizeText = sizeText
        self.createdAt = createdAt
        self.isPDF = isPDF
        self.fileURL = fileURL
        self.imageData = imageData
    }
}

// MARK: - Miniatura (borra no modo privado)

/// Decode + downsample fora do `body`: a imagem é reduzida para o tamanho
/// da thumb (~88px @2x) em background e cacheada por anexo — antes, cada
/// linha decodificava o arquivo full-res de forma síncrona no `body`.
struct AttachmentThumbnail: View {
    let item: AttachmentDisplay
    var hidden: Bool = false
    @State private var thumb: ThumbImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(VercelTheme.inset)
                .frame(width: 44, height: 44)
            if item.isPDF {
                Image(systemName: "doc.fill")
                    .font(.title3)
                    .foregroundStyle(.red.opacity(0.85))
            } else if let thumb {
                thumb.image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .blur(radius: hidden ? 8 : 0)
            } else {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(VercelTheme.textTertiary)
            }
        }
        .task(id: item.id) {
            thumb = await ThumbnailCache.shared.thumb(
                id: item.id, data: item.imageData, url: item.fileURL)
        }
    }
}

#if os(iOS)
struct ThumbImage: Sendable {
    let ui: UIImage
    var image: Image { Image(uiImage: ui) }
}
#else
struct ThumbImage {
    let ns: NSImage
    var image: Image { Image(nsImage: ns) }
}
#endif

/// Thumbs 96px cacheadas por anexo (actor: decode fora da main).
actor ThumbnailCache {
    static let shared = ThumbnailCache()
    private var cache: [String: ThumbImage] = [:]

    func thumb(id: String, data: Data?, url: URL?, maxPixels: Int = 96) async -> ThumbImage? {
        let key = "\(id)|\(maxPixels)"
        if let hit = cache[key] { return hit }
        let cg: CGImage?
        if let data {
            cg = Self.downsample(data: data, maxPixels: maxPixels)
        } else if let url {
            cg = Self.downsample(url: url, maxPixels: maxPixels)
        } else {
            return nil
        }
        guard let cg else { return nil }
        #if os(iOS)
        let t = ThumbImage(ui: UIImage(cgImage: cg))
        #else
        let t = ThumbImage(ns: NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height)))
        #endif
        if cache.count > 300 { cache.removeAll() }
        cache[key] = t
        return t
    }

    private static func thumbOptions(_ maxPixels: Int) -> CFDictionary {
        [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels,
        ] as CFDictionary
    }

    private static func downsample(data: Data, maxPixels: Int = 96) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(
            data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions(maxPixels))
    }

    private static func downsample(url: URL, maxPixels: Int = 96) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(
            url as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        return CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOptions(maxPixels))
    }
}

// MARK: - Linha do anexo

public struct AttachmentRow: View {
    let item: AttachmentDisplay
    var hidden: Bool = false
    var localeIdentifier: String = "pt_BR"
    var onPreview: () -> Void
    var onDelete: () -> Void

    public init(
        item: AttachmentDisplay, hidden: Bool = false,
        localeIdentifier: String = "pt_BR",
        onPreview: @escaping () -> Void, onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.hidden = hidden
        self.localeIdentifier = localeIdentifier
        self.onPreview = onPreview
        self.onDelete = onDelete
    }

    public var body: some View {
        HStack(spacing: FinSpacing.md) {
            Button(action: onPreview) {
                AttachmentThumbnail(item: item, hidden: hidden)
            }
            .buttonStyle(.plain)
            .disabled(item.fileURL == nil && item.imageData == nil)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .font(.subheadline)
                    .foregroundStyle(VercelTheme.textPrimary)
                    .lineLimit(1)
                Text("\(item.sizeText) • \(dateText)")
                    .font(.caption)
                    .foregroundStyle(VercelTheme.textTertiary)
            }
            Spacer()
            if let url = item.fileURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(VercelTheme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onPreview)
    }

    private var dateText: String {
        Format.shortStyle(item.createdAt, localeIdentifier: localeIdentifier)
    }
}

// MARK: - Preview QuickLook in-app

#if os(iOS)
/// Data source do `QLPreviewController` (público pois é o retorno do
/// `makeCoordinator()` público exigido pelo `UIViewControllerRepresentable`).
public final class AttachmentPreviewDataSource: NSObject, QLPreviewControllerDataSource {
    let urls: [URL]
    init(urls: [URL]) { self.urls = urls }
    public func numberOfPreviewItems(in controller: QLPreviewController) -> Int { urls.count }
    public func previewController(
        _ controller: QLPreviewController, previewItemAt index: Int
    ) -> QLPreviewItem {
        urls[index] as NSURL
    }
}

/// Preview de imagens + PDF sem sair do app (iOS).
///
/// Apresentação modal via UIKit (padrão da Apple): o `QLPreviewController`
/// hospedado num sheet do SwiftUI — ainda mais aninhado no sheet do form —
/// abre em branco ou nem abre. Modal sobre o topo da hierarquia funciona
/// sempre, com o form aberto ou não.
public enum AttachmentPreviewPresenter {
    public static func present(urls: [URL], index: Int = 0) {
        guard !urls.isEmpty else { return }
        guard let top = topViewController() else { return }
        let preview = QLPreviewController()
        let source = AttachmentPreviewDataSource(urls: urls)
        preview.dataSource = source
        preview.currentPreviewItemIndex = min(max(index, 0), urls.count - 1)
        let nav = AttachmentPreviewHost(rootViewController: preview)
        nav.previewSource = source // `dataSource` é weak: o host retém.
        top.present(nav, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
            let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

/// Nav com Fechar à esquerda (a direita o QL usa para compartilhar).
private final class AttachmentPreviewHost: UINavigationController {
    var previewSource: AttachmentPreviewDataSource?

    override func viewDidLoad() {
        super.viewDidLoad()
        topViewController?.navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done, target: self, action: #selector(close))
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}
#else
/// Preview de imagens + PDF sem sair do app (macOS).
public struct AttachmentPreview: NSViewRepresentable {
    let urls: [URL]
    let index: Int

    public init(urls: [URL], index: Int = 0) {
        self.urls = urls
        self.index = index
    }

    public func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal)!
        view.previewItem = current as NSURL?
        return view
    }

    public func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = current as NSURL?
    }

    private var current: URL {
        guard !urls.isEmpty else { return URL(fileURLWithPath: "/dev/null") }
        return urls[min(index, urls.count - 1)]
    }
}
#endif

// MARK: - Câmera / fototeca (iOS)

#if os(iOS)
/// `UIImagePickerController` embrulhado: `.camera` tira a foto do
/// comprovante, `.photoLibrary` escolhe uma imagem existente.
public struct PhotoCaptureView: UIViewControllerRepresentable {
    public enum Source {
        case camera
        case library
    }

    let source: Source
    var onPick: (Data, String) -> Void
    var onCancel: () -> Void

    public init(
        source: Source,
        onPick: @escaping (Data, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.source = source
        self.onPick = onPick
        self.onCancel = onCancel
    }

    public func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source == .camera ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    public func updateUIViewController(
        _ uiViewController: UIImagePickerController, context: Context
    ) {}

    public func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick, onCancel: onCancel)
    }

    public final class Coordinator: NSObject,
        UIImagePickerControllerDelegate, UINavigationControllerDelegate
    {
        let onPick: (Data, String) -> Void
        let onCancel: () -> Void

        init(onPick: @escaping (Data, String) -> Void, onCancel: @escaping () -> Void) {
            self.onPick = onPick
            self.onCancel = onCancel
        }

        public func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Sem dismiss manual: o picker foi apresentado pelo SwiftUI
            // (sheet), então dispensar pelo UIKit derrubava também o form
            // da transação. O `onPick` desliga o binding e o SwiftUI
            // dispensa só o sheet da câmera.
            guard let image = info[.originalImage] as? UIImage else { return }
            // JPEG full-res fora da main (encode bloqueava o dismiss).
            // O callback muta `@State` dos call sites, então não pode ser
            // `@Sendable`: a caixa afirma o uso só na main (onde ele é
            // invocado abaixo), o que torna o `@unchecked` sound.
            let callback = MainCallback(onPick)
            DispatchQueue.global(qos: .userInitiated).async {
                guard let data = image.jpegData(compressionQuality: 0.85),
                      !data.isEmpty
                else { return }
                // Sem ":" (o ISO8601 tem, e dois-pontos dão problema em path).
                let name = "foto-\(Dates.shortFileStamp()).jpg"
                DispatchQueue.main.async { callback.call(data, name) }
            }
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }

    /// Callback de UI invocado somente na main queue.
    private struct MainCallback: @unchecked Sendable {
        let fn: (Data, String) -> Void
        init(_ fn: @escaping (Data, String) -> Void) { self.fn = fn }
        func call(_ data: Data, _ name: String) { fn(data, name) }
    }
}
#endif
