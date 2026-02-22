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
        // SPM .process("Resources") 는 Resources/Fonts/*.otf 를 번들 루트에 평탄화
        if let url = Bundle.module.url(forResource: font, withExtension: "otf") {
            return url
        }
        // 서브디렉터리 보존 경로 (미래 빌드 변경 대비)
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
