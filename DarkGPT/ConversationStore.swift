import Foundation

/// Conversations are kept on the device (like the website keeps them in the browser),
/// scoped per account so switching users never mixes histories.
final class ConversationStore {
    private let defaults = UserDefaults.standard
    private var key = "dg_ios_convs_anon"

    func use(account: String) {
        let safe = account.isEmpty ? "anon" : account.lowercased()
        key = "dg_ios_convs_" + safe
    }

    func load() -> [Conversation] {
        guard let data = defaults.data(forKey: key),
              let list = try? JSONDecoder.dg.decode([Conversation].self, from: data) else { return [] }
        return list.sorted { ($0.pinned ? 1 : 0, $0.updated) > ($1.pinned ? 1 : 0, $1.updated) }
    }

    func save(_ conversations: [Conversation]) {
        let trimmed = Array(conversations.prefix(200))
        if let data = try? JSONEncoder.dg.encode(trimmed) { defaults.set(data, forKey: key) }
    }

    func clear() { defaults.removeObject(forKey: key) }
}

extension JSONDecoder {
    static let dg: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}
extension JSONEncoder {
    static let dg: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
}
