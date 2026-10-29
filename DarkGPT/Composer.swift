import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Ultra-refined, compact input capsule matching ChatGPT iOS standards.
struct Composer: View {
    @Binding var input: String
    @Binding var webSearch: Bool
    @Binding var thinking: Bool
    @Binding var attachedImage: Data?
    @Binding var pickerItem: PhotosPickerItem?
    @Binding var attachedDocument: (name: String, content: String)?
    var streaming: Bool
    var showThinking: Bool
    var focused: FocusState<Bool>.Binding
    var onSend: () -> Void
    var onStop: () -> Void

    @ObservedObject private var speech = SpeechService.shared
    @State private var showFilePicker = false
    @State private var showPhotosPicker = false

    private var hasContent: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil || attachedDocument != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            // Active tools / attachments row (only shows when something is attached or active)
            if attachedImage != nil || attachedDocument != nil || webSearch || thinking {
                activePillsRow
            }

            // Main input capsule
            HStack(alignment: .bottom, spacing: 8) {
                // Menu (+)
                plusMenu

                // Text input
                TextField("", text: $input, prompt: Text("Message…").foregroundColor(Theme.faint), axis: .vertical)
                    .focused(focused)
                    .lineLimit(1...6)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .padding(.vertical, 8)

                // Trailing actions: Dictation mic or Send button
                if hasContent || streaming {
                    sendButton
                        .transition(.scale.combined(with: .opacity))
                } else {
                    micButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Color(red: 0.12, green: 0.12, blue: 0.13), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: hasContent)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: streaming)
        }
        .photosPicker(isPresented: $showPhotosPicker, selection: $pickerItem, matching: .images)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.plainText, .sourceCode, .json, .pdf, .text]) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Active pills row (attachments & toggles)
    private var activePillsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let attachedImage, let ui = UIImage(data: attachedImage) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: ui).resizable().scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
                        Button {
                            self.attachedImage = nil
                            pickerItem = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 16, height: 16)
                                .background(Color.black.opacity(0.8), in: Circle())
                        }
                        .offset(x: 4, y: -4)
                    }
                }

                if let doc = attachedDocument {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill").font(.system(size: 11)).foregroundStyle(Theme.accent2)
                        Text(doc.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                        Button {
                            attachedDocument = nil
                        } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.faint)
                        }
                    }
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Theme.surface2, in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
                }

                if webSearch {
                    togglePill(icon: "globe", label: "Web actif", onToggle: { webSearch = false })
                }

                if thinking {
                    togglePill(icon: "sparkle", label: "Réflexion active", onToggle: { thinking = false })
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func togglePill(icon: String, label: String, onToggle: @escaping () -> Void) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold))
            Text(label).font(.system(size: 12, weight: .medium))
            Button(action: onToggle) {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold)).foregroundStyle(Theme.faint)
            }
        }
        .foregroundStyle(Theme.accent2)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Theme.accent.opacity(0.16), in: Capsule())
        .overlay(Capsule().stroke(Theme.accent.opacity(0.4), lineWidth: 1))
    }

    // MARK: - Plus Menu
    private var plusMenu: some View {
        Menu {
            Section("Pièces jointes") {
                Button {
                    showPhotosPicker = true
                } label: {
                    Label("Ajouter une image", systemImage: "photo")
                }

                Button {
                    showFilePicker = true
                } label: {
                    Label("Ajouter un document (Code, TXT)", systemImage: "doc.badge.plus")
                }
            }

            Section("Outils d'analyse") {
                Button {
                    Haptics.tap()
                    webSearch.toggle()
                } label: {
                    Label(webSearch ? "Désactiver le Web" : "Recherche Web en direct", systemImage: "globe")
                }

                if showThinking {
                    Button {
                        Haptics.tap()
                        thinking.toggle()
                    } label: {
                        Label(thinking ? "Désactiver la Réflexion" : "Réflexion approfondie (Reasoning)", systemImage: "sparkle")
                    }
                }
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .background(Color.white.opacity(0.08), in: Circle())
        }
    }

    // MARK: - Microphone Button
    private var micButton: some View {
        Button {
            Haptics.tap()
            speech.toggleDictation { text in
                if !text.isEmpty {
                    input = text
                }
            }
        } label: {
            Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(speech.isRecording ? .white : Color.white.opacity(0.75))
                .frame(width: 34, height: 34)
                .background(speech.isRecording ? Color.red : Color.white.opacity(0.06), in: Circle())
                .scaleEffect(speech.isRecording ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: speech.isRecording)
        }
    }

    // MARK: - Send / Stop Button
    private var sendButton: some View {
        Button {
            Haptics.tap()
            streaming ? onStop() : onSend()
        } label: {
            Image(systemName: streaming ? "stop.fill" : "arrow.up")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(streaming ? .white : .black)
                .frame(width: 34, height: 34)
                .background(streaming ? Color.white.opacity(0.2) : Color.white, in: Circle())
        }
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if let data = try? Data(contentsOf: url),
           let str = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
            let name = url.lastPathComponent
            attachedDocument = (name, String(str.prefix(15000)))
            Haptics.success()
        }
    }
}
