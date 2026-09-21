import Foundation

/// Defines how course units are weighted when calculating GPA.
public enum GPAWeightingPolicy: Codable, Sendable, Equatable {
    /// Weights courses using local university credit hours (e.g. 3 or 4 credits).
    case localCourseCredits

    /// Weights courses using European Credit Transfer and Accumulation System (ECTS) credits.
    case ectsCredits

    /// Equal weighting across all courses regardless of credit count.
    case equalWeight

    /// Custom weight mapping per course code (courseCode: weight).
    case custom([String: Double])

    public var displayName: String {
        switch self {
        case .localCourseCredits: return "Local Course Credits"
        case .ectsCredits: return "ECTS Credits"
        case .equalWeight: return "Equal Weighting"
        case .custom: return "Custom Course Weights"
        }
    }
}

/// Verification status of a GPA calculation.
public enum GPAVerificationStatus: String, Codable, Sendable {
    /// Weighting and grade boundary verified against official university regulation.
    case verifiedOfficial = "Verified Official Regulation"

    /// Approximate projection based on default or student-configured assumptions.
    case projectedEstimate = "Projected Estimate (Unofficial)"
}

/// Configurable grade points scheme (e.g., standard 4.0 scale or custom university scale).
public struct GradeScaleConfiguration: Codable, Sendable, Equatable {
    public var pointsMapping: [String: Double]
    public var minimumPassingPoint: Double
    public var isVerifiedByUniversityRules: Bool

    public init(
        pointsMapping: [String: Double] = Self.standardScale,
        minimumPassingPoint: Double = 1.0,
        isVerifiedByUniversityRules: Bool = false
    ) {
        self.pointsMapping = pointsMapping
        self.minimumPassingPoint = minimumPassingPoint
        self.isVerifiedByUniversityRules = isVerifiedByUniversityRules
    }

    public static let standardScale: [String: Double] = [
        "AA": 4.0, "A+": 4.0, "A": 3.75,
        "BA": 3.5, "A-": 3.5,
        "BB": 3.0, "B+": 3.25, "B": 3.0,
        "CB": 2.5, "B-": 2.75,
        "CC": 2.0, "C+": 2.25, "C": 2.0,
        "DC": 1.5, "C-": 1.75,
        "DD": 1.0, "D": 1.0,
        "FD": 0.5,
        "FF": 0.0, "F": 0.0
    ]
}
