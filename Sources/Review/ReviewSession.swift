import Combine
import CoreGraphics
import Foundation

public final class ReviewSession: ObservableObject {
    @Published public private(set) var asset: AssetRecord?
    @Published public private(set) var reviewItem: ReviewItemRecord?
    @Published public private(set) var annotations: [AnnotationRecord] = []
    @Published public var activeTool: AnnotationType = .rect
    @Published public var draftAnnotation: AnnotationRecord? = nil
    @Published public var isSelecting: Bool = false
    @Published public var selectedAnnotationID: String? = nil

    private let store: ReviewStore

    public init(store: ReviewStore) {
        self.store = store
    }

    public var selectedAnnotation: AnnotationRecord? {
        guard let selectedAnnotationID else { return nil }
        return annotations.first { $0.id == selectedAnnotationID }
    }

    public var selectedText: String? {
        guard let selected = selectedAnnotation else { return nil }
        if case .text(_, let text) = selected.geometry {
            return text
        }
        return nil
    }

    public func loadOrCreate(asset: AssetRecord, defaultTitle: String, currentFrame: Int) {
        self.asset = asset
        if let state = try? store.fetchReviewState(assetHash: asset.id) {
            self.reviewItem = state.reviewItems.first
            self.annotations = state.annotations
            return
        }

        let item = ReviewItemRecord(
            assetId: asset.id,
            title: defaultTitle,
            tags: [],
            startFrame: currentFrame,
            endFrame: currentFrame
        )
        self.reviewItem = item
        self.annotations = []
        persist()
    }

    public func annotations(forFrame frame: Int) -> [AnnotationRecord] {
        annotations.filter { frame >= $0.startFrame && frame <= $0.endFrame }
    }

    public func updateDraft(_ annotation: AnnotationRecord?) {
        draftAnnotation = annotation
    }

    public func commitDraft() {
        guard let draft = draftAnnotation else { return }
        annotations.append(draft)
        draftAnnotation = nil
        persist()
    }

    public func discardDraft() {
        draftAnnotation = nil
    }

    public func persist() {
        guard let asset, let reviewItem else { return }
        do {
            try store.upsertAsset(asset)
            try store.upsertReviewItem(reviewItem)
            try store.replaceAnnotations(reviewItemId: reviewItem.id, annotations: annotations)
        } catch {
            // Persistence errors are surfaced by caller/UI later.
        }
    }

    public func selectAnnotation(id: String?) {
        selectedAnnotationID = id
    }

    public func clearSelection() {
        selectedAnnotationID = nil
    }

    public func updateAnnotation(_ annotation: AnnotationRecord, persist: Bool) {
        guard let index = annotations.firstIndex(where: { $0.id == annotation.id }) else { return }
        annotations[index] = annotation
        if persist {
            self.persist()
        }
    }

    public func deleteSelected() {
        guard let selectedAnnotationID else { return }
        annotations.removeAll { $0.id == selectedAnnotationID }
        self.selectedAnnotationID = nil
        persist()
    }

    public func updateTitle(_ title: String) {
        guard let item = reviewItem else { return }
        reviewItem = ReviewItemRecord(
            id: item.id,
            assetId: item.assetId,
            title: title,
            tags: item.tags,
            startFrame: item.startFrame,
            endFrame: item.endFrame,
            createdAt: item.createdAt,
            updatedAt: Date()
        )
        persist()
    }

    public func updateTags(_ tags: [String]) {
        guard let item = reviewItem else { return }
        reviewItem = ReviewItemRecord(
            id: item.id,
            assetId: item.assetId,
            title: item.title,
            tags: tags,
            startFrame: item.startFrame,
            endFrame: item.endFrame,
            createdAt: item.createdAt,
            updatedAt: Date()
        )
        persist()
    }

    public func updateSelectedText(_ text: String) {
        guard let selected = selectedAnnotation else { return }
        guard case .text(let anchor, _) = selected.geometry else { return }
        let updated = ReviewSession.updatedAnnotation(selected, geometry: .text(anchor: anchor, text: text))
        updateAnnotation(updated, persist: true)
    }

    public static func applyingDelta(to annotation: AnnotationRecord, delta: CGPoint) -> AnnotationRecord {
        let geometry = applyDelta(annotation.geometry, delta: delta)
        return updatedAnnotation(annotation, geometry: geometry)
    }

    private static func updatedAnnotation(_ annotation: AnnotationRecord, geometry: AnnotationGeometry) -> AnnotationRecord {
        AnnotationRecord(
            id: annotation.id,
            reviewItemId: annotation.reviewItemId,
            type: annotation.type,
            geometry: geometry,
            style: annotation.style,
            startFrame: annotation.startFrame,
            endFrame: annotation.endFrame,
            createdAt: annotation.createdAt,
            updatedAt: Date()
        )
    }

    private static func applyDelta(_ geometry: AnnotationGeometry, delta: CGPoint) -> AnnotationGeometry {
        switch geometry {
        case .pen(let points):
            let shifted = points.map { shiftPoint($0, delta: delta) }
            return .pen(points: shifted)
        case .rect(let bounds):
            let rect = shiftRect(bounds, delta: delta)
            return .rect(bounds: rect)
        case .circle(let bounds):
            let rect = shiftRect(bounds, delta: delta)
            return .circle(bounds: rect)
        case .arrow(let start, let end):
            let s = shiftPoint(start, delta: delta)
            let e = shiftPoint(end, delta: delta)
            return .arrow(start: s, end: e)
        case .text(let anchor, let text):
            let a = shiftPoint(anchor, delta: delta)
            return .text(anchor: a, text: text)
        }
    }

    private static func shiftPoint(_ point: NormalizedPoint, delta: CGPoint) -> NormalizedPoint {
        NormalizedPoint(x: point.x + Double(delta.x), y: point.y + Double(delta.y))
    }

    private static func shiftRect(_ rect: NormalizedRect, delta: CGPoint) -> NormalizedRect {
        let maxX = max(0.0, 1.0 - rect.width)
        let maxY = max(0.0, 1.0 - rect.height)
        let newX = min(max(rect.x + Double(delta.x), 0.0), maxX)
        let newY = min(max(rect.y + Double(delta.y), 0.0), maxY)
        return NormalizedRect(x: newX, y: newY, width: rect.width, height: rect.height)
    }
}
