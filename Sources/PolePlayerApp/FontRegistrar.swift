import CoreText
import Foundation
import os

enum FontRegistrar {
    private static let log = Logger(subsystem: "PolePlayer", category: "Fonts")
    private static let fontFiles = [
        "Pretendard-Regular",
        "Pretendard-Medium",
        "Pretendard-SemiBold",
        "Pretendard-Bold"
    ]

    static func registerAll() {
        logBundleLocations()
        for font in fontFiles {
            guard let url = locateFontURL(named: font) else {
                log.error("Missing font resource: \(font, privacy: .public)")
                continue
            }
            var error: Unmanaged<CFError>?
            let success = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
            if !success {
                let message = (error?.takeRetainedValue() as Error?)?.localizedDescription ?? "Unknown error"
                log.error("Failed to register font \(font, privacy: .public): \(message, privacy: .public)")
            }
        }
    }

    private static func locateFontURL(named font: String) -> URL? {
        if let url = Bundle.module.url(forResource: font, withExtension: "otf", subdirectory: "Fonts") {
            return url
        }
        if let url = Bundle.main.url(forResource: font, withExtension: "otf", subdirectory: "Fonts") {
            return url
        }
        if let url = Bundle.main.url(forResource: font, withExtension: "otf") {
            return url
        }
        return nil
    }

    private static func logBundleLocations() {
        let moduleURL = Bundle.module.resourceURL?.path ?? "nil"
        let mainURL = Bundle.main.resourceURL?.path ?? "nil"
        log.info("Bundle.module resourceURL: \(moduleURL, privacy: .public)")
        log.info("Bundle.main resourceURL: \(mainURL, privacy: .public)")
    }
}
