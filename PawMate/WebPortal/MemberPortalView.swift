import SwiftUI
import WebKit

extension Notification.Name {
    static let suspendPortalMedia = Notification.Name("hookup.suspendPortalMedia")
}

struct MemberPortalView: UIViewRepresentable {

    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.load(URLRequest(url: url))
        DiagnosticsLog.record("[WebPortal] Loading: \(url.absoluteString)")
        context.coordinator.webView = webView
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard webView.url != url else { return }
        webView.load(URLRequest(url: url))
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate {

        weak var webView: WKWebView?
        private var observer: NSObjectProtocol?

        override init() {
            super.init()
            observer = NotificationCenter.default.addObserver(
                forName: .suspendPortalMedia, object: nil, queue: .main
            ) { [weak self] _ in
                self?.webView?.evaluateJavaScript(
                    "document.querySelectorAll('video,audio').forEach(el => { el.pause(); el.muted = true; });"
                )
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let url = webView.url else { return }
            MemberSessionStore.shared.memberPortalURL = url
            DiagnosticsLog.record("[WebPortal] Navigated to: \(url.absoluteString)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DiagnosticsLog.record("[WebPortal] Navigation failed: \(error.localizedDescription)")
        }
    }
}
