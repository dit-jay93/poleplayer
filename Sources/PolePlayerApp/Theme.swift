import SwiftUI

enum Theme {
    static let appBackground = LinearGradient(
        colors: [Color(red: 0.08, green: 0.09, blue: 0.12), Color(red: 0.04, green: 0.05, blue: 0.07)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let viewerBackground = Color.black.opacity(0.92)
    static let topBarBackground = Color(red: 0.12, green: 0.13, blue: 0.17)
    static let transportBackground = Color(red: 0.10, green: 0.11, blue: 0.15)
    static let hudBackground = Color.black.opacity(0.7)
    static let modePillBackground = Color(red: 0.15, green: 0.16, blue: 0.2).opacity(0.9)

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.7)
}
