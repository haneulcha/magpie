import Foundation

/// 현재 선택된 텍스트를 읽는다. 없으면 nil.
protocol SelectionReading {
    func readSelection() -> String?
}
