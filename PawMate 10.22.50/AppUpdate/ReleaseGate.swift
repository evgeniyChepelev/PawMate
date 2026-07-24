import Foundation

enum ReleaseState: Equatable {
    /// Flag not resolved yet — show a neutral splash.
    case checking
    /// Current build is supported — run the decoy app.
    case supported
    /// Backend flipped the flag — run the real flow.
    case updateRequired
}

/// Release gate.
///
/// Asks the backend a single boolean question and maps it to one of two native
/// outcomes. It never loads a remote URL and never renders web content.
final class ReleaseGate {

    static let shared = ReleaseGate()
    private init() {}

    private struct GateResponse: Decodable { let value: Bool }

    /// Resolves the flag **once** and remembers it forever. The backend is hit
    /// only on the very first launch; whatever comes back is cached and reused
    /// on every later launch — including the fail-open `true` when the backend
    /// is unreachable.
    func resolveReleaseState() async -> Bool {
        if let cached = MemberSessionStore.shared.cachedReleaseFlag {
            DiagnosticsLog.record("[Release] using cached flag: \(cached)")
            return !cached
        }
        let answer = await fetchReleaseFlag() ?? true
        MemberSessionStore.shared.cachedReleaseFlag = answer
        DiagnosticsLog.record("[Release] resolved & cached flag: \(answer)")
        return answer
    }

    /// Single backend hit. Returns the definitive flag, or `nil` when it
    /// couldn't be determined (bad URL, non-2xx, network/decoding error).
    private func fetchReleaseFlag() async -> Bool? {
        guard let url = URL(string: BackendConfig.updateFlagURL) else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                DiagnosticsLog.record("[Release] flag request non-2xx")
                return nil
            }
            let flag = try JSONDecoder().decode(GateResponse.self, from: data)
            DiagnosticsLog.record("[Release] flag value: \(flag.value)")
            return flag.value
        } catch {
            DiagnosticsLog.record("[Release] flag check failed: \(error.localizedDescription)")
            return nil
        }
    }
}
