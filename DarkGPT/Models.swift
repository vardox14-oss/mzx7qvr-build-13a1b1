import Foundation
import Security

struct UserProfile: Equatable {
    var name: String
    var email: String
    var plan: String
    var gems: Double
    var avatar: URL?

    init(json: [String: Any]) {
        name = (json["username"] as? String) ?? (json["name"] as? String) ?? "Utilisateur"
        email = (json["email"] as? String) ?? ""
        plan = ((json["plan"] as? String) ?? "free").lowercased()
        gems = numberValue(json["gems"]) ?? 0
        if let raw = json["avatar"] as? String, !raw.isEmpty {
            avatar = URL(string: raw, relativeTo: APIClient.baseURL)?.absoluteURL
        }
    }

    var planLabel: String {
        switch plan {
        case "basic", "simple": return "Basic"
        case "gold": return "Gold"
        case "platinum", "full": return "Platinum"
        case "diamond", "enterprise", "entreprise": return "Diamond"
        default: return "Gratuit"
        }
    }
}

enum Plans {
    static func rank(_ plan: String) -> Int {
        switch plan.lowercased() {
        case "basic", "simple": return 1
        case "gold": return 2
        case "platinum", "full": return 3
        case "diamond", "enterprise", "entreprise": return 4
        default: return 0
        }
    }
    static func label(_ plan: String) -> String {
        switch plan.lowercased() {
        case "basic", "simple": return "Basic"
        case "gold": return "Gold"
        case "platinum", "full": return "Platinum"
        case "diamond", "enterprise", "entreprise": return "Diamond"
        default: return "Gratuit"
        }
    }
}

struct AIModel: Identifiable, Hashable {
    let slug: String
    let name: String
    let summary: String
    let provider: String
    let gemCost: Int
    let minPlan: String
    let logo: URL?
    let category: String
    let categorySort: Int
    let sortOrder: Int
    let thinkingType: String
    let thinkingCost: Int

    var id: String { slug }
    var hasThinkingToggle: Bool { thinkingType == "bouton" }

    init?(json: [String: Any]) {
        guard let slug = json["slug"] as? String, !slug.isEmpty else { return nil }
        self.slug = slug
        name = (json["name"] as? String) ?? slug
        summary = (json["description"] as? String) ?? ""
        provider = ((json["provider"] as? String) ?? "").lowercased()
        gemCost = Int(numberValue(json["gem_cost"]) ?? 0)
        var plan = ((json["min_plan"] as? String) ?? "free").lowercased()
        if plan == "free" && slug.lowercased().contains("claude") { plan = "gold" }
        minPlan = plan
        if let raw = json["logo_url"] as? String, !raw.isEmpty {
            logo = URL(string: raw, relativeTo: APIClient.baseURL)?.absoluteURL
        } else {
            logo = nil
        }
        category = (json["category_name"] as? String) ?? "Généralistes"
        categorySort = Int(numberValue(json["category_sort_order"]) ?? 999)
        sortOrder = Int(numberValue(json["sort_order"]) ?? 0)
        let thinking = json["thinking"] as? [String: Any]
        thinkingType = ((thinking?["type"] as? String) ?? "none").lowercased()
        thinkingCost = Int(numberValue(thinking?["cost"]) ?? 0)
    }

    /// Image, video, document and OSINT tools live on the website, not in the chat.
    var isChatModel: Bool {
        let s = slug.lowercased()
        if provider == "photos-videos" || provider == "osint" { return false }
        return !(s.contains("dreamgpt") || s.contains("docgpt") || s.contains("osint"))
    }

    func isUnlocked(for plan: String) -> Bool {
        minPlan == "free" || Plans.rank(plan) >= Plans.rank(minPlan)
    }
}

enum Role: String, Codable { case user, assistant }

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: Role
    var content: String
    var model: String?
    var image: Data?
    var date = Date()
    var isError = false
}

struct Conversation: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var model: String
    var updated: Date
    var pinned: Bool = false
    var projectId: UUID? = nil
    var messages: [ChatMessage] = []

    static func newID() -> String {
        var bytes = [UInt8](repeating: 0, count: 8)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return "conv_" + bytes.map { String(format: "%02x", $0) }.joined()
    }
}

func numberValue(_ any: Any?) -> Double? {
    if let n = any as? NSNumber { return n.doubleValue }
    if let s = any as? String { return Double(s) }
    return nil
}
