import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming = false
    @State private var copied = false

    var body: some View {
        if message.role == .user { userRow } else { assistantRow }
    }

    // User: soft rounded bubble, right-aligned (ChatGPT/Claude style).
    private var userRow: some View {
        HStack(alignment: .top) {
            Spacer(minLength: 44)
            VStack(alignment: .trailing, spacing: 8) {
                if let data = message.image, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(maxWidth: 220, maxHeight: 220).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .padding(.horizontal, 15).padding(.vertical, 11)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
            }
        }
    }

    // Assistant: full-width, no bubble, logo + name header, copy button.
    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image("Logo").resizable().scaledToFit().frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("DarkGPT").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            }
            if message.isError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.accent2).font(.footnote)
                    Text(message.content).foregroundStyle(Theme.accent2)
                }
            } else {
                MarkdownText(message.content).textSelection(.enabled)
                    .foregroundStyle(.white)
            }
            if !isStreaming && !message.isError && !message.content.isEmpty {
                Button {
                    UIPasteboard.general.string = message.content
                    withAnimation { copied = true }
                    Haptics.tap()
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { copied = false } }
                } label: {
                    Label(copied ? "Copié" : "Copier", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption2).foregroundStyle(Theme.faint)
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Three bouncing dots while the assistant is thinking (ChatGPT style).
struct TypingDots: View {
    let label: String?
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            Image("Logo").resizable().scaledToFit().frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle().fill(Theme.muted)
                        .frame(width: 6, height: 6)
                        .opacity(phase == i ? 1 : 0.3)
                        .scaleEffect(phase == i ? 1.15 : 0.9)
                }
            }
            if let label { Text(label).font(.caption).foregroundStyle(Theme.faint) }
            Spacer()
        }
        .onReceive(timer) { _ in phase = (phase + 1) % 3 }
    }
}

/// Lightweight Markdown: paragraphs via AttributedString, fenced code blocks as mono cards with a copy button.
struct MarkdownText: View {
    let raw: String
    init(_ raw: String) { self.raw = raw }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(Self.split(raw).enumerated()), id: \.offset) { _, block in
                switch block {
                case .code(let code):
                    CodeBlock(code: code)
                case .text(let text):
                    Text(Self.inline(text))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    enum Block { case text(String), code(String) }

    static func split(_ s: String) -> [Block] {
        var blocks: [Block] = []
        let parts = s.components(separatedBy: "```")
        for (i, part) in parts.enumerated() {
            if i % 2 == 1 {
                var code = part
                if let nl = code.firstIndex(of: "\n") { code = String(code[code.index(after: nl)...]) }
                blocks.append(.code(code.trimmingCharacters(in: .newlines)))
            } else {
                let t = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { blocks.append(.text(t)) }
            }
        }
        return blocks.isEmpty ? [.text(s)] : blocks
    }

    static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}

struct CodeBlock: View {
    let code: String
    @State private var copied = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("code").font(.caption2.weight(.medium)).foregroundStyle(Theme.faint)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    withAnimation { copied = true }; Haptics.tap()
                    Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { copied = false } }
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc").font(.caption2).foregroundStyle(Theme.faint)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(Color.white.opacity(0.03))
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code).font(.system(.footnote, design: .monospaced)).foregroundStyle(.white.opacity(0.92))
                    .padding(12)
            }
        }
        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.stroke, lineWidth: 1))
    }
}
