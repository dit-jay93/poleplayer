import XCTest
@testable import Review

final class ReviewStoreTests: XCTestCase {
    func testRoundTripReviewState() throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("review-test-\(UUID().uuidString).sqlite")
        let store = try ReviewStore(databaseURL: tempURL)

        let asset = AssetRecord(
            id: "asset-hash",
            url: "file:///tmp/clip.mov",
            fileHashSHA256: "asset-hash",
            fileSizeBytes: 1234,
            modifiedAt: Date(timeIntervalSince1970: 10)
        )
        let reviewItem = ReviewItemRecord(
            id: "review-1",
            assetId: asset.id,
            title: "Test",
            tags: ["qc"],
            startFrame: 10,
            endFrame: 20,
            createdAt: Date(timeIntervalSince1970: 11),
            updatedAt: Date(timeIntervalSince1970: 12)
        )
        let annotation = AnnotationRecord(
            id: "ann-1",
            reviewItemId: reviewItem.id,
            type: .rect,
            geometry: .rect(bounds: NormalizedRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)),
            style: .default,
            startFrame: 12,
            endFrame: 12,
            createdAt: Date(timeIntervalSince1970: 13),
            updatedAt: Date(timeIntervalSince1970: 14)
        )

        try store.upsertAsset(asset)
        try store.upsertReviewItem(reviewItem)
        try store.replaceAnnotations(reviewItemId: reviewItem.id, annotations: [annotation])

        let state = try store.fetchReviewState(assetHash: asset.id)
        XCTAssertNotNil(state)
        XCTAssertEqual(state?.asset, asset)
        XCTAssertEqual(state?.reviewItems, [reviewItem])
        XCTAssertEqual(state?.annotations, [annotation])
    }
}
