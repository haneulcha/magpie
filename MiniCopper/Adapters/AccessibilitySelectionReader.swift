import ApplicationServices

/// 1차 전략: Accessibility API. 부작용이 없고 빠르지만 앱마다 지원 편차가 크다
/// (Chrome/Electron 계열에서 빈 값이 흔함 → 폴백 체인이 받는다).
struct AccessibilitySelectionReader: SelectionReading {
    /// 응답 없는 앱을 물으면 UI 전체가 멈춘다. 타임아웃은 선택이 아니라 필수.
    var messagingTimeout: Float = 0.25

    func readSelection() -> String? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, messagingTimeout)

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused, CFGetTypeID(element) == AXUIElementGetTypeID()
        else { return nil }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
                element as! AXUIElement,
                kAXSelectedTextAttribute as CFString,
                &value
              ) == .success,
              let text = value as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }

        return text
    }
}
