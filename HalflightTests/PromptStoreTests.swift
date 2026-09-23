import Foundation
import Testing
@testable import Halflight

@MainActor
struct PromptStoreTests {
    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("halflight-scripts-\(UUID().uuidString)", isDirectory: true)
    }

    @Test func seedsOnFirstRun() {
        let store = PromptStore(directory: temporaryDirectory())
        #expect(store.scripts.count == PromptScript.seeds.count)
        #expect(store.scripts.contains { $0.body.contains("thanks for watching") })
    }

    @Test func createDuplicateDeleteRoundTrip() {
        let directory = temporaryDirectory()
        let store = PromptStore(directory: directory)
        let created = store.create(title: "Test", body: "Hello")
        #expect(store.scripts.first?.id == created.id)

        let copy = store.duplicate(created)
        #expect(copy.body == "Hello")
        #expect(copy.id != created.id)

        store.delete(created)
        #expect(!store.scripts.contains { $0.id == created.id })

        let reloaded = PromptStore(directory: directory)
        #expect(reloaded.scripts.contains { $0.id == copy.id })
        #expect(reloaded.script(id: copy.id)?.body == "Hello")
    }

    @Test func clipboardImportUsesFirstLineAsTitle() {
        let store = PromptStore(directory: temporaryDirectory())
        let script = store.importFromClipboard(text: "Big opening line\nThen the rest.")
        #expect(script?.title == "Big opening line")
        #expect(store.importFromClipboard(text: "   ") == nil)
        #expect(store.importFromClipboard(text: nil) == nil)
    }
}
