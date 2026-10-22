import Foundation

/// 캡처가 일어난 앱. `url`은 v2(출처 역참조)용 자리.
struct CaptureSource: Codable, Hashable, Sendable {
    var appName: String     // "Safari"
    var bundleID: String    // "com.apple.Safari"
    var title: String?      // 앞 창의 제목. 브라우저에선 페이지 제목
    var url: String?        // v2

    init(appName: String, bundleID: String, title: String? = nil, url: String? = nil) {
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
        self.url = url
    }

    /// 창 제목을 저장할 수 있는 형태로 다듬는다.
    /// "페이지 - Chrome - 프로필" → "페이지". Chrome은 앱 이름("Google Chrome")의 마지막 단어만 붙이므로 그것도 본다.
    /// 메타 주석을 깨는 `"`와 `-->`는 바꾼다.
    static func cleanTitle(_ raw: String?, appName: String) -> String? {
        guard var title = raw?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let names = Set([appName, appName.split(separator: " ").last.map(String.init) ?? appName])
        for name in names {
            for separator in [" - ", " — "] {
                if let range = title.range(of: separator + name, options: .backwards) {
                    title = String(title[..<range.lowerBound])
                }
            }
        }
        title = title
            .replacingOccurrences(of: "\"", with: "'")
            .replacingOccurrences(of: "-->", with: "->")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        return title.isEmpty || title == appName ? nil : title
    }
}
