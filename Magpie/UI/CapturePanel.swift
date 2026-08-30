import SwiftUI

struct CapturePanel: View {
    @Environment(AppEnvironment.self) private var env
    @State private var hovered: Capture.ID?

    private var captures: [Capture] {
        env.store.captures.reversed()       // 최근 것이 위로
    }

    var body: some View {
        VStack(spacing: 0) {
            if captures.isEmpty {
                emptyState
            } else {
                list
            }
            Divider()
            footer
        }
        .frame(maxHeight: 420)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(captures) { capture in
                    row(capture)
                    Divider()
                }
            }
        }
    }

    private func row(_ capture: Capture) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(capture.text)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .textSelection(.enabled)
                Text(subtitle(for: capture))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if hovered == capture.id {
                Button {
                    env.store.delete(capture)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("삭제")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(.rect)
        .onHover { hovered = $0 ? capture.id : (hovered == capture.id ? nil : hovered) }
    }

    private var emptyState: some View {
        // 빈 상태 문구는 습관화 장치다 — 제스처를 상기시키는 한 문장.
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("텍스트를 선택하고 Shift를 두 번.")
                .font(.system(size: 12))
            Text("어디서든 됩니다. 패널은 열리지 않습니다.")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    private var footer: some View {
        HStack {
            if let error = env.store.lastSaveError {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else {
                Text("\(env.store.captures.count)개")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Copy all") { env.copyAllToPasteboard() }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(env.store.captures.isEmpty)
            Menu {
                Button("노트 파일 열기") { NSWorkspace.shared.open(NoteLocation.current) }
                Divider()
                Button("종료") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .frame(width: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func subtitle(for capture: Capture) -> String {
        let time = capture.createdAt.formatted(date: .omitted, time: .shortened)
        guard let source = capture.source else { return time }
        return "\(source.appName) · \(time)"
    }
}
