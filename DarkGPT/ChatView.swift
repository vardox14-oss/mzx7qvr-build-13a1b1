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

    var body: some View {
        VStack(spacing: 0) {
            if conversation.messages.isEmpty { emptyState } else { messageList }
            composer
        }
        .background(Theme.bg)
        .overlay(alignment: .top) { if let errorBanner { banner(errorBanner) } }
        .onChange(of: pickerItem) { item in loadImage(item) }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image("Logo").resizable().scaledToFit().frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).opacity(0.9)
            Text("Pose ta question").font(.title3.weight(.semibold))
            Text("Réponses directes, sans filtre inutile.").font(.subheadline).foregroundStyle(Theme.muted)
            suggestionChips
            Spacer(); Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    private var suggestionChips: some View {
        VStack(spacing: 10) {
            ForEach(["Explique-moi un concept simplement", "Aide-moi à coder une fonction", "Donne-moi un avis cash"], id: \.self) { s in
                Button { input = s; inputFocused = true } label: {
                    Text(s).font(.footnote).foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14).padding(.vertical, 11)
                        .cardStyle(radius: 12)
                }
            }
        }
        .padding(.top, 8).padding(.horizontal, 24)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
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
                .padding(.horizontal, 16).padding(.vertical, 18)
            }
            .onChange(of: conversation.messages.last?.content) { _ in
                withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo("bottom", anchor: .bottom) }
            }
            .onChange(of: statusText) { _ in
                withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
            }
        }
    }

    private func banner(_ text: String) -> some View {
        Text(text).font(.footnote.weight(.medium)).foregroundStyle(.white)
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Theme.accent.opacity(0.92), in: Capsule())
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { errorBanner = nil }
    }
}

// MARK: - Composer
extension ChatView {
    private var composer: some View {
        VStack(spacing: 8) {
            if let attachedImage, let ui = UIImage(data: attachedImage) {
                HStack {
                    Image(uiImage: ui).resizable().scaledToFill().frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Image jointe").font(.footnote).foregroundStyle(Theme.muted)
                    Spacer()
                    Button { self.attachedImage = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.faint) }
                }
                .padding(.horizontal, 14)
            }

            HStack(spacing: 8) {
                toggleChip(icon: "globe", label: "Web", on: $webSearch)
                if model?.hasThinkingToggle == true {
                    toggleChip(icon: "brain", label: "Réflexion", on: $thinking)
                }
                Spacer()
            }
            .padding(.horizontal, 14)

            HStack(alignment: .bottom, spacing: 10) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "photo.on.rectangle").font(.title3).foregroundStyle(Theme.muted)
                        .frame(width: 38, height: 38)
                }

                TextField("", text: $input, prompt: Text("Écris à DarkGPT…").foregroundColor(Theme.faint), axis: .vertical)
                    .focused($inputFocused)
                    .lineLimit(1...6)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.stroke, lineWidth: 1))

                sendButton
            }
            .padding(.horizontal, 12).padding(.bottom, 8).padding(.top, 2)
        }
        .background(Theme.bg)
        .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .top)
    }

    private var sendButton: some View {
        Button {
            Haptics.tap()
            if streaming { stopStreaming() } else { send() }
        } label: {
            Image(systemName: streaming ? "stop.fill" : "arrow.up")
                .font(.headline.weight(.bold)).foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(canSend || streaming ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Theme.surface2), in: Circle())
        }
        .disabled(!canSend && !streaming)
    }

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil
    }

    private func toggleChip(icon: String, label: String, on: Binding<Bool>) -> some View {
        Button { Haptics.tap(); on.wrappedValue.toggle() } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.caption2)
                Text(label).font(.caption.weight(.medium))
            }
            .foregroundStyle(on.wrappedValue ? .white : Theme.muted)
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(on.wrappedValue ? AnyShapeStyle(Theme.accent.opacity(0.9)) : AnyShapeStyle(Theme.surface), in: Capsule())
            .overlay(Capsule().stroke(Theme.stroke, lineWidth: on.wrappedValue ? 0 : 1))
        }
    }

    private func loadImage(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                attachedImage = downscale(data)
            }
        }
    }
}

// MARK: - Send / stream
extension ChatView {
    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend, let model, !streaming else { return }

        if !model.isUnlocked(for: app.plan) {
            showBanner("Ce modèle nécessite l'offre \(Plans.label(model.minPlan)).")
            return
        }

        var image: (base64: String, mediaType: String)?
        var imageData: Data?
        if let data = attachedImage {
            image = (data.base64EncodedString(), "image/jpeg")
            imageData = data
        }

        let userMessage = ChatMessage(role: .user, content: text, image: imageData)
        conversation.messages.append(userMessage)
        if conversation.title == "Nouvelle conversation" && !text.isEmpty {
            conversation.title = String(text.prefix(48))
        }
        conversation.model = model.slug
        conversation.updated = Date()

        let history = Array(conversation.messages.dropLast())
        input = ""; attachedImage = nil; pickerItem = nil
        inputFocused = false

        var assistant = ChatMessage(role: .assistant, content: "", model: model.slug)
        conversation.messages.append(assistant)
        streaming = true
        statusText = "Connexion…"

        streamTask = Task {
            let stream = APIClient.shared.streamChat(
                message: text, history: history, modelSlug: model.slug,
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
                        finishStreaming()
                        return
                    case .failed(let message, let gems):
                        app.setGems(gems)
                        failAssistant(message, &assistant)
                        return
                    }
                }
                // stream ended without explicit done
                if assistant.content.isEmpty { failAssistant("Réponse vide. Réessaie.", &assistant) }
                else { updateAssistant(assistant); finishStreaming() }
            } catch let error as APIError {
                if case .unauthorized = error { await app.logout() }
                else { failAssistant(error.localizedDescription, &assistant) }
            } catch {
                if !Task.isCancelled { failAssistant("Connexion interrompue.", &assistant) }
                else { finishStreaming() }
            }
        }
    }

    private func stopStreaming() {
        streamTask?.cancel()
        finishStreaming()
    }

    private func updateAssistant(_ message: ChatMessage) {
        if let idx = conversation.messages.lastIndex(where: { $0.id == message.id }) {
            conversation.messages[idx] = message
        }
    }

    private func failAssistant(_ text: String, _ assistant: inout ChatMessage) {
        assistant.isError = true
        assistant.content = assistant.content.isEmpty ? text : assistant.content
        updateAssistant(assistant)
        showBanner(text)
        Haptics.error()
        finishStreaming()
    }

    private func finishStreaming() {
        streaming = false
        statusText = nil
        conversation.updated = Date()
        app.upsert(conversation)
    }

    private func showBanner(_ text: String) {
        withAnimation { errorBanner = text }
        Task { try? await Task.sleep(nanoseconds: 3_500_000_000); withAnimation { errorBanner = nil } }
    }
}
