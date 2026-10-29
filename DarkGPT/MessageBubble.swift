import SwiftUI
import UIKit

/// Refined chat bubble layout matching ChatGPT and Claude iOS standards.
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

    // MARK: - User Row (ChatGPT / iMessage luxury pill style)
    private var userRow: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Spacer(minLength: 48)

            VStack(alignment: .trailing, spacing: 6) {
                if let data = message.image, let ui = UIImage(data: data) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(maxWidth: 240, maxHeight: 240).clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                }

                if !message.content.isEmpty {
                    Text(message.content)
                        .font(.system(size: 16, weight: .regular))
                        .lineSpacing(4)
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.18), radius: 6, y: 3)
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
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.faint)
                        .padding(.trailing, 4)
                    }
                }
            }
        }
    }

    // MARK: - Assistant Row (Clean editorial layout, no repeated header)
    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Error State
            if message.isError {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.accent2)
                        .font(.system(size: 15))
                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent2)
                }
                .padding(12)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.accent.opacity(0.3), lineWidth: 1))
            } else {
                // Thinking disclosure
                if let think = parsedContent.thinking, !think.isEmpty {
                    thinkingBox(think)
                }

                // Artifacts cards (if any generated)
                if !artifacts.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(artifacts) { art in
                            ArtifactCardView(artifact: art) { a in
                                onOpenArtifact?(a)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                // Main Markdown response
                if !parsedContent.main.isEmpty {
                    MarkdownText(parsedContent.main)
                        .textSelection(.enabled)
                } else if isStreaming && parsedContent.thinking != nil {
                    HStack(spacing: 8) {
                        ProgressView().tint(Theme.muted).scaleEffect(0.8)
                        Text("Raisonnement en cours…")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.top, 2)
                }
            }

            // Discreet Action Bar (Copy, TTS, Regenerate, Share)
            if !isStreaming && !message.isError && !message.content.isEmpty {
                actionRow
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [message.content])
        }
    }

    // MARK: - Thinking Box (DeepSeek R1 / Claude 3.7 style)
    private func thinkingBox(_ text: String) -> some View {
        let linesCount = text.components(separatedBy: "\n").count
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
                    isThinkingExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent2)

                    Text(isStreaming && parsedContent.main.isEmpty ? "Raisonnement en cours…" : "Raisonnement (\(linesCount) étapes)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)

                    Spacer()

                    Image(systemName: isThinkingExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.faint)
                }
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
            }

            if isThinkingExpanded {
                ScrollView {
                    Text(text)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.65))
                        .lineSpacing(3.5)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 180)
                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Action Row
    private var actionRow: some View {
        HStack(spacing: 8) {
            // Copy
            actionButton(icon: copied ? "checkmark" : "doc.on.doc", highlight: copied) {
                UIPasteboard.general.string = parsedContent.main.isEmpty ? message.content : parsedContent.main
                withAnimation { copied = true }
                Haptics.tap()
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    withAnimation { copied = false }
                }
            }

            // Speak / TTS
            let isCurrentSpeaking = speech.isSpeaking && speech.speakingMessageId == message.id
            actionButton(icon: isCurrentSpeaking ? "stop.fill" : "speaker.wave.2", highlight: isCurrentSpeaking) {
                Haptics.tap()
                speech.speak(text: parsedContent.main.isEmpty ? message.content : parsedContent.main, messageId: message.id)
            }

            // Regenerate
            if let onRegenerate {
                actionButton(icon: "arrow.clockwise") {
                    Haptics.tap()
                    onRegenerate()
                }
            }

            // Share
            actionButton(icon: "square.and.arrow.up") {
                Haptics.tap()
                showShareSheet = true
            }

            Spacer()
        }
        .padding(.top, 4)
    }

    private func actionButton(icon: String, highlight: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(highlight ? Theme.accent2 : Theme.muted)
                .frame(width: 30, height: 30)
                .background(highlight ? Theme.accent.opacity(0.15) : Color.white.opacity(0.03), in: Circle())
        }
    }
}

/// Minimalist elegant pulsing dots while generating (ChatGPT style).
struct TypingDots: View {
    let label: String?
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Theme.muted)
                        .frame(width: 6, height: 6)
                        .opacity(phase == i ? 1.0 : 0.3)
                        .scaleEffect(phase == i ? 1.2 : 0.85)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Color.white.opacity(0.04), in: Capsule())

            if let label {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
            }
            Spacer()
        }
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = (phase + 1) % 3
            }
        }
    }
}
