import Foundation

/// 단일 마크다운 파일 어댑터.
///
/// ```markdown
/// ## 2026-08-30
///
/// - [ ] rate limiting 미들웨어 예제 <!--mc id=8F2A src="Safari" bid=com.apple.Safari at=14:22-->
/// ```
///
/// 메타데이터는 HTML 주석에 숨긴다 → 다른 마크다운 에디터에서 열어도 깨끗하다.
/// 사람이 직접 편집한 줄(= 파싱 실패한 줄)은 **버리지 않고** 원래 날짜 섹션에 그대로 되돌려 쓴다.
@MainActor
final class MarkdownNoteStore: NotePersisting {
    private let url: URL

    /// 파싱하지 못한 줄들. 날짜 섹션 키("2026-08-30")별로 보존하고, "" 키는 첫 헤딩 이전의 서문.
    private var preservedLines: [String: [String]] = [:]
    private var knownDayOrder: [String] = []

    init(url: URL) {
        self.url = url
    }

    // MARK: - NotePersisting

    func load() throws -> [Capture] {
        preservedLines = [:]
        knownDayOrder = []

        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let raw = try String(contentsOf: url, encoding: .utf8)
        return parse(raw)
    }

    func save(_ captures: [Capture]) throws {
        let text = serialize(captures)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(text.utf8).write(to: url, options: .atomic)
    }

    // MARK: - Parsing

    private func parse(_ raw: String) -> [Capture] {
        var captures: [Capture] = []
        var currentDay = ""
        var openBullet: [String] = []

        func rememberDay(_ day: String) {
            if !knownDayOrder.contains(day) { knownDayOrder.append(day) }
        }

        func flushOpenBulletAsExtras() {
            guard !openBullet.isEmpty else { return }
            preservedLines[currentDay, default: []].append(contentsOf: openBullet)
            openBullet = []
        }

        for line in raw.components(separatedBy: .newlines) {
            if let day = Self.dayHeading(in: line) {
                flushOpenBulletAsExtras()
                currentDay = day
                rememberDay(day)
                continue
            }

            let isNewBullet = Self.bulletPrefix(of: line) != nil
            let isContinuation = !openBullet.isEmpty
                && (line.hasPrefix(" ") || line.hasPrefix("\t"))
                && !line.trimmingCharacters(in: .whitespaces).isEmpty

            if isNewBullet {
                flushOpenBulletAsExtras()
                openBullet = [line]
            } else if isContinuation {
                openBullet.append(line)
            } else {
                flushOpenBulletAsExtras()
                if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    preservedLines[currentDay, default: []].append(line)
                }
                continue
            }

            // 메타 주석을 만나면 한 건 완성.
            if openBullet.last?.contains("<!--mc ") == true {
                if let capture = Self.makeCapture(from: openBullet, day: currentDay) {
                    captures.append(capture)
                    openBullet = []
                } else {
                    flushOpenBulletAsExtras()
                }
            }
        }
        flushOpenBulletAsExtras()

        return captures.sorted { $0.createdAt < $1.createdAt }
    }

    private static func dayHeading(in line: String) -> String? {
        guard line.hasPrefix("## ") else { return nil }
        let value = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        return Self.dayFormatter.date(from: value) == nil ? nil : value
    }

    private static func bulletPrefix(of line: String) -> String? {
        for prefix in ["- [ ] ", "- [x] ", "- [X] "] where line.hasPrefix(prefix) {
            return prefix
        }
        return nil
    }

    private static func makeCapture(from lines: [String], day: String) -> Capture? {
        guard let first = lines.first, let prefix = bulletPrefix(of: first) else { return nil }
        guard let commentStart = lines.last?.range(of: "<!--mc "),
              let commentEnd = lines.last?.range(of: "-->", range: commentStart.lowerBound..<lines.last!.endIndex)
        else { return nil }

        let last = lines.last!
        let meta = parseMeta(String(last[commentStart.upperBound..<commentEnd.lowerBound]))
        guard let shortID = meta["id"] else { return nil }

        var body = lines
        body[body.count - 1] = String(last[last.startIndex..<commentStart.lowerBound])
        body[0] = String(body[0].dropFirst(prefix.count))

        let text = body
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        let source = meta["src"].map {
            CaptureSource(appName: $0, bundleID: meta["bid"] ?? "")
        }

        return Capture(
            shortID: shortID,
            text: text,
            createdAt: timestamp(day: day, time: meta["at"]),
            source: source,
            isDone: prefix.lowercased() == "- [x] "
        )
    }

    /// `id=8F2A src="Google Chrome" at=14:22` → 딕셔너리. 값의 따옴표는 벗긴다.
    private static func parseMeta(_ body: String) -> [String: String] {
        var result: [String: String] = [:]
        var key = ""
        var value = ""
        var readingKey = true
        var quoted = false

        func commit() {
            if !key.isEmpty { result[key] = value }
            key = ""; value = ""; readingKey = true; quoted = false
        }

        for character in body {
            if readingKey {
                if character == "=" { readingKey = false }
                else if character == " " { commit() }
                else { key.append(character) }
            } else if character == "\"" {
                quoted.toggle()
            } else if character == " " && !quoted {
                commit()
            } else {
                value.append(character)
            }
        }
        commit()
        return result
    }

    private static func timestamp(day: String, time: String?) -> Date {
        let stamp = "\(day) \(time ?? "00:00")"
        return timestampFormatter.date(from: stamp)
            ?? dayFormatter.date(from: day)
            ?? Date()
    }

    // MARK: - Serializing

    private func serialize(_ captures: [Capture]) -> String {
        var byDay: [String: [Capture]] = [:]
        for capture in captures.sorted(by: { $0.createdAt < $1.createdAt }) {
            byDay[Self.dayFormatter.string(from: capture.createdAt), default: []].append(capture)
        }

        // 파일에 있던 날짜 순서를 유지하고, 새 날짜는 뒤에 붙인다(append-only 로그).
        var days = knownDayOrder.filter { byDay[$0] != nil || preservedLines[$0] != nil }
        for day in byDay.keys.sorted() where !days.contains(day) { days.append(day) }

        var out: [String] = []
        if let preamble = preservedLines[""], !preamble.isEmpty {
            out.append(contentsOf: preamble)
            out.append("")
        }
        for day in days {
            out.append("## \(day)")
            out.append("")
            out.append(contentsOf: (byDay[day] ?? []).map(Self.line(for:)))
            out.append(contentsOf: preservedLines[day] ?? [])
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    private static func line(for capture: Capture) -> String {
        let indent = String(repeating: " ", count: 6)
        let body = capture.text
            .components(separatedBy: .newlines)
            .enumerated()
            .map { $0.offset == 0 ? $0.element : indent + $0.element }
            .joined(separator: "\n")

        var meta = "id=\(capture.shortID)"
        if let source = capture.source {
            meta += " src=\"\(source.appName)\""
            if !source.bundleID.isEmpty { meta += " bid=\(source.bundleID)" }
        }
        meta += " at=\(timeFormatter.string(from: capture.createdAt))"

        return "- [\(capture.isDone ? "x" : " ")] \(body) <!--mc \(meta)-->"
    }

    // MARK: - Formatters

    private static let dayFormatter = fixedFormatter("yyyy-MM-dd")
    private static let timeFormatter = fixedFormatter("HH:mm")
    private static let timestampFormatter = fixedFormatter("yyyy-MM-dd HH:mm")

    private static func fixedFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}
