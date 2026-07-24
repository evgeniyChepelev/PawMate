import Foundation
import CallKit
import AVFoundation
import UIKit
import Combine
import WebRTC

final class CallCoordinator: NSObject, ObservableObject {

    static let shared = CallCoordinator()

    @Published var isCallActive = false
    @Published var callerDisplayName: String = ""
    @Published var elapsedSeconds: Int = 0

    private var callProvider: CXProvider?
    private var activeCallUUID: UUID?
    private var activeCallId: String?
    private var durationTimer: Timer?
    private var mediaEngine: RTCMediaEngine?
    private var micShouldBeEnabled = false
    private var audioSessionActivated = false
    private var audioActivationAttempts = 0

    override private init() {
        super.init()
        configureAudioSession()
        configureCallProvider()
        configureSignalingBridge()
    }

    private func configureAudioSession() {
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.useManualAudio = true
        rtcAudioSession.isAudioEnabled = false

        let config = RTCAudioSessionConfiguration.webRTC()
        config.category = AVAudioSession.Category.playAndRecord.rawValue
        config.categoryOptions = [.allowBluetooth, .duckOthers, .defaultToSpeaker]
        config.mode = AVAudioSession.Mode.voiceChat.rawValue
        RTCAudioSessionConfiguration.setWebRTC(config)
    }

    private func configureCallProvider() {
        let config = CXProviderConfiguration()
        config.supportsVideo = false
        config.maximumCallGroups = 1
        config.maximumCallsPerCallGroup = 1
        config.supportedHandleTypes = [.generic]
        config.iconTemplateImageData = UIImage(systemName: "phone.fill")?.pngData()

        callProvider = CXProvider(configuration: config)
        callProvider?.setDelegate(self, queue: .main)
    }

    private func configureSignalingBridge() {
        let signaling = SignalingSocket.shared

        signaling.onCallStarted = { [weak self] callId, iceServers in
            DiagnosticsLog.record("[CallCoordinator] call.started, setting up peer connection")
            let engine = RTCMediaEngine()
            self?.mediaEngine = engine
            engine.preparePeerConnection(iceServers: iceServers)
            if self?.micShouldBeEnabled == true {
                engine.setMicrophoneEnabled(true)
            }

            engine.onLocalIceCandidate = { candidate in
                SignalingSocket.shared.sendIceCandidate(callId: callId, candidate: [
                    "candidate": candidate.sdp,
                    "sdpMid": candidate.sdpMid ?? "",
                    "sdpMLineIndex": candidate.sdpMLineIndex,
                ])
            }
            engine.onIceConnectionStateChanged = { state in
                DiagnosticsLog.record("[CallCoordinator] ICE connection state: \(state)")
            }
        }

        signaling.onRemoteOffer = { [weak self] sdp in
            guard let self, let callId = self.activeCallId else { return }
            self.mediaEngine?.applyRemoteOffer(sdp: sdp) { answerSdp in
                guard let answerSdp else { return }
                SignalingSocket.shared.sendAnswer(callId: callId, sdp: answerSdp)
            }
        }

        signaling.onRemoteIceCandidate = { [weak self] candidate in
            self?.mediaEngine?.ingestRemoteIceCandidate(candidate)
        }

        signaling.onCallEnded = { [weak self] callId in
            guard let self, let uuid = self.activeCallUUID else { return }
            self.callProvider?.reportCall(with: uuid, endedAt: nil, reason: .remoteEnded)
            self.resetCallState()
        }
    }

    func handleIncomingVoIPPush(payload: [AnyHashable: Any], completion: @escaping () -> Void) {
        DiagnosticsLog.record("[VoIP] Incoming call payload: \(payload)")
        let callId = payload["call_id"] as? String
        let caller = (payload["caller_name"] as? String)
            ?? (payload["caller_handle"] as? String)
            ?? "HookUp"

        NotificationCenter.default.post(name: .suspendPortalMedia, object: nil)

        announceIncomingCall(callId: callId, caller: caller) { [weak self] in
            if let callId {
                SignalingSocket.shared.open(callId: callId)
            }
            completion()
        }
    }

    private func announceIncomingCall(callId: String?, caller: String, completion: @escaping () -> Void) {
        let uuid = UUID()
        activeCallUUID = uuid
        activeCallId = callId
        callerDisplayName = caller

        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.lockForConfiguration()
        do {
            try rtcAudioSession.setConfiguration(RTCAudioSessionConfiguration.webRTC())
        } catch {
            DiagnosticsLog.record("[CallKit] Pre-report audio config failed: \(error.localizedDescription)")
        }
        rtcAudioSession.unlockForConfiguration()

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: caller)
        update.localizedCallerName = caller
        update.hasVideo = false

