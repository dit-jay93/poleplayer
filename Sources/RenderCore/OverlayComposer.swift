import CoreGraphics

public final class OverlayComposer {
    private let hudRenderer = HUDOverlayRenderer()
    private let annotationRenderer = AnnotationOverlayRenderer()

    public init() {}

    public func renderImage(size: CGSize, payload: OverlayPayload) -> CGImage? {
        guard size.width > 1, size.height > 1 else { return nil }
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        if let hud = payload.hud {
            hudRenderer.draw(in: context, size: size, data: hud)
        }

        if !payload.annotations.isEmpty {
            annotationRenderer.draw(in: context, size: size, annotations: payload.annotations)
        }

        return context.makeImage()
    }
}
