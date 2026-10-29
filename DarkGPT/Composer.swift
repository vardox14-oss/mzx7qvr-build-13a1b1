import SwiftUI
import PhotosUI

/// Large rounded input card: text on top, tool row underneath.
struct Composer: View {
    @Binding var input: String
    @Binding var webSearch: Bool
    @Binding var thinking: Bool
    @Binding var attachedImage: Data?
    @Binding var pickerItem: PhotosPickerItem?
    var streaming: Bool
    var showThinking: Bool
    var focused: FocusState<Bool>.Binding
    var onSend: () -> Void
    var onStop: () -> Void

    private var canSend: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let attachedImage, let ui = UIImage(data: attachedImage) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: ui).resizable().scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    Button { self.attachedImage = nil; pickerItem = nil } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 20, height: 20).background(.black.opacity(0.7), in: Circle())
                    }
                    .offset(x: 6, y: -6)
                }
                .padding(.top, 4)
            }

            TextField("", text: $input, prompt: Text("Écris à DarkGPT…").foregroundColor(Theme.faint), axis: .vertical)
                .focused(focused)
                .lineLimit(1...8)
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 4)

            HStack(spacing: 8) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Image(systemName: "plus").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 34, height: 34)
                        .background(Theme.surface2, in: Circle())
                }
                toolChip("globe", "Web", $webSearch)
                if showThinking { toolChip("sparkle", "Réflexion", $thinking) }
                Spacer()
                sendButton
            }
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
    }

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
        Button { Haptics.tap(); on.wrappedValue.toggle() } label: {
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
}
