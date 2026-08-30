import Foundation

/// 노트 파일 입출력. 진실 원천은 파일이 아니라 메모리의 `CaptureStore`이고,
/// 이 포트는 그 스냅샷을 통째로 읽고 쓴다.
@MainActor
protocol NotePersisting {
    func load() throws -> [Capture]
    func save(_ captures: [Capture]) throws
}
