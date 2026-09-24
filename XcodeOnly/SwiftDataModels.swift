// Mapeamento SwiftData (executar na máquina com Xcode).
//
// O macro `@Model` não resolve no CommandLineTools deste ambiente,
// por isso o Core usa structs puros + `Store` em memória/JSON.
// Ao migrar para SwiftData no Xcode, crie um `@Model` por struct
// com os MESMOS campos de `Sources/FinanzinCore/Models.swift`:
//
//   @Model final class CategoryModel {
//       var id: String; var name: String; var type: String
//       var color: String; var icon: String; var createdAt: Date
//   }
//   @Model final class TransactionModel {
//       var id, desc, type, recurrence, categoryID, parentID, fundID...,
//       totalAmount/amount como Double (converter Decimal↔Double na borda),
//       installmentCount, currentInstallment, dueDate, paidDate, status...,
//       creditCardID: String? (nil = à vista; fatura derivada via
//       `InvoiceService` a partir do cartão + competência do vencimento —
//       sem tabela de fatura, sem relacionamento obrigatório)
//   }
//   @Model final class CreditCardModel {
//       var id, name: String; var closingDay, dueDay: Int (1...28)
//       var isActive: Bool; var createdAt: Date
//       (exclusão bloqueada com lançamentos vinculados — prefira arquivar)
//   }
//   @Model final class FundModel { id, name, initialAmount(Double), color, icon, notes... }
//   @Model final class BudgetLimitModel { id, categoryID, month, year, limitAmount(Double)... }
//   @Model final class WishlistModel { id, name, color, icon... }
//   @Model final class WishlistItemModel { id, wishlistID, name, estimatedPrice(Double),
//       priority, categoryID, notes, purchased(Bool), purchasedDate... }
//   @Model final class AttachmentModel { id, transactionID(indexado),
//       fileName, storedFileName, mimeType, size(Int), createdAt...
//       (bytes em arquivo em Application Support/FinanzinAttachments,
//       nunca binário no banco; excluir em cascata com a transação) }
//
// Regras:
// - IDs seguem UUID string (compatível com admin/Inofinancy).
// - Decimal ↔ Double apenas na borda de persistência; regra de negócio
//   continua em Decimal (ver `Currency.split`).
// - `unique` do Core == `single` do Inofinancy (mapear na importação).
// - Manter `Store` como protocolo para trocar InMemory ↔ SwiftData sem
//   tocar nas Views (Sprint 1 fará essa abstração).
