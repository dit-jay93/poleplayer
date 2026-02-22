import AppKit
import CoreGraphics
import Foundation
import Review

// MARK: - PDF Report Builder

/// Review 세션을 A4 PDF 리포트로 내보냅니다.
/// CoreGraphics CGPDFContext를 사용하며, 어노테이션이 많으면 2페이지로 자동 분할합니다.
public enum PDFReportBuilder {

    // MARK: - Layout Constants

    private enum K {
        static let W: CGFloat = 595     // A4 width (pt)
        static let H: CGFloat = 842     // A4 height (pt)
        static let m: CGFloat = 36      // horizontal margin
        static let headerH: CGFloat = 78
        static let footerH: CGFloat = 34
        static let rowH: CGFloat = 22
        static let sectionH: CGFloat = 28
        static let imgMaxH: CGFloat = 268
        static let imgGap: CGFloat = 10
        // Annotation table columns
        static let colIdx:  CGFloat = m
        static let colTC:   CGFloat = m + 28
        static let colType: CGFloat = m + 28 + 90
        static let colText: CGFloat = m + 28 + 90 + 54
    }

    // MARK: - Colors

    private static let headerBg = NSColor(calibratedWhite: 0.11, alpha: 1)
    private static let accentC  = NSColor(calibratedRed: 0.26, green: 0.50, blue: 0.96, alpha: 1)
    private static let dividerC = NSColor(calibratedWhite: 0.82, alpha: 1)
    private static let altRowC  = NSColor(calibratedWhite: 0.962, alpha: 1)
    private static let bodyText = NSColor(calibratedWhite: 0.12, alpha: 1)
    private static let subText  = NSColor(calibratedWhite: 0.48, alpha: 1)

    // MARK: - Error

    public enum Err: LocalizedError {
        case contextFailed
        public var errorDescription: String? { "PDF 렌더링 컨텍스트 생성에 실패했습니다." }
    }

    // MARK: - Public API

    /// ExportContext로부터 outputURL에 PDF 파일을 생성합니다.
    public static func build(context: ExportContext, outputURL: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: K.W, height: K.H)
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let pdfCtx = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { throw Err.contextFailed }

        let still = composeStill(context: context)
        let (p1, p2) = splitAnnotations(context: context, stillAvailable: still != nil)

        drawPage(pdfCtx: pdfCtx, context: context, still: still,
                 annotations: p1, isFirst: true, showNotes: p2.isEmpty)
        if !p2.isEmpty {
            drawPage(pdfCtx: pdfCtx, context: context, still: nil,
                     annotations: p2, isFirst: false, showNotes: true)
        }

