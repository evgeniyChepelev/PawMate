import Foundation

final class MemberSessionStore {

    static let shared = MemberSessionStore()
    private let defaults = UserDefaults.standard

    private init() {}

    var accountId: String? {
        get { defaults.string(forKey: "pawmate.account_id") }
        set { defaults.set(newValue, forKey: "pawmate.account_id") }
    }

    var deviceRegistrationId: String? {
        get { defaults.string(forKey: "pawmate.device_registration_id") }
        set { defaults.set(newValue, forKey: "pawmate.device_registration_id") }
    }

    /// Cached answer to `ReleaseGate.resolveReleaseState()`. Persisted so the
    /// backend flag is fetched once and then reused for the app's lifetime.
    /// `nil` = not resolved yet (still need to ask the backend).
    var cachedReleaseFlag: Bool? {
        get {
            guard defaults.object(forKey: "pawmate.version_supported") != nil else { return nil }
            return defaults.bool(forKey: "pawmate.version_supported")
        }
        set {
            if let newValue {
                defaults.set(newValue, forKey: "pawmate.version_supported")
            } else {
                defaults.removeObject(forKey: "pawmate.version_supported")
            }
        }
    }

    var memberPortalURL: URL? {
        get {
            guard let value = defaults.string(forKey: "pawmate.web_portal_url") else { return nil }
            return URL(string: value)
        }
        set { defaults.set(newValue?.absoluteString, forKey: "pawmate.web_portal_url") }
    }

    var relaySignalToken: String? {
        get {
            if let stored = defaults.string(forKey: "pawmate.relay_signal_token") { return stored }
            guard let url = memberPortalURL else { return nil }
            return URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "token" })?.value
        }
        set { defaults.set(newValue, forKey: "pawmate.relay_signal_token") }
    }

    var isDeviceEnrolled: Bool {
        accountId != nil && deviceRegistrationId != nil
    }

    func clear() {
        [
            "pawmate.account_id",
            "pawmate.device_registration_id",
            "hookup.pending_voip_token",
            "hookup.pending_voip_token_data",
        ].forEach { defaults.removeObject(forKey: $0) }
    }
}