        callProvider?.reportNewIncomingCall(with: uuid, update: update) { error in
            if let error {
                DiagnosticsLog.record("[CallKit] Failed to report incoming call: \(error.localizedDescription)")
                self.activeCallUUID = nil
                self.activeCallId = nil
            }
            completion()
        }
    }

    func endActiveCall() {
        guard let uuid = activeCallUUID else { return }
        let controller = CXCallController()
        let action = CXEndCallAction(call: uuid)
        controller.request(CXTransaction(action: action)) { _ in }
    }

    private func resetCallState() {
        mediaEngine?.teardown()
        mediaEngine = nil
        micShouldBeEnabled = false
        audioSessionActivated = false
        SignalingSocket.shared.close()
        activeCallUUID = nil
        activeCallId = nil
        DispatchQueue.main.async {
            self.isCallActive = false
            self.stopTimer()
        }
    }

    private func startTimer() {
        elapsedSeconds = 0
        durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.elapsedSeconds += 1
        }
    }

    private func stopTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
        elapsedSeconds = 0
    }
}

extension CallCoordinator: CXProviderDelegate {

    func providerDidReset(_ provider: CXProvider) {
        resetCallState()
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        DiagnosticsLog.record("[CallKit] CXAnswerCallAction received")
        audioSessionActivated = false
        audioActivationAttempts = 0
        action.fulfill()
        DiagnosticsLog.record("[CallKit] CXAnswerCallAction fulfilled")
        DispatchQueue.main.async {
            self.isCallActive = true
            self.startTimer()
        }

        retryAudioSessionActivation()

        ensureMicrophoneAccess { [weak self] in
            guard let self, let callId = self.activeCallId else { return }
            self.micShouldBeEnabled = true
            self.mediaEngine?.setMicrophoneEnabled(true)
            SignalingSocket.shared.sendAccept(callId: callId)
        }
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        if let callId = activeCallId {
            if isCallActive {
                SignalingSocket.shared.sendHangup(callId: callId)
            } else {
                SignalingSocket.shared.sendReject(callId: callId)
            }
        }
        resetCallState()
        action.fulfill()
    }

    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        finalizeAudioSessionActivation(audioSession)
    }

    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        DiagnosticsLog.record("[CallKit] Audio session deactivated")
        audioSessionActivated = false
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
        RTCAudioSession.sharedInstance().isAudioEnabled = false
    }

    private func retryAudioSessionActivation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, self.isCallActive, !self.audioSessionActivated else { return }
            self.audioActivationAttempts += 1
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .duckOthers, .defaultToSpeaker])
                try session.setActive(true)
                DiagnosticsLog.record("[CallKit] Manual activation succeeded on attempt \(self.audioActivationAttempts)")
                self.finalizeAudioSessionActivation(session)
                return
            } catch {
                DiagnosticsLog.record("[CallKit] Manual activation attempt \(self.audioActivationAttempts) failed: \(error.localizedDescription)")
            }
            if self.audioActivationAttempts < 10 {
                self.retryAudioSessionActivation()
            }
        }
    }

    private func finalizeAudioSessionActivation(_ audioSession: AVAudioSession) {
        guard !audioSessionActivated else { return }
        audioSessionActivated = true
        DiagnosticsLog.record("[CallKit] Audio session activated")
        let rtcAudioSession = RTCAudioSession.sharedInstance()
        rtcAudioSession.audioSessionDidActivate(audioSession)
        rtcAudioSession.isAudioEnabled = true

        rtcAudioSession.lockForConfiguration()
        do {
            try rtcAudioSession.setConfiguration(RTCAudioSessionConfiguration.webRTC(), active: true)
            DiagnosticsLog.record("[RTCMedia] Audio session configuration applied")
        } catch {
            DiagnosticsLog.record("[RTCMedia] Failed to apply audio session configuration: \(error.localizedDescription)")
        }
        rtcAudioSession.unlockForConfiguration()
    }

    private func ensureMicrophoneAccess(completion: @escaping () -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                if !granted {
                    DiagnosticsLog.record("[Mic] Permission denied")
                }
                completion()
            }
        }
    }
}
