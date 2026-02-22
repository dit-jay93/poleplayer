import SwiftUI

enum Theme {
    static let appBackground = LinearGradient(
        colors: [Color(red: 0.08, green: 0.09, blue: 0.12), Color(red: 0.04, green: 0.05, blue: 0.07)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let viewerBackground = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let topBarBackground = Color(red: 0.11, green: 0.12, blue: 0.16)
    static let panelBackground  = Color(red: 0.10, green: 0.11, blue: 0.14)
    static let panelDivider     = Color.white.opacity(0.07)
    static let transportBackground = Color(red: 0.09, green: 0.10, blue: 0.13)
    static let hudBackground    = Color.black.opacity(0.65)
    static let modePillBackground = Color(red: 0.15, green: 0.16, blue: 0.2).opacity(0.9)

    static let primaryText   = Color.white
    static let secondaryText = Color.white.opacity(0.55)

    // Inspector section header
    static let sectionLabel  = Color.white.opacity(0.35)
}
