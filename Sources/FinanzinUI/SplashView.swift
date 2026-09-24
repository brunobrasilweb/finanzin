import SwiftUI
import FinanzinCore

// MARK: - Splash inicial (logo + nome com animação de montagem)
//
// Geometria autoritativa do `icon.svg` (Inkscape): 5 retângulos brancos
// já com as transformações do SVG aplicadas (viewBox 158.31×119.16):
// barra superior, diagonal (rotate 35.17°), barra inferior e 2 serifes.
// A animação desenha o contorno de cada peça em sequência (montagem)
// e o preenchimento fiel assume no fim.
// O `RootTabView` monta o dashboard por baixo e dispensa o overlay após
// ~1.5s — ver `showSplash` lá.

/// Uma peça do glifo (retângulo/paralelogramo em unidades do viewBox).
private struct GlyphPiece: Shape {
    /// Cantos em ordem de perímetro: TL, TR, BR, BL.
    let corners: [CGPoint]

    func path(in rect: CGRect) -> Path {
        func pt(_ p: CGPoint) -> CGPoint {
            CGPoint(
                x: rect.minX + p.x / 158.30669 * rect.width,
                y: rect.minY + p.y / 119.15643 * rect.height
            )
        }
        var path = Path()
        path.move(to: pt(corners[0]))
        for c in corners.dropFirst() {
            path.addLine(to: pt(c))
        }
        path.closeSubpath()
        return path
    }
}

/// Peças na ordem de montagem: o Z primeiro, depois os serifes.
private let glyphPieces: [GlyphPiece] = [
    // Barra superior.
    GlyphPiece(corners: [
        CGPoint(x: 45.00, y: 18.91), CGPoint(x: 158.31, y: 18.91),
        CGPoint(x: 158.31, y: 39.08), CGPoint(x: 45.00, y: 39.08),
    ]),
    // Diagonal.
    GlyphPiece(corners: [
        CGPoint(x: 44.97, y: 18.93), CGPoint(x: 122.85, y: 84.41),
        CGPoint(x: 113.10, y: 100.90), CGPoint(x: 35.23, y: 35.42),
    ]),
    // Barra inferior.
    GlyphPiece(corners: [
        CGPoint(x: 0.00, y: 80.68), CGPoint(x: 113.01, y: 80.68),
        CGPoint(x: 113.01, y: 100.86), CGPoint(x: 0.00, y: 100.86),
    ]),
    // Serife superior.
    GlyphPiece(corners: [
        CGPoint(x: 86.71, y: 0.00), CGPoint(x: 116.59, y: 0.00),
        CGPoint(x: 116.59, y: 20.18), CGPoint(x: 86.71, y: 20.18),
    ]),
    // Serife inferior.
    GlyphPiece(corners: [
        CGPoint(x: 42.27, y: 98.98), CGPoint(x: 72.14, y: 98.98),
        CGPoint(x: 72.14, y: 119.16), CGPoint(x: 42.27, y: 119.16),
    ]),
]

public struct SplashView: View {
    private static let glyphWidth: CGFloat = 148
    private static var glyphHeight: CGFloat { glyphWidth * 119.15643 / 158.30669 }
    /// Janela de desenho por peça (fração do progresso total) e atraso
    /// entre peças: 4 × 0.16 + 0.36 = 1.0.
    private static let pieceWindow: CGFloat = 0.36
    private static let pieceStagger: CGFloat = 0.16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawProgress: CGFloat = 0
    @State private var fillOpacity: Double = 0
    @State private var showName = false

    public init() {}

    public var body: some View {
        ZStack {
            VercelTheme.bg.ignoresSafeArea()
            VercelTheme.topGlow.ignoresSafeArea()
            VStack(spacing: FinSpacing.xl) {
                Spacer()
                // Cada peça desenha seu contorno em sequência; o fill
                // exato de todas assume junto no fim (mesma cor).
                ZStack {
                    ForEach(glyphPieces.indices, id: \.self) { i in
                        glyphPieces[i]
                            .trim(from: 0, to: pieceFraction(i))
                            .stroke(
                                VercelTheme.textPrimary,
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                            .opacity(1 - fillOpacity)
                        glyphPieces[i]
                            .fill(VercelTheme.textPrimary)
                            .opacity(fillOpacity)
                    }
                }
                .frame(width: Self.glyphWidth, height: Self.glyphHeight)
                .accessibilityHidden(true)
                // Nome com fade + subida + blur (entra com atraso).
                Text("Finanzin")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(VercelTheme.textPrimary)
                    .opacity(showName ? 1 : 0)
                    .offset(y: showName ? 0 : 10)
                    .blur(radius: showName ? 0 : 4)
                    .accessibilityLabel("Finanzin")
                Spacer()
                // Indicador discreto de carregamento do dashboard.
                ProgressView()
                    .tint(VercelTheme.textTertiary)
                    .opacity(showName ? 1 : 0)
                    .padding(.bottom, FinSpacing.xxl)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, FinSpacing.xxl)
        }
        .onAppear { animate() }
    }

    /// Fração desenhada da peça `i` dado o progresso global 0→1.
    private func pieceFraction(_ i: Int) -> CGFloat {
        let raw = (drawProgress - CGFloat(i) * Self.pieceStagger) / Self.pieceWindow
        return min(max(raw, 0), 1)
    }

    private func animate() {
        if reduceMotion {
            drawProgress = 1
            fillOpacity = 1
            showName = true
            return
        }
        // Montagem das 5 peças: ~1.2s; fill assume em 1.0–1.35s;
        // nome entra com ~0.5s de atraso.
        withAnimation(.easeInOut(duration: 1.2)) {
            drawProgress = 1
        }
        withAnimation(.easeOut(duration: 0.35).delay(1.0)) {
            fillOpacity = 1
        }
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            showName = true
        }
    }
}
