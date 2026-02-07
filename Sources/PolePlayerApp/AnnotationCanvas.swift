import PlayerCore
import Review
import SwiftUI

struct AnnotationCanvas: View {
    @ObservedObject var reviewSession: ReviewSession
    let player: PlayerController
    let isAnnotating: Bool

    @State private var dragStart: CGPoint? = nil
    @State private var penPoints: [CGPoint] = []

    var body: some View {
        GeometryReader { geo in
            Color.clear
                .contentShape(Rectangle())
                .gesture(dragGesture(in: geo.size))
                .allowsHitTesting(isAnnotating)
                .onChange(of: isAnnotating) { enabled in
                    if !enabled {
                        reviewSession.discardDraft()
                        dragStart = nil
                        penPoints = []
                    }
                }
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard reviewSession.reviewItem != nil else { return }
                if dragStart == nil {
                    dragStart = value.startLocation
                }
                let start = dragStart ?? value.startLocation
                let current = value.location
                let geometry = buildGeometry(start: start, current: current, size: size, tool: reviewSession.activeTool)
                if let geometry {
                    let annotation = makeAnnotation(geometry: geometry, tool: reviewSession.activeTool)
                    reviewSession.updateDraft(annotation)
                }
            }
            .onEnded { value in
                guard reviewSession.reviewItem != nil else { return }
                let start = dragStart ?? value.startLocation
                let end = value.location
                if let geometry = buildGeometry(start: start, current: end, size: size, tool: reviewSession.activeTool, isFinal: true) {
                    let annotation = makeAnnotation(geometry: geometry, tool: reviewSession.activeTool)
                    reviewSession.updateDraft(annotation)
                    reviewSession.commitDraft()
                } else {
                    reviewSession.discardDraft()
                }
                dragStart = nil
                penPoints = []
            }
    }

    private func buildGeometry(start: CGPoint, current: CGPoint, size: CGSize, tool: AnnotationType, isFinal: Bool = false) -> AnnotationGeometry? {
        switch tool {
        case .pen:
            penPoints.append(current)
            let normalized = penPoints.map { normalize(point: $0, in: size) }
            return .pen(points: normalized)
        case .rect:
            let rect = normalizedRect(start: start, end: current, size: size)
            return .rect(bounds: rect)
        case .circle:
            let rect = normalizedRect(start: start, end: current, size: size)
            return .circle(bounds: rect)
        case .arrow:
            let s = normalize(point: start, in: size)
            let e = normalize(point: current, in: size)
            return .arrow(start: s, end: e)
        case .text:
            if !isFinal {
                return nil
            }
            let anchor = normalize(point: start, in: size)
            return .text(anchor: anchor, text: "Note")
        }
    }

    private func makeAnnotation(geometry: AnnotationGeometry, tool: AnnotationType) -> AnnotationRecord? {
        guard let reviewItem = reviewSession.reviewItem else { return nil }
        let range = annotationRange()
        return AnnotationRecord(
            reviewItemId: reviewItem.id,
            type: tool,
            geometry: geometry,
            style: .default,
            startFrame: range.start,
            endFrame: range.end
        )
    }

    private func annotationRange() -> (start: Int, end: Int) {
        let current = player.frameIndex
        let start = player.inPointFrame ?? current
        let end = player.outPointFrame ?? current
        if start <= end {
            return (start, end)
        }
        return (end, start)
    }

    private func normalize(point: CGPoint, in size: CGSize) -> NormalizedPoint {
        NormalizedPoint(
            x: Double(point.x / max(size.width, 1)),
            y: Double(point.y / max(size.height, 1))
        )
    }

    private func normalizedRect(start: CGPoint, end: CGPoint, size: CGSize) -> NormalizedRect {
        let minX = min(start.x, end.x)
        let minY = min(start.y, end.y)
        let width = abs(end.x - start.x)
        let height = abs(end.y - start.y)
        return NormalizedRect(
            x: Double(minX / max(size.width, 1)),
            y: Double(minY / max(size.height, 1)),
            width: Double(width / max(size.width, 1)),
            height: Double(height / max(size.height, 1))
        )
    }
}
