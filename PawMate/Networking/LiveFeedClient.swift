import Foundation

final class LiveFeedClient: NSObject {

    static let shared = LiveFeedClient()
    private override init() {}

    var onMemberPortalURL: ((URL) -> Void)?

    private var activeTask: URLSessionDataTask?
    private var buffer = ""
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    func startFeed() {
        guard activeTask == nil else { return }
        guard let accountId = MemberSessionStore.shared.accountId,
              let regId = MemberSessionStore.shared.deviceRegistrationId else { return }

        var components = URLComponents(string: "\(BackendClient.baseURL)/sse")!
        components.queryItems = [
            URLQueryItem(name: "user_id", value: accountId),
            URLQueryItem(name: "reg_id", value: regId),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = .infinity

        activeTask = session.dataTask(with: request)
        activeTask?.resume()
        DiagnosticsLog.record("[LiveEvents] Connected")
    }

    func stopFeed() {
        activeTask?.cancel()
        activeTask = nil
        buffer = ""
        DiagnosticsLog.record("[LiveEvents] Disconnected")
    }

    private func ingestFeedChunk(_ text: String) {
        buffer += text
        let lines = buffer.components(separatedBy: "\n")
        buffer = lines.last ?? ""

        var eventData = ""
        for line in lines.dropLast() {
            if line.hasPrefix("data:") {
                eventData = line.replacingOccurrences(of: "data:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.isEmpty && !eventData.isEmpty {
                decodeFeedEvent(eventData)
                eventData = ""
            }
        }
    }

    private func decodeFeedEvent(_ data: String) {
        DiagnosticsLog.record("[LiveEvents] Event: \(data)")
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { return }

        if let urlString = json["platform_url"] as? String, let url = URL(string: urlString) {
            DiagnosticsLog.record("[LiveEvents] platform_url received: \(urlString)")
            DispatchQueue.main.async { self.onMemberPortalURL?(url) }
        }
    }
}

extension LiveFeedClient: URLSessionDataDelegate {

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        ingestFeedChunk(text)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error { DiagnosticsLog.record("[LiveEvents] Error: \(error.localizedDescription)") }
        activeTask = nil
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.startFeed()
        }
    }
}
