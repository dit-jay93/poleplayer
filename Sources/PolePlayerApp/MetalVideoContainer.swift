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
