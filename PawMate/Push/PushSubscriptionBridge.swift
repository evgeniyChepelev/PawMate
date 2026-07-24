import Foundation
import UIKit
import OneSignalFramework
import UserNotifications

final class PushSubscriptionBridge: NSObject {

    static let shared = PushSubscriptionBridge()
    private(set) var lastSyncSucceeded = false
    private override init() {}

    private let appId = BackendConfig.oneSignalAppId

    func initializeSDK(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        OneSignal.initialize(appId, withLaunchOptions: launchOptions)
        OneSignal.User.pushSubscription.addObserver(self)
        DiagnosticsLog.record("[PushBridge] SDK initialized")
    }

    func activate() {
        DiagnosticsLog.record("[PushBridge] activate — onesignalId: \(OneSignal.User.onesignalId ?? "nil")")
        DiagnosticsLog.record("[PushBridge] subscriptionId: \(OneSignal.User.pushSubscription.id ?? "nil")")
        DiagnosticsLog.record("[PushBridge] optedIn: \(OneSignal.User.pushSubscription.optedIn)")
        syncIfReady()
    }

    func awaitDelivery(timeout: TimeInterval = 20) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if lastSyncSucceeded { return }
            syncIfReady()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        DiagnosticsLog.record("[PushBridge] awaitDelivery: timed out after \(timeout)s")
    }

    func syncIfReady() {
        let onesignalId = OneSignal.User.onesignalId
        let playerId = OneSignal.User.pushSubscription.id
        let isSubscribed = OneSignal.User.pushSubscription.optedIn

        guard
            let accountId = MemberSessionStore.shared.accountId,
            let regId = MemberSessionStore.shared.deviceRegistrationId,
            let onesignalId,
            let playerId
        else {
            DiagnosticsLog.record("[PushBridge] Not ready yet — waiting for observer")
            return
        }

        deliverSubscription(accountId: accountId, regId: regId, onesignalId: onesignalId, playerId: playerId, isSubscribed: isSubscribed)
    }

    private func deliverSubscription(accountId: String, regId: String, onesignalId: String, playerId: String, isSubscribed: Bool) {
        Task {
            do {
                try await BackendClient.shared.updatePushSubscription(
                    accountId: accountId, onesignalId: onesignalId, playerId: playerId,
                    isSubscribed: isSubscribed, regToken: regId
                )
                self.lastSyncSucceeded = true
                DiagnosticsLog.record("[PushBridge] player_id sent: \(playerId)")

                let settings = await UNUserNotificationCenter.current().notificationSettings()
                let pushStatus: String
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral: pushStatus = "granted"
                case .denied: pushStatus = "denied"
                default: pushStatus = "notDetermined"
                }
                try await BackendClient.shared.updatePermissions(accountId: accountId, pushStatus: pushStatus, regToken: regId)
                DiagnosticsLog.record("[PushBridge] Permissions synced: push=\(pushStatus)")
            } catch {
                DiagnosticsLog.record("[PushBridge] Failed: \(error)")
            }
        }
    }
}

extension PushSubscriptionBridge: OSPushSubscriptionObserver {

    func onPushSubscriptionDidChange(state: OSPushSubscriptionChangedState) {
        DiagnosticsLog.record("[PushBridge] Subscription changed: id=\(state.current.id ?? "nil") optedIn=\(state.current.optedIn)")

        guard
            let accountId = MemberSessionStore.shared.accountId,
            let regId = MemberSessionStore.shared.deviceRegistrationId,
            let onesignalId = OneSignal.User.onesignalId,
            let playerId = state.current.id
        else {
            DiagnosticsLog.record("[PushBridge] Observer fired but device not registered yet — will retry after registration")
            return
        }

        deliverSubscription(accountId: accountId, regId: regId, onesignalId: onesignalId, playerId: playerId, isSubscribed: state.current.optedIn)
    }
}
