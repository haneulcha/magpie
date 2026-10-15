import Foundation

/// 캡처 한 건. 순수 값 타입 — AppKit도 파일 시스템도 모른다.
struct Capture: Identifiable, Codable, Hashable, Sendable {
    /// 런타임 식별자. 파일에는 기록되지 않는다.
    let id: UUID
    /// 노트 파일에 기록되는 짧은 식별자(`<!--mc id=8F2A-->`).
    /// 사람이 파일을 직접 편집해도 살아남아야 하므로 UUID와 별도로 둔다.
    let shortID: String
    var text: String
    var createdAt: Date
    var source: CaptureSource?
    /// MVP에선 항상 false. 체크박스(v2)를 위해 포맷에 자리만 미리 둔다.
    var isDone: Bool
    /// `#` 없이 저장. 파일에는 메타 주석 뒤에 `#태그`로 쓴다(Obsidian이 태그로 인식).
    var tags: [String]

    init(
        id: UUID = UUID(),
        shortID: String = Capture.makeShortID(),
        text: String,
        createdAt: Date = Date(),
        source: CaptureSource? = nil,
        isDone: Bool = false,
        tags: [String] = []
    ) {
        self.id = id
        self.shortID = shortID
        self.text = text
        self.createdAt = createdAt
        self.source = source
        self.isDone = isDone
        self.tags = tags
    }

    static func makeShortID() -> String {
        String(format: "%04X", UInt16.random(in: 0...UInt16.max))
    }

    /// "#회사, 읽을거리 #회사" → ["회사", "읽을거리"]. 태그 안의 공백은 허용하지 않는다.
    static func parseTags(_ input: String) -> [String] {
        var seen = Set<String>()
        return input
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "#" })
            .map(String.init)
            .filter { seen.insert($0).inserted }
    }

    /// 패널 목록에서 보여줄 한 줄 요약.
    var previewLine: String {
        text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespaces) ?? text
    }
}
