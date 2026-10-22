import Foundation
import Testing
@testable import Magpie

@MainActor
struct MarkdownNoteStoreTests {
    private func makeTempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("MagpieTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("notes.md")
    }

    @Test func 없는_파일은_빈_목록() throws {
        let store = MarkdownNoteStore(url: makeTempURL())
        #expect(try store.load().isEmpty)
    }

    @Test func 저장했다_읽으면_그대로() throws {
        let url = makeTempURL()
        let store = MarkdownNoteStore(url: url)
        let source = CaptureSource(appName: "Safari", bundleID: "com.apple.Safari")
        let original = Capture(text: "rate limiting 미들웨어 예제", source: source)

        try store.save([original])
        let loaded = try MarkdownNoteStore(url: url).load()

        #expect(loaded.count == 1)
        #expect(loaded.first?.text == original.text)
        #expect(loaded.first?.shortID == original.shortID)
        #expect(loaded.first?.source?.appName == "Safari")
        #expect(loaded.first?.source?.bundleID == "com.apple.Safari")
    }

    @Test func 태그는_주석_뒤에_쓰고_본문의_샵은_건드리지_않는다() throws {
        let url = makeTempURL()
        let store = MarkdownNoteStore(url: url)
        let original = Capture(text: "issue #123 참고", tags: ["회사", "읽을거리"])

        try store.save([original])
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(raw.contains("--> #회사 #읽을거리"))

        let loaded = try MarkdownNoteStore(url: url).load()
        #expect(loaded.first?.text == "issue #123 참고")
        #expect(loaded.first?.tags == ["회사", "읽을거리"])
    }

    @Test func 창_제목과_URL이_왕복한다() throws {
        let url = makeTempURL()
        let store = MarkdownNoteStore(url: url)
        let source = CaptureSource(
            appName: "Google Chrome", bundleID: "com.google.Chrome",
            title: "Rate limiting 가이드", url: "https://example.com/a?b=1&c=two words"
        )

        try store.save([Capture(text: "본문", source: source)])
        let loaded = try MarkdownNoteStore(url: url).load()
        #expect(loaded.first?.source?.title == "Rate limiting 가이드")
        #expect(loaded.first?.source?.url == "https://example.com/a?b=1&c=two words")
    }

    @Test func 창_제목_다듬기() {
        #expect(CaptureSource.cleanTitle("AI는 디자인을 어떻게 바꾸고 있는가? | GeekNews - Chrome - 하늘 (nrise.net)", appName: "Google Chrome")
                == "AI는 디자인을 어떻게 바꾸고 있는가? | GeekNews")
        #expect(CaptureSource.cleanTitle("위피-라운지(채널) - NRISE - Slack", appName: "Slack") == "위피-라운지(채널) - NRISE")
        #expect(CaptureSource.cleanTitle("2026-10-01 예약 도메인 보충 - cha - Obsidian 1.13.7", appName: "Obsidian") == "2026-10-01 예약 도메인 보충 - cha")
        #expect(CaptureSource.cleanTitle("Say \"hi\" --> now", appName: "Safari") == "Say 'hi' -> now")
        #expect(CaptureSource.cleanTitle("Slack", appName: "Slack") == nil)
        #expect(CaptureSource.cleanTitle("  ", appName: "Safari") == nil)
        #expect(CaptureSource.cleanTitle(nil, appName: "Safari") == nil)
    }

    @Test func 태그_입력_파싱() {
        #expect(Capture.parseTags("#회사, 읽을거리  #회사") == ["회사", "읽을거리"])
        #expect(Capture.parseTags("  ").isEmpty)
    }

    @Test func 여러_줄_캡처도_왕복한다() throws {
        let url = makeTempURL()
        let store = MarkdownNoteStore(url: url)
        let original = Capture(text: "첫 줄\n둘째 줄", source: CaptureSource(appName: "Arc", bundleID: "company.thebrowser.Browser"))

        try store.save([original])
        let loaded = try MarkdownNoteStore(url: url).load()

        #expect(loaded.first?.text == "첫 줄\n둘째 줄")
    }

    @Test func 앱_이름의_공백이_깨지지_않는다() throws {
        let url = makeTempURL()
        try MarkdownNoteStore(url: url).save([
            Capture(text: "x", source: CaptureSource(appName: "Google Chrome", bundleID: "com.google.Chrome"))
        ])

        let loaded = try MarkdownNoteStore(url: url).load()
        #expect(loaded.first?.source?.appName == "Google Chrome")
    }

    @Test func 사람이_직접_쓴_줄은_보존된다() throws {
        let url = makeTempURL()
        let day = DateFormatter()
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        let today = day.string(from: Date())

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        ## \(today)

        - [ ] 기계가 쓴 줄 <!--mc id=8F2A src="Safari" at=09:00-->
        - 사람이 손으로 쓴 줄

        """.write(to: url, atomically: true, encoding: .utf8)

        let store = MarkdownNoteStore(url: url)
        let loaded = try store.load()
        #expect(loaded.count == 1)

        try store.save(loaded)
        let rewritten = try String(contentsOf: url, encoding: .utf8)
        #expect(rewritten.contains("사람이 손으로 쓴 줄"))
        #expect(rewritten.contains("기계가 쓴 줄"))
    }

    @Test func 체크박스_상태를_읽는다() throws {
        let url = makeTempURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        ## 2026-08-30

        - [x] 끝난 것 <!--mc id=91C3 at=14:31-->
        """.write(to: url, atomically: true, encoding: .utf8)

        let loaded = try MarkdownNoteStore(url: url).load()
        #expect(loaded.first?.isDone == true)
        #expect(loaded.first?.text == "끝난 것")
    }
}
