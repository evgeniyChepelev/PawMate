import Foundation
import WebRTC

final class RTCMediaEngine: NSObject {

    private let factory: RTCPeerConnectionFactory
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?

    var onLocalIceCandidate: ((RTCIceCandidate) -> Void)?
    var onIceConnectionStateChanged: ((RTCIceConnectionState) -> Void)?

    override init() {
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
        super.init()
    }

    func preparePeerConnection(iceServers: [[String: Any]]) {
        let config = RTCConfiguration()
        config.iceServers = iceServers.map { server in
            let urls: [String]
            if let single = server["urls"] as? String {
                urls = [single]
            } else if let multi = server["urls"] as? [String] {
                urls = multi
            } else {
                urls = []
            }
            return RTCIceServer(
                urlStrings: urls,
                username: server["username"] as? String,
                credential: server["credential"] as? String
            )
        }
        config.iceTransportPolicy = .all
        config.sdpSemantics = .unifiedPlan

        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        peerConnection = factory.peerConnection(with: config, constraints: constraints, delegate: self)

        let audioSource = factory.audioSource(with: constraints)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "audio0")
        audioTrack.isEnabled = false
        localAudioTrack = audioTrack
        peerConnection?.add(audioTrack, streamIds: ["stream0"])
    }

    func applyRemoteOffer(sdp: String, completion: @escaping (String?) -> Void) {
        let remoteDescription = RTCSessionDescription(type: .offer, sdp: sdp)
        peerConnection?.setRemoteDescription(remoteDescription) { [weak self] error in
            if let error {
                DiagnosticsLog.record("[RTCMedia] setRemoteDescription failed: \(error.localizedDescription)")
                completion(nil)
                return
            }
            let answerConstraints = RTCMediaConstraints(
                mandatoryConstraints: ["OfferToReceiveAudio": "true"],
                optionalConstraints: nil
            )
            self?.peerConnection?.answer(for: answerConstraints) { answer, error in
                guard let answer, error == nil else {
                    DiagnosticsLog.record("[RTCMedia] createAnswer failed: \(error?.localizedDescription ?? "?")")
                    completion(nil)
                    return
                }
                self?.peerConnection?.setLocalDescription(answer) { error in
                    if let error {
                        DiagnosticsLog.record("[RTCMedia] setLocalDescription failed: \(error.localizedDescription)")
                        completion(nil)
                        return
                    }
                    completion(answer.sdp)
                }
            }
        }
    }

    func ingestRemoteIceCandidate(_ dict: [String: Any]) {
        guard let candidateStr = dict["candidate"] as? String else { return }
        let sdpMid = dict["sdpMid"] as? String
        let sdpMLineIndex = Int32(dict["sdpMLineIndex"] as? Int ?? 0)
        let candidate = RTCIceCandidate(sdp: candidateStr, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
        peerConnection?.add(candidate)
    }

    func setMicrophoneEnabled(_ enabled: Bool) {
        localAudioTrack?.isEnabled = enabled
    }

    func teardown() {
        peerConnection?.close()
        peerConnection = nil
        localAudioTrack = nil
    }
}

extension RTCMediaEngine: RTCPeerConnectionDelegate {

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        DiagnosticsLog.record("[RTCMedia] Remote stream added (legacy): \(stream.streamId)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}

    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        DiagnosticsLog.record("[RTCMedia] ICE state: \(newState)")
        onIceConnectionStateChanged?(newState)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        onLocalIceCandidate?(candidate)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}

    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams mediaStreams: [RTCMediaStream]) {
        DiagnosticsLog.record("[RTCMedia] Remote track added: \(rtpReceiver.track?.trackId ?? "?")")
    }
}
