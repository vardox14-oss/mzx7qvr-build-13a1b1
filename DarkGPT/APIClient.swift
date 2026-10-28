import Foundation

enum APIError: LocalizedError {
    case unauthorized
    case server(String, Int)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Ta session a expiré. Reconnecte-toi."
        case .server(let message, _): return message
        case .network(let message): return message
        }
    }

    var status: Int? {
        if case .server(_, let code) = self { return code }
        return nil
    }
}

enum LoginResult { case success, needsTwoFactor }

enum ChatEvent {
    case text(String)
    case status(String)
    case finished(content: String?, gems: Double?)
    case failed(String, gems: Double?)
}

final class APIClient {
    static let shared = APIClient()
    static let baseURL = URL(string: "https://darkgpt.chat")!

    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.httpShouldSetCookies = true
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 300
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        session = URLSession(configuration: config)
    }

    private func url(_ path: String) -> URL { URL(string: path, relativeTo: APIClient.baseURL)!.absoluteURL }

    private func request(_ path: String, method: String = "GET", json: [String: Any]? = nil) -> URLRequest {
        var req = URLRequest(url: url(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: json)
        }
        return req
    }

    private func parseError(_ data: Data, status: Int) -> APIError {
        if status == 401 { return .unauthorized }
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = (obj["error"] as? String) ?? (obj["message"] as? String) {
            return .server(message, status)
        }
        return .server("Erreur serveur (\(status)).", status)
    }

    // MARK: - Auth

    func loginEmail(email: String, password: String) async throws -> LoginResult {
        let req = request("/api/auth/login-email", method: "POST", json: ["email": email, "password": password])
        let (data, resp) = try await send(req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw parseError(data, status: status) }
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        return (obj?["requires_2fa"] as? Bool) == true ? .needsTwoFactor : .success
    }

    func verifyTwoFactor(code: String) async throws {
        let req = request("/api/auth/login-2fa", method: "POST", json: ["code": code])
        let (data, resp) = try await send(req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw parseError(data, status: status) }
    }

    /// Trade the one-time code from darkgpt://auth for a real session cookie (OAuth via SFAuthenticationSession).
    func exchangeMobileCode(code: String, verifier: String) async throws {
        let req = request("/api/mobile/exchange", method: "POST", json: ["code": code, "verifier": verifier])
        let (data, resp) = try await send(req)
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw parseError(data, status: status) }
    }

    func logout() async {
        _ = try? await send(request("/api/logout", method: "POST", json: [:]))
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies where cookie.domain.contains("darkgpt") { HTTPCookieStorage.shared.deleteCookie(cookie) }
        }
    }

    func me() async throws -> UserProfile {
        let (data, resp) = try await send(request("/api/me"))
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw parseError(data, status: status) }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.server("Réponse invalide.", status)
        }
        return UserProfile(json: obj)
    }

    func models() async throws -> [AIModel] {
        let (data, resp) = try await send(request("/api/models"))
        let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw parseError(data, status: status) }
        let arr = (try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
        return arr.compactMap { AIModel(json: $0) }
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do { return try await session.data(for: request) }
        catch { throw APIError.network("Impossible de joindre DarkGPT. Vérifie ta connexion.") }
    }

    // MARK: - Streamed chat (newline-delimited JSON)

    func streamChat(message: String,
                    history: [ChatMessage],
                    modelSlug: String,
                    conversationId: String,
                    webSearch: Bool,
                    thinking: Bool,
                    image: (base64: String, mediaType: String)?) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                var body: [String: Any] = [
                    "conversationId": conversationId,
                    "message": message,
                    "messages": history.map { ["role": $0.role.rawValue, "content": $0.content] },
                    "model": modelSlug,
                    "web_search": webSearch,
                    "thinking": thinking,
                    "stream": true
                ]
                if let image {
                    body["imageBase64"] = image.base64
                    body["imageMediaType"] = image.mediaType
                }
                var req = request("/api/chat", method: "POST", json: body)
                req.setValue("application/x-ndjson", forHTTPHeaderField: "Accept")
                do {
                    let (bytes, resp) = try await session.bytes(for: req)
                    let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
                    guard status == 200 else {
                        if status == 401 { throw APIError.unauthorized }
                        var collected = Data()
                        for try await b in bytes { collected.append(b) }
                        throw parseError(collected, status: status)
                    }
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = obj["type"] as? String else { continue }
                        switch type {
                        case "delta":
                            if let d = obj["delta"] as? String { continuation.yield(.text(d)) }
                        case "status":
                            if let t = obj["text"] as? String { continuation.yield(.status(t)) }
                        case "done":
                            let counts = obj["new_counts"] as? [String: Any]
                            continuation.yield(.finished(content: obj["content"] as? String, gems: numberValue(counts?["gems"])))
                        case "error":
                            continuation.yield(.failed((obj["error"] as? String) ?? "Erreur.", gems: numberValue(obj["gems_current"])))
                        default: break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
