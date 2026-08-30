import Foundation
import Testing
@testable import Magpie

@MainActor
final class FakeNoteStore: NotePersisting {
    var stored: [Capture] = []
    var saveCount = 0
    var loadError: Error?

    func load() throws -> [Capture] {
        if let loadError { throw loadError }
        return stored
    }

    func save(_ captures: [Capture]) throws {
        stored = captures
        saveCount += 1
    }
}

@MainActor
struct CaptureStoreTests {
    private func makeStore() -> (CaptureStore, FakeNoteStore) {
        let fake = FakeNoteStore()
        // 테스트에서는 debounce를 0으로 — flush()로 결정적으로 확인한다.
        return (CaptureStore(persistence: fake, saveDebounce: .zero), fake)
    }

    @Test func 빈_문자열은_캡처되지_않는다() {
        let (store, _) = makeStore()
        #expect(store.append("   \n ", from: nil) == nil)
        #expect(store.captures.isEmpty)
    }

    @Test func 캡처하면_앞뒤_공백이_잘린다() {
        let (store, _) = makeStore()
        let capture = store.append("  hello  ", from: nil)
        #expect(capture?.text == "hello")
        #expect(store.captures.count == 1)
    }

    @Test func flush하면_디스크에_반영된다() {
        let (store, fake) = makeStore()
        store.append("one", from: nil)
        store.append("two", from: nil)
        store.flush()

        #expect(fake.stored.map(\.text) == ["one", "two"])
    }

    @Test func 삭제가_반영된다() {
        let (store, fake) = makeStore()
        store.append("one", from: nil)
        let second = store.append("two", from: nil)!
        store.delete(second)
        store.flush()

        #expect(fake.stored.map(\.text) == ["one"])
    }

    @Test func 로드_실패해도_죽지_않고_에러를_노출한다() {
        let fake = FakeNoteStore()
        fake.loadError = CocoaError(.fileReadCorruptFile)
        let store = CaptureStore(persistence: fake, saveDebounce: .zero)

        store.loadFromDisk()
        #expect(store.captures.isEmpty)
        #expect(store.lastSaveError != nil)
    }

    @Test func copy_all_텍스트() {
        let (store, _) = makeStore()
        store.append("a", from: nil)
        store.append("b", from: nil)
        #expect(store.plainTextDump == "a\n\nb")
    }
}
