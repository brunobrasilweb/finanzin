---
title: "PRD - Finanzin"
tags: ["prd", "product-requirements", "finanzin"]
created: "2026-09-21T21:22:17Z"
---

# Finanzin — PRD

> **Versão:** 1.0 | **Data:** 2026-09-21 | **Status:** Rascunho
> **Projeto:** finanzin (novo app Swift iOS, pasta atual vazia)

## 1. Resumo Executivo

O **Finanzin** é um app financeiro pessoal nativo para iOS, para **indivíduo com iPhone** que precisa de controle simples de contas a pagar e a receber. Entrega paridade funcional com o módulo Financial do `InoovexaAdmin` macOS e com o `Inofinancy` Expo, porém em experiência mobile-first **moderna, clean e totalmente dark no estilo Vercel**, com **dashboard com gráficos**.
Impacto esperado no MVP: validar uso ativo local/offline e servir como fonte da verdade para evolução futura (sync, IA, família). `[INFERIDO]`.

## 2. Declaração do Problema

**Quem tem esse problema:**
Indivíduo iOS que controla finanças pessoais no dia a dia (resposta da entrevista: "Controle pessoal" + "Indivíduo iOS").

**Qual é o problema:**
Falta de controle de contas a pagar/receber à vista, parceladas, fixas e recorrentes, sem visão consolidada por categoria, fundos, orçamento mensal e desejos futuros.

**Por que é doloroso:**
Controle em planilhas/apps genéricos é trabalhoso, não trata parcelamento/recorrência, estoura orçamento por categoria sem alerta e mistura reserva de fundos com gasto corrente.

**Evidências:**
- Módulo Financial já existe no `InoovexaAdmin`: `Sources/InoovexaAdminCore/Models/FinancialModels.swift` (categorias, fundos, transações, parcelas, orçamentos, wishlist), `Enums/FinancialEnums.swift` (payable/receivable, unique/fixed/recurring/installment, pending/paid/canceled/overdue), views `FinancialDashboardView`, `FundListView`, `FinancialBudgetView`, `FinancialWishlistView`.
- Schema validado no `inofinancy/src/db/schema.ts` + `src/types/index.ts` (transactions, budget_limits, wishlist_items, MonthlyMetrics).
- `[PENDENTE]` Sem quotes/analytics formais de usuários iOS — validar no MVP.

## 3. Público-Alvo e Personas

### Persona Primária: Ana Controle Próprio
- **Perfil:** 25-45 anos, iPhone como dispositivo principal, controla contas sozinha.
- **Goals:** Saber quanto pode gastar no mês, não atrasar contas, juntar em fundos, planejar desejos.
- **Pain Points:** Parcelas esquecidas, fixas que variam, orçamento estourado sem aviso, dinheiro de fundo misturado.
- **Comportamento atual:** Planilha/notas + app banco; consulta admin desktop quando disponível `[INFERIDO]`.

### Persona Secundária: `[PENDENTE]`
- Familiar / autônomo como evolução futura. Fora do MVP.

## 4. Contexto Estratégico

**Objetivos de Negócio (OKRs):**
- `[PENDENTE]` Sem OKR formal (resposta: "Sem metas ainda"). Sugestão para MVP: Validar MVP — v1 usable offline com paridade funcional.

**Oportunidade de Mercado:**
- Portar domínio já modelado (admin + Inofinancy) para iOS nativo, onde está o uso diário.
- Diferencial: dark total estilo Vercel + dashboard com gráficos + fundos + múltiplas listas de desejo (gap vs. admin de lista única).

**Concorrência:**
- `[PENDENTE]` Mobills, Organizze, YNAB — abordam orçamento/transações, raramente fundos com aportes como "contas a pagar" + wishlist múltipla no mesmo app.

**Por que agora:**
- Domínio já especificado e validado no desktop; pasta `finanzin` vazia pronta para app Swift novo; demanda por versão mobile nativa para validação.

## 5. Visão Geral da Solução

