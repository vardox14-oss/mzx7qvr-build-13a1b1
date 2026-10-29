import SwiftUI
import UIKit

struct MessageBubble: View {
    let message: ChatMessage
    var isStreaming = false
    var onRegenerate: (() -> Void)?
    var onEdit: ((String) -> Void)?
    var onOpenArtifact: ((Artifact) -> Void)?

    @ObservedObject private var speech = SpeechService.shared
    @State private var copied = false
    @State private var showShareSheet = false
    @State private var isThinkingExpanded = false

    private var parsedContent: (thinking: String?, main: String) {
        let text = message.content
        if text.contains("<think>") {
            if let closeRange = text.range(of: "</think>") {
                let startRange = text.range(of: "<think>")!
                let thinkText = String(text[startRange.upperBound..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let mainText = String(text[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (thinkText, mainText)
            } else {
                // En cours de streaming dans le bloc <think>
                let startRange = text.range(of: "<think>")!
                let thinkText = String(text[startRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                return (thinkText, "")
            }
        }
        return (nil, text)
    }

    private var artifacts: [Artifact] {
        guard message.role == .assistant else { return [] }
        return ArtifactExtractor.extract(from: parsedContent.main, messageId: message.id)
    }

    var body: some View {
        if message.role == .user {
            userRow
        } else {
            assistantRow
        }
    }

    // MARK: - User Row
    private var userRow: some View {
        HStack(alignment: .top) {
            Spacer(minLength: 44)
            VStack(alignment: .trailing, spacing: 6) {
                if let data = message.image, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(maxWidth: 240, maxHeight: 240).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if !message.content.isEmpty {
                    Text(message.content)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                if let onEdit {
                    Button {
                        Haptics.tap()
                        onEdit(message.content)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                            Text("Modifier")
                        }
                        .font(.caption2)
                        .foregroundStyle(Theme.faint)
                        .padding(.trailing, 4)
                    }
                }
            }
        }
    }

    // MARK: - Assistant Row
    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 8) {
                Image("Logo").resizable().scaledToFit().frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(message.model ?? "DarkGPT")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.muted)
                Spacer()
            }

            // Error state
            if message.isError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.accent2).font(.footnote)
                    Text(message.content).foregroundStyle(Theme.accent2)
                }
            } else {
                // Thinking Process (Raisonnement R1 / o1 / Claude)
                if let think = parsedContent.thinking, !think.isEmpty {
                    thinkingDisclosure(think)
                }

                // Interactive Artifacts Cards
                if !artifacts.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(artifacts) { art in
                            ArtifactCardView(artifact: art) { a in
                                onOpenArtifact?(a)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Main Markdown content
                if !parsedContent.main.isEmpty {
                    MarkdownText(parsedContent.main)
                        .textSelection(.enabled)
                        .foregroundStyle(.white)
                } else if isStreaming && parsedContent.thinking != nil {
                    HStack(spacing: 6) {
                        ProgressView().tint(Theme.muted).scaleEffect(0.8)
                        Text("Raisonnement en cours…")
                            .font(.subheadline)
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 4)
                }
            }

            // Bottom Action Bar (Copy, TTS Speak, Regenerate, Share)
            if !isStreaming && !message.isError && !message.content.isEmpty {
                actionBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [message.content])
        }
    }

    private func thinkingDisclosure(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isThinkingExpanded.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent2)
                    Text(isStreaming && parsedContent.main.isEmpty ? "Raisonnement en cours…" : "Processus de réflexion")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                    Image(systemName: isThinkingExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Theme.surface2.opacity(0.8), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            if isThinkingExpanded {
                ScrollView {
                    Text(text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(3)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                .background(Color.black.opacity(0.3), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 16) {
            // Copy
            Button {
                UIPasteboard.general.string = parsedContent.main.isEmpty ? message.content : parsedContent.main
                withAnimation { copied = true }
                Haptics.tap()
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation { copied = false }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copié" : "Copier")
                }
                .font(.caption2)
                .foregroundStyle(copied ? .green : Theme.faint)
            }

            // Speak / TTS
            let isCurrentSpeaking = speech.isSpeaking && speech.speakingMessageId == message.id
            Button {
                Haptics.tap()
                speech.speak(text: parsedContent.main.isEmpty ? message.content : parsedContent.main, messageId: message.id)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isCurrentSpeaking ? "stop.fill" : "speaker.wave.2")
                    Text(isCurrentSpeaking ? "Arrêter" : "Écouter")
                }
                .font(.caption2)
                .foregroundStyle(isCurrentSpeaking ? Theme.accent2 : Theme.faint)
            }

            // Regenerate
            if let onRegenerate {
                Button {
                    Haptics.tap()
                    onRegenerate()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Régénérer")
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.faint)
                }
            }

            // Share
            Button {
                Haptics.tap()
                showShareSheet = true
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption2)
                    .foregroundStyle(Theme.faint)
            }

            Spacer()
        }
        .padding(.top, 4)
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
