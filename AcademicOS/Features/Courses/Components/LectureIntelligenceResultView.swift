import SwiftUI

/// Premium result screen presenting the holistic synthesis of a processed lecture.
public struct LectureIntelligenceResultView: View {
    public let courseName: String
    public let summary: String
    public let keyTopics: [String]
    public let emphasisItems: [ProfessorEmphasis]
    public let definitions: [DefinitionItem]
    public let onSeekToTimestamp: (Double) -> Void

    public init(
        courseName: String,
        summary: String,
        keyTopics: [String] = [],
        emphasisItems: [ProfessorEmphasis] = [],
        definitions: [DefinitionItem] = [],
        onSeekToTimestamp: @escaping (Double) -> Void = { _ in }
    ) {
        self.courseName = courseName
        self.summary = summary
        self.keyTopics = keyTopics
        self.emphasisItems = emphasisItems
        self.definitions = definitions
        self.onSeekToTimestamp = onSeekToTimestamp
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                // Header Banner
                AcademicCard(
                    cornerRadius: CornerRadius.large,
                    padding: Spacing.medium,
                    borderColor: Color.academicPrimary.opacity(0.4),
                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                ) {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(Color.academicEmerald)
                            Text("LECTURE INTELLIGENCE COMPLETE")
                                .font(.system(size: 11, weight: .black, design: .monospaced))
                                .foregroundColor(Color.textPrimary)
                            Spacer()
                            StatusBadge("SYNTHESIZED", style: .emerald)
                        }

                        Text("Comprehensive analysis for \(courseName). Multi-tier exam hints, structured notes, and memory entries have been generated and isolated.")
                            .font(.commandSubheadline)
                            .foregroundColor(Color.textSecondary)
                    }
                }

                // Section 1: Executive Summary
                VStack(alignment: .leading, spacing: Spacing.xSmall) {
                    Text("EXECUTIVE LECTURE OVERVIEW")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color.textSecondary)

                    AcademicCard(
                        cornerRadius: CornerRadius.medium,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        Text(summary)
                            .font(.commandBody)
                            .foregroundColor(Color.textPrimary)
                            .lineSpacing(3)
                    }
                }

                // Section 2: Professor Emphasis & Exam Hints (Strict Certainty Standards)
                if !emphasisItems.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        HStack {
                            Text("PROFESSOR EMPHASIS & EXAM HINTS")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color.textSecondary)
                            Spacer()
                            Text("\(emphasisItems.count) Identified")
                                .font(.commandCaption)
                                .foregroundColor(Color.textTertiary)
                        }

                        ForEach(emphasisItems) { item in
                            Button(action: { onSeekToTimestamp(item.startTime) }) {
                                AcademicCard(
                                    cornerRadius: CornerRadius.medium,
                                    padding: Spacing.medium,
                                    borderColor: item.classification.accentColor.opacity(0.4),
                                    backgroundColor: Color(uiColor: .secondarySystemBackground)
                                ) {
                                    VStack(alignment: .leading, spacing: Spacing.xxSmall) {
                                        HStack {
                                            StatusBadge(
                                                item.classification.title,
                                                style: item.classification == .explicitExamHint ? .crimson : .amber
                                            )
                                            Spacer()
                                            HStack(spacing: 4) {
                                                Image(systemName: "play.circle.fill")
                                                    .font(.system(size: 12))
                                                Text(item.formattedTimestamp)
                                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            }
                                            .foregroundColor(item.classification.accentColor)
                                        }

                                        Text("\"\(item.exactSourceSnippet)\"")
                                            .font(.commandBody)
                                            .foregroundColor(Color.textPrimary)
                                            .multilineTextAlignment(.leading)
                                            .padding(.top, 2)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                // Section 3: Key Definitions
                if !definitions.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("IDENTIFIED DEFINITIONS")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color.textSecondary)

                        ForEach(definitions, id: \.term) { def in
                            AcademicCard(
                                cornerRadius: CornerRadius.medium,
                                padding: Spacing.medium,
                                backgroundColor: Color(uiColor: .secondarySystemBackground)
                            ) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(def.term)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(Color.academicPrimary)
                                    Text(def.definition)
                                        .font(.commandSubheadline)
                                        .foregroundColor(Color.textPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(Spacing.medium)
        }
        .background(Color.backgroundPrimary.ignoresSafeArea())
        .navigationTitle("Lecture Intelligence")
        .navigationBarTitleDisplayMode(.inline)
    }
}
