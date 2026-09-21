import Foundation

/// Sanitized structural element representation for portal inspection.
public struct SanitizedDOMElement: Codable, Sendable, Equatable {
    public let tagName: String
    public let id: String?
    public let cssClasses: [String]
    public let fieldName: String?
    public let inputType: String?
    public let accessibleLabel: String?
    public let sampleText: String?
    public let linkDestination: String?

    public init(
        tagName: String,
        id: String? = nil,
        cssClasses: [String] = [],
        fieldName: String? = nil,
        inputType: String? = nil,
        accessibleLabel: String? = nil,
        sampleText: String? = nil,
        linkDestination: String? = nil
    ) {
        self.tagName = tagName
        self.id = id
        self.cssClasses = cssClasses
        self.fieldName = fieldName
        self.inputType = inputType
        self.accessibleLabel = accessibleLabel
        self.sampleText = sampleText
        self.linkDestination = linkDestination
    }
}

/// Sanitized structural snapshot of an inspected university portal page.
public struct SanitizedPortalSnapshot: Codable, Sendable, Equatable {
    public let url: URL
    public let pageTitle: String
    public let classifiedType: PortalPageType
    public let tableHeaders: [String]
    public let detectedForms: [String]
    public let structuralElements: [SanitizedDOMElement]
    public let capturedAt: Date

    public init(
        url: URL,
        pageTitle: String,
        classifiedType: PortalPageType,
        tableHeaders: [String] = [],
        detectedForms: [String] = [],
        structuralElements: [SanitizedDOMElement] = [],
        capturedAt: Date = Date()
    ) {
        self.url = url
        self.pageTitle = pageTitle
        self.classifiedType = classifiedType
        self.tableHeaders = tableHeaders
        self.detectedForms = detectedForms
        self.structuralElements = structuralElements
        self.capturedAt = capturedAt
    }
}

/// Developer-only portal DOM inspection service.
/// Extracts technical DOM structure needed to configure selectors while strictly redacting all sensitive credentials.
public final class PortalInspectionService: @unchecked Sendable {
    public static let shared = PortalInspectionService()

    private let classifier = PortalPageClassifier.shared
    private let sensitiveFieldNames: Set<String> = [
        "password", "sifre", "token", "csrf", "authenticity_token",
        "access_token", "secret", "cvv", "creditcard", "tc_kimlik", "auth"
    ]

    public init() {}

    /// Inspects and sanitizes a raw HTML page or DOM node structure.
    public func inspect(
        url: URL,
        pageTitle: String,
        rawHTML: String
    ) -> SanitizedPortalSnapshot {
        let classification = classifier.classify(url: url, pageTitle: pageTitle, sanitizedDOM: rawHTML)

        var elements: [SanitizedDOMElement] = []
        var headers: [String] = []
        var forms: [String] = []

        // Extract table headers safely
        let thPattern = #"<th[^>]*>(.*?)<\/th>"#
        if let regex = try? NSRegularExpression(pattern: thPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
            let matches = regex.matches(in: rawHTML, options: [], range: NSRange(rawHTML.startIndex..<rawHTML.endIndex, in: rawHTML))
            for match in matches {
                if let range = Range(match.range(at: 1), in: rawHTML) {
                    let rawHeader = String(rawHTML[range])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !rawHeader.isEmpty && !headers.contains(rawHeader) {
                        headers.append(rawHeader)
                    }
                }
            }
        }

        // Extract input fields safely (STRIPPING all values, passwords, tokens)
        let inputPattern = #"<input([^>]+)>"#
        if let regex = try? NSRegularExpression(pattern: inputPattern, options: [.caseInsensitive]) {
            let matches = regex.matches(in: rawHTML, options: [], range: NSRange(rawHTML.startIndex..<rawHTML.endIndex, in: rawHTML))
            for match in matches {
                if let range = Range(match.range(at: 1), in: rawHTML) {
                    let attrs = String(rawHTML[range])
                    let name = extractAttribute("name", from: attrs)
                    let type = extractAttribute("type", from: attrs)?.lowercased() ?? "text"
                    let id = extractAttribute("id", from: attrs)
                    let css = extractAttribute("class", from: attrs)?.components(separatedBy: " ") ?? []

                    let isSensitive = type == "password" || (name != nil && sensitiveFieldNames.contains(where: { name!.lowercased().contains($0) }))
                    if !isSensitive {
                        elements.append(SanitizedDOMElement(
                            tagName: "input",
                            id: id,
                            cssClasses: css,
                            fieldName: name,
                            inputType: type,
                            accessibleLabel: extractAttribute("aria-label", from: attrs) ?? extractAttribute("placeholder", from: attrs),
                            sampleText: nil // NEVER capture user-entered values
                        ))
                    }
                }
            }
        }

        // Extract links
        let aPattern = #"<a\s+[^>]*href=["']([^"']+)["'][^>]*>(.*?)<\/a>"#
        if let regex = try? NSRegularExpression(pattern: aPattern, options: [.caseInsensitive]) {
            let matches = regex.matches(in: rawHTML, options: [], range: NSRange(rawHTML.startIndex..<rawHTML.endIndex, in: rawHTML))
            for match in matches.prefix(30) {
                if let hrefRange = Range(match.range(at: 1), in: rawHTML),
                   let textRange = Range(match.range(at: 2), in: rawHTML) {
                    let href = String(rawHTML[hrefRange])
                    let text = String(rawHTML[textRange])
                        .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)

                    // Strip any query parameters from links that might contain tokens
                    let cleanHref = href.components(separatedBy: "?").first ?? href
                    elements.append(SanitizedDOMElement(
                        tagName: "a",
                        cssClasses: [],
                        sampleText: text.prefix(60).description,
                        linkDestination: cleanHref
                    ))
                }
            }
        }

