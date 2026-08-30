import AppKit

/// 2차 폴백: 합성 ⌘C + 클립보드 복원. PopClip 같은 앱들이 쓰는 표준 우회로.
/// 어디서든 동작하지만 사용자의 클립보드를 건드리므로 **반드시 원복**한다.
///
/// 주의: ⌘C를 합성하는 시점에 Shift가 눌려 있으면 ⇧⌘C가 되어 엉뚱한 메뉴가 뜬다.
/// 트리거는 항상 Shift up 이후에 발동하고(`ShiftDoubleTapRecognizer`), 여기서 20ms 더 기다린다.
struct PasteboardSelectionReader: SelectionReading {
    var settleDelay: UInt32 = 20_000        // µs — Shift가 완전히 떼어지길 기다린다
    var pollInterval: UInt32 = 30_000       // µs
    var timeout: TimeInterval = 0.2

    func readSelection() -> String? {
        let pasteboard = NSPasteboard.general
        let backup = snapshot(of: pasteboard)
        let before = pasteboard.changeCount

        usleep(settleDelay)
        postCommandC()

        var text: String?
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if pasteboard.changeCount != before {
                text = pasteboard.string(forType: .string)
                break
            }
            usleep(pollInterval)
        }

        restore(backup, to: pasteboard)
        return text?.isEmpty == false ? text : nil
    }

    // MARK: -

    private func snapshot(of pasteboard: NSPasteboard) -> [[NSPasteboard.PasteboardType: Data]] {
        pasteboard.pasteboardItems?.map { item in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        } ?? []
    }

    /// 원복에 실패하더라도 캡처한 텍스트는 이미 손에 있다 — 여기서 던지지 않는다.
    private func restore(_ backup: [[NSPasteboard.PasteboardType: Data]], to pasteboard: NSPasteboard) {
        guard !backup.isEmpty else { return }
        pasteboard.clearContents()
        let items = backup.map { entry -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in entry { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(items)
    }

    private func postCommandC() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyC: CGKeyCode = 0x08
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
