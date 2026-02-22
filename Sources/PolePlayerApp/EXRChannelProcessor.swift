import AppKit
import CoreImage
import CoreGraphics

// MARK: - Channel Mode

/// EXR 뷰어에서 선택할 수 있는 채널 표시 모드.
public enum EXRChannelMode: String, CaseIterable, Sendable {
    case composite = "RGBA"   /// 합성 (기본)
    case red       = "R"      /// 빨강 채널 → 그레이스케일
    case green     = "G"      /// 초록 채널 → 그레이스케일
    case blue      = "B"      /// 파랑 채널 → 그레이스케일
    case alpha     = "A"      /// 알파 채널 → 그레이스케일
    case luminance = "Y"      /// BT.709 루미넌스 → 그레이스케일

    var label: String { rawValue }
}

// MARK: - Processor

/// CIColorMatrix 필터를 사용해 NSImage에서 단일 채널을 격리합니다.
enum EXRChannelProcessor {

    private static let ciContext = CIContext(options: [
        .cacheIntermediates: false,
        .outputColorSpace: CGColorSpaceCreateDeviceRGB() as Any
    ])

    /// `source` NSImage에서 `mode`에 해당하는 채널을 추출한 NSImage를 반환합니다.
    /// `mode == .composite`이면 source를 그대로 반환합니다.
    static func process(source: NSImage, mode: EXRChannelMode) -> NSImage? {
        guard mode != .composite else { return source }

        var proposedRect = NSRect(origin: .zero, size: source.size)
        guard let cgInput = source.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil)
        else { return nil }

        let ciInput = CIImage(cgImage: cgInput)
        guard let filter = CIFilter(name: "CIColorMatrix") else { return nil }
        filter.setValue(ciInput, forKey: kCIInputImageKey)

        // BT.709 루미넌스 계수
        let rY: CGFloat = 0.2126
        let gY: CGFloat = 0.7152
        let bY: CGFloat = 0.0722

        switch mode {
        case .composite:
            break   // unreachable

        case .red:
            // output.RGB = input.R (그레이스케일)
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 1, y: 0, z: 0, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        case .green:
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 1, z: 0, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        case .blue:
            filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 1, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        case .alpha:
            // A 채널을 RGB 모두에 복사 → 흑백 알파 맵
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputRVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputGVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0, y: 0, z: 0, w: 1), forKey: "inputAVector")

        case .luminance:
            // Y = 0.2126R + 0.7152G + 0.0722B
            filter.setValue(CIVector(x: rY, y: gY, z: bY, w: 0), forKey: "inputRVector")
            filter.setValue(CIVector(x: rY, y: gY, z: bY, w: 0), forKey: "inputGVector")
            filter.setValue(CIVector(x: rY, y: gY, z: bY, w: 0), forKey: "inputBVector")
            filter.setValue(CIVector(x: 0,  y: 0,  z: 0,  w: 1), forKey: "inputAVector")
        }

        guard let outputCI = filter.outputImage,
              let cgOutput = ciContext.createCGImage(outputCI, from: outputCI.extent)
        else { return nil }

        return NSImage(cgImage: cgOutput,
                       size: NSSize(width: cgOutput.width, height: cgOutput.height))
    }
}
