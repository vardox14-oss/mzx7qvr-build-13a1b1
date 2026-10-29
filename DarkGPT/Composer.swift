import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Large rounded input card with media attachments, file attachments, speech dictation, and tools.
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

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil || attachedDocument != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Attachments Preview row
            if attachedImage != nil || attachedDocument != nil {
                attachmentsBar
            }

            // Text input
            TextField("", text: $input, prompt: Text("Écris à DarkGPT…").foregroundColor(Theme.faint), axis: .vertical)
                .focused(focused)
                .lineLimit(1...8)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            // Tools bottom bar
            HStack(spacing: 8) {
                actionMenu

                toolChip("globe", "Web", $webSearch)

                if showThinking {
                    toolChip("sparkle", "Réflexion", $thinking)
                }

                Spacer()

                dictationButton

                sendButton
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
        .photosPicker(isPresented: $showPhotosPicker, selection: $pickerItem, matching: .images)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.plainText, .sourceCode, .json, .pdf, .text]) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Attachments preview
    private var attachmentsBar: some View {
        HStack(spacing: 10) {
            if let attachedImage, let ui = UIImage(data: attachedImage) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button {
                        self.attachedImage = nil
                        pickerItem = nil
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 18, height: 18).background(.black.opacity(0.75), in: Circle())
                    }
                    .offset(x: 5, y: -5)
                }
            }

            if let doc = attachedDocument {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(Theme.accent2)
                    Text(doc.name)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Button {
                        attachedDocument = nil
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Theme.faint)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(Theme.surface2, in: Capsule())
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Action Menu (+)
    private var actionMenu: some View {
        Menu {
            Button {
                showPhotosPicker = true
            } label: {
                Label("Photo / Image", systemImage: "photo")
            }

            Button {
                showFilePicker = true
            } label: {
                Label("Document ou Code (TXT, PY, Swift, JSON)", systemImage: "doc.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 34, height: 34)
                .background(Theme.surface2, in: Circle())
        }
    }

    // MARK: - Dictation Button
    private var dictationButton: some View {
        Button {
            Haptics.tap()
            speech.toggleDictation { text in
                if !text.isEmpty {
                    input = text
                }
            }
        } label: {
            Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(speech.isRecording ? .white : Theme.muted)
                .frame(width: 34, height: 34)
                .background(speech.isRecording ? Color.red : Theme.surface2, in: Circle())
                .scaleEffect(speech.isRecording ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: speech.isRecording)
        }
    }

    // MARK: - Send Button
    private var sendButton: some View {
        Button {
            Haptics.tap()
            streaming ? onStop() : onSend()
        } label: {
            Image(systemName: streaming ? "stop.fill" : "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(canSend || streaming ? Color.black : Theme.faint)
                .frame(width: 34, height: 34)
                .background(canSend || streaming ? Color.white : Theme.surface2, in: Circle())
        }
        .disabled(!canSend && !streaming)
        .animation(.easeOut(duration: 0.15), value: canSend)
    }

    private func toolChip(_ icon: String, _ label: String, _ on: Binding<Bool>) -> some View {
        Button {
            Haptics.tap()
            on.wrappedValue.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12, weight: .semibold))
                Text(label).font(.footnote.weight(.medium))
            }
            .foregroundStyle(on.wrappedValue ? Theme.accent2 : .white.opacity(0.75))
            .padding(.horizontal, 11).frame(height: 34)
            .background(on.wrappedValue ? Theme.accent.opacity(0.16) : Theme.surface2, in: Capsule())
            .overlay(Capsule().stroke(on.wrappedValue ? Theme.accent.opacity(0.45) : .clear, lineWidth: 1))
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
