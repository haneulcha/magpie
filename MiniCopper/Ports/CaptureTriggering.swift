import Foundation

enum ShiftSide: String, Codable, Hashable, Sendable {
    case left, right
}

/// 전역 제스처 인식기. 구현은 전역 이벤트 탭을 쓰므로 테스트에서는 절대 못 돌린다.
/// → 상위 층은 이 프로토콜만 알고, 테스트에서는 통째로 mock 한다.
@MainActor
protocol CaptureTriggering: AnyObject {
    var onTrigger: ((ShiftSide) -> Void)? { get set }
    func start()
    func stop()
}
