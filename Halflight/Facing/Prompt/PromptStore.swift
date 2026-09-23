import Foundation

/// Scripts live as plain text in Documents/Scripts/{uuid}.txt with a small JSON index for titles.
@MainActor @Observable
final class PromptStore {
    private struct IndexEntry: Codable {
        let id: UUID
        var title: String
        var updatedAt: Date
    }

    private(set) var scripts: [PromptScript] = []
    let directory: URL

    init(directory: URL? = nil) {
        let base = directory ?? MediaPaths.standard().scripts
        self.directory = base
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        load()
        if scripts.isEmpty { seed() }
    }

    private var indexURL: URL { directory.appendingPathComponent("index.json") }

    private func bodyURL(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).txt") }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let entries = try? JSONDecoder().decode([IndexEntry].self, from: data) else { return }
        scripts = entries.map { entry in
            let body = (try? String(contentsOf: bodyURL(entry.id), encoding: .utf8)) ?? ""
            return PromptScript(id: entry.id, title: entry.title, body: body, updatedAt: entry.updatedAt)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func seed() {
        for script in PromptScript.seeds { upsert(script) }
    }

    private func persistIndex() {
        let entries = scripts.map { IndexEntry(id: $0.id, title: $0.title, updatedAt: $0.updatedAt) }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: indexURL, options: .atomic)
        }
    }

    func script(id: UUID?) -> PromptScript? {
        guard let id else { return nil }
        return scripts.first { $0.id == id }
    }

    @discardableResult
    func upsert(_ script: PromptScript) -> PromptScript {
        var stored = script
        stored.updatedAt = .now
        try? stored.body.write(to: bodyURL(stored.id), atomically: true, encoding: .utf8)
        if let index = scripts.firstIndex(where: { $0.id == stored.id }) {
            scripts[index] = stored
        } else {
            scripts.insert(stored, at: 0)
        }
        scripts.sort { $0.updatedAt > $1.updatedAt }
        persistIndex()
        return stored
    }

    func create(title: String = String(localized: "New script"), body: String = "") -> PromptScript {
        upsert(PromptScript(title: title, body: body))
    }

    func duplicate(_ script: PromptScript) -> PromptScript {
        upsert(PromptScript(title: script.title + " " + String(localized: "copy"), body: script.body))
    }

    func delete(_ script: PromptScript) {
        scripts.removeAll { $0.id == script.id }
        try? FileManager.default.removeItem(at: bodyURL(script.id))
        persistIndex()
    }

    /// Imports the clipboard as a new script. Returns nil when the clipboard has no text.
    func importFromClipboard(text: String?) -> PromptScript? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let firstLine = text.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? String(localized: "Pasted")
        let title = String(firstLine.prefix(32))
        return upsert(PromptScript(title: title, body: text))
    }
}
