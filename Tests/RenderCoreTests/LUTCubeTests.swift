import XCTest
@testable import RenderCore

final class LUTCubeTests: XCTestCase {
    func testParseMinimalCube() throws {
        let contents = """
        LUT_3D_SIZE 2
        DOMAIN_MIN 0 0 0
        DOMAIN_MAX 1 1 1
        0 0 0
        1 0 0
        0 1 0
        1 1 0
        0 0 1
        1 0 1
        0 1 1
        1 1 1
        """
        let cube = try LUTCube.parse(contents)
        XCTAssertEqual(cube.size, 2)
        XCTAssertEqual(cube.values.count, 8)
        XCTAssertEqual(cube.domainMin, SIMD3<Float>(0, 0, 0))
        XCTAssertEqual(cube.domainMax, SIMD3<Float>(1, 1, 1))
    }

    func testMissingSizeThrows() {
        let contents = """
        DOMAIN_MIN 0 0 0
        DOMAIN_MAX 1 1 1
        0 0 0
        """
        XCTAssertThrowsError(try LUTCube.parse(contents))
    }
}
