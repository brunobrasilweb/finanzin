---
title: "Plano de Implementação - Finanzin iOS"
tags: ["plan", "finanzin", "ios"]
created: "2026-09-21T21:24:22Z"
---

# Plan: Finanzin iOS — App Financeiro SwiftUI

**Generated**: 2026-09-21
**Estimated Complexity**: High
**PRD base**: `.codnia/notes/prd/finanzin-prd.md` v1.0
**Referências**: `inoovexa/admin` (`FinancialModels.swift`, `FinancialEnums.swift`, `FinancialDashboardView`, `FundListView`, `FinancialBudgetView`, `FinancialWishlistView`) + `inofinancy` (`src/db/schema.ts`, `transaction.service.ts`, `metrics.service.ts`)

## Overview

Criar app iOS nativo novo na pasta vazia `finanzin/` com Swift 6, SwiftUI, SwiftData offline-first, Swift Charts, 100% dark estilo Vercel. Paridade com admin/Inofinancy + diferencial de múltiplas listas de desejo.

Abordagem: Xcode App project (não SPM puro como o admin), schema SwiftData espelhando domínio validado, lógica de parcelas/recorrência portada do `transaction.service.ts`, agregações portadas do `metrics.service.ts`, UI por abas demoável a cada sprint.

Decisões assumidas `[INFERIDO]`: iOS 17+, Xcode 16+, BRL único, `Decimal` persistido como `Double`/`String` com cuidado de arredondamento, horizonte fixa/recorrente 24 meses (igual `RECURRING_HORIZON_MONTHS`), sem backend/auth/sync no v1.

## Prerequisites

- macOS com Xcode 16+ e iOS 17 SDK
- Conta Apple Developer para TestFlight (Sprint 6)
- Padrões: `Decimal` para dinheiro, datas `Date` + competência mensal `yyyy-MM-01`, UUID string como IDs
- Design tokens dark a criar em `Theme/`

## Estrutura de pastas proposta

```
Finanzin/
  Finanzin.xcodeproj
  Finanzin/
    App/FinanzinApp.swift
    Theme/Colors.swift, Typography.swift
    Models/Category.swift, Transaction.swift, Installment.swift, Fund.swift, BudgetLimit.swift, Wishlist.swift, WishlistItem.swift, Enums.swift
    Services/TransactionEngine.swift, MetricsService.swift, FundService.swift, BudgetService.swift, SeedService.swift
    Views/Dashboard/, Transactions/, Categories/, Funds/, Budget/, Wishlist/, Components/
  FinanzinTests/
```

## Sprint 0: Setup + Fundação
**Goal**: Projeto compila, roda, navega em dark, SwiftData funcional.
**Demo/Validation**:
- `xcodebuild -scheme Finanzin -destination 'platform=iOS Simulator,name=iPhone 16' build`
- Abrir app: TabBar dark com 6 abas placeholder + toggle de mês.

### Task 0.1: Criar projeto Xcode
- **Location**: `Finanzin/Finanzin.xcodeproj`, `Finanzin/App/FinanzinApp.swift`
- **Description**: Xcode iOS App, SwiftUI, SwiftData, iOS 17+, Bundle ID `br.inoovexa.finanzin`, dark default (`.preferredColorScheme(.dark)`).
- **Dependencies**: Nenhuma
- **Acceptance Criteria**:
  - Compila no simulador iPhone
  - Sem storyboard, entry SwiftUI
- **Validation**: build + run manual

### Task 0.2: Theme dark Vercel + navegação
- **Location**: `Finanzin/Theme/Colors.swift`, `Finanzin/App/RootTabView.swift`, `Components/EmptyStateView.swift, MonthPicker.swift, AmountText.swift`
- **Description**: Tokens `bg #09090B`, `card #111113`, `border #1F1F23`, texto primário/secundário, semânticas payable `#EF4444` / receivable `#10B981` / pending `#F59E0B`; TabView: Dashboard, Transações, Fundos, Orçamento, Desejos, Mais/Categorias.
- **Dependencies**: 0.1
- **Acceptance Criteria**:
  - 100% telas dark, contraste legível, SF Symbols
  - Componentes reutilizáveis criados
