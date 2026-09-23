import Foundation

// MARK: - Anexos de transação (comprovantes: imagens + PDF)
//
// Metadados vivem no `Store` (e no Snapshot JSON); os bytes ficam em
// arquivos ao lado do JSON (`FinanzinAttachments/`), nunca dentro dele.
// O anexo pertence a UMA parcela (`transactionID`), nunca à série toda:
// `applySeriesEdit` não copia anexos entre parcelas.

public struct TransactionAttachment: Identifiable, Hashable, Codable, Sendable {
    public var id: String
    public var transactionID: String
    /// Nome original do arquivo (exibição).
    public var fileName: String
    /// Nome gravado em disco (`<id>.<ext>`).
    public var storedFileName: String
    public var mimeType: String
    public var size: Int
    public var createdAt: Date

    public init(
        id: String = UUID().uuidString,
        transactionID: String,
        fileName: String,
        storedFileName: String,
        mimeType: String,
        size: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.transactionID = transactionID
        self.fileName = fileName
        self.storedFileName = storedFileName
        self.mimeType = mimeType
        self.size = size
        self.createdAt = createdAt
    }

    public var fileExtension: String {
        (storedFileName as NSString).pathExtension.lowercased()
    }

    public var isPDF: Bool { fileExtension == "pdf" }
    public var isImage: Bool { !isPDF }

    public var formattedSize: String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: Int64(size))
    }
}

public enum AttachmentError: Error, Sendable {
    case unsupportedType
    case emptyData
    case transactionNotFound
    case writeFailed(String)
}

/// Validação de tipo (imagens + PDF, sem limite de qtd/tamanho).
public enum AttachmentValidator {
    public static let allowedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp", "pdf",
    ]

    public static func isSupported(fileName: String) -> Bool {
        allowedExtensions.contains((fileName as NSString).pathExtension.lowercased())
    }

    public static func mimeType(for fileName: String) -> String {
        switch (fileName as NSString).pathExtension.lowercased() {
        case "pdf": "application/pdf"
        case "png": "image/png"
        case "heic": "image/heic"
        case "heif": "image/heif"
        case "webp": "image/webp"
        default: "image/jpeg"
        }
    }

    /// Nome seguro para exibição (sem path, sem vazio).
    public static func displayName(for fileName: String, fallback: String) -> String {
        let base = (fileName as NSString).lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return base.isEmpty ? fallback : base
    }
}
