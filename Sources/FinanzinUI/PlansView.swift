import SwiftUI
import FinanzinCore
#if canImport(StoreKit)
import StoreKit
#endif

// MARK: - Tela de planos (Free x Pro)
//
// Moderna e explicativa: herói + toggle mensal/anual + cards Básico/Pro +
// campo de cupom + CTA (compra só pela Apple via StoreKit) + termos.
// Modos: `.onboarding` (1ª abertura, com "Continuar no Básico") e
// `.upgrade` (coroa no topo / Configurações, sem empurrar o grátis).

public enum PlansMode {
    case onboarding
    case upgrade
}

public struct PlansView: View {
    // Dependências explícitas via `init` (em vez de `@EnvironmentObject`):
    // a tela nunca quebra por environment ausente (ex.: canvas de Preview
    // ou apresentação fora da hierarquia da raiz).
    @ObservedObject var store: Store
    @ObservedObject var entitlements: EntitlementService
    @Environment(\.dismiss) private var dismiss

    var mode: PlansMode

    @State private var yearly = true
    @State private var showCoupon = false
    @State private var couponCode = ""
    @State private var couponNote: String?
    @State private var showRedeem = false

    public init(mode: PlansMode, store: Store, entitlements: EntitlementService) {
        self.mode = mode
        self.store = store
        self.entitlements = entitlements
    }

    private var monthlyBase: Decimal { Decimal(string: "9.70") ?? 0 }
    private var yearlyBase: Decimal { Decimal(string: "97") ?? 0 }

    private var monthlyPrice: String {
        entitlements.price(for: EntitlementService.monthlyID, fallback: EntitlementService.monthlyPriceFallback)
    }

    private var yearlyPrice: String {
        entitlements.price(for: EntitlementService.yearlyID, fallback: EntitlementService.yearlyPriceFallback)
    }

    /// Preço com prévia do cupom (só exibição; a cobrança é a da Apple).
    private func shownPrice(base: Decimal, fallback: String) -> String {
        guard let tier = store.appliedCoupon else { return fallback }
        if tier.percent >= 100 { return store.t(.planFree) }
        return Format.currency(
            CouponPolicy.preview(base: base, percent: tier.percent),
            currencyCode: "BRL", localeIdentifier: "pt_BR"
        )
    }

    private var heroPrice: String {
        yearly
            ? shownPrice(base: yearlyBase, fallback: yearlyPrice)
            : shownPrice(base: monthlyBase, fallback: monthlyPrice)
    }

    public var body: some View {
        main
        #if os(iOS)
        #if canImport(StoreKit)
            // API legada (iOS 16+, vale no deploy 17): o completion é
            // `Result<Void, Error>` — a transação do resgate chega pelo
            // listener de `Transaction.updates` (ver `EntitlementService`).
            .offerCodeRedemption(isPresented: $showRedeem) { _ in
                Task { @MainActor in
                    if entitlements.devMode {
                        // Só p/ testar o fluxo no Xcode Debug (sem StoreKit).
                        if let tier = store.appliedCoupon { store.markCouponRedeemed(tier) }
                    } else {
                        await entitlements.refresh()
                        if store.isPro, let tier = store.appliedCoupon {
                            store.markCouponRedeemed(tier)
                        }
                    }
                }
            }
        #endif
        #endif
    }

