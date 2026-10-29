import SwiftUI
import WebKit
import UIKit

/// Carte d'Artefact affichée dans la bulle du message (style Claude Artifacts).
struct ArtifactCardView: View {
    let artifact: Artifact
    var onOpen: (Artifact) -> Void

    var body: some View {
        Button {
            Haptics.tap()
            onOpen(artifact)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: artifact.type.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.accent2)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(artifact.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if artifact.version > 1 {
                            Text("v\(artifact.version)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(Theme.surface2, in: Capsule())
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Text(artifact.type.label)
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }

                Spacer()

                HStack(spacing: 6) {
                    if artifact.isPreviewable {
                        Text("Aperçu")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Theme.accent.opacity(0.25), in: Capsule())
                            .foregroundStyle(Theme.accent2)
                    }
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.faint)
                }
            }
            .padding(12)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Studio / Canvas plein écran pour prévisualiser, exécuter ou inspecter le code d'un Artefact.
struct ArtifactStudioView: View {
    let artifact: Artifact
    @Environment(\.dismiss) private var dismiss

    enum Tab: String, CaseIterable {
        case preview = "Aperçu"
        case code = "Code"
    }

    @State private var selectedTab: Tab
    @State private var copied = false
    @State private var showShare = false
    @State private var shareURL: URL?
    @State private var reloadToken = UUID()

    init(artifact: Artifact) {
        self.artifact = artifact
        _selectedTab = State(initialValue: artifact.isPreviewable ? .preview : .code)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if artifact.isPreviewable {
                    segmentedBar
                }

                ZStack {
                    Theme.bg.ignoresSafeArea()
                    if selectedTab == .preview && artifact.isPreviewable {
                        previewContent
                            .id(reloadToken)
                    } else {
                        codeContent
                    }
                }
            }
            .navigationTitle(artifact.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.surface, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fermer") { dismiss() }
                        .foregroundStyle(Theme.muted)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if selectedTab == .preview {
                            Button {
                                Haptics.tap()
                                reloadToken = UUID()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                        Button {
                            copyCode()
                        } label: {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(copied ? .green : .white)
                        }
                        Button {
                            prepareShare()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .sheet(isPresented: $showShare) {
                if let shareURL {
                    ShareSheet(activityItems: [shareURL])
                }
            }
        }
    }

    private var segmentedBar: some View {
        HStack {
            Picker("Mode", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Theme.surface)
        .overlay(Rectangle().fill(Theme.stroke).frame(height: 1), alignment: .bottom)
    }

    // MARK: - Preview Content (Live WebKit / SVG)
    private var previewContent: some View {
        Group {
            switch artifact.type {
            case .html:
                LiveHTMLView(html: artifact.content)
            case .svg:
                LiveSVGView(svg: artifact.content)
            case .mermaid:
                LiveMermaidView(diagram: artifact.content)
            default:
                codeContent
            }
        }
    }

    // MARK: - Code Content
    private var codeContent: some View {
        let lines = artifact.content.components(separatedBy: "\n")
        return ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text("\(index + 1)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.faint)
                            .frame(width: 34, alignment: .trailing)

                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .lineLimit(1)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(14)
        }
    }

    private func copyCode() {
        UIPasteboard.general.string = artifact.content
        Haptics.success()
        withAnimation { copied = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation { copied = false }
        }
    }

    private func prepareShare() {
        let ext = artifact.type.fileExtension
        let safeName = artifact.title
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let filename = (safeName.isEmpty ? "artefact" : safeName) + "." + ext
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? artifact.content.write(to: tempURL, atomically: true, encoding: .utf8)
        shareURL = tempURL
        showShare = true
    }
}

// MARK: - WebKit Live Views
struct LiveHTMLView: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let fullHTML = wrapHTMLIfNeeded(html)
        uiView.loadHTMLString(fullHTML, baseURL: nil)
    }

    private func wrapHTMLIfNeeded(_ raw: String) -> String {
        if raw.contains("<html") || raw.contains("<!DOCTYPE") {
            // S'assurer qu'il y a un meta viewport pour le mobile
            if !raw.contains("viewport") {
                return raw.replacingOccurrences(of: "<head>", with: "<head><meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">")
            }
            return raw
        }
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 16px; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #0e0e10; color: #fff; }
            </style>
        </head>
        <body>
            \(raw)
        </body>
        </html>
        """
    }
}

struct LiveSVGView: UIViewRepresentable {
    let svg: String

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero)
        web.isOpaque = false
        web.backgroundColor = .clear
        web.scrollView.backgroundColor = .clear
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body { margin: 0; display: flex; align-items: center; justify-content: center; min-height: 100vh; background-color: #0e0e10; }
                svg { max-width: 92vw; max-height: 85vh; height: auto; }
            </style>
        </head>
        <body>
            \(svg)
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }
}

struct LiveMermaidView: UIViewRepresentable {
    let diagram: String

    func makeUIView(context: Context) -> WKWebView {
        let web = WKWebView(frame: .zero)
        web.isOpaque = false
        web.backgroundColor = .clear
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let escaped = diagram.replacingOccurrences(of: "`", with: "\\`")
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <script src="https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"></script>
            <script>mermaid.initialize({ startOnLoad: true, theme: 'dark' });</script>
            <style>
                body { margin: 16px; background-color: #0e0e10; color: #fff; display: flex; justify-content: center; }
            </style>
        </head>
        <body>
            <div class="mermaid">
                \(escaped)
            </div>
        </body>
        </html>
        """
        uiView.loadHTMLString(html, baseURL: nil)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
