import SwiftUI
import PhotosUI

struct ChatView: View {
    @EnvironmentObject var app: AppState
    @Binding var conversation: Conversation

    @State private var input = ""
    @State private var streaming = false
    @State private var statusText: String?
    @State private var webSearch = false
    @State private var thinking = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var attachedImage: Data?
    @State private var streamTask: Task<Void, Never>?
    @State private var errorBanner: String?
    @FocusState private var inputFocused: Bool

    private var model: AIModel? { app.selectedModel() }
    private var isEmpty: Bool { conversation.messages.isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            if isEmpty { emptyState } else { messageList }
            if isEmpty { suggestions }
            Composer(input: $input, webSearch: $webSearch, thinking: $thinking,
                     attachedImage: $attachedImage, pickerItem: $pickerItem,
                     streaming: streaming, showThinking: model?.hasThinkingToggle == true,
                     focused: $inputFocused, onSend: send, onStop: stopStreaming)
                .padding(.horizontal, 12)
            Text("DarkGPT peut se tromper. Vérifie les informations importantes.")
                .font(.system(size: 10)).foregroundStyle(Theme.faint)
                .padding(.top, 6).padding(.bottom, 4)
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .top) { if let errorBanner { banner(errorBanner) } }
        .onChange(of: pickerItem) { item in loadImage(item) }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let hello = (h >= 18 || h < 5) ? "Bonsoir" : "Bonjour"
        let first = app.user?.name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? hello : "\(hello), \(first)"
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Spacer()
            Image("Logo").resizable().scaledToFit().frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Theme.accent.opacity(0.35), radius: 16)
            Text(greeting)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Text("Comment je peux t'aider ?")
                .font(.system(size: 17)).foregroundStyle(Theme.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = false }
    }

    private var suggestions: some View {
        let items: [Suggestion] = [
            Suggestion(icon: "lightbulb", title: "Explique-moi", sub: "un concept simplement"),
            Suggestion(icon: "chevron.left.forwardslash.chevron.right", title: "Aide-moi à coder", sub: "une fonction en Python"),
            Suggestion(icon: "pencil.line", title: "Rédige", sub: "un message pro"),
            Suggestion(icon: "chart.line.uptrend.xyaxis", title: "Analyse", sub: "une idée de business")
        ]
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(items) { item in
                    Button { input = item.title + " " + item.sub; inputFocused = true } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: item.icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(Theme.accent2)
                            Text(item.title).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                            Text(item.sub).font(.caption).foregroundStyle(Theme.muted)
                        }
                        .frame(width: 150, alignment: .leading)
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(.bottom, 10)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(conversation.messages) { msg in
                        let isLast = msg.id == conversation.messages.last?.id
                        if streaming && isLast && msg.role == .assistant && msg.content.isEmpty {
                            TypingDots(label: statusText).id(msg.id)
                        } else {
                            MessageBubble(message: msg, isStreaming: streaming && isLast).id(msg.id)
                        }
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, 18).padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: conversation.messages.last?.content) { _ in
                proxy.scrollTo("bottom", anchor: .bottom)
            }
            .onChange(of: conversation.messages.count) { _ in
                withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
        }
    }

    private func banner(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
            Text(text).font(.footnote.weight(.medium)).lineLimit(3)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.accent.opacity(0.95), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16).padding(.top, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onTapGesture { withAnimation { errorBanner = nil } }
    }
}

// MARK: - Send / stream
extension ChatView {
    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                attachedImage = downscale(data)
            }
        }
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (!text.isEmpty || attachedImage != nil), let model, !streaming else { return }

        if !model.isUnlocked(for: app.plan) {
            showBanner("Ce modèle nécessite l'offre \(Plans.label(model.minPlan)).")
            return
        }

        var image: (base64: String, mediaType: String)?
        let imageData = attachedImage
        if let data = imageData { image = (data.base64EncodedString(), "image/jpeg") }

        let prompt = text.isEmpty ? "Analyse cette image." : text
        conversation.messages.append(ChatMessage(role: .user, content: text, image: imageData))
        if conversation.title == "Nouvelle conversation" {
            conversation.title = String((text.isEmpty ? "Image" : text).prefix(48))
        }
        conversation.model = model.slug
        conversation.updated = Date()

        let history = Array(conversation.messages.dropLast().suffix(30))
        input = ""; attachedImage = nil; pickerItem = nil
        inputFocused = false

        var assistant = ChatMessage(role: .assistant, content: "", model: model.slug)
        conversation.messages.append(assistant)
        streaming = true
        statusText = nil

        streamTask = Task {
            let stream = APIClient.shared.streamChat(
                message: prompt, history: history, modelSlug: model.slug,
                conversationId: conversation.id, webSearch: webSearch, thinking: thinking, image: image)
            do {
                for try await event in stream {
                    switch event {
                    case .text(let delta):
                        statusText = nil
                        assistant.content += delta
                        updateAssistant(assistant)
                    case .status(let s):
                        statusText = s
                    case .finished(let content, let gems):
                        if let content, !content.isEmpty { assistant.content = content }
                        updateAssistant(assistant)
                        app.setGems(gems)
                        Haptics.success()
                        finishStreaming()
                        return
                    case .failed(let message, let gems):
                        app.setGems(gems)
                        fail(message, &assistant)
                        return
                    }
                }
                if assistant.content.isEmpty {
                    if Task.isCancelled { removeEmptyAssistant(assistant); finishStreaming() }
                    else { fail("Réponse vide. Réessaie.", &assistant) }
                } else { updateAssistant(assistant); finishStreaming() }
            } catch let error as APIError {
                if case .unauthorized = error { await app.logout() }
                else { fail(error.localizedDescription, &assistant) }
            } catch {
                if Task.isCancelled {
                    if assistant.content.isEmpty { removeEmptyAssistant(assistant) }
                    finishStreaming()
                } else { fail("Connexion interrompue.", &assistant) }
            }
        }
    }

    private func stopStreaming() {
        streamTask?.cancel()
        if let last = conversation.messages.last, last.role == .assistant, last.content.isEmpty {
            removeEmptyAssistant(last)
        }
        finishStreaming()
    }

    private func updateAssistant(_ message: ChatMessage) {
        if let idx = conversation.messages.lastIndex(where: { $0.id == message.id }) {
            conversation.messages[idx] = message
        }
    }

    private func removeEmptyAssistant(_ message: ChatMessage) {
        conversation.messages.removeAll { $0.id == message.id && $0.content.isEmpty }
    }

    private func fail(_ text: String, _ assistant: inout ChatMessage) {
        assistant.isError = true
        if assistant.content.isEmpty { assistant.content = text }
        updateAssistant(assistant)
        showBanner(text)
        Haptics.error()
        finishStreaming()
    }

    private func finishStreaming() {
        streaming = false
        statusText = nil
        conversation.updated = Date()
        if !conversation.messages.isEmpty { app.upsert(conversation) }
    }

    private func showBanner(_ text: String) {
        withAnimation { errorBanner = text }
        Task { try? await Task.sleep(nanoseconds: 4_000_000_000); withAnimation { errorBanner = nil } }
    }
}

struct Suggestion: Identifiable {
    let icon: String
    let title: String
    let sub: String
    var id: String { title }
}
