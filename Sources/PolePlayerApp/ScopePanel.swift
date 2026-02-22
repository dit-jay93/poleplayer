import RenderCore
import SwiftUI

// MARK: - Pixel Sampler Badge

struct PixelSamplerBadge: View {
    let pixel: PixelColor

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(red: Double(pixel.rNorm), green: Double(pixel.gNorm), blue: Double(pixel.bNorm)))
                .frame(width: 18, height: 18)
                .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(pixel.hex)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.white)
                Text("R \(pixel.r)  G \(pixel.g)  B \(pixel.b)")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5))
    }
}

struct ScopePanel: View {
    let data: HistogramData

    private let panelWidth: CGFloat  = 280
    private let panelHeight: CGFloat = 100

    var body: some View {
        Canvas { ctx, size in
            // Background
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.black.opacity(0.78))
            )

            let count = data.red.count
            let binW  = size.width / CGFloat(count)

            // Channels: blue under, then red, then green (additive feel)
            drawBars(ctx: ctx, size: size, values: data.blue,  color: .blue,  alpha: 0.55, binW: binW)
            drawBars(ctx: ctx, size: size, values: data.red,   color: .red,   alpha: 0.55, binW: binW)
            drawBars(ctx: ctx, size: size, values: data.green, color: .green, alpha: 0.55, binW: binW)

            // Luma as a white line on top
            drawLine(ctx: ctx, size: size, values: data.luma, color: .white, alpha: 0.85, binW: binW)
        }
        .frame(width: panelWidth, height: panelHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Private

    private func drawBars(
        ctx: GraphicsContext, size: CGSize,
        values: [Float], color: Color, alpha: Double, binW: CGFloat
    ) {
        var path = Path()
        for (i, v) in values.enumerated() {
            let x = CGFloat(i) * binW
            let h = CGFloat(v) * size.height
            path.addRect(CGRect(x: x, y: size.height - h, width: max(binW, 1), height: h))
        }
        ctx.fill(path, with: .color(color.opacity(alpha)))
    }

    private func drawLine(
        ctx: GraphicsContext, size: CGSize,
        values: [Float], color: Color, alpha: Double, binW: CGFloat
    ) {
        guard values.count > 1 else { return }
        var path = Path()
        let cx = binW * 0.5
        path.move(to: CGPoint(x: cx, y: size.height - CGFloat(values[0]) * size.height))
        for (i, v) in values.dropFirst().enumerated() {
            let x = CGFloat(i + 1) * binW + cx
            path.addLine(to: CGPoint(x: x, y: size.height - CGFloat(v) * size.height))
        }
        ctx.stroke(path, with: .color(color.opacity(alpha)), lineWidth: 1)
    }
}
