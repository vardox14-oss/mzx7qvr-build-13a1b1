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
