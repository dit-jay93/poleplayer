import Foundation

public struct ExportNotes: Codable, Equatable {
    public let schema: SchemaInfo
    public let export: ExportInfo
    public let author: AuthorInfo?
    public let project: ProjectInfo?
    public let asset: AssetInfo
    public let timeline: TimelineInfo
    public let color: ColorInfo?
    public let reviewItems: [ReviewItemInfo]

    public init(
        schema: SchemaInfo,
        export: ExportInfo,
        author: AuthorInfo?,
        project: ProjectInfo?,
        asset: AssetInfo,
        timeline: TimelineInfo,
        color: ColorInfo?,
        reviewItems: [ReviewItemInfo]
    ) {
        self.schema = schema
        self.export = export
        self.author = author
        self.project = project
        self.asset = asset
        self.timeline = timeline
        self.color = color
        self.reviewItems = reviewItems
    }

    private enum CodingKeys: String, CodingKey {
        case schema
        case export
        case author
        case project
        case asset
        case timeline
        case color
        case reviewItems = "review_items"
    }
}

public struct SchemaInfo: Codable, Equatable {
    public let name: String
    public let version: String

    public init(name: String, version: String) {
        self.name = name
        self.version = version
    }
}

public struct ExportInfo: Codable, Equatable {
    public let exportId: String
    public let exportedAt: String
    public let app: AppInfo

    public init(exportId: String, exportedAt: String, app: AppInfo) {
        self.exportId = exportId
        self.exportedAt = exportedAt
        self.app = app
    }

    private enum CodingKeys: String, CodingKey {
        case exportId = "export_id"
        case exportedAt = "exported_at"
        case app
    }
}

public struct AppInfo: Codable, Equatable {
    public let name: String
    public let version: String
    public let build: String

    public init(name: String, version: String, build: String) {
        self.name = name
        self.version = version
        self.build = build
    }
}

public struct AuthorInfo: Codable, Equatable {
    public let displayName: String
    public let role: String?
    public let email: String?
    public let org: String?

    public init(displayName: String, role: String?, email: String?, org: String?) {
        self.displayName = displayName
        self.role = role
        self.email = email
        self.org = org
    }

    private enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case role
        case email
        case org
    }
}

public struct ProjectInfo: Codable, Equatable {
    public let name: String?
    public let show: String?
    public let sequence: String?
    public let shot: String?

    public init(name: String?, show: String?, sequence: String?, shot: String?) {
        self.name = name
        self.show = show
        self.sequence = sequence
        self.shot = shot
    }
}

public struct AssetInfo: Codable, Equatable {
    public let uri: String
    public let fileName: String
    public let fileHashSHA256: String
    public let fileSizeBytes: Int64
    public let modifiedAt: String

    public init(uri: String, fileName: String, fileHashSHA256: String, fileSizeBytes: Int64, modifiedAt: String) {
        self.uri = uri
        self.fileName = fileName
        self.fileHashSHA256 = fileHashSHA256
        self.fileSizeBytes = fileSizeBytes
        self.modifiedAt = modifiedAt
    }

    private enum CodingKeys: String, CodingKey {
        case uri
        case fileName = "file_name"
        case fileHashSHA256 = "file_hash_sha256"
        case fileSizeBytes = "file_size_bytes"
        case modifiedAt = "modified_at"
    }
}

public struct TimelineInfo: Codable, Equatable {
    public let containerFPS: Double
    public let timebase: String
    public let startTimecode: String
    public let durationFrames: Int

    public init(containerFPS: Double, timebase: String, startTimecode: String, durationFrames: Int) {
        self.containerFPS = containerFPS
        self.timebase = timebase
        self.startTimecode = startTimecode
        self.durationFrames = durationFrames
    }

    private enum CodingKeys: String, CodingKey {
        case containerFPS = "container_fps"
        case timebase
        case startTimecode = "start_timecode"
        case durationFrames = "duration_frames"
    }
}

public struct ColorInfo: Codable, Equatable {
    public let lut: LUTInfo?

    public init(lut: LUTInfo?) {
        self.lut = lut
    }
}

public struct LUTInfo: Codable, Equatable {
    public let name: String
    public let path: String?
    public let hashSHA256: String?
    public let intensity: Double
    public let enabled: Bool

    public init(name: String, path: String?, hashSHA256: String?, intensity: Double, enabled: Bool) {
        self.name = name
        self.path = path
        self.hashSHA256 = hashSHA256
        self.intensity = intensity
        self.enabled = enabled
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case path
        case hashSHA256 = "hash_sha256"
        case intensity
        case enabled
    }
}

public struct ReviewItemInfo: Codable, Equatable {
    public let id: String
    public let title: String
    public let tags: [String]
    public let range: RangeInfo
    public let annotations: [AnnotationInfo]

