import Foundation

// MARK: - Localização in-app (PT-BR + EN)
//
// Dicionário tipado em vez de `Localizable.strings`: funciona no SPM sob
// CLT (sem bundle de strings do Xcode) e é testável no `FinanzinCoreTests`.
// A língua ativa vem de `Store.settings.language`; a raiz injeta
// `.environment(\.locale, settings.locale)` para o sistema formatar junto.

public enum L10nKey: String, CaseIterable, Sendable {
    case settingsTitle
    case languageSection
    case languageFootnote
    case currencySection
    case currencyFootnote
    case notificationsSection
    case notifMaster
    case notifOverdue
    case notifOverdueDesc
    case notifPayDue
    case notifPayDueDesc
    case notifReceiveDue
    case notifReceiveDueDesc
    case notifTime
    case notifDenied
    case notifOpenSettings
    case appearanceSection
    case aboutSection
    case version
    case restoreDefaults
    case startFresh
    case startFreshDesc
    case startFreshTitle
    case startFreshMessage
    case startFreshConfirm
    case done
    case summary
    case transactions
    case budgets
    case wishlist
    case funds
    case overdueSummary
    case payDueToday
    case receiveDueToday
    // Comuns
    case save
    case close
    case cancel
    case delete
    case edit
    case ok
    case all
    case search
    case noCategory
    case select
    case couldNotSave
    case nameRequired
    case colorsCount
    case iconsCount
    case typeLabel
    case statusLabel
    case categoryLabel
    case dataSection
    case nameField
    case notesField
    case descriptionField
    case preview
    case showValues
    case hideValues
    case add
    case settingsAcc
    // Transações
    case txTitle
    case txTypeFilter
    case txEmptyTitle
    case txEmptySubtitle
    case txReopen
    case txSettle
    case txDeleteAccount
    case txDeleteConfirmSingle
    case txDeleteConfirmSeries
    case txStatusMenu
    case txClearFilter
    case txCategoryMenu
    case txAccountType
    case txValueSection
    case txDueAndStatus
    case txDueDate
    case txMoreOptions
    case txLessOptions
    case txSeriesFootnote
    case txRecurrence
    case txInstallments
    case txInterval
    case txGenerates24
    case txGenerates24Monthly
    case txSeriesAccount
    case txSeriesMessage
    case txNewTitle
    case txEditTitle
    case txEditSeriesTitle
    case txEditSeriesMessage
    case txSettleTitle
    case txPaidValue
    case txOriginalValue
    case txSettleDate
    case txPaidOn
    case txReceive
    case txPay
    case txDueLine
    // Pagamento e fatura (cartão de crédito)
    case payMethod
    case payCash
    case payCard
    case payNoCard
    case invoiceGoesTo
    case invoiceDueOn
    case invoicePay
    case invoicePayTitle
    case invoicePayMessage
    case invoicePaid
    case invoiceOpen
    case invoiceClosed
    case invoiceSection
    case invoiceOf
    case invoiceEntries
    case invoiceEmpty
    case invoiceDelete
    case invoiceDeleteMessage
    case cardFilter
    // Cartões
    case cardTitle
    case cardManage
    case cardEmptyTitle
    case cardEmptySubtitle
    case cardNewTitle
    case cardEditTitle
    case cardNamePh
    case cardClosingDay
    case cardDueDay
    case cardDayFootnote
    case cardActive
    case cardArchived
    case cardArchive
    case cardUnarchive
    case cardErrDuplicate
    case cardErrDay
    case cardDeleteBlocked
    // Comprovantes (anexos)
    case txReceipts
    case txAttachFile
    case txTakePhoto
    case txChoosePhoto
    case txAttachEmpty
    case txAttachUnsupported
    case txAttachFailed
    case txSeriesAttachNote
    case txSaveToAttach
    case txScanTitle
    case txScanReceipt
    case txScanReading
    case txScanFailed
    case txScanEmpty
    case txScanHint
    case txScanUse
    // Resumo
    case dashBalance
    case dashSavings
    case dashToReceive
    case dashOverdueStat
    case dashNoFunds
    case dashFundsSummary
    case dashOthers
    case dashEvolution
    case dashNoMovement
    case dashBreakdown
    case dashNoExpenses
    case dashTotal
    case dashCategoriesCount
    case dashNoCategory
    case dashUpcoming7
    case dashNothingDue
    case dashChartIncome
    case dashChartExpense
    case dashOverBy
    case dashLeft
    case dashInvoices
    // Orçamento
    case budEmptyTitle
    case budEmptySubtitle
    case budByCategory
    case budTotalLimit
    case budUsed
    case budOfTemplate
    case budOverBy
    case budLeft
    case budMonthly
    case budNewTitle
    case budEditTitle
    case budLimitSection
    case budMonth
    case budYear
    case budValidFor
    case budOnlyThisMonth
    case budEveryMonth
    case budEditFootnote
    case budRecurringFootnote
    case budSingleFootnote
    case budErrCategory
    case budErrAmount
    case budOverShort    // Categorias
    case catTitle
    case catExpensesPlural
    case catIncomePlural
    case catEmptyTitle
    case catEmptySubtitle
    case catNewTitle
    case catEditTitle
    case catErrDuplicate
    // Fundos
    case fundEmptyTitle
    case fundEmptySubtitle
    case fundMovementsCount
    case fundAttention
    case fundDeleteBlocked
    case fundDeleteFailed
    case fundMovementsSection
    case fundInitial
    case fundRemovedTitle
    case fundRemovedSubtitle
    case fundWithdraw
    case fundDeposit
    case fundDepositSection
    case fundNamePh
    case fundNewTitle
    case fundEditTitle
    case fundAvailable
    case fundLinkedFootnote
    case fundDefaultDeposit
    case fundDefaultWithdraw
    case fundErrAmount
    case fundErrBalance
    case fundDescriptionRequired
    case fundDate
    case fundErrPositive    // Desejos
    case wishEmptyTitle
    case wishEmptySubtitle
    case wishPendingSummary
    case wishAllBought
    case wishNamePh
    case wishNewList
    case wishEditList
    case wishEmptyListTitle
    case wishEmptyListSubtitle
    case wishItems
    case wishReopen
    case wishBuy
    case wishRemovedTitle
    case wishRemovedSubtitle
    case wishToGo
    case wishBought
    case wishDesire
    case wishPriority
    case wishPurchaseSection
    case wishGenerate
    case wishGenerated
    case wishGenerateFootnote
    case wishNewItem
    case wishEditItem
    case wishErrPrice
    case wishErrGenerate
    // Cadastro rápido (deep link + Siri/Atalhos após pagar no NFC)
    case quickAddTitle
    case quickAddHint
    case quickAddValueLabel
    case quickAddDescLabel
    // Registro com IA (prompt/voz/foto — tudo on-device, sem API)
    case entryChoiceTitle
    case entryManual
    case entryAI
    case aiTitle
    case aiPromptPh
    case aiListen
    case aiStop
    case aiListening
    case aiHeardAs
    case aiEmpty
    case aiLowConfidence
    case aiNoSpeech
    case aiNoPermission
    case aiUseData
    case aiTranscribing
    case aiEnhancing
}

