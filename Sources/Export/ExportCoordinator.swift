import CoreGraphics
import Foundation
import Review

public struct ExportContext {
    public let destinationURL: URL
    public let packageName: String
    public let stillBaseName: String
    public let frameIndex: Int
    public let timecode: String
    public let fps: Double
    public let durationFrames: Int
    public let baseImage: CGImage
    public let overlayImage: CGImage?
    public let asset: AssetRecord
    public let reviewItem: ReviewItemRecord
    public let annotations: [AnnotationRecord]
    public let lutName: String?
    public let lutPath: String?
    public let lutHash: String?
    public let lutIntensity: Double
    public let lutEnabled: Bool
    public let appName: String
    public let appVersion: String
    public let appBuild: String
    public let authorName: String?

    public init(
        destinationURL: URL,
        packageName: String,
        stillBaseName: String,
        frameIndex: Int,
        timecode: String,
        fps: Double,
        durationFrames: Int,
        baseImage: CGImage,
        overlayImage: CGImage?,
        asset: AssetRecord,
        reviewItem: ReviewItemRecord,
        annotations: [AnnotationRecord],
        lutName: String?,
        lutPath: String?,
        lutHash: String?,
        lutIntensity: Double,
        lutEnabled: Bool,
        appName: String,
        appVersion: String,
        appBuild: String,
        authorName: String?
    ) {
        self.destinationURL = destinationURL
        self.packageName = packageName
        self.stillBaseName = stillBaseName
        self.frameIndex = frameIndex
        self.timecode = timecode
        self.fps = fps
        self.durationFrames = durationFrames
        self.baseImage = baseImage
        self.overlayImage = overlayImage
        self.asset = asset
        self.reviewItem = reviewItem
        self.annotations = annotations
        self.lutName = lutName
        self.lutPath = lutPath
        self.lutHash = lutHash
        self.lutIntensity = lutIntensity
        self.lutEnabled = lutEnabled
        self.appName = appName
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.authorName = authorName
    }
}

public enum ExportCoordinator {
    public static func exportPackage(context: ExportContext) throws -> ExportPackageResult {
        let notes = buildNotes(context: context)
        let request = ExportPackageRequest(
            destinationURL: context.destinationURL,
            packageName: context.packageName,
            stillBaseName: context.stillBaseName,
            frameIndex: context.frameIndex,
            baseImage: context.baseImage,
            overlayImage: context.overlayImage,
            notes: notes
        )
        return try ExportPackageBuilder.build(request: request)
    }

    public static func buildNotes(context: ExportContext) -> ExportNotes {
        let schema = SchemaInfo(name: "com.poledit.review-notes", version: "1.0.0")
        let exportedAt = NotesDateFormatter.iso8601String(from: Date())
        let exportInfo = ExportInfo(
            exportId: UUID().uuidString,
            exportedAt: exportedAt,
            app: AppInfo(name: context.appName, version: context.appVersion, build: context.appBuild)
        )
        let author = context.authorName.map { AuthorInfo(displayName: $0, role: nil, email: nil, org: nil) }
        let assetURL = URL(string: context.asset.url) ?? URL(fileURLWithPath: context.asset.url)
        let asset = AssetInfo(
            uri: context.asset.url,
            fileName: assetURL.lastPathComponent,
            fileHashSHA256: context.asset.fileHashSHA256,
            fileSizeBytes: context.asset.fileSizeBytes,
            modifiedAt: NotesDateFormatter.iso8601String(from: context.asset.modifiedAt)
        )
        let timeline = TimelineInfo(
            containerFPS: context.fps,
            timebase: String(format: "%.3f", context.fps),
            startTimecode: context.timecode,
            durationFrames: context.durationFrames
        )
        let lut = context.lutName.map {
            LUTInfo(name: $0, path: context.lutPath, hashSHA256: context.lutHash, intensity: context.lutIntensity, enabled: context.lutEnabled)
        }
        let color = ColorInfo(lut: lut)
        let reviewItem = ReviewItemInfo(
            id: context.reviewItem.id,
            title: context.reviewItem.title,
            tags: context.reviewItem.tags,
            range: RangeInfo(
                startFrame: context.reviewItem.startFrame,
                endFrame: context.reviewItem.endFrame,
                startTimecode: nil,
                endTimecode: nil
            ),
            annotations: context.annotations.map { mapAnnotation($0) }
        )
        return ExportNotes(
            schema: schema,
            export: exportInfo,
            author: author,
            project: nil,
            asset: asset,
            timeline: timeline,
            color: color,
            reviewItems: [reviewItem]
        )
    }

    private static func mapAnnotation(_ record: AnnotationRecord) -> AnnotationInfo {
        let style = NotesStyle(
            strokeRGBA: [record.style.strokeColor.x, record.style.strokeColor.y, record.style.strokeColor.z, record.style.strokeColor.w],
            fillRGBA: [record.style.fillColor.x, record.style.fillColor.y, record.style.fillColor.z, record.style.fillColor.w],
            strokeWidth: record.style.strokeWidth
        )
        let geometry: NotesGeometry
        switch record.geometry {
        case .pen(let points):
            geometry = .pen(points: points.map { NotesPoint(x: $0.x, y: $0.y) })
        case .rect(let bounds):
            geometry = .rect(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height, rotationDegrees: 0)
        case .circle(let bounds):
            geometry = .circle(x: bounds.x, y: bounds.y, width: bounds.width, height: bounds.height)
        case .arrow(let start, let end):
            geometry = .arrow(start: NotesPoint(x: start.x, y: start.y), end: NotesPoint(x: end.x, y: end.y))
        case .text(let anchor, let text):
            geometry = .text(x: anchor.x, y: anchor.y, text: text)
        }
        return AnnotationInfo(
            id: record.id,
            type: record.type.rawValue,
            geometry: geometry,
            style: style,
            startFrame: record.startFrame,
            endFrame: record.endFrame
        )
    }
}
