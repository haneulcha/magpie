import AppKit
import SwiftUI

/// 화면 우상단에 0.8초 떴다 사라지는 알림.
///
/// `MenuBarExtra`로는 만들 수 없다(패널이 닫혀 있으면 뷰 자체가 없음).
/// 별도 `NSPanel`을 쓰되 **포커스를 절대 뺏지 않는다** — `.nonactivatingPanel` + 마우스 이벤트 무시.
@MainActor
final class CaptureHUD {
    static let shared = CaptureHUD()

    enum Message {
        case captured
        case nothingSelected
        case secureInput

        var text: String {
            switch self {
            case .captured: "Captured ↑"
            case .nothingSelected: "선택된 텍스트 없음"
            case .secureInput: "보안 입력 중 — 캡처할 수 없음"
            }
        }

        var symbol: String {
            switch self {
            case .captured: "tray.and.arrow.down.fill"
            case .nothingSelected: "text.cursor"
            case .secureInput: "lock.fill"
            }
        }
    }

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?

    private let visibleDuration: Duration = .milliseconds(800)
    private let fadeDuration: TimeInterval = 0.18

    func show(_ message: Message) {
        let panel = panel ?? makePanel()
        self.panel = panel

        panel.contentView = NSHostingView(rootView: HUDView(message: message))
        panel.setContentSize(NSSize(width: 190, height: 40))
        reposition(panel)

        panel.alphaValue = 1
        panel.orderFrontRegardless()

        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: self?.visibleDuration ?? .milliseconds(800))
            guard !Task.isCancelled else { return }
            self?.fadeOut()
        }
    }

    // MARK: -

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 190, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        return panel
    }

    private func reposition(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.maxX - size.width - 16,
            y: frame.maxY - size.height - 16
        ))
    }

    private func fadeOut() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            panel.animator().alphaValue = 0
        } completionHandler: { [weak panel] in
            MainActor.assumeIsolated { panel?.orderOut(nil) }
        }
    }
}

private struct HUDView: View {
    let message: CaptureHUD.Message

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: message.symbol)
            Text(message.text)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 10))
    }
}
