import Foundation

/// Grade item input for GPA calculation.
public struct GPASubjectItem: Sendable {
    public let courseCode: String
    public let credits: Int
    public let ects: Int
    public let letterGrade: String?
    public let numericalScore: Double?

    public init(courseCode: String, credits: Int, ects: Int, letterGrade: String?, numericalScore: Double? = nil) {
        self.courseCode = courseCode
        self.credits = credits
        self.ects = ects
        self.letterGrade = letterGrade
        self.numericalScore = numericalScore
    }
}

/// Comprehensive GPA computation results.
public struct GPAResult: Sendable, Equatable {
    public let gpa: Double
    public let weightingPolicy: GPAWeightingPolicy
    public let verificationStatus: GPAVerificationStatus
    public let totalCreditsAttempted: Int
    public let totalCreditsEarned: Int
    public let totalECTSAttempted: Int
    public let totalECTSEarned: Int
    public let honorStatus: String?

    public init(
        gpa: Double,
        weightingPolicy: GPAWeightingPolicy = .localCourseCredits,
        verificationStatus: GPAVerificationStatus = .projectedEstimate,
        totalCreditsAttempted: Int,
        totalCreditsEarned: Int,
        totalECTSAttempted: Int,
        totalECTSEarned: Int,
        honorStatus: String? = nil
    ) {
        self.gpa = gpa
        self.weightingPolicy = weightingPolicy
        self.verificationStatus = verificationStatus
        self.totalCreditsAttempted = totalCreditsAttempted
        self.totalCreditsEarned = totalCreditsEarned
        self.totalECTSAttempted = totalECTSAttempted
        self.totalECTSEarned = totalECTSEarned
        self.honorStatus = honorStatus
    }
}

/// Deterministic GPA calculator supporting multiple weighting policies and configurable grade scales.
public struct GPACalculator: Sendable {
    public var defaultPolicy: GPAWeightingPolicy
    public var scaleConfiguration: GradeScaleConfiguration

    public init(
        defaultPolicy: GPAWeightingPolicy = .localCourseCredits,
        scaleConfiguration: GradeScaleConfiguration = GradeScaleConfiguration()
    ) {
        self.defaultPolicy = defaultPolicy
        self.scaleConfiguration = scaleConfiguration
    }

    /// Converts a letter grade to points using the configured scale.
    public func gradePoints(for letter: String) -> Double {
        let clean = letter.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return scaleConfiguration.pointsMapping[clean] ?? 0.0
    }

    /// Static standard 4.0 scale points lookup.
    public static func gradePoints(for letter: String) -> Double {
        let clean = letter.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return GradeScaleConfiguration.standardScale[clean] ?? 0.0
    }

    /// Converts a 0-100 numerical percentage score to the standard letter grade.
    public static func letterGrade(forScore score: Double) -> String {
        switch score {
        case 90.0...100.0: return "AA"
        case 85.0..<90.0: return "BA"
        case 80.0..<85.0: return "BB"
        case 75.0..<80.0: return "CB"
        case 70.0..<75.0: return "CC"
        case 65.0..<70.0: return "DC"
        case 60.0..<65.0: return "DD"
        case 50.0..<60.0: return "FD"
        default: return "FF"
        }
    }

    /// Calculates weighted GPA using the specified policy.
    public func calculateGPA(
        subjects: [GPASubjectItem],
        policy: GPAWeightingPolicy? = nil
    ) -> GPAResult {
        let activePolicy = policy ?? defaultPolicy

        guard !subjects.isEmpty else {
            return GPAResult(
                gpa: 0.0,
                weightingPolicy: activePolicy,
                verificationStatus: scaleConfiguration.isVerifiedByUniversityRules ? .verifiedOfficial : .projectedEstimate,
                totalCreditsAttempted: 0,
                totalCreditsEarned: 0,
                totalECTSAttempted: 0,
                totalECTSEarned: 0
            )
        }

        var totalWeight: Double = 0.0
        var totalWeightedPoints: Double = 0.0
        var creditsAttempted = 0
        var creditsEarned = 0
        var ectsAttempted = 0
        var ectsEarned = 0

        for subject in subjects {
            let weight: Double
            switch activePolicy {
            case .localCourseCredits:
                weight = Double(max(1, subject.credits))
            case .ectsCredits:
                weight = Double(max(1, subject.ects))
            case .equalWeight:
                weight = 1.0
            case .custom(let customWeights):
                weight = customWeights[subject.courseCode] ?? Double(subject.credits)
            }

            let letter: String
            if let l = subject.letterGrade, !l.isEmpty {
                letter = l
            } else if let s = subject.numericalScore {
                letter = Self.letterGrade(forScore: s)
            } else {
                continue // Incomplete evaluation
            }

            let pts = gradePoints(for: letter)
            totalWeightedPoints += pts * weight
            totalWeight += weight

            creditsAttempted += subject.credits
            ectsAttempted += subject.ects

            if pts >= scaleConfiguration.minimumPassingPoint {
                creditsEarned += subject.credits
                ectsEarned += subject.ects
            }
        }

        let finalGPA = totalWeight > 0 ? (totalWeightedPoints / totalWeight) : 0.0
        let roundedGPA = (finalGPA * 100.0).rounded() / 100.0

        let honor: String?
        if roundedGPA >= 3.50 {
            honor = "High Honor (Yüksek Onur)"
        } else if roundedGPA >= 3.00 {
            honor = "Honor (Onur)"
        } else {
            honor = nil
        }

        let verificationStatus: GPAVerificationStatus = scaleConfiguration.isVerifiedByUniversityRules
            ? .verifiedOfficial
            : .projectedEstimate

        return GPAResult(
            gpa: roundedGPA,
            weightingPolicy: activePolicy,
            verificationStatus: verificationStatus,
            totalCreditsAttempted: creditsAttempted,
            totalCreditsEarned: creditsEarned,
            totalECTSAttempted: ectsAttempted,
            totalECTSEarned: ectsEarned,
            honorStatus: honor
        )
    }

    /// Projects required GPA in remaining semesters to hit graduation target GPA.
    public func requiredFutureGPA(currentGPA: Double, completedCredits: Int, targetGPA: Double, totalCreditsRequired: Int) -> Double? {
        let remaining = totalCreditsRequired - completedCredits
        guard remaining > 0 else { return nil }

        let currentPoints = currentGPA * Double(completedCredits)
        let targetTotalPoints = targetGPA * Double(totalCreditsRequired)
        let requiredRemainingPoints = targetTotalPoints - currentPoints

        let neededGPA = requiredRemainingPoints / Double(remaining)
        return (neededGPA * 100.0).rounded() / 100.0
    }
}
