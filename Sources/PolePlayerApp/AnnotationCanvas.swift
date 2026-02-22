import PlayerCore
import Review
import SwiftUI

struct AnnotationCanvas: View {
    @ObservedObject var reviewSession: ReviewSession
    let player: PlayerController
    let isAnnotating: Bool
    var videoTransform: VideoTransform = VideoTransform()

    @State private var dragStart: CGPoint? = nil
    @State private var penPoints: [CGPoint] = []
    @State private var selectionDragStart: CGPoint? = nil
    @State private var selectionBase: AnnotationRecord? = nil
    @State private var selectionMoved: Bool = false

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
                        reviewSession.clearSelection()
                    }
                }
                .onChange(of: reviewSession.isSelecting) { selecting in
                    if !selecting {
                        reviewSession.clearSelection()
                    }
                }
                .overlay {
                    if let selected = reviewSession.selectedAnnotation {
                        SelectionOverlay(annotation: selected, size: geo.size)
                            .stroke(Color.yellow.opacity(0.8), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private func dragGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard reviewSession.reviewItem != nil else { return }
                if reviewSession.isSelecting {
                    handleSelectionDrag(value: value, size: size)
                    return
                }
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
                if reviewSession.isSelecting {
                    finishSelectionDrag()
                    return
                }
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

    private func handleSelectionDrag(value: DragGesture.Value, size: CGSize) {
        if selectionDragStart == nil {
            selectionDragStart = value.startLocation
            selectionMoved = false
            if reviewSession.selectedAnnotationID == nil {
                selectAnnotation(at: value.startLocation, size: size)
            }
            selectionBase = reviewSession.selectedAnnotation
        }

        guard let start = selectionDragStart,
              let base = selectionBase else { return }

        let delta = CGPoint(
            x: (value.location.x - start.x) / max(size.width, 1),
            y: (value.location.y - start.y) / max(size.height, 1)
        )
        let moved = abs(delta.x) > 0.001 || abs(delta.y) > 0.001
        if moved {
            selectionMoved = true
        }
        if selectionMoved {
            let updated = ReviewSession.applyingDelta(to: base, delta: delta)
            reviewSession.updateAnnotation(updated, persist: false)
        }
    }

    private func finishSelectionDrag() {
        if selectionMoved {
            reviewSession.persist()
        }
        selectionDragStart = nil
        selectionBase = nil
        selectionMoved = false
    }

    private func selectAnnotation(at point: CGPoint, size: CGSize) {
        let normalized = normalize(point: point, in: size)
        let candidates = reviewSession.annotations(forFrame: player.frameIndex)
        let threshold = 8.0 / max(size.width, size.height)
        for annotation in candidates.reversed() {
            if hitTest(annotation: annotation, point: normalized, threshold: threshold) {
                reviewSession.selectAnnotation(id: annotation.id)
                return
            }
        }
        reviewSession.clearSelection()
    }

    private func hitTest(annotation: AnnotationRecord, point: NormalizedPoint, threshold: Double) -> Bool {
        guard let bounds = annotationBounds(annotation) else { return false }
        let minX = bounds.x - threshold
        let minY = bounds.y - threshold
        let maxX = bounds.x + bounds.width + threshold
        let maxY = bounds.y + bounds.height + threshold
        return point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    private func annotationBounds(_ annotation: AnnotationRecord) -> NormalizedRect? {
        switch annotation.geometry {
        case .rect(let bounds), .circle(let bounds):
            return bounds
        case .arrow(let start, let end):
            let minX = min(start.x, end.x)
            let minY = min(start.y, end.y)
            let maxX = max(start.x, end.x)
            let maxY = max(start.y, end.y)
            return NormalizedRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .pen(let points):
            guard let first = points.first else { return nil }
            var minX = first.x
            var minY = first.y
            var maxX = first.x
            var maxY = first.y
            for point in points {
                minX = min(minX, point.x)
                minY = min(minY, point.y)
                maxX = max(maxX, point.x)
                maxY = max(maxY, point.y)
            }
            return NormalizedRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        case .text(let anchor, _):
            let size = 0.08
            let half = size * 0.5
            return NormalizedRect(x: anchor.x - half, y: anchor.y - half, width: size, height: size)
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

    /// SwiftUI 뷰 좌표 → 정규화 영상 UV (0~1)
    ///
    /// - MetalVideoContainer padding(4pt) 오프셋 보정
    /// - zoom/pan transform 역변환 (NDC → image UV)
    private func normalize(point: CGPoint, in size: CGSize) -> NormalizedPoint {
        let pad: CGFloat = 4                          // MetalVideoContainer .padding(4)
        let vw = max(size.width  - pad * 2, 1)
        let vh = max(size.height - pad * 2, 1)
        let px = point.x - pad
        let py = point.y - pad

        // SwiftUI(top-left, y-down) → Metal NDC(center, y-up)
        let ndcX =  Float(px / vw) * 2 - 1
        let ndcY = -(Float(py / vh) * 2 - 1)

        // NDC → image UV — MetalVideoView.computeTransform 역변환
        let sc  = videoTransform.scale
        let off = videoTransform.offset
        let u = (ndcX - off.x) / (2 * sc.x) + 0.5
        let v = 1.0 - ((ndcY - off.y) / (2 * sc.y) + 0.5)

        return NormalizedPoint(x: Double(max(0, min(1, u))),
                               y: Double(max(0, min(1, v))))
    }

    private func normalizedRect(start: CGPoint, end: CGPoint, size: CGSize) -> NormalizedRect {
        let ns = normalize(point: start, in: size)
        let ne = normalize(point: end, in: size)
        let minX = min(ns.x, ne.x)
        let minY = min(ns.y, ne.y)
        return NormalizedRect(x: minX, y: minY,
                              width: abs(ne.x - ns.x),
                              height: abs(ne.y - ns.y))
    }
}

private struct SelectionOverlay: Shape {
    let annotation: AnnotationRecord
    let size: CGSize

    func path(in rect: CGRect) -> Path {
        let bounds = CGRect(origin: .zero, size: size)
        var path = Path()
        switch annotation.geometry {
        case .rect(let box):
            let rect = denormalizeRect(box, size: bounds.size)
            path.addRect(rect)
        case .circle(let box):
            let rect = denormalizeRect(box, size: bounds.size)
            path.addEllipse(in: rect)
        case .arrow(let start, let end):
            let s = denormalizePoint(start, size: bounds.size)
            let e = denormalizePoint(end, size: bounds.size)
            path.move(to: s)
            path.addLine(to: e)
        case .pen(let points):
            if let first = points.first {
                path.move(to: denormalizePoint(first, size: bounds.size))
                for point in points.dropFirst() {
                    path.addLine(to: denormalizePoint(point, size: bounds.size))
                }
            }
        case .text(let anchor, _):
            let center = denormalizePoint(anchor, size: bounds.size)
            let radius: CGFloat = 6
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        }
        return path
    }

    private func denormalizePoint(_ point: NormalizedPoint, size: CGSize) -> CGPoint {
        CGPoint(x: point.x * Double(size.width), y: point.y * Double(size.height))
    }

    private func denormalizeRect(_ rect: NormalizedRect, size: CGSize) -> CGRect {
        CGRect(
            x: rect.x * Double(size.width),
            y: rect.y * Double(size.height),
            width: rect.width * Double(size.width),
            height: rect.height * Double(size.height)
        )
    }
}