- **Validation**: snapshot manual + preview SwiftUI

### Task 0.3: Schema SwiftData + Enums
- **Location**: `Finanzin/Models/*.swift`
- **Description**: Portar `FinancialModels.swift` + `FinancialEnums.swift` para `@Model`: Category(id, name, type income/expense, color, icon), Transaction(parent linkage, type payable/receivable, recurrence unique/fixed/recurring/installment, status pending/paid/cancelled/overdue, amount Decimal, dueDate, paidDate, total/currentInstallment, periodType/Interval), Fund(name, initialAmount, color, icon, notes), BudgetLimit(category, month, year, limitAmount), Wishlist(id, name, color, icon), WishlistItem(wishlist ref, name, price, priority low/medium/high, category ref, purchased, purchasedDate). Nova entidade `Wishlist` (diferença vs admin lista única).
- **Dependencies**: 0.1
- **Acceptance Criteria**:
  - ModelContainer em memória funciona em previews/testes
  - Migração leve habilitada
- **Validation**: teste unitário cria/lê cada modelo

### Task 0.4: Seed + utilidades
- **Location**: `Finanzin/Services/SeedService.swift`, `Utils/Currency.swift, Dates.swift`
- **Description**: Seed de categorias padrão (Mercado, Moradia, Transporte...), formatação BRL, helpers competência mensal, geração UUID.
- **Dependencies**: 0.3
- **Acceptance Criteria**: Fresh install já tem 8-10 categorias
- **Validation**: rodar app limpo e listar categorias

## Sprint 1: Categorias + Transações à vista
**Goal**: CRUD completo do ciclo básico mensal.
**Demo**: Criar categoria com cor → lançar pagar/receber única → filtrar por mês/tipo/status → dar baixa.

### Task 1.1: CRUD Categorias
- **Location**: `Views/Categories/*`, `Services/CategoryService.swift` (ou SwiftData direto)
- **Description**: Lista, criar/editar/excluir com color picker + SF Symbol picker; validação nome único por tipo.
- **Dependencies**: Sprint 0
- **Acceptance Criteria**: Cor refletida em listas; excluir categoria em uso seta `category=nil` + aviso (edge PRD)
- **Validation**: testes CRUD + exclusão em uso

### Task 1.2: Form + lista de transações únicas
- **Location**: `Views/Transactions/TransactionFormView.swift, TransactionListView.swift`, `Services/TransactionEngine.swift`
- **Description**: Campos descrição, tipo, valor (>0), categoria, vencimento, status, obs; lista do mês com busca, filtros tipo/status/categoria; swipe dar baixa.
- **Dependencies**: 1.1
- **Acceptance Criteria**: Salva offline, aparece na competência correta; validação valor/descrição
- **Validation**: testes criação/listagem por mês (espelhar `listTransactionsForMonth`)

### Task 1.3: Baixa e status
- **Location**: `TransactionEngine.togglePaid()`
- **Description**: paid ⇄ pending com paidDate, cancelled, cálculo de vencido (`dueDate < hoje && pending`).
- **Dependencies**: 1.2
- **Acceptance Criteria**: Vencidos destacados em vermelho
- **Validation**: teste de transição de status

## Sprint 2: Parcelamento + Fixa/Recorrente
**Goal**: Regra mais arriscada isolada e testada.
**Demo**: Lançar 10x mensal → ver 10 parcelas → baixar 3ª sem afetar demais → criar fixa → ver 24 competências futuras.

### Task 2.1: Motor de parcelas
- **Location**: `Services/TransactionEngine.swift::createInstallments()`, `Utils/Dates.swift`
- **Description**: Portar `generateInstallmentDates` + rateio com ajuste na última (`round` + diff), parent_id linkage, current/total.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**: Soma parcelas == total (centavos ok)
- **Validation**: testes 3x 100.00, 10x 1000.00, semanal/anual

