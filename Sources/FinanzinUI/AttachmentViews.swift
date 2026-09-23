import SwiftUI
import FinanzinCore
#if os(iOS)
import QuickLook
import UIKit
#else
import AppKit
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
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(data.count))
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

struct AttachmentThumbnail: View {
    let item: AttachmentDisplay
    var hidden: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(VercelTheme.inset)
                .frame(width: 44, height: 44)
            if item.isPDF {
                Image(systemName: "doc.fill")
                    .font(.title3)
                    .foregroundStyle(.red.opacity(0.85))
            } else if let image = thumbnailImage {
                image
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
    }

    private var thumbnailImage: Image? {
        #if os(iOS)
        if let data = item.imageData, let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        }
        if let url = item.fileURL, let ui = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: ui)
        }
        return nil
        #else
        if let data = item.imageData, let ns = NSImage(data: data) {
            return Image(nsImage: ns)
        }
        if let url = item.fileURL, let ns = NSImage(contentsOf: url) {
            return Image(nsImage: ns)
        }
        return nil
        #endif
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
        let f = DateFormatter()
        f.locale = Locale(identifier: localeIdentifier)
        f.dateStyle = .short
        return f.string(from: item.createdAt)
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
            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.85),
                  !data.isEmpty
            else { return }
            // Sem ":" (o ISO8601 tem, e dois-pontos dão problema em path).
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd-HHmmss"
            onPick(data, "foto-\(f.string(from: Date())).jpg")
        }

        public func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onCancel()
        }
    }
}
#endif
