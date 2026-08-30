import SwiftUI

@main
struct MagpieApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var env = AppEnvironment.shared

    var body: some Scene {
        MenuBarExtra {
            RootView()
                .environment(env)
        } label: {
            Image(systemName: "tray.and.arrow.down")
            // 패널을 안 열어도 몇 개 쌓였는지 보인다.
            if !env.store.captures.isEmpty {
                Text("\(env.store.captures.count)")
            }
        }
        .menuBarExtraStyle(.window)     // 커스텀 SwiftUI 뷰를 쓰려면 필수
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 유닛 테스트는 이 앱을 test host로 띄운다. 거기서 start()가 돌면 권한 프롬프트가 뜨고,
        // 무엇보다 TCC에 테스트 빌드의 바이너리 해시가 등록돼 실제 앱의 권한을 가로챈다.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        AppEnvironment.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppEnvironment.shared.stop()
    }
}
