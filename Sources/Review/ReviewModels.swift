import Foundation
import simd

public struct NormalizedPoint: Codable, Equatable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = NormalizedPoint.clamp(x)
        self.y = NormalizedPoint.clamp(y)
    }

    private static func clamp(_ value: Double) -> Double {
        return min(max(value, 0.0), 1.0)
    }
}

public struct NormalizedRect: Codable, Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = NormalizedRect.clamp(x)
        self.y = NormalizedRect.clamp(y)
        self.width = NormalizedRect.clamp(width)
        self.height = NormalizedRect.clamp(height)
    }

    private static func clamp(_ value: Double) -> Double {
        return min(max(value, 0.0), 1.0)
    }
}

public enum AnnotationType: String, Codable {
    case pen
    case rect
    case circle
    case arrow
    case text
}

public struct AnnotationStyle: Codable, Equatable, Sendable {
    public let strokeColor: SIMD4<Double>
    public let fillColor: SIMD4<Double>
    public let strokeWidth: Double

    public init(strokeColor: SIMD4<Double>, fillColor: SIMD4<Double>, strokeWidth: Double) {
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.strokeWidth = strokeWidth
    }

    public static var `default`: AnnotationStyle {
        AnnotationStyle(
            strokeColor: SIMD4<Double>(1.0, 0.2, 0.2, 1.0),
            fillColor: SIMD4<Double>(1.0, 0.2, 0.2, 0.15),
            strokeWidth: 2.0
        )
    }
}

public enum AnnotationGeometry: Codable, Equatable {
    case pen(points: [NormalizedPoint])
    case rect(bounds: NormalizedRect)
    case circle(bounds: NormalizedRect)
    case arrow(start: NormalizedPoint, end: NormalizedPoint)
    case text(anchor: NormalizedPoint, text: String)
}

public struct AnnotationRecord: Codable, Equatable, Identifiable {
    public let id: String
    public let reviewItemId: String
    public let type: AnnotationType
    public let geometry: AnnotationGeometry
    public let style: AnnotationStyle
    public let startFrame: Int
    public let endFrame: Int
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        reviewItemId: String,
        type: AnnotationType,
        geometry: AnnotationGeometry,
        style: AnnotationStyle,
        startFrame: Int,
        endFrame: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.reviewItemId = reviewItemId
        self.type = type
        self.geometry = geometry
        self.style = style
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct ReviewItemRecord: Codable, Equatable, Identifiable {
    public let id: String
    public let assetId: String
    public let title: String
    public let tags: [String]
    public let startFrame: Int
    public let endFrame: Int
    public let createdAt: Date
    public let updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        assetId: String,
        title: String,
        tags: [String],
        startFrame: Int,
        endFrame: Int,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.assetId = assetId
        self.title = title
        self.tags = tags
        self.startFrame = startFrame
        self.endFrame = endFrame
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct AssetRecord: Codable, Equatable, Identifiable {
    public let id: String
    public let url: String
    public let fileHashSHA256: String
    public let fileSizeBytes: Int64
    public let modifiedAt: Date

    public init(id: String, url: String, fileHashSHA256: String, fileSizeBytes: Int64, modifiedAt: Date) {
        self.id = id
        self.url = url
        self.fileHashSHA256 = fileHashSHA256
        self.fileSizeBytes = fileSizeBytes
        self.modifiedAt = modifiedAt
    }
}

public struct ReviewState: Codable, Equatable {
    public let asset: AssetRecord
    public let reviewItems: [ReviewItemRecord]
    public let annotations: [AnnotationRecord]

    public init(asset: AssetRecord, reviewItems: [ReviewItemRecord], annotations: [AnnotationRecord]) {
        self.asset = asset
        self.reviewItems = reviewItems
        self.annotations = annotations
    }
}