    private var main: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FinSpacing.lg) {
                HStack {
                    Spacer()
                    HeaderButton("xmark") { dismiss() }
                        .accessibilityLabel(store.t(.close))
                }
                hero
                billingToggle
                proCard
                basicCard
                couponSection
                ctaBlock
            }
            .padding(.horizontal, FinSpacing.lg)
            .padding(.bottom, FinSpacing.xxl)
        }
        .finBackground()
    }

    // MARK: - Herói

    private var hero: some View {
        VStack(spacing: FinSpacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.16))
                    .frame(width: 76, height: 76)
                    .overlay(Circle().stroke(Color.yellow.opacity(0.4), lineWidth: 1))
                Image(systemName: "crown.fill")
                    .font(.title)
                    .foregroundStyle(.yellow)
            }
            Text(store.t(.planTitle))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(VercelTheme.textPrimary)
            Text(store.t(.planSubtitle))
                .font(.subheadline)
                .foregroundStyle(VercelTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Toggle mensal/anual

    private var billingToggle: some View {
        VStack(spacing: FinSpacing.sm) {
            Picker("", selection: $yearly) {
                Text(store.t(.planMonthly)).tag(false)
                Text(store.t(.planAnnual)).tag(true)
            }
            .pickerStyle(.segmented)
            if yearly {
                StatusPill(store.t(.planSaveBadge), color: .green)
            }
        }
    }

    // MARK: - Cards

    private var proCard: some View {
        VStack(alignment: .leading, spacing: FinSpacing.sm) {
            HStack {
                Text(store.t(.planPro))
                    .font(.headline)
                    .foregroundStyle(VercelTheme.textPrimary)
                StatusPill(store.t(.planPopular), color: .yellow)
                Spacer()
                Text(heroPrice)
                    .font(.title2.bold()).monospacedDigit()
                    .foregroundStyle(VercelTheme.textPrimary)
            }
            Divider().background(VercelTheme.border)
            planRow(icon: "arrow.left.arrow.right", label: store.t(.planFeatTx), value: store.t(.planValUnlimited), free: false)
            planRow(icon: "banknote", label: store.t(.planFeatAcct), value: store.t(.planValUnlimited), free: false)
            planRow(icon: "gauge.with.dots.needle.67percent", label: store.t(.planFeatBudget), value: store.t(.planValUnlimited), free: false)
            planRow(icon: "chart.pie.fill", label: store.t(.planFeatFunds), value: store.t(.planValUnlimited), free: false)
            planRow(icon: "heart.fill", label: store.t(.planFeatWish), value: store.t(.planValUnlimited), free: false)
            planRow(icon: "tag.fill", label: store.t(.planFeatCat), value: store.t(.planValUnlimited), free: false)
            planRow(icon: "bell.fill", label: store.t(.planFeatNotif), value: store.t(.planValUnlimited), free: false)
        }
        .finCard()
        .overlay(
            RoundedRectangle(cornerRadius: FinRadius.lg, style: .continuous)
                .stroke(Color.yellow.opacity(0.45), lineWidth: 1.5)
        )
    }

    private var basicCard: some View {
        VStack(alignment: .leading, spacing: FinSpacing.sm) {
            HStack {
                Text(store.t(.planBasic))
                    .font(.headline)
                    .foregroundStyle(VercelTheme.textPrimary)
                Spacer()
                Text(store.t(.planFree))
                    .font(.subheadline.bold())
                    .foregroundStyle(VercelTheme.textSecondary)
            }
            Divider().background(VercelTheme.border)
            planRow(icon: "arrow.left.arrow.right", label: store.t(.planFeatTx), value: store.t(.planValUnlimited), free: true)
            planRow(icon: "banknote", label: store.t(.planFeatAcct), value: store.t(.planVal121), free: true)
            planRow(icon: "gauge.with.dots.needle.67percent", label: store.t(.planFeatBudget), value: store.t(.planVal2), free: true)
            planRow(icon: "chart.pie.fill", label: store.t(.planFeatFunds), value: store.t(.planValNone), free: true)
            planRow(icon: "heart.fill", label: store.t(.planFeatWish), value: store.t(.planValNone), free: true)
            planRow(icon: "tag.fill", label: store.t(.planFeatCat), value: store.t(.planValEdit), free: true)
            planRow(icon: "bell.fill", label: store.t(.planFeatNotif), value: store.t(.planValNone), free: true)
        }
        .finCard()
    }

    private func planRow(icon: String, label: String, value: String, free: Bool) -> some View {
        HStack(spacing: FinSpacing.sm) {
            Image(systemName: free ? "minus.circle" : "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(free ? VercelTheme.textTertiary : .green)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(VercelTheme.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(VercelTheme.textSecondary)
        }
        .padding(.vertical, 3)
    }

    // MARK: - Cupom

    private var couponSection: some View {
        VStack(alignment: .leading, spacing: FinSpacing.sm) {
            Button {
                withAnimation { showCoupon.toggle() }
            } label: {
                HStack {
                    Image(systemName: "ticket.fill")
                        .foregroundStyle(.yellow)
                    Text(store.t(.planCoupon))
                        .font(.subheadline.bold())
                        .foregroundStyle(VercelTheme.textPrimary)
                    Spacer()
                    Image(systemName: showCoupon ? "chevron.up" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(VercelTheme.textTertiary)
                }
            }
            .buttonStyle(.plain)
            if showCoupon {
                HStack(spacing: FinSpacing.sm) {
                    TextField(store.t(.planCouponPh), text: $couponCode)
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .padding(.horizontal, FinSpacing.md)
                        .padding(.vertical, 10)
                        .background(VercelTheme.inset)
                        .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
                    Button(store.t(.planCouponApply)) { applyCoupon() }
                        .font(.subheadline.bold())
                        .padding(.horizontal, FinSpacing.md)
                        .padding(.vertical, 10)
                        .background(VercelTheme.inset)
                        .clipShape(RoundedRectangle(cornerRadius: FinRadius.md, style: .continuous))
                        .foregroundStyle(VercelTheme.textPrimary)
                }
                .buttonStyle(.plain)
                if let note = couponNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(VercelTheme.textSecondary)
                }
                if store.appliedCoupon != nil {
                    Text(store.t(.planRedeemNote))
                        .font(.footnote)
                        .foregroundStyle(VercelTheme.textSecondary)
                    #if os(iOS)
                    if !entitlements.devMode {
                        Button(store.t(.planRedeem)) { showRedeem = true }
                            .font(.subheadline.bold())
                            .foregroundStyle(.yellow)
                    }
                    #endif
                }
            }
        }
        .finCard()
    }

    private func applyCoupon() {
        switch store.applyCoupon(couponCode) {
        case .applied(let tier):
            couponNote = String(format: store.t(.planCouponOk), tier.percent)
        case .invalid:
            couponNote = store.t(.planCouponInvalid)
        case .locked(let secs):
            couponNote = String(format: store.t(.planCouponLocked), Int(secs))
        case .alreadyRedeemed:
            couponNote = store.t(.planCouponUsed)
        }
    }

    // MARK: - CTA

    @ViewBuilder
    private var ctaBlock: some View {
        if store.isPro {
            VStack(spacing: FinSpacing.sm) {
                HStack {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                    Text(store.t(.proActive))
                        .font(.subheadline.bold())
                        .foregroundStyle(VercelTheme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .finCard()
                #if os(iOS)
                if !entitlements.devMode {
                    Button(store.t(.planManage)) {
                        entitlements.manageSubscriptions()
                    }
                    .font(.subheadline)
                    .foregroundStyle(VercelTheme.textSecondary)
                }
                #endif
                if mode == .onboarding {
                    Button(store.t(.done)) { dismiss() }
                        .font(.headline)
                        .foregroundStyle(VercelTheme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(VercelTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: FinRadius.lg, style: .continuous))
                }
            }
        } else if entitlements.devMode {
            Text(store.t(.planDevNote))
                .font(.footnote)
                .foregroundStyle(VercelTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
            if mode == .onboarding {
                continueFreeButton
            }
        } else {
            VStack(spacing: FinSpacing.sm) {
                Button {
                    Task { @MainActor in
                        let id = yearly ? EntitlementService.yearlyID : EntitlementService.monthlyID
                        if await entitlements.purchase(productID: id) { dismiss() }
                    }
                } label: {
                    Text(String(
                        format: store.t(yearly ? .planCtaYearly : .planCtaMonthly),
                        heroPrice
                    ))
                    .font(.headline)
                    .foregroundStyle(VercelTheme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(entitlements.purchasing ? VercelTheme.textTertiary : VercelTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: FinRadius.lg, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(entitlements.purchasing)
                Button(store.t(.planRestore)) {
                    Task { @MainActor in
                        await entitlements.restore()
                        if store.isPro { dismiss() }
                    }
                }
                .font(.subheadline)
                .foregroundStyle(VercelTheme.textSecondary)
                Text(store.t(.planTerms))
                    .font(.caption)
                    .foregroundStyle(VercelTheme.textTertiary)
                    .multilineTextAlignment(.center)
                if mode == .onboarding {
                    continueFreeButton
                }
            }
        }
    }

    private var continueFreeButton: some View {
        Button(store.t(.planContinueFree)) { dismiss() }
            .font(.subheadline.bold())
            .foregroundStyle(VercelTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, FinSpacing.xs)
    }
}

// MARK: - Coroa de upgrade (topo das telas)

/// Abre `PlansView(.upgrade)` via `store.upgradeRequested` (sheet na raiz).
/// Com Pro mostra selo; no Free mostra coroa com ponto de atenção.
public struct UpgradeButton: View {
    @EnvironmentObject var store: Store

    public init() {}

    public var body: some View {
        Button { store.requestUpgrade() } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "crown.fill")
                    .font(.subheadline.bold())
                    .frame(width: 36, height: 36)
                    .background(VercelTheme.inset)
                    .foregroundStyle(store.isPro ? .yellow : VercelTheme.textPrimary)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(VercelTheme.border, lineWidth: 1))
                if !store.isPro {
                    Circle()
                        .fill(.red)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(VercelTheme.bg, lineWidth: 1.5))
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.t(.upgradeAcc))
    }
}

// MARK: - Previews (canvas do Xcode; nunca quebram por environment)

#if DEBUG
#Preview("Plans · onboarding") {
    let store = Store()
    return PlansView(mode: .onboarding, store: store, entitlements: EntitlementService(store: store))
}

#Preview("Plans · upgrade (Free)") {
    let store = Store()
    let entitlements = EntitlementService(store: store)
    // Simula o Free para visualizar gates e upsell (dev força Pro no init).
    store.setPro(false)
    return PlansView(mode: .upgrade, store: store, entitlements: entitlements)
}
#endif
