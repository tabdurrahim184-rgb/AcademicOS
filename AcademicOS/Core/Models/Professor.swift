import Foundation

/// Represents a course instructor or academic advisor.
public struct Professor: Identifiable, Codable, Equatable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var title: String
    public var email: String
    public var officeLocation: String
    public var officeHours: String
    public var notes: String

    public init(
        id: UUID = UUID(),
        name: String,
        title: String = "Prof. Dr.",
        email: String = "",
        officeLocation: String = "",
        officeHours: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.title = title
        self.email = email
        self.officeLocation = officeLocation
        self.officeHours = officeHours
        self.notes = notes
    }
}
