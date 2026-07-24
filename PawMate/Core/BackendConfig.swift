import Foundation

enum BackendConfig {
    static let appStoreId = "6794031908"
    static let oneSignalAppId = "23010d4c-926f-437d-b6eb-97d15ca442a8"
    static let apiHost = "norgilen.xyz"

    static var restBaseURL: String { "https://\(apiHost)/api/v1" }
    static var socketBaseURL: String { "https://\(apiHost)" }

    /// Force-update flag endpoint. Must return `{ "value": Bool }` where
    /// `true` = installed build supported (run the app) and
    /// `false` = update required (show ForceUpdateView).
    /// Point this at your real backend route.
    static var updateFlagURL: String { "https://\(apiHost)/api/v1/manager/settings/getUpdates" }
}