public enum L10n {
    public static func t(_ key: L10nKey, _ lang: AppLanguage) -> String {
        switch lang {
        case .ptBR: pt(key)
        case .en: en(key)
        }
    }

    private static func pt(_ key: L10nKey) -> String {
        switch key {
        // Configurações
        case .settingsTitle: "Configurações"
        // 
        case .languageSection: "Idioma"
        case .languageFootnote: "Vale para telas, rótulos e formatos de data."
        case .currencySection: "Moeda"
        case .currencyFootnote: "Só formatação — valores não são convertidos."
        case .notificationsSection: "Notificações"
        case .notifMaster: "Permitir notificações"
        case .notifOverdue: "Contas vencidas (diário)"
        case .notifOverdueDesc: "Resumo todo dia no horário escolhido."
        case .notifPayDue: "Dia de pagamento"
        case .notifPayDueDesc: "Alerta quando uma conta a pagar vence hoje."
        case .notifReceiveDue: "Dia de recebimento"
        case .notifReceiveDueDesc: "Alerta quando um recebimento vence hoje."
        case .notifTime: "Horário"
        case .notifDenied: "Permissão negada. Ative em Ajustes do sistema."
        case .notifOpenSettings: "Abrir Ajustes"
        case .appearanceSection: "Aparência"
        case .aboutSection: "Sobre"
        case .version: "Versão"
        case .restoreDefaults: "Restaurar padrões"
        case .dataSection: "Dados"
        case .startFresh: "Começar do zero"
        case .startFreshDesc: "Apaga tudo e mantém só as categorias padrão."
        case .startFreshTitle: "Começar do zero?"
        case .startFreshMessage: "Todas as transações, fundos, orçamentos, listas e categorias serão apagados. Só as categorias padrão voltam. Essa ação não pode ser desfeita."
        case .startFreshConfirm: "Apagar tudo"
        case .done: "Concluir"
        case .summary: "Resumo"
        case .transactions: "Transações"
        case .budgets: "Orçamento"
        case .wishlist: "Desejos"
        case .funds: "Fundos"
        case .overdueSummary: "Contas vencidas"
        case .payDueToday: "Vence hoje"
        case .receiveDueToday: "Recebe hoje"
        // Comuns
        case .save: "Salvar"
        // 
        case .close: "Fechar"
        case .cancel: "Cancelar"
        case .delete: "Excluir"
        case .edit: "Editar"
        case .ok: "OK"
        case .all: "Todas"
        case .search: "Buscar"
        case .noCategory: "Sem categoria"
        case .select: "Selecione"
        case .couldNotSave: "Não foi possível salvar."
        case .nameRequired: "Nome é obrigatório."
        case .colorsCount: "Cor (%d cores)"
        case .iconsCount: "Ícone (%d ícones)"
        case .typeLabel: "Tipo"
        case .statusLabel: "Status"
        case .categoryLabel: "Categoria"
        case .dataSection: "Dados"
        case .nameField: "Nome"
        case .notesField: "Observações"
        case .descriptionField: "Descrição"
        case .preview: "Pré-visualização"
        case .showValues: "Mostrar valores"
        case .hideValues: "Esconder valores"
        case .add: "Adicionar"
        case .settingsAcc: "Configurações"
        // Transações
        case .txTitle: "Transações"
        // 
        case .txTypeFilter: "Tipo"
        case .txEmptyTitle: "Sem transações"
        case .txEmptySubtitle: "Toque em + para lançar a primeira conta do mês."
        case .txReopen: "Reabrir"
        case .txSettle: "Dar baixa"
        case .txDeleteAccount: "Excluir conta"
        case .txDeleteConfirmSingle: "Excluir “%@”?"
        case .txDeleteConfirmSeries: "“%@” é %@ e faz parte de uma série de %d lançamentos. O que excluir?"
        case .txStatusMenu: "Status"
        case .txClearFilter: "Limpar filtro"
        case .txCategoryMenu: "Categoria"
        case .txAccountType: "Tipo de conta"
        case .txValueSection: "Valor"
        case .txDueAndStatus: "Vencimento e status"
        case .txDueDate: "Vencimento"
        case .txMoreOptions: "Mais opções"
        case .txLessOptions: "Menos opções"
        case .txSeriesFootnote: "Se o alcance incluir outras parcelas, cada uma mantém seu vencimento."
        case .txRecurrence: "Recorrência"
        case .txInstallments: "Parcelas: %d"
        case .txInterval: "Intervalo"
        case .txGenerates24: "Gera os próximos 24 lançamentos."
        case .txGenerates24Monthly: "Gera 24 competências mensais."
        case .txSeriesAccount: "Conta em série"
        case .txSeriesMessage: "Esta conta é %@ e faz parte de uma série de %d lançamentos. Ao salvar, escolha o alcance da alteração."
        case .txNewTitle: "Nova transação"
        case .txEditTitle: "Editar transação"
        case .txEditSeriesTitle: "Editar conta em série"
        case .txEditSeriesMessage: "“%@” é %@. Alterar somente esta, esta e as próximas ou todas? Vencimentos das demais são preservados."
        case .txSettleTitle: "Dar baixa"
        case .txPaidValue: "Valor pago"
        case .txOriginalValue: "Valor original: %@"
        case .txSettleDate: "Data da baixa"
        case .txPaidOn: "Pago em"
        case .txReceive: "Receber"
        case .txPay: "Pagar"
        case .txDueLine: "Vencimento %@ • %@"
        case .payMethod: "Pagamento"
        case .payCash: "À vista"
        case .payCard: "Cartão"
        case .payNoCard: "Cadastre um cartão primeiro."
        case .invoiceGoesTo: "Cai na fatura de %@"
        case .invoiceDueOn: "Vence %@"
        case .invoicePay: "Pagar fatura"
        case .invoicePayTitle: "Pagar fatura"
        case .invoicePayMessage: "Dar baixa em %d conta(s) no valor de %@?"
        case .invoicePaid: "Paga"
        case .invoiceOpen: "Aberta"
        case .invoiceClosed: "Fechada"
        case .invoiceSection: "Faturas"
        case .invoiceOf: "Fatura do %@"
        case .invoiceEntries: "Lançamentos"
        case .invoiceEmpty: "Nenhum lançamento nesta fatura."
        case .invoiceDelete: "Excluir fatura"
        case .invoiceDeleteMessage: "Excluir %d lançamento(s) desta fatura? Não pode ser desfeita."
        case .cardFilter: "Cartão"
        case .cardTitle: "Cartões"
        case .cardManage: "Cartões"
        case .cardEmptyTitle: "Sem cartões"
        case .cardEmptySubtitle: "Cadastre seu cartão com fechamento e vencimento para gerenciar as faturas."
        case .cardNewTitle: "Novo cartão"
        case .cardEditTitle: "Editar cartão"
        case .cardNamePh: "Nome (ex.: Nubank)"
        case .cardClosingDay: "Fechamento (dia)"
        case .cardDueDay: "Vencimento (dia)"
        case .cardDayFootnote: "De 1 a 31 — meses curtos ajustam sozinhos."
        case .cardActive: "Ativo"
        case .cardArchived: "Arquivado"
        case .cardArchive: "Arquivar"
        case .cardUnarchive: "Reativar"
        case .cardErrDuplicate: "Já existe um cartão com esse nome."
        case .cardErrDay: "Fechamento e vencimento devem ser entre 1 e 31."
        case .cardDeleteBlocked: "“%@” tem lançamentos e não pode ser excluído (arquive para esconder do form)."
        case .txReceipts: "Comprovantes"
        case .txAttachFile: "Anexar arquivo"
        case .txTakePhoto: "Tirar foto"
        case .txChoosePhoto: "Escolher foto"
        case .txAttachEmpty: "Nenhum comprovante anexado."
        case .txAttachUnsupported: "Só imagens e PDF são aceitos."
        case .txAttachFailed: "Não foi possível anexar o arquivo."
        case .txSeriesAttachNote: "O comprovante vale só para esta parcela."
        case .txSaveToAttach: "Os arquivos entram após salvar — já dá para tirar a foto e deixar pronta aqui."
        case .txScanTitle: "Ler recibo"
        case .txScanReceipt: "Escanear recibo"
        case .txScanReading: "Lendo recibo…"
        case .txScanFailed: "Não foi possível ler a foto. Preencha manualmente."
        case .txScanEmpty: "Nenhum texto na foto — tente de novo com boa luz."
        case .txScanHint: "A foto vira comprovante e os campos entram sozinhos. Confira antes de usar — a leitura pode errar."
        case .txScanUse: "Usar estes dados"
        // Resumo
        case .dashBalance: "Balanço do mês"
        // 
        case .dashSavings: "Poupança"
        case .dashToReceive: "A receber"
        case .dashOverdueStat: "Vencido"
        case .dashNoFunds: "Nenhum fundo criado"
        case .dashFundsSummary: "%d fundo(s) · %@"
        case .dashOthers: "+%d outros"
        case .dashEvolution: "Evolução · 6 meses"
        case .dashNoMovement: "Sem movimentações no período."
        case .dashBreakdown: "Despesas por categoria"
        case .dashNoExpenses: "Nenhuma despesa no mês."
        case .dashTotal: "Total"
        case .dashCategoriesCount: "%d categorias"
        case .dashNoCategory: "Categoria removida"
        case .dashUpcoming7: "Próximos 7 dias"
        case .dashNothingDue: "Nada vencendo nos próximos 7 dias. 🎉"
        case .dashChartIncome: "Receitas"
        case .dashChartExpense: "Despesas"
        case .dashOverBy: "Estourou %@"
        case .dashLeft: "Restam %@"
        case .dashInvoices: "Faturas"
        // Orçamento
        case .budEmptyTitle: "Sem orçamentos"
        // 
        case .budEmptySubtitle: "Defina um limite mensal por categoria para acompanhar."
        case .budByCategory: "Por categoria"
        case .budTotalLimit: "Limite total"
        case .budUsed: "Utilizado"
        case .budOfTemplate: "%@ de %@"
        case .budOverBy: "Acima do limite por %@"
        case .budLeft: "Restam %@"
        case .budMonthly: "Mensal"
        case .budNewTitle: "Novo orçamento"
        case .budEditTitle: "Editar orçamento"
        case .budLimitSection: "Limite mensal"
        case .budMonth: "Mês"
        case .budYear: "Ano: %d"
        case .budValidFor: "Vale por"
        case .budOnlyThisMonth: "Somente este mês"
        case .budEveryMonth: "Todos os meses (mensal)"
        case .budEditFootnote: "Categoria e competência não mudam; valor e recorrência sim. Mensal vale para este e os próximos meses."
        case .budRecurringFootnote: "Será criado um limite mensal que aparece em %@ de %d e em todos os meses seguintes."
        case .budSingleFootnote: "Vale somente %@ de %d. Se já existir limite da categoria no mês, o valor será atualizado."
        case .budErrCategory: "Escolha uma categoria."
        case .budErrAmount: "Limite deve ser maior que zero."
        case .budOverShort: "Estourou"
        // Categorias
        case .catTitle: "Categorias"
        // 
        case .catExpensesPlural: "Despesas"
        case .catIncomePlural: "Receitas"
        case .catEmptyTitle: "Sem categorias"
        case .catEmptySubtitle: "Toque em + para criar a primeira."
        case .catNewTitle: "Nova categoria"
        case .catEditTitle: "Editar categoria"
        case .catErrDuplicate: "Já existe uma categoria com esse nome para este tipo."
        // Fundos
        case .fundEmptyTitle: "Sem fundos"
        // 
        case .fundEmptySubtitle: "Crie um fundo para separar reservas (ex.: Viagem, Emergência)."
        case .fundMovementsCount: "%d movimentações"
        case .fundAttention: "Atenção"
        case .fundDeleteBlocked: "“%@” tem movimentações e não pode ser excluído (histórico preservado)."
        case .fundDeleteFailed: "Não foi possível excluir."
        case .fundMovementsSection: "Movimentações"
        case .fundInitial: "inicial %@"
        case .fundRemovedTitle: "Fundo removido"
        case .fundRemovedSubtitle: "Volte para a lista."
        case .fundWithdraw: "Sacar"
        case .fundDeposit: "Aportar"
        case .fundDepositSection: "Aporte (conta a pagar)"
        case .fundNamePh: "Nome (ex.: Viagem)"
        case .fundNewTitle: "Novo fundo"
        case .fundEditTitle: "Editar fundo"
        case .fundAvailable: "Disponível: %@"
        case .fundLinkedFootnote: "Será lançada como conta a pagar vinculada ao fundo."
        case .fundDefaultDeposit: "Aporte %@"
        case .fundDefaultWithdraw: "Saque %@"
        case .fundErrAmount: "Valor inicial não pode ser negativo."
        case .fundErrBalance: "Saldo insuficiente para este saque."
        case .fundDescriptionRequired: "Descrição é obrigatória."
        case .fundDate: "Data"
        case .fundErrPositive: "Valor deve ser maior que zero."
        // Desejos
        case .wishEmptyTitle: "Sem listas"
        // 
        case .wishEmptySubtitle: "Crie listas (ex.: Viagem, Setup) e priorize seus desejos."
        case .wishPendingSummary: "%d pendente(s) · %@"
        case .wishAllBought: "Tudo comprado 🎉"
        case .wishNamePh: "Nome (ex.: Setup)"
        case .wishNewList: "Nova lista"
        case .wishEditList: "Editar lista"
        case .wishEmptyListTitle: "Lista vazia"
        case .wishEmptyListSubtitle: "Adicione o primeiro desejo."
        case .wishItems: "Itens"
        case .wishReopen: "Reabrir"
        case .wishBuy: "Comprar"
        case .wishRemovedTitle: "Lista removida"
        case .wishRemovedSubtitle: "Volte para as listas."
        case .wishToGo: "Falta juntar"
        case .wishBought: "Comprados"
        case .wishDesire: "Desejo"
        case .wishPriority: "Prioridade"
        case .wishPurchaseSection: "Compra"
        case .wishGenerate: "Gerar conta a pagar"
        case .wishGenerated: "Conta a pagar criada em Transações ✅"
        case .wishGenerateFootnote: "Cria um “a pagar” único com nome, preço e categoria do item."
        case .wishNewItem: "Novo desejo"
        case .wishEditItem: "Editar desejo"
        case .wishErrPrice: "Preço deve ser maior que zero."
        case .wishErrGenerate: "Não foi possível gerar a conta."
        case .quickAddTitle: "Registrar gasto"
        case .quickAddHint: "Vindo do atalho — confira e salve."
        case .quickAddValueLabel: "Valor"
        case .quickAddDescLabel: "O quê?"
        case .entryChoiceTitle: "Como registrar?"
        case .entryManual: "Cadastro manual"
        case .entryAI: "Registro com IA"
        case .aiTitle: "Registro com IA"
        case .aiPromptPh: "Ex.: paguei 45 na padaria ontem"
        case .aiListen: "Ditar"
        case .aiStop: "Parar"
        case .aiListening: "Ouvindo… toque em Parar ao terminar."
        case .aiHeardAs: "Entendi"
        case .aiEmpty: "Descreva o gasto por texto ou voz — ex.: paguei 45 na padaria ontem."
        case .aiLowConfidence: "Entendimento parcial — confira os campos antes de usar."
        case .aiNoSpeech: "Não entendi o áudio. Tente de novo ou digite."
        case .aiNoPermission: "Permita o microfone e o reconhecimento de fala em Ajustes para ditar."
        case .aiUseData: "Usar estes dados"
        case .aiTranscribing: "Transcrevendo…"
        case .aiEnhancing: "Interpretando com IA…"
        }
    }

