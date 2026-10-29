import SwiftUI
import UIKit

/// Block-level Markdown renderer: headings, bullet / numbered lists, quotes, rules, fenced code.
struct MarkdownText: View {
    let raw: String
    init(_ raw: String) { self.raw = raw }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(MarkdownParser.parse(raw).enumerated()), id: \.offset) { _, block in
                MDBlockView(block: block)
            }
        }
    }
}

struct MDBlockView: View {
    let block: MDBlock

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(MarkdownParser.inline(text))
                .font(level == 1 ? .title2.weight(.bold) : (level == 2 ? .title3.weight(.bold) : .headline))
                .padding(.top, 4)
        case .paragraph(let text):
            Text(MarkdownParser.inline(text))
                .font(.body).lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•").font(.body.weight(.bold)).foregroundStyle(Theme.accent2)
                        Text(MarkdownParser.inline(item)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .numbered(let items):
            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(items.enumerated()), id: \.offset) { pair in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(pair.offset + 1).").font(.body.weight(.semibold)).foregroundStyle(Theme.muted).monospacedDigit()
                        Text(MarkdownParser.inline(pair.element)).lineSpacing(3).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(Theme.accent.opacity(0.7)).frame(width: 3)
                Text(MarkdownParser.inline(text)).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
        case .rule:
            Rectangle().fill(Theme.stroke).frame(height: 1).padding(.vertical, 4)
        case .code(let lang, let code):
            CodeBlock(language: lang, code: code)
        }
    }
}

enum MDBlock {
    case heading(Int, String)
    case paragraph(String)
    case bullets([String])
    case numbered([String])
    case quote(String)
    case rule
    case code(String, String)
}

enum MarkdownParser {
    static func parse(_ text: String) -> [MDBlock] {
        var blocks: [MDBlock] = []
        var paragraph: [String] = []
        var bullets: [String] = []
        var numbered: [String] = []
        var inCode = false
        var codeLang = ""
        var codeLines: [String] = []

        func flushText() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
            if !bullets.isEmpty { blocks.append(.bullets(bullets)); bullets = [] }
            if !numbered.isEmpty { blocks.append(.numbered(numbered)); numbered = [] }
        }

        for rawLine in text.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if inCode {
                    blocks.append(.code(codeLang, codeLines.joined(separator: "\n")))
                    codeLines = []
                    inCode = false
                } else {
                    flushText()
                    inCode = true
                    codeLang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                }
                continue
            }
            if inCode { codeLines.append(rawLine); continue }
            if line.isEmpty { flushText(); continue }
            if line == "---" || line == "***" || line == "___" { flushText(); blocks.append(.rule); continue }

            if line.hasPrefix("#") {
                let level = line.prefix(while: { $0 == "#" }).count
                if level <= 6 {
                    flushText()
                    let title = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                    blocks.append(.heading(min(level, 3), title))
                    continue
                }
            }
            if line.hasPrefix("> ") { flushText(); blocks.append(.quote(String(line.dropFirst(2)))); continue }

            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                if !paragraph.isEmpty || !numbered.isEmpty {
                    let keep = bullets; flushText(); bullets = keep
                }
                bullets.append(String(line.dropFirst(2)))
                continue
            }
            if let item = numberedItem(line) {
                if !paragraph.isEmpty || !bullets.isEmpty {
                    let keep = numbered; flushText(); numbered = keep
                }
                numbered.append(item)
                continue
            }
            if !bullets.isEmpty || !numbered.isEmpty { flushText() }
            paragraph.append(line)
        }
        if inCode { blocks.append(.code(codeLang, codeLines.joined(separator: "\n"))) }
        flushText()
        return blocks
    }

    /// "12. texte" -> "texte"
    private static func numberedItem(_ line: String) -> String? {
        let digits = line.prefix(while: { $0.isNumber })
        guard !digits.isEmpty, digits.count <= 3 else { return nil }
        let rest = line.dropFirst(digits.count)
        guard rest.hasPrefix(". ") || rest.hasPrefix(") ") else { return nil }
        return String(rest.dropFirst(2))
    }

    static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

struct CodeBlock: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(language.isEmpty ? "code" : language).font(.caption.weight(.medium)).foregroundStyle(Theme.muted)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                    Haptics.tap()
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { copied = false } }
                } label: {
                    Label(copied ? "Copié" : "Copier", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Color.white.opacity(0.04))
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code).font(.system(size: 13, design: .monospaced)).foregroundStyle(.white.opacity(0.92))
                    .padding(14)
            }
        }
        .background(Color(red: 0.07, green: 0.07, blue: 0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
    }
}
