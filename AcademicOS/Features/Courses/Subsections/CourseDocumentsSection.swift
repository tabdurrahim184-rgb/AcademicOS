import SwiftUI

/// Documents tab inside Course Detail displaying syllabus, slides, and indexed research PDFs.
public struct CourseDocumentsSection: View {
    public let documents: [AcademicDocument]

    public init(documents: [AcademicDocument]) {
        self.documents = documents
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if documents.isEmpty {
                EmptyStateView(
                    icon: "doc.text.magnifyingglass",
                    title: "No Course Documents",
                    message: "Upload syllabi, lecture slides, or PDF readings. Documents are stored locally and indexed for Course AI retrieval.",
                    actionTitle: "Upload Document"
                ) {
                    // Upload document handler
                }
            } else {
                ForEach(documents) { doc in
                    AcademicCard(
                        cornerRadius: CornerRadius.medium,
                        padding: Spacing.medium,
                        backgroundColor: Color(uiColor: .secondarySystemBackground)
                    ) {
                        HStack(spacing: Spacing.medium) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20))
                                .foregroundColor(Color.academicPrimary)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(doc.fileName)
                                    .font(.commandHeadline)
                                    .foregroundColor(Color.textPrimary)

                                Text("\(doc.docType.rawValue) • \(doc.formattedSize)")
                                    .font(.commandCaption)
                                    .foregroundColor(Color.textSecondary)
                            }

                            Spacer()

                            if doc.isIndexedForAI {
                                StatusBadge("INDEXED", icon: "bolt.fill", style: .emerald)
                            }
                        }
                    }
                }
            }
        }
    }
}