### Task 2.2: Fixa e recorrente (horizonte 24m)
- **Location**: `TransactionEngine.createRecurring()`
- **Description**: Portar lógica `fixed` (mensal) / `recurring` (weekly/biweekly/monthly/yearly + interval) com horizonte 24; parent linkage.
- **Dependencies**: 2.1
- **Acceptance Criteria**: Fixa sem fim exige confirmação (edge PRD)
- **Validation**: testes geração 24 itens, yearly, biweekly 15 dias (igual Inofinancy)

### Task 2.3: Edição/exclusão com escopo
- **Location**: `TransactionEngine.edit(scope: .this/.future/.all)`, sheets de confirmação
- **Description**: Portar `editTransaction`/`deleteTransaction` com escopos; UI "somente esta / futuras / todas".
- **Dependencies**: 2.1, 2.2
- **Acceptance Criteria**: Editar futura não altera passadas; excluir parent exclui filhas com confirmação
- **Validation**: testes de escopo

## Sprint 3: Fundos
**Goal**: Reservas separadas do fluxo.
**Demo**: Criar fundo Viagem R$500 inicial roxo → aportar R$200 como pagar → ver saldo R$700 + extrato → sacar R$100.

### Task 3.1: CRUD Fundos
- **Location**: `Models/Fund.swift`, `Views/Funds/FundListView.swift, FundFormView.swift, FundDetailView.swift`
- **Description**: Campos nome, valor inicial, obs, cor, ícone; cards com saldo e progresso.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**: Validação nome/valor inicial >=0
- **Validation**: testes CRUD

### Task 3.2: Movimentações application/withdrawal
- **Location**: `Services/FundService.swift`
- **Description**: Aporte = Transaction payable vinculada (`fundID` + `fundMovementType=application`); saque = withdrawal com validação de saldo; saldo = inicial + aplicações − saques; extrato ordenado.
- **Dependencies**: 3.1 + Sprint 2
- **Acceptance Criteria**: Sem saldo negativo sem confirmação; excluir fundo com saldo bloqueia/pergunta (pendência PRD — implementar bloqueio + alerta v1)
- **Validation**: testes saldo, saque acima do saldo, vínculo transação-fundo

## Sprint 4: Orçamento mensal
**Goal**: Limite vs utilizado por categoria.
**Demo**: Definir Mercado R$1500 out/2026 → lançar R$400 → ver barra 27% → estourar e ver vermelho.

### Task 4.1: CRUD limites + listagem mensal
- **Location**: `Services/BudgetService.swift`, `Views/Budget/BudgetListView.swift, BudgetFormView.swift`, `Components/BudgetBar.swift`
- **Description**: Upsert único por (category, month, year); soma utilizado = payable do mês (pendentes+pagas `[INFERIDO]`); % + barra 80% amarelo / 100% vermelho.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**: Sem duplicata categoria/mês; mostra limite, usado, restante
- **Validation**: testes agregação, upsert, estouro

### Task 4.2: Alertas e atalhos
- **Location**: `BudgetListView`, integração Dashboard
- **Description**: Badge de estouro, atalho "ver transações da categoria no mês".
- **Dependencies**: 4.1
- **Acceptance Criteria**: Navegação cruzada funciona
- **Validation**: manual

## Sprint 5: Listas de Desejo (múltiplas)
**Goal**: Diferencial vs admin.
**Demo**: Criar listas Viagem + Setup → adicionar iPhone R$5000 alta em Setup → marcar comprado → gerar pagar.

### Task 5.1: Listas + itens
- **Location**: `Models/Wishlist.swift`, `Views/Wishlist/*`
- **Description**: CRUD listas; CRUD itens (nome, preço BRL, prioridade, categoria opcional, link/obs opcionais); ordenação por prioridade/preço.
- **Dependencies**: Sprint 1
- **Acceptance Criteria**: Múltiplas listas independentes; prioridade com cor (low cinza / medium âmbar / high vermelho)
- **Validation**: testes CRUD aninhado, cascade delete

