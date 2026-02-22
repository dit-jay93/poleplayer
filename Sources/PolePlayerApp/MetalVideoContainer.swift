import RenderCore
import PlayerCore
import Review
import SwiftUI

struct MetalVideoContainer: NSViewRepresentable {
    let player: PlayerController
    let lutCube: LUTCube?
    let lutEnabled: Bool
    let lutIntensity: Double
    let reviewSession: ReviewSession?
    let isAnnotating: Bool
    @Binding var zoomCommand: ZoomCommand?
    let scopeEnabled: Bool
    let onHistogram: ((HistogramData) -> Void)?
    let onWaveform: ((WaveformData) -> Void)?
    let onVectorscope: ((VectorscopeData) -> Void)?
    let onColorSample: ((PixelColor?) -> Void)?
    // A/B compare
    let compareEnabled: Bool
    let comparePixelBuffer: CVPixelBuffer?
    let compareSplitX: Float
    @Binding var captureCompareRequest: Bool
    let onCompareCapture: ((CVPixelBuffer?) -> Void)?
    // C: False Color
    let falseColorEnabled: Bool
    // Phase 95: transform 콜백 + HDR
    let onTransformUpdate: ((VideoTransform) -> Void)?
    let autoToneMap: Bool

    func makeNSView(context: Context) -> MetalVideoView {
        let view = MetalVideoView(frame: .zero, frameProvider: { hostTime in
            Task { @MainActor in
                player.recordRenderTick(hostTime: hostTime)
            }
            return player.copyPixelBuffer(hostTime: hostTime)
        }, overlayProvider: {
            guard player.hasVideo else { return nil }
            let hud = HUDOverlayData(
                timecode: player.timecode,
                frameIndex: player.frameIndex,
                fps: player.fps,
                resolution: player.resolution
            )
            let annotations = currentOverlayAnnotations()
            return OverlayPayload(hud: hud, annotations: annotations)
        })
        view.updateLUT(cube: lutCube, intensity: Float(lutIntensity), enabled: lutEnabled)
        view.updateVideoSize(player.resolution)
        view.isInteractionEnabled = !isAnnotating
        view.compareEnabled = compareEnabled
        view.comparePixelBuffer = comparePixelBuffer
        view.compareSplitX = compareSplitX
        view.falseColorEnabled = falseColorEnabled
        view.updateHDRMode(player.hdrMode, autoToneMap: autoToneMap)
        return view
    }

    func updateNSView(_ nsView: MetalVideoView, context: Context) {
        nsView.updateFrameProvider { hostTime in
            Task { @MainActor in
                player.recordRenderTick(hostTime: hostTime)
            }
            return player.copyPixelBuffer(hostTime: hostTime)
        }
        nsView.updateOverlayProvider {
            guard player.hasVideo else { return nil }
            let hud = HUDOverlayData(
                timecode: player.timecode,
                frameIndex: player.frameIndex,
                fps: player.fps,
                resolution: player.resolution
            )
            let annotations = currentOverlayAnnotations()
            return OverlayPayload(hud: hud, annotations: annotations)
        }
        nsView.updateLUT(cube: lutCube, intensity: Float(lutIntensity), enabled: lutEnabled)
        nsView.updateVideoSize(player.resolution)
        nsView.isInteractionEnabled = !isAnnotating
        nsView.onHistogram    = scopeEnabled ? onHistogram    : nil
        nsView.onWaveform     = scopeEnabled ? onWaveform     : nil
        nsView.onVectorscope  = scopeEnabled ? onVectorscope  : nil
        nsView.onColorSample  = isAnnotating ? nil : onColorSample
        nsView.compareEnabled     = compareEnabled
        nsView.comparePixelBuffer = comparePixelBuffer
        nsView.compareSplitX      = compareSplitX
        nsView.falseColorEnabled  = falseColorEnabled
        nsView.updateHDRMode(player.hdrMode, autoToneMap: autoToneMap)

        // transform 콜백 → AppState.videoTransform 업데이트 (어노테이션 좌표 보정)
        nsView.onTransformUpdate = { scale, offset in
            onTransformUpdate?(VideoTransform(scale: scale, offset: offset))
        }

        if captureCompareRequest {
            let captured = nsView.lastPixelBuffer
            DispatchQueue.main.async {
                captureCompareRequest = false
                onCompareCapture?(captured)
            }
        }
        if let cmd = zoomCommand {
            nsView.applyZoomCommand(cmd)
            DispatchQueue.main.async { zoomCommand = nil }
        }
    }

    private var videoAspect: Float {
        let res = player.resolution
        guard res.height > 0 else { return 1.0 }
        return Float(res.width / res.height)
    }

    private func currentOverlayAnnotations() -> [OverlayAnnotation] {
        guard let session = reviewSession else { return [] }
        let frame = player.frameIndex
        var records = session.annotations(forFrame: frame)
        if isAnnotating, let draft = session.draftAnnotation {
            records.append(draft)
        }
        return records.compactMap { mapAnnotation($0) }
    }

    private func mapAnnotation(_ record: AnnotationRecord) -> OverlayAnnotation? {
        let style = OverlayStyle(
            strokeColor: record.style.strokeColor,
            fillColor: record.style.fillColor,
            strokeWidth: record.style.strokeWidth
        )
        switch record.geometry {
        case .pen(let points):
            let overlayPoints = points.map { OverlayPoint(x: $0.x, y: $0.y) }
            return OverlayAnnotation(type: .pen, geometry: .pen(points: overlayPoints), style: style)
        case .rect(let bounds):
            let rect = OverlayRect(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
            return OverlayAnnotation(type: .rect, geometry: .rect(bounds: rect), style: style)
        case .circle(let bounds):
            let rect = OverlayRect(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
            return OverlayAnnotation(type: .circle, geometry: .circle(bounds: rect), style: style)
        case .arrow(let start, let end):
            let s = OverlayPoint(x: start.x, y: start.y)
            let e = OverlayPoint(x: end.x, y: end.y)
            return OverlayAnnotation(type: .arrow, geometry: .arrow(start: s, end: e), style: style)
        case .text(let anchor, let text):
            let a = OverlayPoint(x: anchor.x, y: anchor.y)
            return OverlayAnnotation(type: .text, geometry: .text(anchor: a, text: text), style: style)
        }
    }
}
