import UIKit
import UniformTypeIdentifiers
import WebKit

enum Brand {
    static let accent = UIColor(red: 6 / 255, green: 76 / 255, blue: 59 / 255, alpha: 1)
    static let gold = UIColor(red: 201 / 255, green: 154 / 255, blue: 63 / 255, alpha: 1)
    static let background = UIColor(red: 248 / 255, green: 247 / 255, blue: 243 / 255, alpha: 1)
}

/// Thin native shell around the production web app at https://gastroconnect.ru/.
/// Everything (auth, content, forms) lives on the site; the shell only adds
/// file uploads, downloads, external link handling, progress and a retry screen.
final class WebViewController: UIViewController {

    private enum Constants {
        static let homeURL = URL(string: "https://gastroconnect.ru/")!
        static let userAgentSuffix = "GastroConnectApp/1.0.0"
        static let allowedHosts = ["gastroconnect.ru", "www.gastroconnect.ru"]
    }

    private var webView: WKWebView!
    private var progressView: UIProgressView!
    private var errorView: UIView!
    private var errorLabel: UILabel!

    private var progressObservation: NSKeyValueObservation?
    private var fileHandler: (([URL]?) -> Void)?
    private var downloads: [WKDownload: URL] = [:]

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Brand.background
        configureWebView()
        configureProgress()
        configureErrorView()
        load(Constants.homeURL)
        observeProgress()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .darkContent }

    // MARK: - Public

    func load(_ url: URL) {
        guard isAllowed(url) else {
            openExternally(url)
            return
        }
        guard webView.url != url else { return }
        hideError()
        webView.load(URLRequest(url: url))
    }

    // MARK: - Setup

    private func configureWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.applicationNameForUserAgent = Constants.userAgentSuffix
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.websiteDataStore = .default()

        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        webView.backgroundColor = Brand.background
        webView.scrollView.backgroundColor = Brand.background

        let refresh = UIRefreshControl()
        refresh.tintColor = Brand.accent
        refresh.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureProgress() {
        progressView = UIProgressView(progressViewStyle: .bar)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progressTintColor = Brand.gold
        progressView.trackTintColor = .clear
        progressView.isHidden = true
        view.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    private func configureErrorView() {
        errorView = UIView()
        errorView.translatesAutoresizingMaskIntoConstraints = false
        errorView.backgroundColor = Brand.background
        errorView.isHidden = true

        errorLabel = UILabel()
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.numberOfLines = 0
        errorLabel.textAlignment = .center
        errorLabel.font = .preferredFont(forTextStyle: .body)
        errorLabel.textColor = .secondaryLabel
        errorLabel.text = "Нет подключения к интернету.\nПроверьте сеть и попробуйте снова."

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Повторить", for: .normal)
        button.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = Brand.accent
        button.layer.cornerRadius = 12
        button.contentEdgeInsets = UIEdgeInsets(top: 14, left: 28, bottom: 14, right: 28)
        button.addTarget(self, action: #selector(retry), for: .touchUpInside)

        errorView.addSubview(errorLabel)
        errorView.addSubview(button)
        view.addSubview(errorView)

        NSLayoutConstraint.activate([
            errorView.topAnchor.constraint(equalTo: view.topAnchor),
            errorView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            errorView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            errorView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            errorLabel.centerYAnchor.constraint(equalTo: errorView.centerYAnchor, constant: -40),
            errorLabel.leadingAnchor.constraint(equalTo: errorView.leadingAnchor, constant: 32),
            errorLabel.trailingAnchor.constraint(equalTo: errorView.trailingAnchor, constant: -32),

            button.topAnchor.constraint(equalTo: errorLabel.bottomAnchor, constant: 24),
            button.centerXAnchor.constraint(equalTo: errorView.centerXAnchor)
        ])
    }

    private func observeProgress() {
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
            guard let self else { return }
            let value = Float(webView.estimatedProgress)
            self.progressView.isHidden = value >= 1
            self.progressView.setProgress(value, animated: true)
        }
    }

    // MARK: - Actions

    @objc private func handleRefresh() {
        webView.reload()
    }

    @objc private func retry() {
        hideError()
        if webView.url == nil {
            load(Constants.homeURL)
        } else {
            webView.reload()
        }
    }

    private func showError() {
        errorView.isHidden = false
        progressView.isHidden = true
    }

    private func hideError() {
        errorView.isHidden = true
    }

    // MARK: - Navigation helpers

    private func isAllowed(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if ["about", "data", "blob", "javascript", "file"].contains(scheme) { return true }
        guard scheme == "http" || scheme == "https" else { return false }
        guard let host = url.host?.lowercased() else { return false }
        return Constants.allowedHosts.contains(host) || host.hasSuffix(".gastroconnect.ru")
    }

    private func openExternally(_ url: URL) {
        UIApplication.shared.open(url, options: [:]) { [weak self] opened in
            guard !opened, url.scheme?.lowercased() == "tg" else { return }
            var components = URLComponents()
            components.scheme = "https"
            components.host = "t.me"
            components.path = url.path.isEmpty ? "/GastroConnect_Bot" : url.path
            if let fallback = components.url {
                UIApplication.shared.open(fallback)
            }
            self?.hideError()
        }
    }

    private func presentShare(for fileURL: URL) {
        let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = view
        controller.popoverPresentationController?.sourceRect = view.bounds
        present(controller, animated: true)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewController: WKNavigationDelegate {

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if isAllowed(url) {
            // window.open() and target=_blank: open in the same web view.
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
                return
            }
            decisionHandler(.allow)
            return
        }

        openExternally(url)
        decisionHandler(.cancel)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.scrollView.refreshControl?.endRefreshing()
        progressView.isHidden = true
        hideError()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        if (error as NSError).code == NSURLErrorCancelled { return }
        showError()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        webView.scrollView.refreshControl?.endRefreshing()
        if (error as NSError).code == NSURLErrorCancelled { return }
        showError()
    }

    func webView(
        _ webView: WKWebView,
        navigationAction: WKNavigationAction,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }

    func webView(
        _ webView: WKWebView,
        navigationResponse: WKNavigationResponse,
        didBecome download: WKDownload
    ) {
        download.delegate = self
    }
}