        pdfCtx.closePDF()
        try (data as Data).write(to: outputURL)
    }

    // MARK: - Still Composition

    private static func composeStill(context: ExportContext) -> CGImage? {
        guard let overlay = context.overlayImage else { return context.baseImage }
        let w = context.baseImage.width
        let h = context.baseImage.height
        guard let bCtx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return context.baseImage }
        let r = CGRect(x: 0, y: 0, width: w, height: h)
        bCtx.draw(context.baseImage, in: r)
        bCtx.draw(overlay, in: r)
        return bCtx.makeImage() ?? context.baseImage
    }

    // MARK: - Pagination

    private static func splitAnnotations(
        context: ExportContext,
        stillAvailable: Bool
    ) -> ([AnnotationRecord], [AnnotationRecord]) {
        let anns = context.annotations
        guard !anns.isEmpty else { return ([], []) }

        // Estimate how much y-space annotations consume on page 1
        var usedY: CGFloat = K.headerH + K.imgGap
        if stillAvailable {
            // approximate image height (16:9 max)
            let imgW = K.W - 2 * K.m
            let imgH = min(K.imgMaxH, imgW * 9 / 16)
            usedY += imgH + K.imgGap
        }
        usedY += 2   // divider + gap
        usedY += K.sectionH + 16   // section header + column headers
        let available = K.H - K.footerH - 8 - usedY
        let fits = max(0, Int(available / K.rowH))

        if fits >= anns.count {
            return (anns, [])
        }
        return (Array(anns.prefix(fits)), Array(anns.suffix(anns.count - fits)))
    }

    // MARK: - Page

    private static func drawPage(
        pdfCtx: CGContext,
        context: ExportContext,
        still: CGImage?,
        annotations: [AnnotationRecord],
        isFirst: Bool,
        showNotes: Bool
    ) {
        pdfCtx.beginPDFPage(nil)
        // Flip to top-down coordinate system (y=0 at page top)
        pdfCtx.translateBy(x: 0, y: K.H)
        pdfCtx.scaleBy(x: 1, y: -1)

        let nsCtx = NSGraphicsContext(cgContext: pdfCtx, flipped: false)
        NSGraphicsContext.current = nsCtx
        defer {
            NSGraphicsContext.current = nil
            pdfCtx.endPDFPage()
        }

        // White background
        NSColor.white.setFill()
        NSBezierPath.fill(CGRect(x: 0, y: 0, width: K.W, height: K.H))

        var y: CGFloat = 0

        y = drawHeader(pdfCtx: pdfCtx, context: context, y: y)
        y += K.imgGap

        if isFirst, let img = still {
            y = drawStill(img, pdfCtx: pdfCtx, y: y)
            y += K.imgGap
        }

        drawHRule(y: y); y += 8

        if !annotations.isEmpty {
            y = drawAnnotations(pdfCtx: pdfCtx, context: context, annotations: annotations, y: y)
            y += 8
        }

        if showNotes {
            let title = context.reviewItem.title
            let tags  = context.reviewItem.tags
            if !title.isEmpty || !tags.isEmpty {
                drawHRule(y: y); y += 8
                drawNotes(title: title, tags: tags, y: y)
            }
        }

        drawFooter(pdfCtx: pdfCtx, context: context)
    }

    // MARK: - Header

    @discardableResult
    private static func drawHeader(pdfCtx: CGContext, context: ExportContext, y: CGFloat) -> CGFloat {
        // Dark background
        headerBg.setFill()
        NSBezierPath.fill(CGRect(x: 0, y: y, width: K.W, height: K.headerH))
        // Accent left stripe
        accentC.setFill()
        NSBezierPath.fill(CGRect(x: 0, y: y, width: 4, height: K.headerH))

        var textY = y + 14

        // Title
        draw(string: "REVIEW REPORT", at: CGPoint(x: K.m, y: textY), attrs: [
            .font: NSFont.boldSystemFont(ofSize: 16),
            .foregroundColor: NSColor.white,
            .kern: 1.5 as AnyObject
        ])
        textY += 22

        // File name
        let assetURL = URL(string: context.asset.url) ?? URL(fileURLWithPath: context.asset.url)
        draw(string: assetURL.lastPathComponent, at: CGPoint(x: K.m, y: textY), attrs: [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.white.withAlphaComponent(0.85)
        ])
        textY += 17

        // Meta line
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        var parts = ["TC \(context.timecode)", String(format: "%.3f fps", context.fps)]
        if let author = context.authorName { parts.append(author) }
        parts.append(df.string(from: Date()))
        if context.lutEnabled, let lut = context.lutName { parts.append("LUT: \(lut)") }
        draw(string: parts.joined(separator: "  ·  "), at: CGPoint(x: K.m, y: textY), attrs: [
            .font: NSFont.systemFont(ofSize: 9.5),
            .foregroundColor: NSColor.white.withAlphaComponent(0.50)
        ])

        return y + K.headerH
    }

    // MARK: - Still Image

    @discardableResult
    private static func drawStill(_ image: CGImage, pdfCtx: CGContext, y: CGFloat) -> CGFloat {
        let maxW = K.W - 2 * K.m
        let aspect = CGFloat(image.width) / max(1, CGFloat(image.height))
        let imgW = min(maxW, K.imgMaxH * aspect)
        let imgH = imgW / aspect
        let x = (K.W - imgW) / 2

        // Subtle border
        NSColor(calibratedWhite: 0.86, alpha: 1).setFill()
        NSBezierPath.fill(CGRect(x: x - 1, y: y - 1, width: imgW + 2, height: imgH + 2))

        // CG images are bottom-left origin; flip locally to draw right-side-up
        pdfCtx.saveGState()
        pdfCtx.translateBy(x: x, y: y + imgH)
        pdfCtx.scaleBy(x: 1, y: -1)
        pdfCtx.draw(image, in: CGRect(x: 0, y: 0, width: imgW, height: imgH))
        pdfCtx.restoreGState()

        return y + imgH
    }

    // MARK: - Annotations

    @discardableResult
    private static func drawAnnotations(
        pdfCtx: CGContext,
        context: ExportContext,
        annotations: [AnnotationRecord],
        y: CGFloat
    ) -> CGFloat {
        var curY = y

        // Section header
        draw(string: "ANNOTATIONS  (\(context.annotations.count))", at: CGPoint(x: K.m, y: curY + 6), attrs: [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: subText,
            .kern: 0.8 as AnyObject
        ])
        curY += K.sectionH

        // Column headers
        let hdrAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 9),
            .foregroundColor: subText
        ]
        for (txt, x) in [("#", K.colIdx), ("TIMECODE", K.colTC), ("TYPE", K.colType), ("CONTENT", K.colText)] {
            draw(string: txt, at: CGPoint(x: x, y: curY), attrs: hdrAttrs)
        }
        curY += 16

        // Rows
        for (i, ann) in annotations.enumerated() {
            if i % 2 == 1 {
                altRowC.setFill()
                NSBezierPath.fill(CGRect(x: K.m - 4, y: curY - 2,
                                         width: K.W - 2 * K.m + 8, height: K.rowH))
            }
            let mono: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .regular),
                .foregroundColor: bodyText
            ]
            let idx  = String(format: "%02d", i + 1)
            let tc   = timecodeString(frame: ann.startFrame, fps: context.fps)
            let type = ann.type.rawValue.capitalized
            let text: String
            if case .text(_, let t) = ann.geometry { text = t } else { text = "—" }

            for (s, x) in [(idx, K.colIdx), (tc, K.colTC), (type, K.colType)] {
                draw(string: s, at: CGPoint(x: x, y: curY + 4), attrs: mono)
            }
            // Content with line wrap
            let contentAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9.5),
                .foregroundColor: bodyText
            ]
            NSAttributedString(string: text, attributes: contentAttrs)
                .draw(in: CGRect(x: K.colText, y: curY + 3,
                                 width: K.W - K.colText - K.m, height: K.rowH - 2))
            curY += K.rowH
        }
        return curY
    }

    // MARK: - Notes Section

    private static func drawNotes(title: String, tags: [String], y: CGFloat) {
        var curY = y
        draw(string: "REVIEW NOTES", at: CGPoint(x: K.m, y: curY + 6), attrs: [
            .font: NSFont.boldSystemFont(ofSize: 10),
            .foregroundColor: subText,
            .kern: 0.8 as AnyObject
        ])
        curY += K.sectionH

        if !title.isEmpty {
            NSAttributedString(string: title, attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: bodyText
            ]).draw(in: CGRect(x: K.m, y: curY, width: K.W - 2 * K.m, height: 56))
            curY += 24
        }
        if !tags.isEmpty {
            draw(string: tags.map { "#\($0)" }.joined(separator: "  "), at: CGPoint(x: K.m, y: curY), attrs: [
                .font: NSFont.systemFont(ofSize: 9.5),
                .foregroundColor: accentC
            ])
        }
    }

    // MARK: - Horizontal Rule

    private static func drawHRule(y: CGFloat) {
        dividerC.setStroke()
        let p = NSBezierPath()
        p.move(to: CGPoint(x: K.m, y: y + 0.5))
        p.line(to: CGPoint(x: K.W - K.m, y: y + 0.5))
        p.lineWidth = 0.5
        p.stroke()
    }

    // MARK: - Footer

    private static func drawFooter(pdfCtx: CGContext, context: ExportContext) {
        let fy = K.H - K.footerH
        dividerC.setStroke()
        let p = NSBezierPath()
        p.move(to: CGPoint(x: K.m, y: fy + 0.5))
        p.line(to: CGPoint(x: K.W - K.m, y: fy + 0.5))
        p.lineWidth = 0.5
        p.stroke()

        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let leftStr = "Generated by \(context.appName) \(context.appVersion)  ·  \(df.string(from: Date()))"
        draw(string: leftStr, at: CGPoint(x: K.m, y: fy + 10), attrs: [
            .font: NSFont.systemFont(ofSize: 9),
            .foregroundColor: subText
        ])

        let hashStr = "SHA256: \(String(context.asset.fileHashSHA256.prefix(16)))…"
        let hashAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 8, weight: .regular),
            .foregroundColor: NSColor(calibratedWhite: 0.70, alpha: 1)
        ]
        let hashAS = NSAttributedString(string: hashStr, attributes: hashAttrs)
        hashAS.draw(at: CGPoint(x: K.W - K.m - hashAS.size().width, y: fy + 10))
    }

    // MARK: - Helpers

    private static func draw(string: String, at point: CGPoint, attrs: [NSAttributedString.Key: Any]) {
        NSAttributedString(string: string, attributes: attrs).draw(at: point)
    }

    private static func timecodeString(frame: Int, fps: Double) -> String {
        guard fps > 0 else { return "--:--:--:--" }
        let totalSec = Int(Double(frame) / fps)
        let fr = frame - Int(Double(totalSec) * fps)
        let ss = totalSec % 60
        let mm = (totalSec / 60) % 60
        let hh = totalSec / 3600
        return String(format: "%02d:%02d:%02d:%02d", hh, mm, ss, fr)
    }
}
