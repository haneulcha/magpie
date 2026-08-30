import Foundation

/// 노트 파일 위치. 지금은 Application Support 고정이지만,
/// 나중에 Obsidian/iCloud 폴더로 바꿀 수 있도록 UserDefaults에 URL 하나만 둔다.
enum NoteLocation {
    private static let defaultsKey = "noteURL"

    static var current: URL {
        get {
            if let path = UserDefaults.standard.string(forKey: defaultsKey), !path.isEmpty {
                return URL(fileURLWithPath: path)
            }
            return fallback
        }
        set { UserDefaults.standard.set(newValue.path, forKey: defaultsKey) }
    }

    static var fallback: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? URL(fileURLWithPath: NSHomeDirectory())
        return base
            .appendingPathComponent("MiniCopper", isDirectory: true)
            .appendingPathComponent("notes.md")
    }
}
