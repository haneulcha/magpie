import AppKit
import ApplicationServices

extension CaptureSource {
    /// 캡처 시점의 프론트 앱. `url`(출처 역참조)은 v2.
    static func frontmost() -> CaptureSource? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appName = app.localizedName ?? "Unknown"
        return CaptureSource(
            appName: appName,
            bundleID: app.bundleIdentifier ?? "",
            title: cleanTitle(focusedWindowTitle(pid: app.processIdentifier), appName: appName),
            url: app.bundleIdentifier.flatMap(browserURL(bundleID:))
        )
    }

    /// 브라우저별 "현재 탭 URL" AppleScript. 목록에 없는 앱은 URL을 묻지 않는다.
    private static let urlScripts: [String: String] = {
        let chromium = "URL of active tab of front window"
        return [
            "com.apple.Safari": "URL of front document",
            "com.google.Chrome": chromium,
            "company.thebrowser.dia": chromium,
            "company.thebrowser.Browser": chromium,     // Arc
            "com.brave.Browser": chromium,
            "com.microsoft.edgemac": chromium,
        ]
    }()

    /// 자동화 권한이 필요하다(브라우저마다 첫 1회 시스템 프롬프트). 거부하거나 응답이 없으면 nil.
    private static func browserURL(bundleID: String) -> String? {
        guard let expression = urlScripts[bundleID] else { return nil }
        let source = """
        with timeout of 1 seconds
            tell application id "\(bundleID)" to return \(expression)
        end timeout
        """
        var error: NSDictionary?
        guard let url = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue,
              url.hasPrefix("http://") || url.hasPrefix("https://") || url.hasPrefix("file://")
        else { return nil }
        return url.replacingOccurrences(of: "\"", with: "%22")
    }

    private static func focusedWindowTitle(pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)   // 응답 없는 앱에 묶이지 않게

        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &window) == .success,
              let window, CFGetTypeID(window) == AXUIElementGetTypeID()
        else { return nil }

        var title: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success
        else { return nil }
        return title as? String
    }
}
