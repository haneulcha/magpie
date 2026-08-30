import AppKit

extension CaptureSource {
    /// 캡처 시점의 프론트 앱. `url`(출처 역참조)은 v2.
    static func frontmost() -> CaptureSource? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return CaptureSource(
            appName: app.localizedName ?? "Unknown",
            bundleID: app.bundleIdentifier ?? ""
        )
    }
}
