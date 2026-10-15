import Foundation
import Observation

/// 단일 진실 원천. 파일이 아니라 여기 있는 배열이 진짜다.
/// 파일 쓰기는 debounce(300ms) + atomic write — 빠른 연속 캡처에서 파일이 깨지지 않게.
@MainActor
@Observable
final class CaptureStore {
    private(set) var captures: [Capture] = []
    /// 마지막 저장이 실패했다면 그 에러. 패널에서 조용히 죽지 않도록 노출한다.
    private(set) var lastSaveError: String?

    private let persistence: NotePersisting
    private let saveDebounce: Duration
    private var pendingSave: Task<Void, Never>?

    init(persistence: NotePersisting, saveDebounce: Duration = .milliseconds(300)) {
        self.persistence = persistence
        self.saveDebounce = saveDebounce
    }

    /// 앱 시작 시 1회. 실패하면 빈 목록으로 시작하되 파일은 건드리지 않는다.
    func loadFromDisk() {
        do {
            captures = try persistence.load()
        } catch {
            lastSaveError = "노트를 읽지 못했습니다: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func append(_ text: String, from source: CaptureSource?) -> Capture? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let capture = Capture(text: trimmed, source: source)
        captures.append(capture)
        scheduleSave()
        return capture
    }

    func delete(_ capture: Capture) {
        captures.removeAll { $0.id == capture.id }
        scheduleSave()
    }

    func setTags(_ tags: [String], for capture: Capture) {
        guard let index = captures.firstIndex(where: { $0.id == capture.id }) else { return }
        captures[index].tags = tags
        scheduleSave()
    }

    func deleteAll() {
        captures.removeAll()
        scheduleSave()
    }

    /// `Copy all (⌘C)`이 클립보드에 넣는 내용. 필터가 걸려 있으면 보이는 것만 넘어온다.
    static func plainTextDump(_ captures: [Capture]) -> String {
        captures.map(\.text).joined(separator: "\n\n")
    }

    /// 앱 종료 직전 등, 대기 중인 쓰기를 즉시 반영해야 할 때.
    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        writeNow()
    }

    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [saveDebounce] in
            try? await Task.sleep(for: saveDebounce)
            guard !Task.isCancelled else { return }
            writeNow()
        }
    }

    private func writeNow() {
        do {
            try persistence.save(captures)
            lastSaveError = nil
        } catch {
            lastSaveError = "저장 실패: \(error.localizedDescription)"
        }
    }
}
