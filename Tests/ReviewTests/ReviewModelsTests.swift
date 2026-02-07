import XCTest
@testable import Review

final class ReviewModelsTests: XCTestCase {
    func testNormalizedPointClamps() {
        let point = NormalizedPoint(x: -0.5, y: 1.5)
        XCTAssertEqual(point.x, 0.0)
        XCTAssertEqual(point.y, 1.0)
    }

    func testNormalizedRectClamps() {
        let rect = NormalizedRect(x: -1, y: 2, width: 0.5, height: -0.25)
        XCTAssertEqual(rect.x, 0.0)
        XCTAssertEqual(rect.y, 1.0)
        XCTAssertEqual(rect.width, 0.5)
        XCTAssertEqual(rect.height, 0.0)
    }
}
