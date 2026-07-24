import UIKit
import PushKit
import OneSignalFramework
import UserNotifications

class PushCoordinator: NSObject, UIApplicationDelegate {

    static weak var shared: PushCoordinator?

    private let voipRegistry = PKPushRegistry(queue: .main)

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        DiagnosticsLog.record("[PushCoordinator] didFinishLaunching")
        PushCoordinator.shared = self

        UNUserNotificationCenter.current().delegate = self

        voipRegistry.delegate = self
        voipRegistry.desiredPushTypes = [.voIP]
        DiagnosticsLog.record("[PushCoordinator] PKPushRegistry configured")

        PushSubscriptionBridge.shared.initializeSDK(launchOptions: launchOptions)

        return true
    }

    func activateSessionServices() {
        PushSubscriptionBridge.shared.activate()
    }
}

extension PushCoordinator: PKPushRegistryDelegate {

    func pushRegistry(_ registry: PKPushRegistry,
                      didUpdate credentials: PKPushCredentials,
                      for type: PKPushType) {
        guard type == .voIP else { return }

        let tokenData = credentials.token
        let tokenString = tokenData.map { String(format: "%02x", $0) }.joined()
        DiagnosticsLog.record("[VoIP] Token received: \(tokenString)")

        UserDefaults.standard.set(tokenData, forKey: "hookup.last_voip_token_data")
        UserDefaults.standard.set(tokenString, forKey: "hookup.last_voip_token")

        guard let accountId = MemberSessionStore.shared.accountId,
              let regId = MemberSessionStore.shared.deviceRegistrationId else {
            UserDefaults.standard.set(tokenString, forKey: "hookup.pending_voip_token")
            UserDefaults.standard.set(tokenData, forKey: "hookup.pending_voip_token_data")
            return
        }

        Task { await syncVoipToken(accountId: accountId, regId: regId, tokenString: tokenString) }
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didInvalidatePushTokenFor type: PKPushType) {
        DiagnosticsLog.record("[VoIP] Token invalidated")
    }

    func pushRegistry(_ registry: PKPushRegistry,
                      didReceiveIncomingPushWith payload: PKPushPayload,
                      for type: PKPushType,
                      completion: @escaping () -> Void) {
        guard type == .voIP else { completion(); return }
        DiagnosticsLog.record("[VoIP] Incoming push")
        CallCoordinator.shared.handleIncomingVoIPPush(payload: payload.dictionaryPayload, completion: completion)
    }

    private func syncVoipToken(accountId: String, regId: String, tokenString: String) async {
        do {
            try await BackendClient.shared.updateVoipToken(accountId: accountId, token: tokenString, regToken: regId)
        } catch {
            DiagnosticsLog.record("[VoIP] Registration failed: \(error)")
        }
    }
}

extension PushCoordinator {

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
        DiagnosticsLog.record("[APNs] Device token: \(tokenString)")
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        DiagnosticsLog.record("[APNs] Failed to register: \(error.localizedDescription)")
    }
}

extension PushCoordinator: UNUserNotificationCenterDelegate {

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
}
