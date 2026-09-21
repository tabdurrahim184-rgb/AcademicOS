import SwiftUI

/// Structured chat message in the Course AI consultation thread.
public struct CourseChatMessage: Identifiable, Sendable {
    public let id: UUID
    public let isUser: Bool
    public let text: String
    public let providerBadge: String?
    public let sourceCitation: String?
    public let date: Date

    public init(
        id: UUID = UUID(),
        isUser: Bool,
        text: String,
        providerBadge: String? = nil,
        sourceCitation: String? = nil,
        date: Date = Date()
    ) {
        self.id = id
        self.isUser = isUser
        self.text = text
        self.providerBadge = providerBadge
        self.sourceCitation = sourceCitation
        self.date = date
    }
}

/// Interactive Course AI conversation view with strict course memory isolation,
/// "My Materials Only" toggle, source citations, and provider status badges.
public struct CourseAISection: View {
    public let course: Course

    @State private var queryInput: String = ""
    @State private var isAnalyzing: Bool = false
    @State private var myMaterialsOnly: Bool = true
    @State private var messages: [CourseChatMessage] = []

    public init(course: Course) {
        self.course = course
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            // Mode & Isolation Header
            AcademicCard(
                cornerRadius: CornerRadius.medium,
                padding: Spacing.medium,
                borderColor: Color.academicPrimary.opacity(0.3),
                backgroundColor: Color(uiColor: .secondarySystemBackground)
            ) {
                VStack(alignment: .leading, spacing: Spacing.small) {
                    HStack {
                        Image(systemName: "brain.fill")
                            .foregroundColor(Color.academicPrimary)

                        Text("COURSE INTELLIGENCE")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.academicPrimary)

                        Spacer()

                        StatusBadge("ISOLATED MEMORY", style: .emerald)
                    }

                    // Strict Material Grounding Toggle
                    Toggle(isOn: $myMaterialsOnly) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("MY MATERIALS ONLY")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textPrimary)
                            Text(myMaterialsOnly
                                 ? "Strictly answers from course notes & transcripts. Zero external AI hallucination."
                                 : "General AI mode. May supplement with broader academic explanations.")
                                .font(.commandCaption)
                                .foregroundColor(Color.textSecondary)
                        }
                    }
                    .toggleStyle(SwitchToggleStyle(tint: Color.academicEmerald))
                    .padding(.top, 4)
                }
            }

            // Quick Prompt Suggestions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.small) {
                    QuickChip(title: "Dersi Özetle", icon: "doc.text") {
                        sendQuery("Bugünkü dersi özetle.")
                    }
                    QuickChip(title: "Hoca Final İpucu", icon: "exclamationmark.triangle") {
                        sendQuery("Hoca final sınavı hakkında ne söyledi?")
                    }
                    QuickChip(title: "Bana 5 Soru Sor", icon: "checkmark.circle") {
                        sendQuery("Bu dersten bana 5 soru sor.")
                    }
                    QuickChip(title: "Önemli Tanımlar", icon: "book.closed") {
                        sendQuery("Dersin en önemli kavram ve tanımlarını listele.")
                    }
                }
            }

            // Conversation Thread
            if messages.isEmpty {
                VStack(spacing: Spacing.small) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28))
                        .foregroundColor(Color.textTertiary)
                    Text("Ask questions grounded strictly in \(course.name) materials.")
                        .font(.commandSubheadline)
                        .foregroundColor(Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.large)
            } else {
                VStack(spacing: Spacing.small) {
                    ForEach(messages) { msg in
                        ChatMessageBubble(message: msg)
                    }
                }
            }

            if isAnalyzing {
                HStack(spacing: Spacing.small) {
                    ProgressView()
                    Text(myMaterialsOnly ? "Scanning verified course notes..." : "Synthesizing answer...")
                        .font(.commandCaption)
                        .foregroundColor(Color.textSecondary)
                }
                .padding(.vertical, Spacing.xSmall)
            }

            // Input Bar
            HStack(spacing: Spacing.small) {
                TextField("Ask course agent about notes, exams, definitions...", text: $queryInput)
                    .font(.commandBody)
                    .padding(Spacing.small)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))

                Button(action: {
                    let text = queryInput
                    queryInput = ""
                    sendQuery(text)
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(queryInput.isEmpty ? Color.textTertiary : Color.academicPrimary)
                }
                .disabled(queryInput.isEmpty || isAnalyzing)
            }
        }
    }

    private func sendQuery(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let userMsg = CourseChatMessage(isUser: true, text: text)
        messages.append(userMsg)
        isAnalyzing = true

        Task {
            let container = AppContainer.shared
            let courseAgent = container.agentCoordinator.agent(withId: "agent.course") as? CourseAgent

            var context: [String: String] = [
                "course_name": course.name,
                "course_code": course.code,
                "course_id": course.id.uuidString,
                "my_materials_only": myMaterialsOnly ? "true" : "false"
            ]

            // Inject isolated course context
            if let builder = try? await container.buildCourseContext(forCourseId: course.id) {
                context.merge(builder) { _, new in new }
            }

            let responseText: String
            let providerBadge: String
            let citation: String?

            if let agent = courseAgent {
                do {
                    let result = try await agent.queryCourse(
                        courseId: course.id,
                        courseName: course.name,
                        question: text,
                        context: context,
                        myMaterialsOnly: myMaterialsOnly
                    )
                    responseText = result.content
                    providerBadge = result.provider == .online ? "GEMINI" : "LOCAL AI"
                    citation = result.isGrounded ? "Grounded in \(course.code) Lecture Notes" : nil
                } catch {
                    responseText = "Error: \(error.localizedDescription)"
                    providerBadge = "ERROR"
                    citation = nil
                }
            } else {
                responseText = "Course Agent is currently unavailable."
                providerBadge = "LOCAL AI"
                citation = nil
            }

            await MainActor.run {
                let agentMsg = CourseChatMessage(
                    isUser: false,
                    text: responseText,
                    providerBadge: providerBadge,
                    sourceCitation: citation
                )
                self.messages.append(agentMsg)
                self.isAnalyzing = false
            }
        }
    }
}

private struct ChatMessageBubble: View {
    let message: CourseChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                if let badge = message.providerBadge {
                    HStack(spacing: 4) {
                        StatusBadge(badge, style: badge == "GEMINI" ? .indigo : .emerald)
                        if let citation = message.sourceCitation {
                            Text(citation)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textTertiary)
                        }
                    }
                }

                Text(message.text)
                    .font(.commandBody)
                    .foregroundColor(message.isUser ? Color.white : Color.textPrimary)
                    .padding(Spacing.small)
                    .background(message.isUser ? Color.academicPrimary : Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium))
            }

            if !message.isUser { Spacer() }
        }
    }
}

private struct QuickChip: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .padding(.horizontal, Spacing.small)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemBackground))
            .foregroundColor(Color.textPrimary)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.separatorPrimary, lineWidth: 1))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
