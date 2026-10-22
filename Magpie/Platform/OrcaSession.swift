import Foundation

/// Orca(터미널 워크스페이스 앱)는 창 제목이 늘 "Orca"고, 어느 탭이 화면에 있는지도 CLI·AX로 알 수 없다.
/// 대신 캡처한 텍스트로 `orca search`(에이전트 세션 전문 검색)를 돌려, 그 텍스트가 나온 Claude Code 세션의 제목을 쓴다.
enum OrcaSession {
    static let bundleID = "com.stablyai.orca"

    /// CLI 호출에 0.2초쯤, `--fresh`면 색인 갱신을 최대 5초 기다리므로 메인 스레드 밖에서 돈다.
    static func title(containing text: String) async -> String? {
        guard let query = query(for: text) else { return nil }
        return await Task.detached { title(fromSearchJSON: search(query)) }.value
    }

    /// 첫 줄만, 너무 길면 앞부분만 검색어로 쓴다.
    // ponytail: 짧고 흔한 문장("네")은 엉뚱한 세션에 맞을 수 있다. 오매칭이 보이면 최소 길이나 점수 하한을 둔다.
    static func query(for text: String) -> String? {
        // 표준입력 한 줄로 넘기므로 줄바꿈이 없어야 한다(첫 줄만 쓰는 이유이기도 하다).
        let line = text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty }
        return line.map { String($0.prefix(150)) }
    }

    /// `orca search --json` 출력에서 가장 관련도 높은 세션의 제목.
    static func title(fromSearchJSON data: Data?) -> String? {
        guard let data,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let result = root["result"] as? [String: Any],
              let hit = (result["hits"] as? [[String: Any]])?.first,
              let title = hit["title"] as? String
        else { return nil }
        return CaptureSource.cleanTitle(title, appName: "Orca")
    }

    private static func search(_ query: String) -> Data? {
        let since = Date().addingTimeInterval(-3 * 24 * 3600).ISO8601Format()
        // 검색어는 표준입력으로 넘긴다. Process는 인자·환경변수의 한글을 NFD(자모 분해)로 바꿔 넘겨서
        // NFC로 색인된 세션과 맞지 않는다(인자로 넘기면 결과가 항상 비었다).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "IFS= read -r q; exec orca search \"$q\" --scope conversation --since \(since) --limit 1 --fresh --json"]
        // 메뉴바 앱은 로그인 셸의 PATH를 물려받지 않는다.
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/usr/local/bin:/opt/homebrew/bin:" + (environment["PATH"] ?? "/usr/bin:/bin")
        process.environment = environment
        let pipe = Pipe()
        let input = Pipe()
        process.standardOutput = pipe
        process.standardInput = input
        process.standardError = FileHandle.nullDevice

        do { try process.run() } catch { return nil }
        input.fileHandleForWriting.write(Data((query + "\n").utf8))
        try? input.fileHandleForWriting.close()
        DispatchQueue.global().asyncAfter(deadline: .now() + 8) {
            if process.isRunning { process.terminate() }
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}
