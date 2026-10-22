import Foundation
import Testing
@testable import Magpie

struct OrcaSessionTests {
    @Test func 검색_결과_첫_세션의_제목() {
        // 실제 `orca search --json` 출력을 줄인 것.
        let json = """
        {"ok": true, "result": {"kind": "search", "hits": [
          {"agent": "claude", "sessionId": "14f4", "title": "코드 설명 요청", "cwd": "/Users/haneul/Study/magpie"},
          {"agent": "claude", "sessionId": "871f", "title": "Handoff lounge onboarding PR comments"}
        ]}}
        """
        #expect(OrcaSession.title(fromSearchJSON: Data(json.utf8)) == "코드 설명 요청")
    }

    @Test func 결과가_없거나_깨지면_nil() {
        #expect(OrcaSession.title(fromSearchJSON: Data(#"{"ok": true, "result": {"hits": []}}"#.utf8)) == nil)
        #expect(OrcaSession.title(fromSearchJSON: Data("{}".utf8)) == nil)
        #expect(OrcaSession.title(fromSearchJSON: nil) == nil)
    }

    @Test func 검색어는_첫_줄_150자() {
        #expect(OrcaSession.query(for: "\n  첫 줄  \n둘째 줄") == "첫 줄")
        #expect(OrcaSession.query(for: String(repeating: "가", count: 300))?.count == 150)
        #expect(OrcaSession.query(for: " \n ") == nil)
    }
}
