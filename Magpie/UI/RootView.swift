import SwiftUI

/// 메뉴바 패널의 루트. 권한이 없으면 온보딩만 보여주고 인식기는 시작하지 않는다.
struct RootView: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Group {
            if env.isTrusted {
                CapturePanel()
            } else {
                OnboardingView()
            }
        }
        .frame(width: 340)
    }
}
