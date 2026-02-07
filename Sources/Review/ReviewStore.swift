import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

public enum ReviewStoreError: Error, LocalizedError {
    case openDatabaseFailed(String)
    case executeFailed(String)
    case prepareFailed(String)
    case bindFailed(String)
    case decodeFailed(String)

    public var errorDescription: String? {
        switch self {
        case .openDatabaseFailed(let message),
             .executeFailed(let message),
             .prepareFailed(let message),
             .bindFailed(let message),
             .decodeFailed(let message):
            return message
        }
    }
}

public final class ReviewStore {
    private let db: OpaquePointer?
    private let queue = DispatchQueue(label: "Review.Store")
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(databaseURL: URL) throws {
        var handle: OpaquePointer?
        if sqlite3_open(databaseURL.path, &handle) != SQLITE_OK {
            throw ReviewStoreError.openDatabaseFailed("Failed to open database at \(databaseURL.path)")
        }
        self.db = handle
        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    private func migrate() throws {
        let createAssets = """
        CREATE TABLE IF NOT EXISTS assets (
            id TEXT PRIMARY KEY,
            url TEXT NOT NULL,
            file_hash TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            modified_at REAL NOT NULL
        );
        """
        let createReviewItems = """
        CREATE TABLE IF NOT EXISTS review_items (
            id TEXT PRIMARY KEY,
            asset_id TEXT NOT NULL,
            title TEXT NOT NULL,
            tags TEXT NOT NULL,
            start_frame INTEGER NOT NULL,
            end_frame INTEGER NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """
        let createAnnotations = """
        CREATE TABLE IF NOT EXISTS annotations (
            id TEXT PRIMARY KEY,
            review_item_id TEXT NOT NULL,
            type TEXT NOT NULL,
            geometry_json TEXT NOT NULL,
            style_json TEXT NOT NULL,
            start_frame INTEGER NOT NULL,
            end_frame INTEGER NOT NULL,
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );
        """

        try execute(sql: createAssets)
        try execute(sql: createReviewItems)
        try execute(sql: createAnnotations)
    }

    public func upsertAsset(_ asset: AssetRecord) throws {
        try queue.sync {
            let sql = """
            INSERT INTO assets (id, url, file_hash, file_size, modified_at)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                url = excluded.url,
                file_hash = excluded.file_hash,
                file_size = excluded.file_size,
                modified_at = excluded.modified_at;
            """
            let stmt = try prepare(sql: sql)
            defer { sqlite3_finalize(stmt) }
            try bindText(stmt, index: 1, value: asset.id)
            try bindText(stmt, index: 2, value: asset.url)
            try bindText(stmt, index: 3, value: asset.fileHashSHA256)
            sqlite3_bind_int64(stmt, 4, asset.fileSizeBytes)
            sqlite3_bind_double(stmt, 5, asset.modifiedAt.timeIntervalSince1970)
            try step(stmt)
        }
    }

    public func upsertReviewItem(_ item: ReviewItemRecord) throws {
        try queue.sync {
            let sql = """
            INSERT INTO review_items (id, asset_id, title, tags, start_frame, end_frame, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                tags = excluded.tags,
                start_frame = excluded.start_frame,
                end_frame = excluded.end_frame,
                updated_at = excluded.updated_at;
            """
            let stmt = try prepare(sql: sql)
            defer { sqlite3_finalize(stmt) }
            try bindText(stmt, index: 1, value: item.id)
            try bindText(stmt, index: 2, value: item.assetId)
            try bindText(stmt, index: 3, value: item.title)
            let tagsData = try encoder.encode(item.tags)
            let tagsJSON = String(decoding: tagsData, as: UTF8.self)
            try bindText(stmt, index: 4, value: tagsJSON)
            sqlite3_bind_int(stmt, 5, Int32(item.startFrame))
            sqlite3_bind_int(stmt, 6, Int32(item.endFrame))
            sqlite3_bind_double(stmt, 7, item.createdAt.timeIntervalSince1970)
            sqlite3_bind_double(stmt, 8, item.updatedAt.timeIntervalSince1970)
            try step(stmt)
        }
    }

    public func replaceAnnotations(reviewItemId: String, annotations: [AnnotationRecord]) throws {
        try queue.sync {
            try execute(sql: "DELETE FROM annotations WHERE review_item_id = '\(reviewItemId)';")

            let sql = """
            INSERT INTO annotations (id, review_item_id, type, geometry_json, style_json, start_frame, end_frame, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            let stmt = try prepare(sql: sql)
            defer { sqlite3_finalize(stmt) }

            for annotation in annotations {
                sqlite3_reset(stmt)
                try bindText(stmt, index: 1, value: annotation.id)
                try bindText(stmt, index: 2, value: reviewItemId)
                try bindText(stmt, index: 3, value: annotation.type.rawValue)
                let geometryData = try encoder.encode(annotation.geometry)
                let geometryJSON = String(decoding: geometryData, as: UTF8.self)
                try bindText(stmt, index: 4, value: geometryJSON)
                let styleData = try encoder.encode(annotation.style)
                let styleJSON = String(decoding: styleData, as: UTF8.self)
                try bindText(stmt, index: 5, value: styleJSON)
                sqlite3_bind_int(stmt, 6, Int32(annotation.startFrame))
                sqlite3_bind_int(stmt, 7, Int32(annotation.endFrame))
                sqlite3_bind_double(stmt, 8, annotation.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 9, annotation.updatedAt.timeIntervalSince1970)
                try step(stmt)
            }
        }
    }

    public func fetchReviewState(assetHash: String) throws -> ReviewState? {
        return try queue.sync {
            let assetSQL = "SELECT id, url, file_hash, file_size, modified_at FROM assets WHERE id = ?;"
            let assetStmt = try prepare(sql: assetSQL)
            defer { sqlite3_finalize(assetStmt) }
            try bindText(assetStmt, index: 1, value: assetHash)
            guard sqlite3_step(assetStmt) == SQLITE_ROW else { return nil }
            let asset = AssetRecord(
                id: readText(assetStmt, index: 0),
                url: readText(assetStmt, index: 1),
                fileHashSHA256: readText(assetStmt, index: 2),
                fileSizeBytes: sqlite3_column_int64(assetStmt, 3),
                modifiedAt: Date(timeIntervalSince1970: sqlite3_column_double(assetStmt, 4))
            )

            let reviewSQL = """
            SELECT id, asset_id, title, tags, start_frame, end_frame, created_at, updated_at
            FROM review_items WHERE asset_id = ?;
            """
            let reviewStmt = try prepare(sql: reviewSQL)
            defer { sqlite3_finalize(reviewStmt) }
            try bindText(reviewStmt, index: 1, value: asset.id)

            var reviewItems: [ReviewItemRecord] = []
            while sqlite3_step(reviewStmt) == SQLITE_ROW {
                let tagsJSON = readText(reviewStmt, index: 3)
                let tagsData = Data(tagsJSON.utf8)
                let tags = (try? decoder.decode([String].self, from: tagsData)) ?? []
                reviewItems.append(
                    ReviewItemRecord(
                        id: readText(reviewStmt, index: 0),
                        assetId: readText(reviewStmt, index: 1),
                        title: readText(reviewStmt, index: 2),
                        tags: tags,
                        startFrame: Int(sqlite3_column_int(reviewStmt, 4)),
                        endFrame: Int(sqlite3_column_int(reviewStmt, 5)),
                        createdAt: Date(timeIntervalSince1970: sqlite3_column_double(reviewStmt, 6)),
                        updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(reviewStmt, 7))
                    )
                )
            }

            var annotations: [AnnotationRecord] = []
            let annotationSQL = """
            SELECT id, review_item_id, type, geometry_json, style_json, start_frame, end_frame, created_at, updated_at
            FROM annotations WHERE review_item_id = ?;
            """

            for item in reviewItems {
                let annotationStmt = try prepare(sql: annotationSQL)
                defer { sqlite3_finalize(annotationStmt) }
                try bindText(annotationStmt, index: 1, value: item.id)
                while sqlite3_step(annotationStmt) == SQLITE_ROW {
                    let typeRaw = readText(annotationStmt, index: 2)
                    let type = AnnotationType(rawValue: typeRaw) ?? .rect
                    let geometryJSON = readText(annotationStmt, index: 3)
                    let geometryData = Data(geometryJSON.utf8)
                    let geometry = try decoder.decode(AnnotationGeometry.self, from: geometryData)
                    let styleJSON = readText(annotationStmt, index: 4)
                    let styleData = Data(styleJSON.utf8)
                    let style = try decoder.decode(AnnotationStyle.self, from: styleData)
                    annotations.append(
                        AnnotationRecord(
                            id: readText(annotationStmt, index: 0),
                            reviewItemId: readText(annotationStmt, index: 1),
                            type: type,
                            geometry: geometry,
                            style: style,
                            startFrame: Int(sqlite3_column_int(annotationStmt, 5)),
                            endFrame: Int(sqlite3_column_int(annotationStmt, 6)),
                            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(annotationStmt, 7)),
                            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(annotationStmt, 8))
                        )
                    )
                }
            }

            return ReviewState(asset: asset, reviewItems: reviewItems, annotations: annotations)
        }
    }

    private func execute(sql: String) throws {
        var errorMessage: UnsafeMutablePointer<Int8>?
        if sqlite3_exec(db, sql, nil, nil, &errorMessage) != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQL error"
            sqlite3_free(errorMessage)
            throw ReviewStoreError.executeFailed(message)
        }
    }

    private func prepare(sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            throw ReviewStoreError.prepareFailed(message)
        }
        return stmt
    }

    private func bindText(_ stmt: OpaquePointer?, index: Int32, value: String) throws {
        if sqlite3_bind_text(stmt, index, value, -1, sqliteTransient) != SQLITE_OK {
            let message = String(cString: sqlite3_errmsg(db))
            throw ReviewStoreError.bindFailed(message)
        }
    }

    private func step(_ stmt: OpaquePointer?) throws {
        if sqlite3_step(stmt) != SQLITE_DONE {
            let message = String(cString: sqlite3_errmsg(db))
            throw ReviewStoreError.executeFailed(message)
        }
    }

    private func readText(_ stmt: OpaquePointer?, index: Int32) -> String {
        guard let text = sqlite3_column_text(stmt, index) else { return "" }
        return String(cString: text)
    }
}