### Task 5.2: Comprar → transação
- **Location**: `WishlistService.purchase()`
- **Description**: Marcar comprado com data + ação "gerar conta a pagar" pré-preenchida.
- **Dependencies**: 5.1
- **Acceptance Criteria**: Item comprado sai da soma pendente; transação vinculada opcional
- **Validation**: teste purchase flow

## Sprint 6: Dashboard + Polish + TestFlight
**Goal**: Valor visível + release.
**Demo**: Abrir outubro com cards, barras 6 meses, donut por categoria, próximos 7 dias, tudo dark.

### Task 6.1: Agregações mensais
- **Location**: `Services/MetricsService.swift`
- **Description**: Portar `getMonthlyMetrics`, `getCategoryBreakdown`, `getMonthlyEvolution(6)`, `getUpcomingDue(7)` para SwiftData (predicates por competência).
- **Dependencies**: Sprints 1-2
- **Acceptance Criteria**: paid vs pending, overdue só payable, savingsRate
- **Validation**: testes com massa fixa comparada ao Inofinancy

### Task 6.2: UI Dashboard Charts
- **Location**: `Views/Dashboard/DashboardView.swift`, `Components/StatCard.swift, MonthlyBars.swift, DonutChart.swift, UpcomingList.swift`
- **Description**: Swift Charts bars + donut, MonthPicker, pull-to-refresh, empty states, tap categoria → filtra transações.
- **Dependencies**: 6.1
- **Acceptance Criteria**: <16ms scroll, sem flash claro, VoiceOver básico
- **Validation**: manual + perf no device

### Task 6.3: QA, ícone, TestFlight
- **Location**: `Assets`, `FinanzinTests/`, CI manual
- **Description**: AppIcon dark, launch screen, testes fim-a-fim do roteiro PRD (fluxo 1-5), `xcodebuild test`, archive + TestFlight interno, notas de release.
- **Dependencies**: Todas
- **Acceptance Criteria**: 0 crash no roteiro, crash-free alvo 99%
- **Validation**: `xcodebuild test -scheme Finanzin`, instalação TestFlight

## Testing Strategy

- Unit por sprint: engine parcelas (soma exata), recorrência (24 itens), saldo fundos, agregações orçamento/dashboard, escopos this/future/all.
- UI manual: roteiro PRD §5 (categorias → orçamentos → transações → fundos → dashboard → desejos).
- SwiftData em memória para testes; massa seed fixa para comparar com `metrics.service.ts`.
- Device real no Sprint 6 para Charts + dark + performance.

## Potential Risks & Gotchas

- **Decimal em SwiftData**: admin serializa Decimal como String; definir `Double` + `Decimal` só em UI ou `Transformable` testado — mitigar com testes de centavos desde Sprint 2.
- **Fixa vs recorrente ambígua** (pendência PRD §10): v1 = fixa gera 24 cópias mensais editáveis por escopo; documentar e confirmar antes do Sprint 2.
- **Orçamento conta pendentes?** Assumido sim (pendentes+pagas); se mudar, só ajustar predicate em `BudgetService` — isolado.
- **Wishlist única → múltipla**: não reaproveitar migração do admin; entidade nova evita corrupção.
- **Swift Charts iOS 17**: checar API `Charts` disponível; fallback para barras custom se preciso.
- **Performance**: agregações por mês com predicate indexado (dueDate, type, status); evitar fetch-all.
- **Escopo crescendo (notificações/widgets/sync)**: explicitamente fora do v1 — recusar no review de sprint.

## Rollback Plan

- Cada sprint é branch/PR independente (`sprint-0-setup`, ..., `sprint-6-dashboard`); revert por PR.
- SwiftData: versioned schema desde v1 para migração leve; se quebrar, apagar container dev (sem dados prod no v1).
- Sem backend: sem migração servidor; TestFlight usa build numerado, rollback = reinstalar build anterior.

## Ordem de execução sugerida

Sprint 0 → 1 → 2 → 3 → 4 → 5 → 6. Paralelizável após Sprint 1: Fundos (3) e Orçamento (4) e Desejos (5) em paralelo por pessoa diferente, pois só dependem de Transações/Categorias. Dashboard (6) por último.
