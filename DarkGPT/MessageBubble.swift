import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if message.role == .assistant {
                avatar
                content.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 40)
                content
            }
        }
    }

    private var avatar: some View {
        Image("Logo").resizable().scaledToFit().frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .padding(.top, 2)
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            if let data = message.image, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
                    .frame(maxWidth: 220, maxHeight: 220).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if !message.content.isEmpty || message.role == .assistant {
                MarkdownText(message.content.isEmpty ? "…" : message.content)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(bubbleBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(message.role == .user ? .clear : Theme.stroke, lineWidth: 1))
                    .foregroundStyle(message.isError ? Theme.accent2 : .white)
            }
        }
    }

    private var bubbleBackground: AnyShapeStyle {
        message.role == .user ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.surface)
    }
}

struct StatusRow: View {
    let text: String
    @State private var pulse = false
    var body: some View {
        HStack(spacing: 8) {
            Image("Logo").resizable().scaledToFit().frame(width: 24, height: 24)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7).tint(Theme.muted)
                Text(text).font(.footnote).foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .opacity(pulse ? 1 : 0.6)
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { pulse = true } }
    }
}

/// Lightweight Markdown: bold/italic/inline-code via AttributedString, with fenced code blocks shown as mono cards.
struct MarkdownText: View {
    let raw: String
    init(_ raw: String) { self.raw = raw }

    var body: some View {
        let blocks = Self.split(raw)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .code(let code):
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(code).font(.system(.footnote, design: .monospaced)).foregroundStyle(.white.opacity(0.92))
                            .padding(10)
                    }
                    .background(Theme.bg, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.stroke, lineWidth: 1))
                case .text(let text):
                    Text(Self.inline(text))
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
            } else if !part.isEmpty {
                blocks.append(.text(part))
            }
        }
        return blocks.isEmpty ? [.text(s)] : blocks
    }

    static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(text)
    }
}
