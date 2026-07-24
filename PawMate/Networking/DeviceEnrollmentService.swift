import Foundation
import UserNotifications

final class DeviceEnrollmentService {

    static let shared = DeviceEnrollmentService()
    private init() {}

    func enrollIfNeeded() async {
        guard !MemberSessionStore.shared.isDeviceEnrolled else { return }

        let body = BackendClient.EnrollmentRequest(
            device_id: stableDeviceId(),
            app_id: BackendConfig.appStoreId,
            push_permission_status: await currentNotificationStatus()
        )

        do {
            let response = try await BackendClient.shared.enrollDevice(body)
            MemberSessionStore.shared.accountId = response.user_id
            MemberSessionStore.shared.deviceRegistrationId = response.reg_id
            let url = response.webview_url.flatMap { URL(string: $0) }
            MemberSessionStore.shared.memberPortalURL = url
            MemberSessionStore.shared.relaySignalToken = url.flatMap {
                URLComponents(url: $0, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "token" })?.value
            }
            DiagnosticsLog.record("[Onboarding] Registered, account_id: \(response.user_id)")
            DiagnosticsLog.record("[Onboarding] memberPortalURL: \(response.webview_url ?? "nil")")
            await drainQueuedVoipToken()
            PushSubscriptionBridge.shared.syncIfReady()
        } catch {
            DiagnosticsLog.record("[Onboarding] Registration failed: \(error)")
        }
    }

    private func drainQueuedVoipToken() async {
        guard
            let accountId = MemberSessionStore.shared.accountId,
            let regId = MemberSessionStore.shared.deviceRegistrationId,
            let tokenString = UserDefaults.standard.string(forKey: "hookup.pending_voip_token")
        else { return }

        UserDefaults.standard.removeObject(forKey: "hookup.pending_voip_token")
        UserDefaults.standard.removeObject(forKey: "hookup.pending_voip_token_data")

        do {
            try await BackendClient.shared.updateVoipToken(accountId: accountId, token: tokenString, regToken: regId)
            DiagnosticsLog.record("[Onboarding] Queued VoIP token flushed")
        } catch {
            DiagnosticsLog.record("[Onboarding] Failed to flush VoIP token: \(error)")
        }
    }

    private func stableDeviceId() -> String {
        if let id = UserDefaults.standard.string(forKey: "pawmate.device_id") { return id }
        let id = UUID().uuidString
        UserDefaults.standard.set(id, forKey: "pawmate.device_id")
        return id
    }

    private func currentNotificationStatus() async -> String {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return "granted"
        case .denied: return "denied"
        default: return "notDetermined"
        }
    }
}
