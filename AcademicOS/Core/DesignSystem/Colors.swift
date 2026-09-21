import SwiftUI

/// Semantic palette supporting high-contrast Dark Mode and crisp Light Mode.
/// Emulates an Apple-native command center aesthetic (Things, Notion, Apple Developer).
public extension Color {
    // Brand Accents
    static let academicPrimary = Color(hex: "#4F46E5") // Deep Indigo
    static let academicSecondary = Color(hex: "#6366F1") // Radiant Indigo
    static let academicCyan = Color(hex: "#06B6D4") // Tactical Cyan
    static let academicEmerald = Color(hex: "#10B981") // Success Green
    static let academicAmber = Color(hex: "#F59E0B") // Warning Amber
    static let academicCrimson = Color(hex: "#EF4444") // Critical Red

    // Backgrounds
    static let commandBackground = Color("CommandBackground", bundle: nil, fallback: Color(uiColor: .systemBackground))
    static let cardBackground = Color("CardBackground", bundle: nil, fallback: Color(uiColor: .secondarySystemBackground))
    static let elevatedBackground = Color("ElevatedBackground", bundle: nil, fallback: Color(uiColor: .tertiarySystemBackground))

    // Borders & Separators
    static let borderSubtle = Color(uiColor: .separator).opacity(0.4)
    static let borderProminent = Color(uiColor: .separator)

    // Text Semantics
    static let textPrimary = Color(uiColor: .label)
    static let textSecondary = Color(uiColor: .secondaryLabel)
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    private init(_ name: String, bundle: Bundle?, fallback: Color) {
        self = fallback
    }
}
