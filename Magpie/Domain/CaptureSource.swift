import Foundation

/// 캡처가 일어난 앱. `url`은 v2(출처 역참조)용 자리.
struct CaptureSource: Codable, Hashable, Sendable {
    var appName: String     // "Safari"
    var bundleID: String    // "com.apple.Safari"
    var url: String?        // v2

    init(appName: String, bundleID: String, url: String? = nil) {
        self.appName = appName
        self.bundleID = bundleID
        self.url = url
    }
}
