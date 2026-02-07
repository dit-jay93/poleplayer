import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

public struct ExportPackageRequest {
    public let destinationURL: URL
    public let packageName: String
    public let stillBaseName: String
    public let frameIndex: Int
    public let baseImage: CGImage
    public let overlayImage: CGImage?
    public let notes: ExportNotes

    public init(
        destinationURL: URL,
        packageName: String,
        stillBaseName: String,
        frameIndex: Int,
        baseImage: CGImage,
        overlayImage: CGImage?,
        notes: ExportNotes
    ) {
        self.destinationURL = destinationURL
        self.packageName = packageName
        self.stillBaseName = stillBaseName
        self.frameIndex = frameIndex
        self.baseImage = baseImage
        self.overlayImage = overlayImage
        self.notes = notes
    }
}

public struct ExportPackageResult: Equatable {
    public let packageURL: URL
    public let stillURL: URL
    public let notesURL: URL

    public init(packageURL: URL, stillURL: URL, notesURL: URL) {
        self.packageURL = packageURL
        self.stillURL = stillURL
        self.notesURL = notesURL
    }
}

public enum ExportPackageBuilder {
    public static func build(request: ExportPackageRequest) throws -> ExportPackageResult {
        let packageURL = try ExportFileSystem.createUniqueFolder(
            at: request.destinationURL,
            name: request.packageName
        )
        let stillFileName = ExportNaming.stillFileName(
            baseName: request.stillBaseName,
            frameIndex: request.frameIndex
        )
        let stillURL = packageURL.appendingPathComponent(stillFileName)
        let notesURL = packageURL.appendingPathComponent("notes.json")

        let finalImage = ExportImageComposer.compose(
            base: request.baseImage,
            overlay: request.overlayImage
        )
        try ExportImageWriter.writePNG(image: finalImage, to: stillURL)
        try NotesWriter.write(notes: request.notes, to: notesURL)

        return ExportPackageResult(packageURL: packageURL, stillURL: stillURL, notesURL: notesURL)
    }
}

public enum ExportNaming {
    public static func packageName(baseName: String, frameIndex: Int, date: Date) -> String {
        let sanitized = sanitize(baseName)
        let stamp = timestampString(from: date)
        return "\(sanitized)_export_F\(frameIndex)_\(stamp)"
    }

    public static func stillFileName(baseName: String, frameIndex: Int) -> String {
        let sanitized = sanitize(baseName)
        return "\(sanitized)_F\(frameIndex).png"
    }

    private static func timestampString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    private static func sanitize(_ name: String) -> String {
        let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let components = name.components(separatedBy: invalid)
        let joined = components.filter { !$0.isEmpty }.joined(separator: "_")
        return joined.isEmpty ? "PolePlayer" : joined
    }
}

public enum ExportImageComposer {
    public static func compose(base: CGImage, overlay: CGImage?) -> CGImage {
        guard let overlay else { return base }
        let width = base.width
        let height = base.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)
        )
        let bytesPerRow = width * 4
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return base }
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(base, in: rect)
        context.draw(overlay, in: rect)
        return context.makeImage() ?? base
    }
}

public enum ExportImageWriter {
    public static func writePNG(image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw NSError(domain: "Export", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"]) 
        }
        CGImageDestinationAddImage(destination, image, nil)
        if !CGImageDestinationFinalize(destination) {
            throw NSError(domain: "Export", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to write PNG"]) 
        }
    }
}

public enum ExportFileSystem {
    public static func createUniqueFolder(at destinationURL: URL, name: String) throws -> URL {
        let fileManager = FileManager.default
        var folderURL = destinationURL.appendingPathComponent(name, isDirectory: true)
        var attempt = 0
        while fileManager.fileExists(atPath: folderURL.path) {
            attempt += 1
            let suffix = "-\(attempt)"
            let newName = name + suffix
            folderURL = destinationURL.appendingPathComponent(newName, isDirectory: true)
        }
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        return folderURL
    }
}