App iOS nativo SwiftUI, offline-first, 100% dark. Navegação por abas: Dashboard, Transações, Fundos, Orçamento, Desejos + Config/Categorias. Design tokens dark estilo Vercel: fundo near-black (#09090b `[INFERIDO]`), cards #111113, bordas sutis, acento branco + cores semânticas de categoria/status.

**Principais Funcionalidades:**
1. **Transações:** pagar/receber, tipos à vista (`unique/single`), parcelada (`installment` com N parcelas + intervalo weekly/biweekly/monthly/yearly), fixa (`fixed`), recorrente (`recurring`); status pendente/pago/cancelado/vencido; filtros por mês/tipo/status/categoria.
2. **Categorias:** CRUD nome, tipo (receita/despesa), cor, ícone (SF Symbols).
3. **Fundos:** CRUD nome, valor inicial, obs, cor, ícone; detalhe com saldo = inicial + aplicações − saques; adicionar movimentação como conta a pagar (aporte para o fundo) + saque.
4. **Orçamento mensal por categoria:** definir limite mês/ano por categoria; listagem mensal limite vs. utilizado (transações do mês) com barra de progresso e alerta de estouro.
5. **Listas de desejo:** múltiplas listas (ex.: Viagem, Setup); itens com nome, preço, prioridade (baixa/média/alta ou 1-5), categoria; marcar comprado/converter em transação `[INFERIDO]`.
6. **Dashboard moderno:** saldos do mês (receitas, despesas, balanço, taxa poupança), evolução mensal em barras, donut por categoria, próximos vencimentos, pendentes/vencidos.
7. **Layout:** totalmente dark, clean, tipografia SF, gráficos nativos.

**Fluxo do Usuário:**
1. Cria categorias com cores → define orçamentos do mês.
2. Lança transações (avulsa/parcelada/fixa/recorrente) e marca pagas.
3. Cria fundo e faz aportes mensais como pagar.
4. Acompanha dashboard + orçamento; ajusta gastos.
5. Planeja desejos em listas e prioriza compra.

## 6. Métricas de Sucesso

### Métrica Principal
- **Indicador:** `[PENDENTE]` — sugestão: % semanas com app aberto + transações lançadas (ativação semanal).
- **Atual:** 0 | **Meta:** `[PENDENTE]`
- **Prazo:** 30 dias pós-TestFlight.

### Métricas Secundárias
- Paridade funcional v1: 7/7 módulos entregues — atual 0 → meta 7.
- Orçamentos respeitados: % categorias dentro do limite `[PENDENTE]`.
- Crash-free sessions > 99% `[INFERIDO]`.

### Métricas de Guardrail (o que NÃO pode piorar)
- Tempo para lançar transação < 30s `[INFERIDO]`.
- Sem perda de dados locais (SwiftData) — 0 incidentes.

## 7. Histórias de Usuário e Requisitos

### Épico
Como indivíduo iOS, quero controlar pagar/receber, fundos, orçamento e desejos num app dark rápido, para não atrasar contas e gastar dentro do limite.

### Histórias de Usuário

**US-001: Lançar transação à vista**
> Como usuário, quero lançar conta a pagar/receber única para registrar gasto/ganho.
**Critérios de Aceitação:**
- [ ] Campos: descrição, tipo (pagar/receber), valor, categoria, vencimento, status, obs.
- [ ] Salva offline e aparece na lista do mês e no dashboard.
- [ ] Validação: valor > 0, descrição obrigatória.

**US-002: Parcelar transação**
> Como usuário, quero parcelar em Nx para acompanhar parcelas.
**Critérios de Aceitação:**
- [ ] Informa N parcelas + intervalo (semanal/quinzenal/mensal/anual).
- [ ] Gera parcelas com vencimento, valor, número, status pendente.
- [ ] Baixa individual por parcela sem afetar demais.

**US-003: Fixa e recorrente**
> Como usuário, quero marcar fixa/recorrente para não relançar todo mês.
**Critérios de Aceitação:**
- [ ] Fixa: replica competência mensal até data fim (se houver).
- [ ] Recorrente: regra de repetição com intervalo.
- [ ] Permite encerrar/cancelar futuras `[INFERIDO]`.

**US-004: Categorias com cores**
> Como usuário, quero categorias com cor/ícone para identificar gastos.
**Critérios de Aceitação:**
- [ ] CRUD nome, tipo receita/despesa, cor hex, ícone SF Symbol.
- [ ] Cor usada em listas, donut e orçamento.

**US-005: Fundos com aportes**
> Como usuário, quero criar fundo (nome, valor inicial, obs, cor, ícone) e aportar via conta a pagar.
**Critérios de Aceitação:**
- [ ] Saldo = inicial + aplicações − saques, recalculado a cada movimentação.
- [ ] Aporte cria transação pagar vinculada ao fundo (fundMovementType=application).
- [ ] Saque (withdrawal) com validação de saldo `[INFERIDO]`.

**US-006: Orçamento mensal**
> Como usuário, quero limite por categoria/mês e ver utilizado.
**Critérios de Aceitação:**
- [ ] Define limite por categoria + mês/ano.
- [ ] Listagem mostra limite, utilizado (soma pagar do mês), % e barra.
- [ ] Alerta visual ao ultrapassar 80%/100% `[INFERIDO]`.

**US-007: Listas de desejo múltiplas**
> Como usuário, quero várias listas com itens (nome, preço, prioridade, categoria).
**Critérios de Aceitação:**
- [ ] CRUD de listas + CRUD de itens dentro da lista.
- [ ] Prioridade baixa/média/alta, preço BRL, categoria opcional.
- [ ] Marcar comprado (data) e opcional gerar transação pagar `[INFERIDO]`. Diferença vs. admin (lista única `financial_wishlist`).

**US-008: Dashboard com gráficos**
> Como usuário, quero dashboard mensal com gráficos para decidir.
**Critérios de Aceitação:**
- [ ] Cards: receitas, despesas, balanço, a pagar/receber pendentes, vencidos.
- [ ] Gráfico barras evolução mensal + donut por categoria (Swift Charts).
- [ ] Filtro de mês; toque em categoria filtra transações `[INFERIDO]`.

**US-009: Dark Vercel total**
> Como usuário, quero layout moderno clean 100% dark.
**Critérios de Aceitação:**
- [ ] Sem modo claro no v1; contraste AA; SF Symbols consistentes.
- [ ] TabBar + cards escuros, estados vazios ilustrados.

### Restrições Técnicas
- Swift 6, SwiftUI, iOS 17+ `[INFERIDO]`, SwiftData offline-first, Swift Charts, SF Symbols, moeda BRL, `Decimal` para valores.
- Sem backend/Postgres no v1 (diferente do admin); sem sync nuvem.
- Modelo espelha `FinancialModels.swift` + nova entidade `Wishlist` (pai de itens).

### Casos de Borda
- Parcela com centavos: rateio com ajuste na última.
- Fixa sem data fim: exige confirmação de continuidade.
- Excluir categoria em uso: manter transação com categoria nula + aviso.
- Excluir fundo com saldo: bloquear ou exigir transferência `[PENDENTE decisão]`.
- Orçamento duplicado categoria/mês/ano: upsert, não duplicar.
- Moeda: apenas BRL no v1.

## 8. Fora do Escopo

| Item | Motivo |
| ---- | ------ |
| Sync nuvem, login/multiusuário | v1 somente local (resposta entrevista) |
| Open Finance / importação bancária | Complexidade regulatória, pós-MVP |
| Backend Postgres do admin | Manter MVP offline; migração futura `[PENDENTE]` |
| IA / insights automáticos | Existe no admin/Inofinancy, não no v1 iOS |
| Widgets, notificações push, Apple Watch | Pós-MVP |
| Modo claro, iPad otimizado | Foco iPhone dark |
| Multicarteira/contas bancárias | Fundos cobrem reserva no v1 |

## 9. Dependências e Riscos

### Dependências
- **Técnicas:** Xcode + SwiftData, Swift Charts (iOS 16+), SF Symbols `[INFERIDO Stack Apple local]`.
- **Externas:** Nenhuma no v1 (sem backend).
- **Time:** Design tokens dark Vercel a definir; decisão regra fixa vs. recorrente.

### Riscos e Mitigações
| Risco | Probabilidade | Impacto | Mitigação |
| ----- | ------------- | ------- | --------- |
| Regra parcelamento/recorrência divergir do admin | Alta | Alto | Espelhar `FinancialEnums` + testes de datas/valores; spike de calendário |
| Cálculo saldo fundos incorreto | Média | Alto | Testes unitários saldo = inicial + aportes − saques; lista auditável |
| Escopo wishlist múltipla crescer | Média | Médio | Modelar Lista→Itens desde v1; não reaproveitar tabela única |
| Performance dashboard com muitas tx | Baixa | Médio | Agregação mensal paginada, índices por data/categoria |
| Migração dados admin/Expo futura | Média | Médio | Manter IDs UUID + export JSON desde v1 |

## 10. Perguntas em Aberto

- [ ] Fixa vs. recorrente: fixa gera cópias mensais automáticas ou apenas repete visualmente? — `[PENDENTE]`
- [ ] Fundos permitem rendimento/juros ou só soma simples? — `[PENDENTE]`
- [ ] Excluir fundo com saldo: bloquear, zerar ou transferir? — `[PENDENTE]`
- [ ] Orçamento conta apenas pagas ou também pendentes? Proposta: pendentes+pagas do mês `[INFERIDO]` — confirmar.
- [ ] Moeda única BRL? Multimoeda futura? — `[PENDENTE]`
- [ ] Converter desejo comprado automaticamente em transação? — `[PENDENTE]`

---

## Notas e Pontos de Atenção

> ⚠️ Domínio já bem modelado — reutilizar tipos e regras do admin reduz risco. Maior atenção para: (1) nova entidade Lista de Desejos (quebra da premissa de lista única), (2) semântica de aporte em fundo como "conta a pagar", (3) definição de métrica principal pendente antes do TestFlight. Recomendo spike técnico de SwiftData + Charts + regra de parcelas antes do sprint 1.
