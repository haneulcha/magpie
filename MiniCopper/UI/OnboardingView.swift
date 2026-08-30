import SwiftUI

/// 권한이 없을 때만 보이는 화면. 여기서는 인식기를 시작하지 않는다.
struct OnboardingView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("손쉬운 사용 권한이 필요합니다")
                .font(.system(size: 13, weight: .semibold))
            Text("""
                Shift 더블탭을 감지하고 선택한 텍스트를 읽으려면 \
                시스템 설정 › 개인정보 보호 및 보안 › 손쉬운 사용에서 \
                MiniCopper를 허용해 주세요.
                """)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("시스템 설정 열기") { PermissionGate.openSystemSettings() }
                Spacer()
                Button("종료") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 2)

            Text("허용하면 자동으로 켜집니다. 재실행은 필요 없습니다.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
    }
}
