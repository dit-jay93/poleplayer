import AppKit
import RenderCore
import SwiftUI

struct WaveformPanel: View {
    let data: WaveformData

    private let panelWidth:  CGFloat = 280
    private let panelHeight: CGFloat = 100

    var body: some View {
        Canvas { ctx, size in
            // Dark background
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.black.opacity(0.78))
            )

            // Graticule lines at 0 / 25 / 50 / 75 / 100 % luma
            let levels: [Double] = [0, 0.25, 0.5, 0.75, 1.0]
            for level in levels {
                let y = size.height * (1.0 - level)   // 1.0 = white = top
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(Color.white.opacity(0.15)), lineWidth: 0.5)
            }

            // Waveform bitmap
            if let cgImg = buildImage(from: data) {
                let nsImg = NSImage(cgImage: cgImg, size: NSSize(width: data.columns, height: 256))
                let resolved = ctx.resolve(Image(nsImage: nsImg))
                ctx.draw(resolved, in: CGRect(origin: .zero, size: size))
            }
        }
        .frame(width: panelWidth, height: panelHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Private

    /// Converts density data into a teal-green RGBA bitmap (cols × 256).
    /// Bin 0 (black) → bottom of image; bin 255 (white) → top.
    private func buildImage(from data: WaveformData) -> CGImage? {
        let cols = data.columns
        let bins = 256
        var pixels = Data(count: cols * bins * 4)  // RGBA, zero-initialised

        pixels.withUnsafeMutableBytes { rawBuf in
            let px = rawBuf.bindMemory(to: UInt8.self)
            for c in 0..<cols {
                for b in 0..<bins {
                    let v = data.density[c * bins + b]
                    guard v > 0.02 else { continue }
                    // Gamma-expand density so dim regions are visible
                    let brightness = UInt8(min(v * 420, 255))
                    // Flip: bin 0 (black) → bottom row in CGImage (high y)
                    let row = bins - 1 - b
                    let idx = (row * cols + c) * 4
                    px[idx + 0] = UInt8(Double(brightness) * 0.20)  // R — slight teal tint
                    px[idx + 1] = brightness                          // G — dominant green
                    px[idx + 2] = UInt8(Double(brightness) * 0.45)  // B
                    px[idx + 3] = 255                                 // A
                }
            }
        }

        guard let provider = CGDataProvider(data: pixels as CFData) else { return nil }
        return CGImage(
            width: cols, height: bins,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: cols * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }
}
