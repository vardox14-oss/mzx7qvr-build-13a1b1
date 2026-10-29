import SwiftUI
import WebKit

struct WebContainerView: View {
    @State private var isLoading = true
    @State private var loadProgress: Double = 0.0
    @State private var loadError: String?
    @State private var reloadTrigger = UUID()

    var body: some View {
        ZStack {
            Color(red: 6/255, green: 6/255, blue: 8/255)
                .ignoresSafeArea()

            WebViewControllerRepresentable(
                url: URL(string: "https://darkgpt.chat/chat")!,
                isLoading: $isLoading,
                loadProgress: $loadProgress,
                loadError: $loadError,
                reloadTrigger: reloadTrigger
            )
            .ignoresSafeArea()

            // Subtle top progress bar while navigating
            if isLoading && loadProgress < 1.0 {
                VStack {
                    GeometryReader { geo in
                        Rectangle()
                            .fill(LinearGradient(colors: [Theme.accent, Theme.accent2], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * CGFloat(loadProgress), height: 2.5)
                            .animation(.easeOut(duration: 0.2), value: loadProgress)
                    }
                    .frame(height: 2.5)
                    Spacer()
                }
                .ignoresSafeArea(edges: .top)
            }

            // Offline error screen
            if let error = loadError {
                offlineView(error: error)
            }

            // Splash Screen during initial load
            if isLoading && loadProgress < 0.65 {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isLoading)
    }

    private func offlineView(error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 48))
                .foregroundStyle(Theme.accent2)

            Text("Connexion impossible")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)

            Text("Vérifie ta connexion internet pour accéder à DarkGPT.")
                .font(.subheadline)
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Haptics.tap()
                loadError = nil
                isLoading = true
                reloadTrigger = UUID()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Réessayer")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(Theme.accent, in: Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 6/255, green: 6/255, blue: 8/255).ignoresSafeArea())
    }
}

// MARK: - UIKit Representation
struct WebViewControllerRepresentable: UIViewControllerRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var loadProgress: Double
    @Binding var loadError: String?
    let reloadTrigger: UUID

    func makeUIViewController(context: Context) -> WebViewController {
        let vc = WebViewController(url: url)
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: WebViewController, context: Context) {
        if context.coordinator.lastReloadTrigger != reloadTrigger {
            context.coordinator.lastReloadTrigger = reloadTrigger
            uiViewController.reload()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WebViewControllerDelegate {
        var parent: WebViewControllerRepresentable
        var lastReloadTrigger: UUID

        init(_ parent: WebViewControllerRepresentable) {
            self.parent = parent
            self.lastReloadTrigger = parent.reloadTrigger
        }

        func didChangeLoading(_ loading: Bool) {
            DispatchQueue.main.async {
                self.parent.isLoading = loading
            }
        }

        func didUpdateProgress(_ progress: Double) {
            DispatchQueue.main.async {
                self.parent.loadProgress = progress
            }
        }

        func didFailWithError(_ error: Error) {
            DispatchQueue.main.async {
                let ns = error as NSError
                if ns.code != NSURLErrorCancelled {
                    self.parent.loadError = error.localizedDescription
                }
                self.parent.isLoading = false
            }
        }
    }
}

// MARK: - Custom WebViewController
protocol WebViewControllerDelegate: AnyObject {
    func didChangeLoading(_ loading: Bool)
    func didUpdateProgress(_ progress: Double)
    func didFailWithError(_ error: Error)
}

final class WebViewController: UIViewController, WKNavigationDelegate, WKUIDelegate {
    private let initialURL: URL
    weak var delegate: WebViewControllerDelegate?

    private var webView: WKWebView!
    private var progressObserver: NSKeyValueObservation?
    private let refreshControl = UIRefreshControl()

    init(url: URL) {
        self.initialURL = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 6/255, green: 6/255, blue: 8/255, alpha: 1.0)
        setupWebView()
        setupRefreshControl()
        loadInitialPage()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = WKWebsiteDataStore.default()

        // Inject dark theme & safe-area mobile script
        let userScriptSource = """
        document.documentElement.style.backgroundColor = '#060608';
        document.body.style.backgroundColor = '#060608';
        var meta = document.querySelector('meta[name="viewport"]');
        if (meta) {
            meta.setAttribute('content', 'width=device-width, initial-scale=1.0, viewport-fit=cover, interactive-widget=resizes-content');
        }
        """
        let script = WKUserScript(source: userScriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)

        webView = WKWebView(frame: view.bounds, configuration: config)
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 6/255, green: 6/255, blue: 8/255, alpha: 1.0)
        webView.scrollView.backgroundColor = UIColor(red: 6/255, green: 6/255, blue: 8/255, alpha: 1.0)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = true

        view.addSubview(webView)

        // Progress observation
        progressObserver = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            self?.delegate?.didUpdateProgress(webView.estimatedProgress)
        }
    }

    private func setupRefreshControl() {
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
    }

    @objc private func handleRefresh() {
        Haptics.tap()
        webView.reload()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.refreshControl.endRefreshing()
        }
    }

    private func loadInitialPage() {
        var req = URLRequest(url: initialURL)
        req.timeoutInterval = 30
        webView.load(req)
    }

    func reload() {
        loadInitialPage()
    }

    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        delegate?.didChangeLoading(true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        delegate?.didChangeLoading(false)
        refreshControl.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        delegate?.didFailWithError(error)
        refreshControl.endRefreshing()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        delegate?.didFailWithError(error)
        refreshControl.endRefreshing()
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        // Si le lien pointe vers un domaine externe (ex: Discord, Stripe, etc.), ouvrir dans Safari
        let host = url.host?.lowercased() ?? ""
        if !host.isEmpty && !host.contains("darkgpt.chat") && !host.contains("challenges.cloudflare.com") {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    // MARK: - WKUIDelegate (Native JS Alert/Confirm/Prompt + Popup Support)
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: "DarkGPT", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: "DarkGPT", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "Confirmer", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}
