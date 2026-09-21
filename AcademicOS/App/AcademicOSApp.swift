import SwiftUI

@main
struct AcademicOSApp: App {
    @StateObject private var container = AppContainer.shared
    @State private var isOnboarded: Bool = false
    @State private var isCheckingOnboarding: Bool = true

    var body: some Scene {
        WindowGroup {
            Group {
                if isCheckingOnboarding {
                    ZStack {
                        Color(uiColor: .systemBackground).ignoresSafeArea()
                        ProgressView()
                            .tint(Color.academicPrimary)
                    }
                } else if isOnboarded {
                    RootTabView()
                } else {
                    OnboardingView {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            self.isOnboarded = true
                        }
                    }
                }
            }
            .environmentObject(container)
            .preferredColorScheme(.dark) // Command center aesthetic defaults to dark mode
            .task {
                await checkOnboardingStatus()
            }
        }
    }

    private func checkOnboardingStatus() async {
        do {
            let student = try await container.studentRepository.getStudent()
            await MainActor.run {
                self.isOnboarded = (student != nil)
                self.isCheckingOnboarding = false
            }
        } catch {
            await MainActor.run {
                self.isOnboarded = false
                self.isCheckingOnboarding = false
            }
        }
    }
}
