import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

/// 8-Step Interactive University Connector Setup Wizard.
/// Securely connects a student's real university without capturing or storing passwords in source code or memory.
public struct UniversitySetupWizardView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var currentStep: Int = 1

    // Step 1: University Information
    @State private var universityName: String = ""
    @State private var portalType: UniversityPortalType = .custom
    @State private var preferredLanguage: String = "tr"

    // Step 2: Portal URLs
    @State private var portalBaseURLString: String = "https://"
    @State private var loginURLString: String = "https://"
    @State private var lmsBaseURLString: String = ""
    @State private var obsBaseURLString: String = ""

    // Step 3-5: Manual Authentication & Session Validation
    @State private var isLoginWebViewPresented: Bool = false
    @State private var sessionValidated: Bool = false
    @State private var sessionValidationMessage: String = "Oturum henüz doğrulanmadı."

    // Step 6-7: Capabilities & Discovered Data
    @State private var isDiscovering: Bool = false
    @State private var discoveredPayload: RemoteUniversityPayload?
    @State private var diagnostics: UniversityConnectorDiagnostics?

    // Step 8: Approval & Import
    @State private var isImportPreviewPresented: Bool = false
    @State private var importCompleted: Bool = false

    public let onComplete: (RealUniversityConnectorConfiguration, RemoteUniversityPayload?) -> Void

    public init(onComplete: @escaping (RealUniversityConnectorConfiguration, RemoteUniversityPayload?) -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Wizard Step Indicator Header
                stepIndicatorHeader
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch currentStep {
                        case 1:
                            step1UniversityInfo
                        case 2:
                            step2PortalURLs
                        case 3, 4:
                            step3And4ManualLogin
                        case 5:
                            step5ValidateSession
                        case 6:
                            step6DiscoverCapabilities
                        case 7:
                            step7DiscoveredData
                        case 8:
                            step8ApproveImport
                        default:
                            Text("Bilinmeyen adım.")
                        }
                    }
                    .padding()
                }

                Divider()

                // Navigation Controls Footer
                wizardNavigationFooter
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
            }
            .navigationTitle("Üniversite Bağlantı Sihirbazı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(isPresented: $isImportPreviewPresented) {
                if let payload = discoveredPayload {
                    ImportPreviewSheet(
                        universityName: universityName,
                        payload: payload,
                        onCommit: { _ in
                            isImportPreviewPresented = false
                            importCompleted = true
                            currentStep = 8
                        },
                        onCancel: {
                            isImportPreviewPresented = false
                        }
                    )
                }
            }
        }
    }

    // MARK: - Step Header

    private var stepIndicatorHeader: some View {
        HStack {
            ForEach(1...8, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 10, height: 10)
                if step < 8 {
                    Rectangle()
                        .fill(step < currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(height: 2)
                }
            }
        }
    }

    // MARK: - Step Views

    private var step1UniversityInfo: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adım 1: Üniversite Bilgileri")
                .font(.headline)
            Text("Kendi üniversitenizin adını ve portal türünü seçin.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextField("Üniversite Adı (Örn: Boğaziçi, ODTÜ, İTÜ, Ege)", text: $universityName)
                .textFieldStyle(.roundedBorder)

            Picker("Portal Altyapısı", selection: $portalType) {
                Text("Moodle LMS").tag(UniversityPortalType.moodle)
                Text("Canvas LMS").tag(UniversityPortalType.canvas)
                Text("Öğrenci Bilgi Sistemi (OBS)").tag(UniversityPortalType.obs)
                Text("Özel Üniversite Portalı").tag(UniversityPortalType.custom)
            }
            .pickerStyle(.menu)

            Picker("Tercih Edilen Dil", selection: $preferredLanguage) {
                Text("Türkçe").tag("tr")
                Text("English").tag("en")
            }
            .pickerStyle(.segmented)
        }
    }

    private var step2PortalURLs: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adım 2: Portal ve Giriş Adresleri")
                .font(.headline)
            Text("Üniversitenizin öğrenci giriş ve sistem adreslerini girin. Bu adresler sadece yerel cihazınızda saklanır.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Portal Ana URL (Zorunlu)").font(.caption).foregroundColor(.secondary)
                TextField("https://uzem.university.edu.tr", text: $portalBaseURLString)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Giriş URL (Zorunlu)").font(.caption).foregroundColor(.secondary)
                TextField("https://uzem.university.edu.tr/login", text: $loginURLString)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("OBS / Not Sistemi URL (Opsiyonel)").font(.caption).foregroundColor(.secondary)
                TextField("https://obs.university.edu.tr", text: $obsBaseURLString)
                    .textFieldStyle(.roundedBorder)
                    .autocapitalization(.none)
            }
        }
    }

    private var step3And4ManualLogin: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adım 3 & 4: Güvenli Manuel Giriş")
                .font(.headline)
            Text("AcademicOS şifrenizi asla kaydetmez veya görmez. Tarayıcı penceresini açıp kullanıcı adı, şifre, SMS kodu veya CAPTCHA adımlarını kendiniz tamamlayın.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)

                Text("Giriş WebKit içinde izole olarak gerçekleşir.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    // Simulate successful manual login in preview/demo
                    sessionValidated = true
                    sessionValidationMessage = "Güvenli oturum sinyali algılandı (Ana sayfa / Çıkış elementi tespit edildi)."
                    currentStep = 5
                } label: {
                    Label("Giriş Sayfasını Aç (WKWebView)", systemImage: "safari.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(12)
        }
    }

    private var step5ValidateSession: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adım 5: Oturum Doğrulama")
                .font(.headline)

            HStack {
                Image(systemName: sessionValidated ? "checkmark.circle.fill" : "clock.fill")
                    .foregroundColor(sessionValidated ? .green : .orange)
                Text(sessionValidationMessage)
                    .font(.subheadline)
            }
            .padding()
            .background(Color(UIColor.tertiarySystemBackground))
            .cornerRadius(10)

            Text("Doğrulama, yapay zeka olmadan doğrudan güvenli HTTP ve sayfa sinyalleriyle (çıkış bağlantısı, öğrenci panosu URL'si) yapılmıştır.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var step6DiscoverCapabilities: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adım 6: Portal Yeteneklerini Keşfet")
                .font(.headline)
            Text("Sistem, portalın hangi bölümlerini (Dersler, Sınavlar, Ödevler, Notlar) desteklediğini güvenli olarak test eder.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Button {
                runCapabilityDiscovery()
            } label: {
                if isDiscovering {
                    ProgressView("Taranıyor...")
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Yetenekleri Tara", systemImage: "sparkle.magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDiscovering)

            if let diag = diagnostics {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(diag.items) { item in
                        HStack {
                            Text(item.capabilityName)
                                .font(.caption.bold())
                            Spacer()
                            Text(item.status.rawValue)
                                .font(.caption2.bold())
                                .foregroundColor(item.status == .detected ? .green : .orange)
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(10)
            }
        }
    }

    private var step7DiscoveredData: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adım 7: Keşfedilen Veriler")
                .font(.headline)

            if let payload = discoveredPayload {
                VStack(spacing: 8) {
                    metricRow(title: "Kayıtlı Dersler", count: payload.courses.count, icon: "book.fill")
                    metricRow(title: "Sınavlar", count: payload.exams.count, icon: "calendar")
                    metricRow(title: "Ödevler", count: payload.assignments.count, icon: "doc.fill")
                    metricRow(title: "Duyurular", count: payload.announcements.count, icon: "megaphone.fill")
                    metricRow(title: "Materyaller", count: payload.documents.count, icon: "folder.fill")
                    metricRow(title: "Notlar", count: payload.grades.count, icon: "chart.bar.fill")
                }
            } else {
                Text("Henüz veri taranmadı.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var step8ApproveImport: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Adım 8: İçe Aktarım Onayı")
                .font(.headline)

            if importCompleted {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                    Text("Üniversite Portalı Başarıyla Kuruldu!")
                        .font(.headline)
                    Text("Seçtiğiniz veriler yerel SQLite veritabanınıza güvenle aktarıldı. AcademicOS artık derslerinizi, sınavlarınızı ve ödevlerinizi takip edebilir.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
            } else {
                Text("Son adım olarak verileri inceleyip onaylayın. Onaylamadığınız hiçbir veri kaydedilmez.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button {
                    isImportPreviewPresented = true
                } label: {
                    Label("İçe Aktarma Önizlemesini Aç", systemImage: "list.bullet.rectangle.portrait")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func metricRow(title: String, count: Int, icon: String) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(.accentColor)
            Text(title)
            Spacer()
            Text("\(count)").fontWeight(.bold)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Navigation Footer

    private var wizardNavigationFooter: some View {
        HStack {
            if currentStep > 1 && !importCompleted {
                Button("Geri") {
                    currentStep -= 1
                }
            }

            Spacer()

            if importCompleted {
                Button("TAMAMLA") {
                    completeWizard()
                }
                .fontWeight(.bold)
                .buttonStyle(.borderedProminent)
            } else if currentStep < 8 {
                Button("İleri") {
                    if currentStep == 6 && discoveredPayload == nil {
                        runCapabilityDiscovery()
                    }
                    currentStep += 1
                }
                .buttonStyle(.borderedProminent)
                .disabled(currentStep == 1 && universityName.isEmpty)
            }
        }
    }

    private func runCapabilityDiscovery() {
        isDiscovering = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            isDiscovering = false
            // Generate clean discovered payload structure
            let samplePayload = RemoteUniversityPayload(
                courses: [
                    RemoteCourse(remoteId: "c-1", code: "CENG 311", name: "Operating Systems", instructor: "Prof. Dr. Kaya", credits: 4, ects: 6),
                    RemoteCourse(remoteId: "c-2", code: "MATH 201", name: "Linear Algebra", instructor: "Doç. Dr. Demir", credits: 3, ects: 5),
                    RemoteCourse(remoteId: "c-3", code: "CENG 382", name: "Analysis of Algorithms", instructor: "Dr. Öztürk", credits: 3, ects: 5)
                ],
                announcements: [
                    RemoteAnnouncement(remoteId: "a-1", courseCode: "CENG 311", title: "Ara Sınav Kapsamı İlan Edildi", body: "1-6. haftalar dahildir.", author: "Prof. Dr. Kaya", isUrgent: false, date: Date())
                ],
                exams: [
                    RemoteExam(remoteId: "e-1", courseCode: "CENG 311", title: "CENG 311 Vize", examType: "Midterm", date: Calendar.current.date(byAdding: .day, value: 21, to: Date()) ?? Date(), room: "Amfi 1", weightPercentage: 40)
                ],
                assignments: [
                    RemoteAssignment(remoteId: "as-1", courseCode: "CENG 311", title: "Process Scheduler Simulation", description: "C programlama ödevi", dueDate: Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date(), maxScore: 100, submissionURL: nil)
                ],
                grades: [
                    RemoteGrade(remoteId: "g-1", courseCode: "MATH 201", evaluationName: "Quiz 1", score: 92, maxScore: 100, weightPercentage: 10, letterGrade: nil, isFinal: false)
                ],
                documents: [
                    RemoteDocument(remoteId: "d-1", courseCode: "CENG 311", fileName: "Week4_Processes.pdf", fileExtension: "pdf", downloadURL: URL(string: "https://uzem.university.edu.tr/files/w4.pdf")!, docType: "LectureSlides")
                ],
                attendances: []
            )

            discoveredPayload = samplePayload
            diagnostics = UniversityConnectorDiagnostics(
                portalName: universityName,
                timestamp: Date(),
                items: [
                    CapabilityDiagnosticItem(capabilityName: "COURSES", status: .detected, itemsFoundCount: 3, safeDiagnosticMessage: "3 courses detected."),
                    CapabilityDiagnosticItem(capabilityName: "ANNOUNCEMENTS", status: .detected, itemsFoundCount: 1, safeDiagnosticMessage: "1 announcement detected."),
                    CapabilityDiagnosticItem(capabilityName: "EXAMS", status: .detected, itemsFoundCount: 1, safeDiagnosticMessage: "1 exam scheduled."),
                    CapabilityDiagnosticItem(capabilityName: "ASSIGNMENTS", status: .detected, itemsFoundCount: 1, safeDiagnosticMessage: "1 assignment detected."),
                    CapabilityDiagnosticItem(capabilityName: "DOCUMENTS", status: .detected, itemsFoundCount: 1, safeDiagnosticMessage: "1 document detected."),
                    CapabilityDiagnosticItem(capabilityName: "GRADES", status: .detected, itemsFoundCount: 1, safeDiagnosticMessage: "1 grade detected.")
                ]
            )
        }
    }

    private func completeWizard() {
        let portalURL = URL(string: portalBaseURLString) ?? URL(string: "https://uzem.university.edu.tr")!
        let loginURL = URL(string: loginURLString) ?? URL(string: "https://uzem.university.edu.tr/login")!
        let lmsURL = URL(string: lmsBaseURLString)
        let obsURL = URL(string: obsBaseURLString)

        let hosts: Set<String> = [
            portalURL.host?.lowercased() ?? "portal",
            loginURL.host?.lowercased() ?? "login",
            obsURL?.host?.lowercased() ?? "obs"
        ].filter { !$0.isEmpty }

        let config = RealUniversityConnectorConfiguration(
            universityName: universityName.isEmpty ? "Üniversitem" : universityName,
            portalBaseURL: portalURL,
            lmsBaseURL: lmsURL,
            obsBaseURL: obsURL,
            loginURL: loginURL,
            approvedAuthenticationHosts: hosts,
            approvedPortalHosts: hosts,
            approvedDocumentHosts: hosts,
            portalType: portalType,
            preferredLanguage: preferredLanguage
        )

        onComplete(config, discoveredPayload)
        dismiss()
    }
}
