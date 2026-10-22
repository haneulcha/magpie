import AppKit
import Observation

/// 조립은 여기서 한 번만. 각 층은 아래 층의 프로토콜만 알고 구현을 모른다.
@MainActor
@Observable
final class AppEnvironment {
    static let shared = AppEnvironment()

    let store: CaptureStore
    private let reader: any SelectionReading
    private let trigger: any CaptureTriggering

    private(set) var isTrusted = PermissionGate.isTrusted
    private var permissionPoll: Task<Void, Never>?

    init(
        store: CaptureStore = CaptureStore(persistence: MarkdownNoteStore(url: NoteLocation.current)),
        reader: any SelectionReading = ChainedSelectionReader([
            AccessibilitySelectionReader(),
            PasteboardSelectionReader(),      // AX 실패 시 합성 ⌘C
        ]),
        trigger: any CaptureTriggering = ShiftDoubleTapRecognizer()
    ) {
        self.store = store
        self.reader = reader
        self.trigger = trigger
    }

    func start() {
        store.loadFromDisk()

        trigger.onTrigger = { [weak self] _ in
            self?.capture()
        }

        if isTrusted {
            trigger.start()
        } else {
            PermissionGate.requestIfNeeded()
            startPermissionPolling()
        }
    }

    func stop() {
        permissionPoll?.cancel()
        permissionPoll = nil
        trigger.stop()
        store.flush()
    }

    /// 캡처 한 번. 패널은 절대 열리지 않고 포커스도 뺏지 않는다 — HUD만 알린다.
    func capture() {
        guard let text = reader.readSelection() else {
            CaptureHUD.shared.show(PermissionGate.isSecureInputEnabled ? .secureInput : .nothingSelected)
            return
        }
        guard let capture = store.append(text, from: .frontmost()) else {
            CaptureHUD.shared.show(.nothingSelected)
            return
        }
        CaptureHUD.shared.show(.captured)

        if capture.source?.bundleID == OrcaSession.bundleID {
            Task {
                guard let title = await OrcaSession.title(containing: capture.text) else { return }
                store.setSourceTitle(title, for: capture.id)
            }
        }
    }

    func copyAllToPasteboard(_ captures: [Capture]) {
        let dump = CaptureStore.plainTextDump(captures)
        guard !dump.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(dump, forType: .string)
    }

    // MARK: -

    /// AX 권한 변화에는 알림이 없다. 권한이 없는 동안만 가볍게 폴링한다.
    private func startPermissionPolling() {
        permissionPoll?.cancel()
        permissionPoll = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                guard PermissionGate.isTrusted else { continue }
                self.isTrusted = true
                self.trigger.start()
                return
            }
        }
    }
}
