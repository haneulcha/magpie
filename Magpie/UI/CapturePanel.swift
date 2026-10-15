import SwiftUI

struct CapturePanel: View {
    @Environment(AppEnvironment.self) private var env
    @State private var hovered: Capture.ID?
    @State private var filter: Filter?
    @State private var editingTags: Capture.ID?
    @State private var tagDraft = ""
    /// MenuBarExtra 창은 ScrollView에 높이를 주지 않아 0으로 접힌다. 내용 높이를 재서 직접 준다.
    @State private var listHeight: CGFloat = 360

    enum Filter: Hashable {
        case app(String)
        case tag(String)
    }

    private var filterOptions: [Filter] {
        let captures = env.store.captures
        let apps = Set(captures.compactMap { $0.source?.appName }).sorted()
        let tags = Set(captures.flatMap(\.tags)).sorted()
        return apps.map(Filter.app) + tags.map(Filter.tag)
    }

    /// 걸어둔 태그를 지워서 필터가 사라지면 전체 보기로 돌아간다.
    private var activeFilter: Filter? {
        filter.flatMap { filterOptions.contains($0) ? $0 : nil }
    }

    /// 시간순(오래된 것 먼저). `Copy all`도 이 순서로 복사한다.
    private var filtered: [Capture] {
        env.store.captures.filter { capture in
            switch activeFilter {
            case nil: true
            case .app(let name): capture.source?.appName == name
            case .tag(let tag): capture.tags.contains(tag)
            }
        }
    }

    /// 최근 날짜가 위로, 날짜 안에서도 최근 것이 위로.
    private var days: [(day: Date, captures: [Capture])] {
        var result: [(day: Date, captures: [Capture])] = []
        for capture in filtered.reversed() {
            let day = Calendar.current.startOfDay(for: capture.createdAt)
            if result.last?.day == day {
                result[result.count - 1].captures.append(capture)
            } else {
                result.append((day, [capture]))
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            if env.store.captures.isEmpty {
                emptyState
            } else {
                if filterOptions.count > 1 {
                    filterBar
                    Divider()
                }
                list
            }
            Divider()
            footer
        }
        .frame(maxHeight: 420)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.captures) { capture in
                            row(capture)
                            Divider()
                        }
                    } header: {
                        Text(dayTitle(group.day))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.bar)
                    }
                }
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.height) { listHeight = $0 }
        }
        .frame(height: min(listHeight, 360))
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                chip("전체", isOn: activeFilter == nil) { filter = nil }
                ForEach(filterOptions, id: \.self) { option in
                    chip(label(for: option), isOn: activeFilter == option) {
                        filter = activeFilter == option ? nil : option
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func chip(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isOn ? Color.accentColor : Color.secondary.opacity(0.15), in: .capsule)
                .foregroundStyle(isOn ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }

    private func label(for filter: Filter) -> String {
        switch filter {
        case .app(let name): name
        case .tag(let tag): "#\(tag)"
        }
    }

    private func row(_ capture: Capture) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(capture.text)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .textSelection(.enabled)
                HStack(spacing: 6) {
                    Text(subtitle(for: capture))
                    ForEach(capture.tags, id: \.self) { tag in
                        Button("#\(tag)") { filter = .tag(tag) }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                if editingTags == capture.id {
                    TextField("#태그 (공백으로 구분, Enter로 저장)", text: $tagDraft)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 11))
                        .onSubmit {
                            env.store.setTags(Capture.parseTags(tagDraft), for: capture)
                            editingTags = nil
                        }
                        .onExitCommand { editingTags = nil }
                }
            }
            Spacer(minLength: 0)
            if hovered == capture.id {
                Button {
                    tagDraft = capture.tags.map { "#\($0)" }.joined(separator: " ")
                    editingTags = capture.id
                } label: {
                    Image(systemName: "tag")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("태그 편집")
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
                Text("\(filtered.count)개")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Copy all") { env.copyAllToPasteboard(filtered) }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(filtered.isEmpty)
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

    private func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "오늘" }
        if calendar.isDateInYesterday(day) { return "어제" }
        let sameYear = calendar.isDate(day, equalTo: .now, toGranularity: .year)
        return sameYear
            ? day.formatted(.dateTime.month().day().weekday())
            : day.formatted(.dateTime.year().month().day().weekday())
    }

    private func subtitle(for capture: Capture) -> String {
        let time = capture.createdAt.formatted(date: .omitted, time: .shortened)
        guard let source = capture.source else { return time }
        return "\(source.appName) · \(time)"
    }
}
