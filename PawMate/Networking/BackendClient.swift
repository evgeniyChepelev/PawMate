import Foundation

final class BackendClient {

    static let shared = BackendClient()
    static let baseURL = BackendConfig.restBaseURL
    private let baseURL = BackendClient.baseURL

    private init() {}

    struct EnrollmentRequest: Encodable {
        let device_id: String
        let app_id: String
        let push_permission_status: String
    }

    struct EnrollmentResponse: Decodable {
        let user_id: String
        let reg_id: String
        let user_state: String
        let webview_url: String?
    }

    func enrollDevice(_ body: EnrollmentRequest) async throws -> EnrollmentResponse {
        try await post("/users", body: body, auth: nil)
    }

    struct VoipTokenPayload: Encodable {
        let voip_token: String
    }

    func updateVoipToken(accountId: String, token: String, regToken: String) async throws {
        let body = VoipTokenPayload(voip_token: token)
        let _: EmptyBody = try await patch("/users/\(accountId)/voip", body: body, auth: regToken)
    }

    struct PermissionsPayload: Encodable {
        let push_permission_status: String
    }

    func updatePermissions(accountId: String, pushStatus: String, regToken: String) async throws {
        let body = PermissionsPayload(push_permission_status: pushStatus)
        let _: EmptyBody = try await patch("/users/\(accountId)/permissions", body: body, auth: regToken)
    }

    struct SubscriptionPayload: Encodable {
        let player_id: String
        let onesignal_id: String
        let is_subscribed: Bool
    }

    func updatePushSubscription(accountId: String, onesignalId: String, playerId: String, isSubscribed: Bool, regToken: String) async throws {
        let body = SubscriptionPayload(player_id: playerId, onesignal_id: onesignalId, is_subscribed: isSubscribed)
        let _: EmptyBody = try await patch("/users/\(accountId)/onesignal", body: body, auth: regToken)
    }

    private struct EmptyBody: Decodable {}

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = URLRequest(url: URL(string: baseURL + path)!)
        return try await dispatch(request)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B, auth: String?) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        if let auth { request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization") }
        return try await dispatch(request)
    }

    private func patch<B: Encodable, T: Decodable>(_ path: String, body: B, auth: String?) async throws -> T {
        var request = URLRequest(url: URL(string: baseURL + path)!)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        if let auth { request.setValue("Bearer \(auth)", forHTTPHeaderField: "Authorization") }
        return try await dispatch(request)
    }

    private func dispatch<T: Decodable>(_ request: URLRequest) async throws -> T {
        let method = request.httpMethod ?? "?"
        let url = request.url?.absoluteString ?? ""
        if let body = request.httpBody, let bodyStr = String(data: body, encoding: .utf8) {
            DiagnosticsLog.record("[API] \(method) \(url)\nBody: \(bodyStr)")
        } else {
            DiagnosticsLog.record("[API] \(method) \(url)")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        let responseStr = String(data: data, encoding: .utf8) ?? "<binary>"
        DiagnosticsLog.record("[API] Response \(status): \(responseStr)")

        guard let http, (200...299).contains(http.statusCode) else {
            throw NSError(
                domain: "BackendClient",
                code: status,
                userInfo: [NSLocalizedDescriptionKey: responseStr]
            )
        }
        if T.self == EmptyBody.self {
            return EmptyBody() as! T
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
