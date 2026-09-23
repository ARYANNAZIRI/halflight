import Foundation

struct PromptScript: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var body: String
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, body: String, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
    }

    static let seeds: [PromptScript] = [
        PromptScript(title: String(localized: "Intro"), body: String(localized: "Hi, thanks for watching. Today I’m showing you…")),
        PromptScript(title: String(localized: "Portrait"), body: String(localized: "Look at the mark, smile, hold still.")),
        PromptScript(title: String(localized: "For you"), body: String(localized: "My name is ____ and I made this for you.")),
        PromptScript(title: String(localized: "Empty"), body: ""),
    ]
}
