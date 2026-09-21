import SwiftUI

/// Semantic corner radii conforming to modern Apple interface conventions.
public enum CornerRadius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let xLarge: CGFloat = 20
    public static let pill: CGFloat = 999
}

/// Elevation and depth styling tokens.
public extension View {
    func academicCardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    func academicElevatedShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    func academicGlow(color: Color, radius: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.3), radius: radius, x: 0, y: 0)
    }
}
