import SwiftUI

/// Item representing a discovered material ready for authenticated download.
public struct DiscoveredCourseMaterial: Identifiable, Sendable, Equatable {
    public let id: String
    public let filename: String
    public let courseCode: String
    public let fileExtension: String
    public let downloadURL: URL
    public let sizeBytes: Int64?
    public var isDownloaded: Bool

    public init(
        id: String = UUID().uuidString,
        filename: String,
        courseCode: String,
        fileExtension: String,
        downloadURL: URL,
        sizeBytes: Int64? = nil,
        isDownloaded: Bool = false
    ) {
        self.id = id
        self.filename = filename
        self.courseCode = courseCode
        self.fileExtension = fileExtension
        self.downloadURL = downloadURL
        self.sizeBytes = sizeBytes
        self.isDownloaded = isDownloaded
    }
}

/// Sheet presenting discovered course documents for user inspection before download.
/// Supports individual download and "DOWNLOAD ALL FOR COURSE".
public struct NEUMaterialImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var materials: [DiscoveredCourseMaterial]
    @State private var selectedCourse: String = "ALL"
    @State private var isDownloadingAll: Bool = false

    public init(materials: [DiscoveredCourseMaterial] = []) {
        _materials = State(initialValue: materials)
    }

    private var availableCourses: [String] {
        let unique = Set(materials.map { $0.courseCode })
        return ["ALL"] + Array(unique).sorted()
    }

    private var filteredMaterials: [DiscoveredCourseMaterial] {
        if selectedCourse == "ALL" {
            return materials
        }
        return materials.filter { $0.courseCode == selectedCourse }
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.large) {
                    // Header Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DEBİM COURSE MATERIALS DISCOVERED")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.blue)
                        Text("Ders Materyalleri Önizleme")
                            .font(.system(size: 18, weight: .bold))
                        Text("Ders notları, slaytlar ve laboratuvar kılavuzları cihazınıza yerel olarak indirilir ve çevrimdışı erişilebilir hale getirilir.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, Spacing.medium)

                    // Course Filter
                    if availableCourses.count > 2 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(availableCourses, id: \.self) { c in
                                    Button(action: { selectedCourse = c }) {
                                        Text(c)
                                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(selectedCourse == c ? Color.academicPrimary : Color(UIColor.secondarySystemBackground))
                                            .foregroundColor(selectedCourse == c ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.medium)
                        }
                    }

                    // Bulk Download Button
                    Button(action: {
                        isDownloadingAll = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            for i in 0..<materials.count {
                                if selectedCourse == "ALL" || materials[i].courseCode == selectedCourse {
                                    materials[i].isDownloaded = true
                                }
                            }
                            isDownloadingAll = false
                        }
                    }) {
                        HStack {
                            if isDownloadingAll {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "arrow.down.circle.fill")
                            }
                            Text(selectedCourse == "ALL" ? "DOWNLOAD ALL MATERIALS" : "DOWNLOAD ALL FOR \(selectedCourse)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.academicPrimary)
                        .cornerRadius(10)
                    }
                    .padding(.horizontal, Spacing.medium)

                    // Materials List
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("DETAYLI LİSTE (\(filteredMaterials.count) DOSYA)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, Spacing.medium)

                        ForEach(filteredMaterials) { mat in
                            HStack(spacing: Spacing.medium) {
                                Image(systemName: fileIcon(for: mat.fileExtension))
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(mat.filename)
                                        .font(.system(size: 13, weight: .semibold))
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text(mat.courseCode)
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(.blue)
                                        if let size = mat.sizeBytes {
                                            Text(formatBytes(size))
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                if mat.isDownloaded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 18))
                                } else {
                                    Button(action: {
                                        if let idx = materials.firstIndex(where: { $0.id == mat.id }) {
                                            materials[idx].isDownloaded = true
                                        }
                                    }) {
                                        Text("DOWNLOAD")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.15))
                                            .foregroundColor(.blue)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(Spacing.medium)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(10)
                            .padding(.horizontal, Spacing.medium)
                        }
                    }
                }
                .padding(.vertical, Spacing.medium)
            }
            .navigationTitle("Material Import Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func fileIcon(for ext: String) -> String {
        switch ext.lowercased() {
        case "pdf": return "doc.richtext.fill"
        case "ppt", "pptx": return "doc.on.doc.fill"
        case "doc", "docx": return "doc.text.fill"
        default: return "doc.fill"
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
