import Foundation
import Review

enum ReviewAssetBuilder {
    static func build(url: URL) async throws -> AssetRecord {
        try await Task.detached(priority: .utility) {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let modifiedAt = (attributes[.modificationDate] as? Date) ?? Date()
            let hash = try FileHasher.sha256(url: url)
            return AssetRecord(
                id: hash,
                url: url.absoluteString,
                fileHashSHA256: hash,
                fileSizeBytes: fileSize,
                modifiedAt: modifiedAt
            )
        }.value
    }
}
