import XCTest
@testable import PlayerCore

final class TimecodeFormatterTests: XCTestCase {
    func testTimecodeFormattingAtZero() {
        let timecode = TimecodeFormatter.timecodeString(frameIndex: 0, fps: 24.0)
        XCTAssertEqual(timecode, "00:00:00:00")
    }

    func testTimecodeFormattingOneSecond() {
        let timecode = TimecodeFormatter.timecodeString(frameIndex: 24, fps: 24.0)
        XCTAssertEqual(timecode, "00:00:01:00")
    }

    func testTimecodeFormattingMinute() {
        let timecode = TimecodeFormatter.timecodeString(frameIndex: 24 * 60, fps: 24.0)
        XCTAssertEqual(timecode, "00:01:00:00")
    }
}
