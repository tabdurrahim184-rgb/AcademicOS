import SwiftUI
import Combine

/// State management for the Courses list screen.
@MainActor
public final class CoursesViewModel: ObservableObject {
    @Published public var courses: [Course] = []
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String?
    @Published public var searchQuery: String = ""

    private let courseRepo: CourseRepositoryProtocol

    public init(courseRepo: CourseRepositoryProtocol) {
        self.courseRepo = courseRepo
    }

    public var filteredCourses: [Course] {
        if searchQuery.isEmpty {
            return courses
        }
        return courses.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.code.localizedCaseInsensitiveContains(searchQuery) ||
            $0.department.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public func loadCourses() async {
        isLoading = true
        errorMessage = nil
        do {
            self.courses = try await courseRepo.getCourses()
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
