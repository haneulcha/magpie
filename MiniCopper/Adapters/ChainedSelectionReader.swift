import Foundation

/// 앞에서부터 시도해 처음 성공한 결과를 쓴다.
/// 폴백(클립보드 우회)은 AX가 실패했을 때만 돈다 — 사용자 클립보드를 건드리는 비용이 있으므로.
struct ChainedSelectionReader: SelectionReading {
    private let readers: [any SelectionReading]

    init(_ readers: [any SelectionReading]) {
        self.readers = readers
    }

    func readSelection() -> String? {
        for reader in readers {
            if let text = reader.readSelection() { return text }
        }
        return nil
    }
}