// MARK: - WKUIDelegate

extension WebViewController: WKUIDelegate {

    func webView(
        _ webView: WKWebView,
        runOpenPanelWith parameters: WKOpenPanelParameters,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping ([URL]?) -> Void
    ) {
        fileHandler = completionHandler

        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.image, UTType.pdf, UTType.movie],
            asCopy: true
        )
        picker.allowsMultipleSelection = parameters.allowsMultipleSelection
        picker.delegate = self
        present(picker, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptAlertPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping () -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(
        _ webView: WKWebView,
        runJavaScriptConfirmPanelWithMessage message: String,
        initiatedByFrame frame: WKFrameInfo,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel) { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "ОК", style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension WebViewController: UIDocumentPickerDelegate {

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        fileHandler?(urls)
        fileHandler = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        fileHandler?(nil)
        fileHandler = nil
    }
}

// MARK: - WKDownloadDelegate

extension WebViewController: WKDownloadDelegate {

    func download(
        _ download: WKDownload,
        decideDestinationUsing response: URLResponse,
        suggestedFilename: String,
        completionHandler: @escaping (URL?) -> Void
    ) {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("GastroConnectDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let destination = folder.appendingPathComponent(safeName(suggestedFilename))
        try? FileManager.default.removeItem(at: destination)
        downloads[download] = destination
        completionHandler(destination)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let fileURL = downloads.removeValue(forKey: download) else { return }
        presentShare(for: fileURL)
    }

    func download(
        _ download: WKDownload,
        didFailWithError error: Error,
        resumeData: Data?
    ) {
        downloads.removeValue(forKey: download)
    }

    private func safeName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._- "))
        let cleaned = name.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
        return cleaned.isEmpty ? UUID().uuidString : cleaned
    }
}
