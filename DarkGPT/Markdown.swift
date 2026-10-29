import SwiftUI
import UIKit

/// High-end typography Markdown renderer (style ChatGPT & Claude iOS).
struct MarkdownText: View {
    let raw: String
    init(_ raw: String) { self.raw = raw }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                .font(level == 1 ? .system(size: 21, weight: .bold) : (level == 2 ? .system(size: 18, weight: .semibold) : .system(size: 16.5, weight: .semibold)))
                .foregroundStyle(.white)
                .padding(.top, level == 1 ? 8 : 4)

        case .paragraph(let text):
            Text(MarkdownParser.inline(text))
                .font(.system(size: 16, weight: .regular))
                .lineSpacing(4.5)
                .foregroundStyle(Color.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("•")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Theme.accent2.opacity(0.85))
                        Text(MarkdownParser.inline(item))
                            .font(.system(size: 16))
                            .lineSpacing(4)
                            .foregroundStyle(Color.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 2)

        case .numbered(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { pair in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text("\(pair.offset + 1).")
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Theme.muted)
                        Text(MarkdownParser.inline(pair.element))
                            .font(.system(size: 16))
                            .lineSpacing(4)
                            .foregroundStyle(Color.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 2)

        case .quote(let text):
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Theme.accent2.opacity(0.7))
                    .frame(width: 3)
                Text(MarkdownParser.inline(text))
                    .font(.system(size: 15.5))
                    .italic()
                    .lineSpacing(4)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)

        case .rule:
            Rectangle()
                .fill(Theme.stroke)
                .frame(height: 1)
                .padding(.vertical, 8)

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

// MARK: - Premium Console-Style Code Block
struct CodeBlock: View {
    let language: String
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // macOS style console header
            HStack(spacing: 8) {
                HStack(spacing: 5) {
                    Circle().fill(Color.red.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(Color.yellow.opacity(0.8)).frame(width: 8, height: 8)
                    Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8)
                }
                .padding(.leading, 2)

                Text((language.isEmpty ? "code" : language).uppercased())
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.muted)
                    .padding(.leading, 6)

                Spacer()

                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }
                    Haptics.tap()
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { copied = false } }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11, weight: .semibold))
                        Text(copied ? "Copié !" : "Copier")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(copied ? .green : Theme.muted)
                    .padding(.horizontal, 9).padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(red: 0.11, green: 0.11, blue: 0.12))

            // Code lines
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
                    .lineSpacing(4)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .padding(14)
            }
        }
        .background(Color(red: 0.08, green: 0.08, blue: 0.09), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .padding(.vertical, 2)
    }
}
