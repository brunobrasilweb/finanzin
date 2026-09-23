# Finanzin — App Financeiro iOS (Swift)

PRD: `.codnia/notes/prd/finanzin-prd.md` · Plano: `.codnia/notes/plans/finanzin-implementation-plan.md`

Stack: Swift 6, SwiftUI, Charts, SwiftData (no Xcode) · iOS 17+ · 100% dark estilo Vercel · offline-first.

## Estrutura

- `Package.swift` — pacote SPM (`FinanzinCore`, `FinanzinUI`, `FinanzinCoreTests` executável)
- `Sources/FinanzinCore/` — domínio puro: `Enums`, `Models`, `TransactionEngine`, `Services` (Metrics/Fund/Budget), `Store` (memória + JSON), `Seed`, `Dates`, `Currency`
- `Sources/FinanzinUI/` — `Theme` + `RootTabView` (6 abas) + telas: Transações, Categorias, Fundos, Orçamento, Desejos, Dashboard (Charts)
- `FinanzinApp/FinanzinApp.swift` — entry `@main` para o projeto Xcode iOS
- `FinanzinApp/Assets.xcassets/` — catalog com slot `AppIcon` 1024 (adicionar PNG no Xcode)
- `XcodeOnly/SwiftDataModels.swift` — mapeamento para `@Model` (requer Xcode; `@Model` não resolve no CLT)
- `Tests/FinanzinCoreTests/` — 33 testes executáveis (padrão InoovexaAdmin, sem XCTest no CLT)

## Como rodar (demo macOS com dados de exemplo)

- **Duplo-clique:** abra `FinanzinDemo.app` no Finder (bundle gerado a partir do
  `swift build`; se o macOS reclamar, clique com botão direito → Abrir).
- **Terminal:** `swift run FinanzinDemo`
- Rebuild do bundle após mudanças: `swift build --target FinanzinDemo && cp .build/arm64-apple-macosx/debug/FinanzinDemo FinanzinDemo.app/Contents/MacOS/ && codesign --force -s - FinanzinDemo.app`

A demo abre a UI real (6 abas, dark) com massa de exemplo: 5 meses de salário/aluguel/mercado,
iPhone 10x, Uber a vencer, estacionamento vencido, fundo Viagem Japão + aporte,
orçamentos e lista Setup.

## Comandos (nesta máquina, sem Xcode)

```bash
swift build                  # compila Core + UI (macOS SDK)
swift run FinanzinCoreTests  # 33/33 testes
```

## Status

- [x] Sprint 0: fundação, theme dark, tabs, modelos, seed, 10/10 testes
- [x] Sprint 1: categorias (CRUD cor/ícone, nome único por tipo) + transações à vista (form com validação, lista mês/filtros/busca, baixa) — 14/14 testes
- [x] Sprint 2: parcelada (Nx + intervalo, rateio centavos) + fixa/recorrente (horizonte 24) + edição com escopo esta/futuras/todas + exclusão com escopo + cascade — 19/19 testes
- [x] Sprint 3: fundos (CRUD cor/ícone, aporte/saque como conta a pagar, saldo, extrato, bloqueio de exclusão com movimentos) — 23/23 testes
- [x] Sprint 4: orçamento mensal (limite por categoria/mês, barra limite vs utilizado, alertas 80%/estouro, totais) — 26/26 testes
- [x] Sprint 5: desejos (múltiplas listas cor/ícone, itens preço/prioridade/categoria, compra com data, gerar conta a pagar) — 30/30 testes
- [x] Sprint 6: dashboard (cards, barras 6m, donut, próximos 7d, deep-link categoria → transações) — 33/33 testes

## Rodar no iPhone (máquina COM Xcode 16+)

> O `.ipa` precisa ser compilado no Xcode — sem ele aqui, o `project.yml` gera o
> projeto pronto para abrir e rodar aí em 2 comandos.

```bash
brew install xcodegen        # só na primeira vez
xcodegen generate            # gera Finanzin.xcodeproj (já gerado e commitado)
open Finanzin.xcodeproj
```

> ⚠️ Na primeira vez o Xcode exige aceitar a licença (precisa da SUA senha, não
> consigo fazer daqui): `sudo xcodebuild -license accept` — ou abra o Xcode uma
> vez e clique em Agree.

No Xcode:
1. Selecione o target **Finanzin** → **Signing & Capabilities** → **Team**: seu Apple ID
   (Xcode → Settings → Accounts; conta gratuita funciona, app expira em ~7 dias).
2. Ajuste o Bundle ID se precisar (`br.inoovexa.finanzin`).
3. Conecte o iPhone via USB → **Confiar** no iPhone.
4. iPhone com **iOS 17+**. Troque o destino para **seu iPhone** → ▶ **Run**.
5. Se o iOS pedir: Ajustes → Geral → VPN e Gerenciamento de Dispositivo → confiar no Apple ID.
6. Sem fio depois do 1º run: Window → Devices and Simulators → **Connect via network**.

Dados no iPhone persistem em Application Support (`Store.defaultFileURL()`); a demo
macOS continua em memória (sempre fresca).

## QA antes do TestFlight (roteiro do PRD §5)

```bash
swift build && swift run FinanzinCoreTests  # 33/33
```

1. Criar categorias com cores → definir orçamentos do mês.
2. Lançar única + 10x mensal + fixa + recorrente; baixar a 3ª parcela; editar série (futuras); excluir série (todas).
3. Criar fundo, aportar como pagar, sacar (testar saldo insuficiente), tentar excluir fundo com movimentos.
4. Estourar um orçamento e conferir alerta vermelho; conferir totais.
5. Criar 2 listas de desejo, priorizar itens, comprar um, gerar conta a pagar.
6. Dashboard: conferir cards, barras, donut, próximos 7 dias; tocar categoria no donut e cair nas Transações filtradas.
7. No Xcode: Product → Archive → Distribute → TestFlight (interno), notas com o roteiro acima.

## Pendências conhecidas (PRD §10)

- Fixa gera 24 cópias mensais (decisão v1, confirmar).
- Orçamento soma pagas + pendentes (confirmar).
- Exclusão de fundo com saldo: bloqueada com movimentos (v1).
- Métrica principal do MVP ainda `[PENDENTE]` — definir antes do TestFlight.
- Persistência atual é memória + JSON; migrar para SwiftData no Xcode (`XcodeOnly/`).

> Nota: o modelo `Category` foi renomeado para `FinanceCategory` (colisão com o tipo
> Objective-C `Category` no SDK). `CategoryType` e `CategoryBreakdown` mantidos.
