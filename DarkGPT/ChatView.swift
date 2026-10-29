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
    @State private var attachedDocument: (name: String, content: String)?
    @State private var streamTask: Task<Void, Never>?
    @State private var errorBanner: String?
    @State private var activeArtifact: Artifact?
    @State private var showArtifactsSheet = false
    @State private var showExportSheet = false
    @State private var exportText: String = ""
    @FocusState private var inputFocused: Bool

    private var model: AIModel? { app.selectedModel() }
    private var isEmpty: Bool { conversation.messages.isEmpty }
    private var project: Project? { app.project(for: conversation.projectId) }

    private var conversationArtifacts: [Artifact] {
        var list: [Artifact] = []
        for m in conversation.messages where m.role == .assistant {
            list.append(contentsOf: ArtifactExtractor.extract(from: m.content, messageId: m.id))
        }
        return list
    }

    var body: some View {
        VStack(spacing: 0) {
            if let project {
                projectHeaderPill(project)
            }

            if isEmpty { emptyState } else { messageList }

            if isEmpty { suggestions }

            Composer(input: $input, webSearch: $webSearch, thinking: $thinking,
                     attachedImage: $attachedImage, pickerItem: $pickerItem,
                     attachedDocument: $attachedDocument,
                     streaming: streaming, showThinking: model?.hasThinkingToggle == true,
                     focused: $inputFocused, onSend: send, onStop: stopStreaming)
                .padding(.horizontal, 12)

            bottomDisclaimer
        }
        .background(Theme.bg.ignoresSafeArea())
        .overlay(alignment: .top) { if let errorBanner { banner(errorBanner) } }
        .onChange(of: pickerItem) { item in loadImage(item) }
        .sheet(item: $activeArtifact) { art in
            ArtifactStudioView(artifact: art)
        }
        .sheet(isPresented: $showArtifactsSheet) {
            ConversationArtifactsSheet(artifacts: conversationArtifacts) { art in
                showArtifactsSheet = false
                activeArtifact = art
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ShareSheet(activityItems: [exportText])
        }
    }

    private var bottomDisclaimer: some View {
        HStack(spacing: 12) {
            Text("DarkGPT peut se tromper. Vérifie les informations importantes.")
                .font(.system(size: 10)).foregroundStyle(Theme.faint)

            if !conversationArtifacts.isEmpty {
                Button {
                    Haptics.tap()
                    showArtifactsSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("\(conversationArtifacts.count) artefact(s)")
                    }
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent2)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Theme.accent.opacity(0.15), in: Capsule())
                }
            }
        }
        .padding(.top, 6).padding(.bottom, 4)
    }

    private func projectHeaderPill(_ proj: Project) -> some View {
        HStack(spacing: 6) {
            Image(systemName: proj.icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(proj.color)
            Text("Projet : \(proj.name)")
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.85))
            Spacer()
            if !proj.files.isEmpty {
                Text("\(proj.files.count) ref(s)")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.faint)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 6)
        .background(proj.color.opacity(0.12))
        .overlay(Rectangle().fill(proj.color.opacity(0.3)).frame(height: 1), alignment: .bottom)
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        let hello = (h >= 18 || h < 5) ? "Bonsoir" : "Bonjour"
        let first = app.user?.name.split(separator: " ").first.map(String.init) ?? ""
        return first.isEmpty ? hello : "\(hello), \(first)"
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.12))
                    .frame(width: 80, height: 80)
                    .blur(radius: 20)
                Image("Logo").resizable().scaledToFit().frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.4), radius: 10)
            }
            VStack(spacing: 6) {
                Text(greeting)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                Text(project != nil ? "Projet « \(project!.name) » actif" : "Que souhaites-tu explorer ou créer aujourd'hui ?")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { inputFocused = false }
    }

    private var suggestions: some View {
        let items: [Suggestion] = [
            Suggestion(icon: "laptopcomputer", title: "App Web", sub: "Calculatrice HTML interactive"),
            Suggestion(icon: "sparkles", title: "Image SVG", sub: "Illustration vectorielle"),
            Suggestion(icon: "curlybraces", title: "Script Python", sub: "Automatisation ou algorithme"),
            Suggestion(icon: "lightbulb", title: "Analyse", sub: "Synthèse d'un sujet complexe")
        ]
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(items) { item in
                Button {
                    Haptics.tap()
                    input = item.title + " : " + item.sub
                    inputFocused = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.accent2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(item.sub)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.06), lineWidth: 1))
                }
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 8)
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
                            MessageBubble(
                                message: msg,
                                isStreaming: streaming && isLast,
                                onRegenerate: { regenerate() },
                                onEdit: { text in input = text; inputFocused = true },
                                onOpenArtifact: { art in activeArtifact = art }
                            )
                            .id(msg.id)
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

// MARK: - Send / stream / regenerate
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
        guard (!text.isEmpty || attachedImage != nil || attachedDocument != nil), let model, !streaming else { return }

        if !model.isUnlocked(for: app.plan) {
            showBanner("Ce modèle nécessite l'offre \(Plans.label(model.minPlan)).")
            return
        }

        var image: (base64: String, mediaType: String)?
        let imageData = attachedImage
        if let data = imageData { image = (data.base64EncodedString(), "image/jpeg") }

        var prompt = text.isEmpty ? "Analyse cette image." : text

        // Injection du document joint si présent
        if let doc = attachedDocument {
            prompt = "[Fichier attaché : \(doc.name)] :\n\(doc.content)\n\n\(prompt)"
        }

        // Injection du contexte du projet si présent
        if let proj = project {
            let context = proj.systemContextPrompt
            if !context.isEmpty {
                prompt = "\(context)\n\n\(prompt)"
            }
        }

        conversation.messages.append(ChatMessage(role: .user, content: text.isEmpty ? "Analyse le document/image joint" : text, image: imageData))
        if conversation.title == "Nouvelle conversation" {
            conversation.title = String((text.isEmpty ? "Document joint" : text).prefix(48))
        }
        conversation.model = model.slug
        conversation.updated = Date()

        let history = Array(conversation.messages.dropLast().suffix(30))
        input = ""; attachedImage = nil; pickerItem = nil; attachedDocument = nil
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

    private func regenerate() {
        guard !streaming else { return }
        // Supprimer la dernière réponse de l'assistant si présente
        if let last = conversation.messages.last, last.role == .assistant {
            conversation.messages.removeLast()
        }
        // Trouver le dernier message utilisateur
        guard let lastUser = conversation.messages.last(where: { $0.role == .user }) else { return }
        // Retirer le dernier message utilisateur pour le ré-envoyer proprement
        conversation.messages.removeAll { $0.id == lastUser.id }
        input = lastUser.content
        attachedImage = lastUser.image
        send()
    }

    func exportConversation() {
        var output = "# \(conversation.title)\nModèle: \(conversation.model)\nDate: \(conversation.updated)\n\n"
        for m in conversation.messages {
            output += "### \(m.role == .user ? "Utilisateur" : "DarkGPT")\n"
            output += m.content + "\n\n"
        }
        exportText = output
        showExportSheet = true
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

// MARK: - Conversation Artifacts Sheet
struct ConversationArtifactsSheet: View {
    let artifacts: [Artifact]
    var onSelect: (Artifact) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(artifacts) { art in
                        ArtifactCardView(artifact: art) { a in
                            onSelect(a)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.bg.ignoresSafeArea())
            .navigationTitle("Artefacts générés (\(artifacts.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }
}

struct Suggestion: Identifiable {
    let icon: String
    let title: String
    let sub: String
    var id: String { title }
}
