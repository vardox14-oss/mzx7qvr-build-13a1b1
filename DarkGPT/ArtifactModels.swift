import Foundation

enum ArtifactType: Equatable, Codable {
    case html
    case svg
    case mermaid
    case markdown
    case code(String)

    var icon: String {
        switch self {
        case .html: return "globe"
        case .svg: return "sparkles"
        case .mermaid: return "point.3.connected.trianglepath.dotted"
        case .markdown: return "doc.richtext"
        case .code(let lang):
            let l = lang.lowercased()
            if l.contains("swift") { return "swift" }
            if l.contains("python") || l == "py" { return "curlybraces" }
            if l.contains("javascript") || l == "js" || l.contains("typescript") || l == "ts" { return "chevron.left.forwardslash.chevron.right" }
            return "chevron.left.forwardslash.chevron.right"
        }
    }

    var label: String {
        switch self {
        case .html: return "HTML / Web App"
        case .svg: return "Image Vectorielle SVG"
        case .mermaid: return "Diagramme Mermaid"
        case .markdown: return "Document Markdown"
        case .code(let lang): return lang.isEmpty ? "Code" : lang.uppercased()
        }
    }

    var isVisualPreviewable: Bool {
        switch self {
        case .html, .svg, .mermaid: return true
        default: return false
        }
    }

    var fileExtension: String {
        switch self {
        case .html: return "html"
        case .svg: return "svg"
        case .mermaid: return "mmd"
        case .markdown: return "md"
        case .code(let lang):
            switch lang.lowercased() {
            case "swift": return "swift"
            case "python", "py": return "py"
            case "javascript", "js": return "js"
            case "typescript", "ts": return "ts"
            case "json": return "json"
            case "css": return "css"
            case "c": return "c"
            case "cpp", "c++": return "cpp"
            case "rust", "rs": return "rs"
            case "go": return "go"
            case "sh", "bash": return "sh"
            case "sql": return "sql"
            default: return "txt"
            }
        }
    }
}

struct Artifact: Identifiable, Equatable, Codable {
    var id: String
    var title: String
    var type: ArtifactType
    var language: String
    var content: String
    var messageId: UUID
    var version: Int = 1
    var created: Date = Date()

    var isPreviewable: Bool { type.isVisualPreviewable }
}

enum ArtifactExtractor {
    /// Extrait les artefacts d'un texte (balises <antArtifact> de Claude ou blocs de code volumineux/web).
    static func extract(from text: String, messageId: UUID) -> [Artifact] {
        var results: [Artifact] = []

        // 1. Détection des balises Claude: <antArtifact identifier="..." type="..." title="...">...content...</antArtifact>
        if text.contains("<antArtifact") {
            let pattern = #"<antArtifact\s+([^>]*?)>([\s\S]*?)<\/antArtifact>"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let ns = text as NSString
                let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
                for match in matches {
                    guard match.numberOfRanges >= 3 else { continue }
                    let attrsString = ns.substring(with: match.range(at: 1))
                    let content = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)

                    let id = extractAttribute("identifier", from: attrsString) ?? UUID().uuidString
                    let title = extractAttribute("title", from: attrsString) ?? "Artefact"
                    let typeRaw = extractAttribute("type", from: attrsString) ?? ""
                    let lang = extractAttribute("language", from: attrsString) ?? ""

                    let artifactType: ArtifactType
                    if typeRaw.contains("html") || lang.lowercased() == "html" {
                        artifactType = .html
                    } else if typeRaw.contains("svg") || lang.lowercased() == "svg" {
                        artifactType = .svg
                    } else if typeRaw.contains("mermaid") || lang.lowercased() == "mermaid" {
                        artifactType = .mermaid
                    } else if typeRaw.contains("markdown") || lang.lowercased() == "markdown" || lang.lowercased() == "md" {
                        artifactType = .markdown
                    } else {
                        artifactType = .code(lang)
                    }

                    results.append(Artifact(id: id, title: title, type: artifactType, language: lang, content: content, messageId: messageId))
                }
            }
        }

        // 2. Détection des blocs de code Markdown (```lang ... ```)
        // Les blocs de code HTML, SVG, Mermaid ou de code substantiel (> 8 lignes) sont promus en Artefacts
        let codePattern = #"```([a-zA-Z0-9_\-+]*)\s*\n([\s\S]*?)```"#
        if let regex = try? NSRegularExpression(pattern: codePattern, options: []) {
            let ns = text as NSString
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: ns.length))
            var counter = 1

            for match in matches {
                guard match.numberOfRanges >= 3 else { continue }
                let lang = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let content = ns.substring(with: match.range(at: 2)).trimmingCharacters(in: .whitespacesAndNewlines)

                let lineCount = content.components(separatedBy: "\n").count
                let isVisual = (lang == "html" || lang == "svg" || lang == "mermaid" || content.contains("<!DOCTYPE html>") || content.contains("<svg"))

                // Ne promouvoir que les blocs visuels ou substantiels
                guard isVisual || lineCount >= 6 else { continue }

                let artifactType: ArtifactType
                let title: String
                if lang == "html" || content.contains("<!DOCTYPE html>") || content.contains("<html>") {
                    artifactType = .html
                    title = extractTitleFromContent(content) ?? "Application Web HTML"
                } else if lang == "svg" || content.hasPrefix("<svg") {
                    artifactType = .svg
                    title = "Illustration SVG"
                } else if lang == "mermaid" {
                    artifactType = .mermaid
                    title = "Diagramme Mermaid"
                } else {
                    artifactType = .code(lang)
                    title = extractFileName(from: content) ?? "\(lang.capitalized) Script #\(counter)"
                }

                let id = "art_\(messageId.uuidString.prefix(6))_\(counter)"
                // Éviter les doublons exacts
                if !results.contains(where: { $0.content == content }) {
                    results.append(Artifact(id: id, title: title, type: artifactType, language: lang, content: content, messageId: messageId, version: counter))
                    counter += 1
                }
            }
        }

        return results
    }

    private static func extractAttribute(_ name: String, from string: String) -> String? {
        let pattern = name + #"=["']([^"']*)["']"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: string, range: NSRange(location: 0, length: (string as NSString).length)),
              match.numberOfRanges >= 2 else { return nil }
        return (string as NSString).substring(with: match.range(at: 1))
    }

    private static func extractTitleFromContent(_ content: String) -> String? {
        let pattern = #"<title>(.*?)<\/title>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: content, range: NSRange(location: 0, length: (content as NSString).length)),
              match.numberOfRanges >= 2 else { return nil }
        let title = (content as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private static func extractFileName(from content: String) -> String? {
        let firstLine = content.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces) ?? ""
        if (firstLine.hasPrefix("//") || firstLine.hasPrefix("#") || firstLine.hasPrefix("/*")) &&
           (firstLine.contains(".") || firstLine.lowercased().contains("file")) {
            let cleaned = firstLine.replacingOccurrences(of: "//", with: "")
                .replacingOccurrences(of: "/*", with: "")
                .replacingOccurrences(of: "*/", with: "")
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: "filename:", with: "")
                .replacingOccurrences(of: "file:", with: "")
                .trimmingCharacters(in: .whitespaces)
            if !cleaned.isEmpty && cleaned.count < 40 { return cleaned }
        }
        return nil
    }
}
