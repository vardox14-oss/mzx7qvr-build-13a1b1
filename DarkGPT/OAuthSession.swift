import AuthenticationServices
import CryptoKit
import Foundation
import UIKit

/// Opens the website OAuth flow in a secure in-app browser (ASWebAuthenticationSession),
/// then exchanges the returned one-time code (+ PKCE verifier) for a session cookie.
@MainActor
final class OAuthSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = OAuthSession()
    private var current: ASWebAuthenticationSession?

    func signIn(provider: String) async throws {
        let verifier = Self.makeVerifier()
        let challenge = Self.sha256Hex(verifier)
        var comps = URLComponents(string: "https://darkgpt.chat/mobile/auth")!
        comps.queryItems = [.init(name: "provider", value: provider), .init(name: "challenge", value: challenge)]
        let startURL = comps.url!

        let callbackURL: URL = try await withCheckedThrowingContinuation { cont in
            let authSession = ASWebAuthenticationSession(url: startURL, callbackURLScheme: "darkgpt") { url, error in
                if let url { cont.resume(returning: url) }
                else if let error { cont.resume(throwing: error) }
                else { cont.resume(throwing: APIError.network("Connexion annulée.")) }
            }
            authSession.presentationContextProvider = self
            authSession.prefersEphemeralWebBrowserSession = false
            self.current = authSession
            authSession.start()
        }

        let items = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let err = items.first(where: { $0.name == "error" })?.value {
            throw APIError.server(err == "session" ? "Connexion non terminée." : "Connexion refusée.", 401)
        }
        guard let code = items.first(where: { $0.name == "code" })?.value else {
            throw APIError.network("Réponse de connexion invalide.")
        }
        try await APIClient.shared.exchangeMobileCode(code: code, verifier: verifier)
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }

    private static func makeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 48)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded()
    }

    private static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

extension Data {
    func base64URLEncoded() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