    private static func en(_ key: L10nKey) -> String {
        switch key {
        // 
        case .settingsTitle: "Settings"
        case .languageSection: "Language"
        case .languageFootnote: "Applies to screens, labels and date formats."
        case .currencySection: "Currency"
        case .currencyFootnote: "Formatting only — values are not converted."
        case .notificationsSection: "Notifications"
        case .notifMaster: "Allow notifications"
        case .notifOverdue: "Overdue bills (daily)"
        case .notifOverdueDesc: "Summary every day at the chosen time."
        case .notifPayDue: "Bill due day"
        case .notifPayDueDesc: "Alert when a bill is due today."
        case .notifReceiveDue: "Income due day"
        case .notifReceiveDueDesc: "Alert when an income is due today."
        case .notifTime: "Time"
        case .notifDenied: "Permission denied. Enable it in system Settings."
        case .notifOpenSettings: "Open Settings"
        case .appearanceSection: "Appearance"
        case .aboutSection: "About"
        case .version: "Version"
        case .restoreDefaults: "Reset to defaults"
        case .dataSection: "Data"
        case .startFresh: "Start fresh"
        case .startFreshDesc: "Erases everything, keeps only default categories."
        case .startFreshTitle: "Start fresh?"
        case .startFreshMessage: "All transactions, funds, budgets, lists and categories will be deleted. Only the default categories come back. This cannot be undone."
        case .startFreshConfirm: "Delete everything"
        case .done: "Done"
        case .summary: "Summary"
        case .transactions: "Transactions"
        case .budgets: "Budget"
        case .wishlist: "Wishlist"
        case .funds: "Funds"
        case .overdueSummary: "Overdue bills"
        case .payDueToday: "Due today"
        case .receiveDueToday: "Incoming today"
        case .save: "Save"
        case .close: "Close"
        case .cancel: "Cancel"
        case .delete: "Delete"
        case .edit: "Edit"
        case .ok: "OK"
        case .all: "All"
        case .search: "Search"
        case .noCategory: "No category"
        case .select: "Select"
        case .couldNotSave: "Could not save."
        case .nameRequired: "Name is required."
        case .colorsCount: "Color (%d colors)"
        case .iconsCount: "Icon (%d icons)"
        case .typeLabel: "Type"
        case .statusLabel: "Status"
        case .categoryLabel: "Category"
        case .dataSection: "Details"
        case .nameField: "Name"
        case .notesField: "Notes"
        case .descriptionField: "Description"
        case .preview: "Preview"
        case .showValues: "Show values"
        case .hideValues: "Hide values"
        case .add: "Add"
        case .settingsAcc: "Settings"
        case .txTitle: "Transactions"
        case .txTypeFilter: "Type"
        case .txEmptyTitle: "No transactions"
        case .txEmptySubtitle: "Tap + to add the first bill of the month."
        case .txReopen: "Reopen"
        case .txSettle: "Settle"
        case .txDeleteAccount: "Delete bill"
        case .txDeleteConfirmSingle: "Delete “%@”?"
        case .txDeleteConfirmSeries: "“%@” is %@ with %d entries in its series. What to delete?"
        case .txStatusMenu: "Status"
        case .txClearFilter: "Clear filter"
        case .txCategoryMenu: "Category"
        case .txAccountType: "Bill type"
        case .txValueSection: "Amount"
        case .txDueAndStatus: "Due date & status"
        case .txDueDate: "Due date"
        case .txMoreOptions: "More options"
        case .txLessOptions: "Fewer options"
        case .txSeriesFootnote: "If the scope includes other installments, each keeps its due date."
        case .txRecurrence: "Recurrence"
        case .txInstallments: "Installments: %d"
        case .txInterval: "Interval"
        case .txGenerates24: "Generates the next 24 entries."
        case .txGenerates24Monthly: "Generates 24 monthly entries."
        case .txSeriesAccount: "Series bill"
        case .txSeriesMessage: "This bill is %@ with %d entries in its series. When saving, choose the scope of the change."
        case .txNewTitle: "New transaction"
        case .txEditTitle: "Edit transaction"
        case .txEditSeriesTitle: "Edit series bill"
        case .txEditSeriesMessage: "“%@” is %@. Change only this one, this and following, or all? Other due dates are preserved."
        case .txSettleTitle: "Settle"
        case .txPaidValue: "Paid amount"
        case .txOriginalValue: "Original amount: %@"
        case .txSettleDate: "Settlement date"
        case .txPaidOn: "Paid on"
        case .txReceive: "Receive"
        case .txPay: "Pay"
        case .txDueLine: "Due %@ • %@"
        case .payMethod: "Payment"
        case .payCash: "Cash"
        case .payCard: "Card"
        case .payNoCard: "Add a card first."
        case .invoiceGoesTo: "Goes to the %@ bill"
        case .invoiceDueOn: "Due %@"
        case .invoicePay: "Pay bill"
        case .invoicePayTitle: "Pay bill"
        case .invoicePayMessage: "Settle %d bill(s) totaling %@?"
        case .invoicePaid: "Paid"
        case .invoiceOpen: "Open"
        case .invoiceClosed: "Closed"
        case .invoiceSection: "Bills"
        case .invoiceOf: "%@ bill"
        case .invoiceEntries: "Entries"
        case .invoiceEmpty: "No entries in this bill."
        case .invoiceDelete: "Delete bill"
        case .invoiceDeleteMessage: "Delete %d entrie(s) from this bill? This cannot be undone."
        case .cardFilter: "Card"
        case .cardTitle: "Cards"
        case .cardManage: "Cards"
        case .cardEmptyTitle: "No cards"
        case .cardEmptySubtitle: "Add your card with closing and due days to manage bills."
        case .cardNewTitle: "New card"
        case .cardEditTitle: "Edit card"
        case .cardNamePh: "Name (e.g. Nubank)"
        case .cardClosingDay: "Closing (day)"
        case .cardDueDay: "Due (day)"
        case .cardDayFootnote: "1 to 31 — short months adjust automatically."
        case .cardActive: "Active"
        case .cardArchived: "Archived"
        case .cardArchive: "Archive"
        case .cardUnarchive: "Unarchive"
        case .cardErrDuplicate: "A card with this name already exists."
        case .cardErrDay: "Closing and due days must be between 1 and 31."
        case .cardDeleteBlocked: "“%@” has transactions and cannot be deleted (archive it to hide from the form)."
        case .txReceipts: "Receipts"
        case .txAttachFile: "Attach file"
        case .txTakePhoto: "Take photo"
        case .txChoosePhoto: "Choose photo"
        case .txAttachEmpty: "No receipts attached."
        case .txAttachUnsupported: "Only images and PDF are supported."
        case .txAttachFailed: "Could not attach the file."
        case .txSeriesAttachNote: "The receipt applies to this installment only."
        case .txSaveToAttach: "Files attach after saving — you can take the photo now and keep it ready here."
        case .txScanTitle: "Scan receipt"
        case .txScanReceipt: "Scan receipt"
        case .txScanReading: "Reading receipt…"
        case .txScanFailed: "Could not read the photo. Fill in manually."
        case .txScanEmpty: "No text in the photo — try again with good lighting."
        case .txScanHint: "The photo becomes a receipt and fills the fields. Double-check before using — scanning can make mistakes."
        case .txScanUse: "Use these details"
        case .dashBalance: "Month balance"
        case .dashSavings: "Savings"
        case .dashToReceive: "To receive"
        case .dashOverdueStat: "Overdue"
        case .dashNoFunds: "No funds yet"
        case .dashFundsSummary: "%d fund(s) · %@"
        case .dashOthers: "+%d more"
        case .dashEvolution: "Trend · 6 months"
        case .dashNoMovement: "No activity in this period."
        case .dashBreakdown: "Expenses by category"
        case .dashNoExpenses: "No expenses this month."
        case .dashTotal: "Total"
        case .dashCategoriesCount: "%d categories"
        case .dashNoCategory: "Removed category"
        case .dashUpcoming7: "Next 7 days"
        case .dashNothingDue: "Nothing due in the next 7 days. 🎉"
        case .dashChartIncome: "Income"
        case .dashChartExpense: "Expenses"
        case .dashOverBy: "Over by %@"
        case .dashLeft: "%@ left"
        case .dashInvoices: "Bills"
        case .budEmptyTitle: "No budgets"
        case .budEmptySubtitle: "Set a monthly limit per category to track."
        case .budByCategory: "By category"
        case .budTotalLimit: "Total limit"
        case .budUsed: "Used"
        case .budOfTemplate: "%@ of %@"
        case .budOverBy: "Over limit by %@"
        case .budLeft: "%@ left"
        case .budMonthly: "Monthly"
        case .budNewTitle: "New budget"
        case .budEditTitle: "Edit budget"
        case .budLimitSection: "Monthly limit"
        case .budMonth: "Month"
        case .budYear: "Year: %d"
        case .budValidFor: "Valid for"
        case .budOnlyThisMonth: "This month only"
        case .budEveryMonth: "Every month (monthly)"
        case .budEditFootnote: "Category and month don't change; amount and recurrence do. Monthly applies to this and following months."
        case .budRecurringFootnote: "A monthly limit will be created starting %@ %d and for all following months."
        case .budSingleFootnote: "Valid only for %@ %d. If the category already has a limit this month, it will be updated."
        case .budErrCategory: "Choose a category."
        case .budErrAmount: "Limit must be greater than zero."
        case .budOverShort: "Over"
        case .catTitle: "Categories"
        case .catExpensesPlural: "Expenses"
        case .catIncomePlural: "Income"
        case .catEmptyTitle: "No categories"
        case .catEmptySubtitle: "Tap + to create the first one."
        case .catNewTitle: "New category"
        case .catEditTitle: "Edit category"
        case .catErrDuplicate: "A category with this name already exists for this type."
        case .fundEmptyTitle: "No funds"
        case .fundEmptySubtitle: "Create a fund to set money aside (e.g. Travel, Emergency)."
        case .fundMovementsCount: "%d transactions"
        case .fundAttention: "Heads up"
        case .fundDeleteBlocked: "“%@” has transactions and cannot be deleted (history preserved)."
        case .fundDeleteFailed: "Could not delete."
        case .fundMovementsSection: "Transactions"
        case .fundInitial: "initial %@"
        case .fundRemovedTitle: "Fund removed"
        case .fundRemovedSubtitle: "Go back to the list."
        case .fundWithdraw: "Withdraw"
        case .fundDeposit: "Deposit"
        case .fundDepositSection: "Deposit (bill)"
        case .fundNamePh: "Name (e.g. Travel)"
        case .fundNewTitle: "New fund"
        case .fundEditTitle: "Edit fund"
        case .fundAvailable: "Available: %@"
        case .fundLinkedFootnote: "It will be added as a bill linked to the fund."
        case .fundDefaultDeposit: "Deposit %@"
        case .fundDefaultWithdraw: "Withdraw %@"
        case .fundErrAmount: "Initial amount cannot be negative."
        case .fundErrBalance: "Insufficient balance for this withdrawal."
        case .fundDescriptionRequired: "Description is required."
        case .fundDate: "Date"
        case .fundErrPositive: "Amount must be greater than zero."
        case .wishEmptyTitle: "No lists"
        case .wishEmptySubtitle: "Create lists (e.g. Travel, Setup) and prioritize your wishes."
        case .wishPendingSummary: "%d pending · %@"
        case .wishAllBought: "All purchased 🎉"
        case .wishNamePh: "Name (e.g. Setup)"
        case .wishNewList: "New list"
        case .wishEditList: "Edit list"
        case .wishEmptyListTitle: "Empty list"
        case .wishEmptyListSubtitle: "Add the first wish."
        case .wishItems: "Items"
        case .wishReopen: "Reopen"
        case .wishBuy: "Buy"
        case .wishRemovedTitle: "List removed"
        case .wishRemovedSubtitle: "Go back to the lists."
        case .wishToGo: "Left to save"
        case .wishBought: "Purchased"
        case .wishDesire: "Wish"
        case .wishPriority: "Priority"
        case .wishPurchaseSection: "Purchase"
        case .wishGenerate: "Create bill"
        case .wishGenerated: "Bill created in Transactions ✅"
        case .wishGenerateFootnote: "Creates a one-time bill with the item's name, price and category."
        case .wishNewItem: "New wish"
        case .wishEditItem: "Edit wish"
        case .wishErrPrice: "Price must be greater than zero."
        case .wishErrGenerate: "Could not create the bill."
        case .quickAddTitle: "Log expense"
        case .quickAddHint: "From the shortcut — review and save."
        case .quickAddValueLabel: "Amount"
        case .quickAddDescLabel: "What?"
        case .entryChoiceTitle: "How to log it?"
        case .entryManual: "Manual entry"
        case .entryAI: "Smart entry"
        case .aiTitle: "Smart entry"
        case .aiPromptPh: "E.g.: paid 45 at the bakery yesterday"
        case .aiListen: "Dictate"
        case .aiStop: "Stop"
        case .aiListening: "Listening… tap Stop when done."
        case .aiHeardAs: "Understood"
        case .aiEmpty: "Describe the expense by text or voice — e.g.: paid 45 at the bakery yesterday."
        case .aiLowConfidence: "Partial understanding — double-check the fields before using."
        case .aiNoSpeech: "Could not understand the audio. Try again or type."
        case .aiNoPermission: "Allow microphone and speech recognition in Settings to dictate."
        case .aiUseData: "Use these details"
        case .aiTranscribing: "Transcribing…"
        case .aiEnhancing: "Interpreting with AI…"
        }
    }
}

// MARK: - Atalho nas Views (todas têm `store` no ambiente)

public extension Store {
    /// Idioma ativo (para `label(language:)` dos enums e locales).
    var lang: AppLanguage { settings.language }

    /// Texto localizado na língua ativa: `store.t(.save)`.
    /// Templates com formato usam `String(format:store.t(...), args)`.
    func t(_ key: L10nKey) -> String {
        L10n.t(key, settings.language)
    }
}
