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
        for font in fontFiles {
            guard let url = Bundle.module.url(forResource: font, withExtension: "otf", subdirectory: "Fonts") else {
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
}
