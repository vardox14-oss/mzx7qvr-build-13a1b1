import Foundation
import SwiftUI

struct ProjectFile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var content: String
    var uploadedAt = Date()

    var sizeFormatted: String {
        let count = content.utf8.count
        if count < 1024 { return "\(count) o" }
        return String(format: "%.1f Ko", Double(count) / 1024.0)
    }
}

struct Project: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var description: String
    var icon: String = "folder.fill"
    var colorHex: String = "#E53935"
    var customInstructions: String = ""
    var files: [ProjectFile] = []
    var conversationIds: [String] = []
    var created = Date()
    var updated = Date()

    var color: Color {
        Color(hex: colorHex) ?? Theme.accent
    }

    /// Génère le bloc de contexte système à injecter dans le prompt
    var systemContextPrompt: String {
        var parts: [String] = []
        if !customInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("[Directives du projet « \(name) »] :\n\(customInstructions)")
        }
        if !files.isEmpty {
            parts.append("[Fichiers & Connaissances du projet] :")
            for f in files {
                parts.append("--- Fichier: \(f.name) ---\n\(f.content)")
            }
        }
        return parts.joined(separator: "\n\n")
    }
}

extension Color {
    init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let rgb = UInt64(str, radix: 16) else { return nil }
        self.init(
            red: Double((rgb & 0xFF0000) >> 16) / 255.0,
            green: Double((rgb & 0x00FF00) >> 8) / 255.0,
            blue: Double(rgb & 0x0000FF) / 255.0
        )
    }
}