    public init(id: String, title: String, tags: [String], range: RangeInfo, annotations: [AnnotationInfo]) {
        self.id = id
        self.title = title
        self.tags = tags
        self.range = range
        self.annotations = annotations
    }
}

public struct RangeInfo: Codable, Equatable {
    public let startFrame: Int
    public let endFrame: Int
    public let startTimecode: String?
    public let endTimecode: String?

    public init(startFrame: Int, endFrame: Int, startTimecode: String?, endTimecode: String?) {
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.startTimecode = startTimecode
        self.endTimecode = endTimecode
    }

    private enum CodingKeys: String, CodingKey {
        case startFrame = "start_frame"
        case endFrame = "end_frame"
        case startTimecode = "start_timecode"
        case endTimecode = "end_timecode"
    }
}

public struct AnnotationInfo: Codable, Equatable {
    public let id: String
    public let type: String
    public let geometry: NotesGeometry
    public let style: NotesStyle
    public let startFrame: Int
    public let endFrame: Int

    public init(id: String, type: String, geometry: NotesGeometry, style: NotesStyle, startFrame: Int, endFrame: Int) {
        self.id = id
        self.type = type
        self.geometry = geometry
        self.style = style
        self.startFrame = startFrame
        self.endFrame = endFrame
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case type
        case geometry
        case style
        case startFrame = "start_frame"
        case endFrame = "end_frame"
    }
}

public struct NotesStyle: Codable, Equatable {
    public let strokeRGBA: [Double]
    public let fillRGBA: [Double]
    public let strokeWidth: Double

    public init(strokeRGBA: [Double], fillRGBA: [Double], strokeWidth: Double) {
        self.strokeRGBA = strokeRGBA
        self.fillRGBA = fillRGBA
        self.strokeWidth = strokeWidth
    }

    private enum CodingKeys: String, CodingKey {
        case strokeRGBA = "stroke_rgba"
        case fillRGBA = "fill_rgba"
        case strokeWidth = "stroke_width"
    }
}

public struct NotesPoint: Codable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public enum NotesGeometry: Codable, Equatable {
    case pen(points: [NotesPoint])
    case rect(x: Double, y: Double, width: Double, height: Double, rotationDegrees: Double)
    case circle(x: Double, y: Double, width: Double, height: Double)
    case arrow(start: NotesPoint, end: NotesPoint)
    case text(x: Double, y: Double, text: String)

    private enum CodingKeys: String, CodingKey {
        case points
        case x
        case y
        case width = "w"
        case height = "h"
        case rotationDegrees = "rotation_deg"
        case start
        case end
        case text
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pen(let points):
            try container.encode(points, forKey: .points)
        case .rect(let x, let y, let width, let height, let rotationDegrees):
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
            try container.encode(width, forKey: .width)
            try container.encode(height, forKey: .height)
            try container.encode(rotationDegrees, forKey: .rotationDegrees)
        case .circle(let x, let y, let width, let height):
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
            try container.encode(width, forKey: .width)
            try container.encode(height, forKey: .height)
        case .arrow(let start, let end):
            try container.encode(start, forKey: .start)
            try container.encode(end, forKey: .end)
        case .text(let x, let y, let text):
            try container.encode(x, forKey: .x)
            try container.encode(y, forKey: .y)
            try container.encode(text, forKey: .text)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let points = try container.decodeIfPresent([NotesPoint].self, forKey: .points) {
            self = .pen(points: points)
            return
        }
        if let start = try container.decodeIfPresent(NotesPoint.self, forKey: .start),
           let end = try container.decodeIfPresent(NotesPoint.self, forKey: .end) {
            self = .arrow(start: start, end: end)
            return
        }
        if let text = try container.decodeIfPresent(String.self, forKey: .text),
           let x = try container.decodeIfPresent(Double.self, forKey: .x),
           let y = try container.decodeIfPresent(Double.self, forKey: .y) {
            self = .text(x: x, y: y, text: text)
            return
        }
        if let x = try container.decodeIfPresent(Double.self, forKey: .x),
           let y = try container.decodeIfPresent(Double.self, forKey: .y),
           let width = try container.decodeIfPresent(Double.self, forKey: .width),
           let height = try container.decodeIfPresent(Double.self, forKey: .height) {
            let rotation = try container.decodeIfPresent(Double.self, forKey: .rotationDegrees)
            if let rotation {
                self = .rect(x: x, y: y, width: width, height: height, rotationDegrees: rotation)
            } else {
                self = .circle(x: x, y: y, width: width, height: height)
            }
            return
        }
        throw DecodingError.dataCorruptedError(forKey: .x, in: container, debugDescription: "Unrecognized geometry")
    }
}

public enum NotesWriter {
    public static func encode(notes: ExportNotes) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(notes)
    }

    public static func write(notes: ExportNotes, to url: URL) throws {
        let data = try encode(notes: notes)
        try data.write(to: url, options: .atomic)
    }
}

public enum NotesDateFormatter {
    public static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}
