import AppKit
import ApplicationServices
import Carbon.HIToolbox

/// 필요한 권한은 **손쉬운 사용(Accessibility)** 하나뿐이다.
/// NSEvent 전역 모니터와 AX 읽기 둘 다 이걸로 커버된다.
///
/// 권한은 **코드 서명에 묶인다.** 개발 중 서명이 바뀌면 조용히 죽고 증상은 "이벤트가 안 잡힘".
/// 그때는 `tccutil reset Accessibility com.haneul.Magpie` 후 다시 허용.
enum PermissionGate {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// 시스템 권한 다이얼로그를 띄운다(이미 허용돼 있으면 아무 일도 없음).
    @discardableResult
    static func requestIfNeeded() -> Bool {
        // 전역 var인 kAXTrustedCheckOptionPrompt는 Swift 6에서 concurrency-safe하지 않다.
        // 값은 고정 문자열이므로 그대로 쓴다.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    /// 비밀번호 필드가 활성인 앱(터미널 `sudo`, 1Password 등)이 앞에 있으면
    /// 전역 이벤트가 아예 오지 않는다. 버그가 아니라 정상 동작 — 안내만 한다.
    static var isSecureInputEnabled: Bool { IsSecureEventInputEnabled() }
}
