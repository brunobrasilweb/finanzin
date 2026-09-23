# AGENTS.md — Finanzin

## Commands (this machine has CLT only, no Xcode)

```bash
swift build                  # compiles Core + UI (macOS SDK)
swift run FinanzinCoreTests  # runs the 33 tests — NOT `swift test` (no testTarget, errors "no tests found")
swift run FinanzinDemo       # opens real UI with seed data (macOS)
```

Rebuild the double-clickable bundle after changes:
```bash
swift build --target FinanzinDemo && cp .build/arm64-apple-macosx/debug/FinanzinDemo FinanzinDemo.app/Contents/MacOS/ && codesign --force -s - FinanzinDemo.app
```

iOS device run (machine WITH Xcode 16+ only): `xcodegen generate && open Finanzin.xcodeproj` — this dir only edits sources.

## Architecture

- SPM (`Package.swift`): `FinanzinCore` (pure domain, no SwiftUI) ← `FinanzinUI` (SwiftUI + Charts) ← executables `FinanzinCoreTests`, `FinanzinDemo`.
- `Sources/FinanzinCore/`: `Models` + `Enums` + `TransactionEngine` (installment split / 24-copy fixed) + `Services` (Metrics/Fund/Budget) + `Store` (in-memory + JSON) + `Seed` + `Dates` + `Currency`.
- `Sources/FinanzinUI/`: `Theme` (tokens/modifiers) + `RootTabView` (6 tabs) + one `*Views.swift` per tab.
- Entries: iOS `@main` is `FinanzinApp/FinanzinApp.swift`; macOS demo `@main` is `Sources/FinanzinDemo/`. `XcodeOnly/SwiftDataModels.swift` is doc-only mapping, never compiled in SPM.

## Quirks agents miss

- Tests are an `executableTarget` with a hand-rolled `check()` (no XCTest — CLT lacks the module). Same pattern as InoovexaAdmin. Run the single binary; there is no single-test filter.
- Never add `Sources/FinanzinDemo` to the iOS target (`project.yml`): duplicate `@main` breaks the build.
- Never import SwiftData / `@Model` into `Sources/`: it doesn't resolve under CLT. Persist via `Store`; convert `Decimal↔Double` only at the SwiftData boundary per `XcodeOnly/`.
- `Category` is named `FinanceCategory` — plain `Category` collides with ObjC `Category` in the SDK.
- `Store` privacy mode: `valuesHidden` (UserDefaults) + `maskedAmount()` — new money text must use `maskedAmount`/`AmountText(..., hidden:)`, never `Format.currency` directly.
- UI rows: clean lists use `.finCleanRow()` + `.finCleanList()` (transparent + separator, e.g. Transações/Orçamento/Desejos); boxed cards use `.finRow()` + `.finList()`. Screens need `.finBackground()` + `.finHideNavBar()` (root) or `.finDetailChrome()` (detail) or the notch/tab bar flashes light.
- Persistence differs: iPhone uses `Store.defaultFileURL()` (Application Support); macOS demo is memory-only, always fresh.
- No CI / lint / formatter config. Verify with `swift build && swift run FinanzinCoreTests`. Commits here use `feat: ...` (conventional, lowercase).
