import AppKit
import RenderCore
import SwiftUI

struct VectorscopePanel: View {
    let data: VectorscopeData

    private let panelSize: CGFloat = 100

    var body: some View {
        Canvas { ctx, size in
            // Dark background
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(Color.black.opacity(0.78))
            )

            // Graticule: concentric circles at 25 / 50 / 75 / 100 % saturation
            let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            let maxR   = min(size.width, size.height) * 0.5
            for fraction in [0.25, 0.5, 0.75, 1.0] as [CGFloat] {
                let r = maxR * fraction
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r,
                                          width: r * 2,  height: r * 2)),
                    with: .color(Color.white.opacity(0.15)),
                    lineWidth: 0.5
                )
            }

            // Crosshair at center
            var ch = Path()
            ch.move(to: CGPoint(x: 0, y: center.y))
            ch.addLine(to: CGPoint(x: size.width, y: center.y))
            ch.move(to: CGPoint(x: center.x, y: 0))
            ch.addLine(to: CGPoint(x: center.x, y: size.height))
            ctx.stroke(ch, with: .color(Color.white.opacity(0.15)), lineWidth: 0.5)

            // Hue target markers for 75 % colour bars (Rec. 709)
            let targets: [(cb: Float, cr: Float, label: String)] = [
                (-0.1440, -0.2127, "Yl"),   // Yellow
                ( 0.3750, -0.1875, "Cy"),   // Cyan
                ( 0.2310, -0.4002, "Gr"),   // Green
                (-0.2310,  0.4002, "Mg"),   // Magenta
                (-0.3750,  0.1875, "Rd"),   // Red
                ( 0.1440,  0.2127, "Bl"),   // Blue
            ]
            for t in targets {
                let x = center.x + CGFloat(t.cb) * maxR * 2
                let y = center.y - CGFloat(t.cr) * maxR * 2   // flip V axis
                let r: CGFloat = 3
                ctx.stroke(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                    with: .color(Color.white.opacity(0.5)),
                    lineWidth: 0.75
                )
            }

            // Vectorscope scatter bitmap
            if let cgImg = buildImage(from: data, panelSize: size) {
                let nsImg = NSImage(cgImage: cgImg, size: NSSize(width: data.size, height: data.size))
                let resolved = ctx.resolve(Image(nsImage: nsImg))
                ctx.draw(resolved, in: CGRect(origin: .zero, size: size))
            }
        }
        .frame(width: panelSize, height: panelSize)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    // MARK: - Private

    /// Builds an RGBA bitmap where each cell is coloured by its hue angle (Cb/Cr → HSB),
    /// with brightness proportional to density. v_idx 0 = Cr −0.5 = bottom of image.
    private func buildImage(from data: VectorscopeData, panelSize: CGSize) -> CGImage? {
        let sz  = data.size
        var pixels = Data(count: sz * sz * 4)

        pixels.withUnsafeMutableBytes { rawBuf in
            let px = rawBuf.bindMemory(to: UInt8.self)
            for vIdx in 0..<sz {
                for uIdx in 0..<sz {
                    let v = data.density[vIdx * sz + uIdx]
                    guard v > 0.005 else { continue }

                    // Cb / Cr in –0.5 … +0.5
                    let cb = Float(uIdx) / Float(sz - 1) - 0.5
                    let cr = Float(vIdx) / Float(sz - 1) - 0.5

                    // Hue from chrominance angle
                    let angle = atan2(Double(cr), Double(cb))           // –π … +π
                    let hue   = (angle / (2 * .pi) + 1.0).truncatingRemainder(dividingBy: 1.0)
                    let sat   = min(sqrt(Double(cb * cb + cr * cr)) / 0.5, 1.0)
                    let bri   = Double(min(v * 3.0, 1.0))

                    let (r, g, b) = hsbToRGB(h: hue, s: sat, bri: bri)

                    // CGImage y=0 is top; v_idx 0 = Cr –0.5 = bottom → flip row
                    let row = sz - 1 - vIdx
                    let idx = (row * sz + uIdx) * 4
                    px[idx + 0] = r
                    px[idx + 1] = g
                    px[idx + 2] = b
                    px[idx + 3] = 255
                }
            }
        }

        guard let provider = CGDataProvider(data: pixels as CFData) else { return nil }
        return CGImage(
            width: sz, height: sz,
            bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: sz * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    // MARK: - HSB → RGB

    private func hsbToRGB(h: Double, s: Double, bri: Double) -> (UInt8, UInt8, UInt8) {
        guard s > 0 else {
            let v = UInt8(bri * 255)
            return (v, v, v)
        }
        let h6 = h * 6.0
        let i  = Int(h6) % 6
        let f  = h6 - Double(Int(h6))
        let p  = bri * (1 - s)
        let q  = bri * (1 - s * f)
        let t  = bri * (1 - s * (1 - f))
        let (r, g, b): (Double, Double, Double)
        switch i {
        case 0:  (r, g, b) = (bri, t,   p)
        case 1:  (r, g, b) = (q,   bri, p)
        case 2:  (r, g, b) = (p,   bri, t)
        case 3:  (r, g, b) = (p,   q,   bri)
        case 4:  (r, g, b) = (t,   p,   bri)
        default: (r, g, b) = (bri, p,   q)
        }
        return (UInt8(r * 255), UInt8(g * 255), UInt8(b * 255))
    }
}
