import Combine
import Foundation

public final class ReviewSession: ObservableObject {
    @Published public private(set) var asset: AssetRecord?
    @Published public private(set) var reviewItem: ReviewItemRecord?
    @Published public private(set) var annotations: [AnnotationRecord] = []
    @Published public var activeTool: AnnotationType = .rect
    @Published public var draftAnnotation: AnnotationRecord? = nil

    private let store: ReviewStore

    public init(store: ReviewStore) {
        self.store = store
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
}