        // Extract form names
        let formPattern = #"<form([^>]+)>"#
        if let regex = try? NSRegularExpression(pattern: formPattern, options: [.caseInsensitive]) {
            let matches = regex.matches(in: rawHTML, options: [], range: NSRange(rawHTML.startIndex..<rawHTML.endIndex, in: rawHTML))
            for match in matches {
                if let range = Range(match.range(at: 1), in: rawHTML) {
                    let attrs = String(rawHTML[range])
                    if let formId = extractAttribute("id", from: attrs) ?? extractAttribute("name", from: attrs) {
                        forms.append(formId)
                    }
                }
            }
        }

        return SanitizedPortalSnapshot(
            url: url,
            pageTitle: pageTitle,
            classifiedType: classification.pageType,
            tableHeaders: headers,
            detectedForms: forms,
            structuralElements: elements
        )
    }

    /// Exports sanitized technical DOM structure as clean Markdown documentation.
    public func exportSanitizedPortalStructure(from snapshot: SanitizedPortalSnapshot) -> String {
        var output = """
        # Sanitized University Portal Structure
        **Captured URL:** `\(snapshot.url.scheme ?? "https")://\(snapshot.url.host ?? "portal")\(snapshot.url.path)`
        **Page Title:** \(snapshot.pageTitle)
        **Classified Page Type:** \(snapshot.classifiedType.rawValue)
        **Captured At:** \(snapshot.capturedAt)
        **Credentials/Cookies:** [STRICTLY REDACTED / NONE RECORDED]

        ## Table Headers Detected (\(snapshot.tableHeaders.count))
        """

        if snapshot.tableHeaders.isEmpty {
            output += "\n- None detected."
        } else {
            for th in snapshot.tableHeaders {
                output += "\n- `\(th)`"
            }
        }

        output += "\n\n## Form Fields Detected (\(snapshot.detectedForms.count) forms)\n"
        let inputs = snapshot.structuralElements.filter { $0.tagName == "input" }
        for input in inputs {
            output += "- `<input>` type=`\(input.inputType ?? "text")` name=`\(input.fieldName ?? "-")` id=`\(input.id ?? "-")` class=`\(input.cssClasses.joined(separator: " "))`\n"
        }

        output += "\n## Key Navigation Links\n"
        let links = snapshot.structuralElements.filter { $0.tagName == "a" }
        for link in links.prefix(15) {
            output += "- [\(link.sampleText ?? "Link")](\(link.linkDestination ?? "#"))\n"
        }

        return output
    }

    private func extractAttribute(_ attr: String, from text: String) -> String? {
        let pattern = "\(attr)=[\"']([^\"']+)[\"']"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let matchRange = Range(match.range(at: 1), in: text) {
            return String(text[matchRange])
        }
        return nil
    }
}
