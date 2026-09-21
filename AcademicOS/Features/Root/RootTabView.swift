import SwiftUI

/// Root tab coordinator holding the 5 primary navigation tabs of AcademicOS.
public struct RootTabView: View {
    @EnvironmentObject private var container: AppContainer
    @State private var selectedTab: Tab = .command

    public enum Tab: String, CaseIterable, Identifiable {
        case command = "Command"
        case courses = "Courses"
        case calendar = "Calendar"
        case ai = "AI"
        case profile = "Profile"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .command: return "terminal.fill"
            case .courses: return "books.vertical.fill"
            case .calendar: return "calendar"
            case .ai: return "sparkles"
            case .profile: return "person.crop.circle"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Global Offline & Local-First Resiliency Indicator
            OfflineBanner(
                status: container.networkStatus,
                pendingSyncCount: container.pendingSyncCount
            )

            TabView(selection: $selectedTab) {
                NavigationStack {
                    CommandDashboardView()
                }
                .tabItem {
                    Label(Tab.command.rawValue, systemImage: Tab.command.iconName)
                }
                .tag(Tab.command)

                NavigationStack {
                    CoursesListView()
                }
                .tabItem {
                    Label(Tab.courses.rawValue, systemImage: Tab.courses.iconName)
                }
                .tag(Tab.courses)

                NavigationStack {
                    AcademicCalendarView()
                }
                .tabItem {
                    Label(Tab.calendar.rawValue, systemImage: Tab.calendar.iconName)
                }
                .tag(Tab.calendar)

                NavigationStack {
                    AICommandCenterView()
                }
                .tabItem {
                    Label(Tab.ai.rawValue, systemImage: Tab.ai.iconName)
                }
                .tag(Tab.ai)

                NavigationStack {
                    ProfileView()
                }
                .tabItem {
                    Label(Tab.profile.rawValue, systemImage: Tab.profile.iconName)
                }
                .tag(Tab.profile)
            }
            .tint(Color.academicPrimary)
        }
    }
}
