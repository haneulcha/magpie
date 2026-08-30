import AppKit

/// Shift 더블탭 인식기.
///
/// `NSEvent.addGlobalMonitorForEvents`(읽기 전용, 접근성 권한만 필요)를 쓴다.
/// `CGEvent.tapCreate`는 이벤트를 삼킬 수 있어 더 강력하지만 Input Monitoring 권한이 추가로
/// 필요하고, 우린 Shift를 소비할 필요가 없다.
///
/// 오탐 방지가 이 인식기의 90%다. 대문자를 빠르게 치면 `⇧↓ A ⇧↑ ⇧↓ B ⇧↑`가 나오므로
/// "깨끗한 탭" 3조건(오염 없음 / 250ms 미만 / 다른 modifier 없음)을 모두 만족해야 1탭으로 센다.
@MainActor
final class ShiftDoubleTapRecognizer: CaptureTriggering {
    var onTrigger: ((ShiftSide) -> Void)?

    private let tapWindow: TimeInterval = 0.35   // 두 탭 사이 최대 간격
    private let maxHold: TimeInterval = 0.25     // 한 탭의 최대 누름 시간

    // NX_DEVICE[LR]SHIFTKEYMASK — 좌/우 구분은 keyCode가 아니라 device-dependent 비트로 본다.
    private let leftShiftBit: UInt = 0x02
    private let rightShiftBit: UInt = 0x04

    private var monitors: [Any] = []
    private var downAt: Date?
    private var downSide: ShiftSide?
    private var contaminated = false
    private var lastTap: (side: ShiftSide, at: Date)?

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard !isRunning else { return }

        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] event in
            self?.handleFlags(event)
        }) {
            monitors.append(monitor)
        }
        // 다른 입력이 끼어들면 이번 Shift 보유 구간은 무효.
        if let monitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown],
            handler: { [weak self] _ in self?.contaminated = true }
        ) {
            monitors.append(monitor)
        }
    }

    func stop() {
        for monitor in monitors { NSEvent.removeMonitor(monitor) }
        monitors = []
        reset()
        lastTap = nil
    }

    // MARK: -

    private func handleFlags(_ event: NSEvent) {
        let raw = event.modifierFlags.rawValue
        let side: ShiftSide? = (raw & leftShiftBit) != 0 ? .left
                             : (raw & rightShiftBit) != 0 ? .right
                             : nil
        let hasOtherModifiers = !event.modifierFlags
            .intersection([.command, .option, .control, .function])
            .isEmpty

        if let side {                                   // Shift down
            downAt = hasOtherModifiers ? nil : Date()
            downSide = side
            contaminated = hasOtherModifiers
        } else {                                        // Shift up
            defer { reset() }
            guard !contaminated,
                  let downAt, let downSide,
                  Date().timeIntervalSince(downAt) < maxHold
            else { return }
            registerTap(downSide)
        }
    }

    private func registerTap(_ side: ShiftSide) {
        let now = Date()
        if let last = lastTap, last.side == side, now.timeIntervalSince(last.at) < tapWindow {
            lastTap = nil
            onTrigger?(side)                            // 항상 Shift up 이후에 발동한다
        } else {
            lastTap = (side, now)
        }
    }

    private func reset() {
        downAt = nil
        downSide = nil
        contaminated = false
    }
}
