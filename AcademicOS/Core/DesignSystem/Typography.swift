import SwiftUI

/// Semantic Apple San Francisco typography scale with monospaced digit support.
public extension Font {
    static let commandDisplay = Font.system(size: 28, weight: .bold, design: .default)
    static let commandHeader = Font.system(size: 22, weight: .bold, design: .default)
    static let commandTitle = Font.system(size: 18, weight: .semibold, design: .default)
    static let commandHeadline = Font.system(size: 16, weight: .semibold, design: .default)
    static let commandBody = Font.system(size: 15, weight: .regular, design: .default)
    static let commandSubheadline = Font.system(size: 13, weight: .medium, design: .default)
    static let commandCaption = Font.system(size: 11, weight: .regular, design: .default)

    // Monospaced for metrics, countdowns, timestamps, and codes
    static let metricCountdown = Font.system(size: 32, weight: .black, design: .monospaced)
    static let metricLarge = Font.system(size: 24, weight: .bold, design: .monospaced)
    static let metricMedium = Font.system(size: 16, weight: .semibold, design: .monospaced)
    static let codeSnippet = Font.system(size: 12, weight: .medium, design: .monospaced)
}
