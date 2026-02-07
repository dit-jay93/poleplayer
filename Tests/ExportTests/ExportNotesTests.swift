import XCTest
import Export

final class ExportNotesTests: XCTestCase {
    func testNotesEncodingIncludesRequiredFields() throws {
        let notes = ExportNotes(
            schema: SchemaInfo(name: "com.poledit.review-notes", version: "1.0.0"),
            export: ExportInfo(
                exportId: "TEST",
                exportedAt: "2026-02-07T00:00:00Z",
                app: AppInfo(name: "PolePlayer", version: "0.1.0", build: "1")
            ),
            author: nil,
            project: nil,
            asset: AssetInfo(
                uri: "file:///tmp/clip.mov",
                fileName: "clip.mov",
                fileHashSHA256: "ABC123",
                fileSizeBytes: 10,
                modifiedAt: "2026-02-07T00:00:00Z"
            ),
            timeline: TimelineInfo(containerFPS: 24, timebase: "24.000", startTimecode: "00:00:00:00", durationFrames: 100),
            color: nil,
            reviewItems: []
        )
        let data = try NotesWriter.encode(notes: notes)
        let json = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(json.contains("\"file_hash_sha256\""))
        XCTAssertTrue(json.contains("\"duration_frames\""))
        XCTAssertTrue(json.contains("\"schema\""))
    }

    func testNamingSanitizesAndFormats() {
        let name = ExportNaming.packageName(baseName: "A/B:C", frameIndex: 12, date: Date(timeIntervalSince1970: 0))
        XCTAssertTrue(name.contains("A_B_C"))
        XCTAssertTrue(name.contains("F12"))

        let still = ExportNaming.stillFileName(baseName: "A/B:C", frameIndex: 12)
        XCTAssertEqual(still, "A_B_C_F12.png")
    }
}
