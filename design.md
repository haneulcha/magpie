# Magpie — 설계 문서

> shadcn의 [Copper](https://shadcn.com/copper)($39, macOS 14+)를 참고해 만드는 개인용 캡처 앱.
> MVP 범위 = **캡처 루프 하나만**. 스택 = **SwiftUI 네이티브**.
>
> **포지셔닝: 개인용.** 제품화는 내 사용 데이터가 근거가 될 때 검토한다(기준은 M6 회고에서 정한다).
> 그때까지 제품화로 가는 길을 막는 결정은 피한다 — 샌드박스 off라 App Store는 불가하지만 공증된 DMG 직접 배포는 열려 있다.

---

## 1. 무엇을 만드는가

한 문장: **어디서든 텍스트를 선택하고 Shift를 두 번 치면, 메뉴바 노트에 쌓이고, 나중에 ⌘C로 통째로 꺼내 쓴다.**

MVP에 들어가는 것 (이게 전부):

| # | 기능 | 완료 기준 |
|---|---|---|
| 1 | 전역 제스처 인식 | 어떤 앱에서든 Shift 더블탭이 감지된다 |
| 2 | 선택 텍스트 읽기 | Safari / VS Code / 터미널 / Slack에서 선택한 문자열이 잡힌다 |
| 3 | 캡처 저장 | 마크다운 파일 한 개에 append 된다 |
| 4 | 메뉴바 패널 | 쌓인 목록을 보고, 삭제할 수 있다 |
| 5 | 되꺼내기 | ⌘C로 노트 전체를 클립보드에 복사 |
| 6 | 캡처 피드백 | 패널이 안 보여도 "잡혔다"는 걸 안다 |

**MVP에 안 넣는 것:** 섹션(`# 이름`), ⌘K 전환, 체크박스, 좌/우 Shift 타입 구분, 이미지 첨부, URL 역참조, 설정 UI, 검색.
→ 전부 v2 후보. 3~6번까지 붙이고 **일주일 실제로 써본 뒤에** 뭘 더할지 정한다. (Copper 사용자들의 공통 피드백이 "기능이 부족하다"가 아니라 "쓰는 걸 자꾸 까먹는다"였음 — 즉 승부처는 기능 수가 아니라 습관화다.)

### 핵심 설계 원칙 (Copper에서 훔쳐올 통찰)

⌘C에 훅을 걸지 않는다. 복사는 하루에 수백 번 일어나고 그 대부분은 쓰레기다.
**의도적인 별도 제스처**를 요구함으로써 노트가 자동으로 큐레이션된다. 캡처 비용을 0으로 만들되, 0보다 아주 조금 크게 유지하는 것이 이 제품의 전부다.

---

## 2. UX 정의

```
[어떤 앱에서든]  텍스트 드래그 선택
      ↓
   Shift, Shift   (350ms 이내, 다른 키 입력 없이)
      ↓
   화면 우상단에 작은 HUD 0.8초 "Captured ↑"   ← 패널은 열리지 않는다
      ↓
   메뉴바 아이콘 뱃지 숫자 +1
```

- **패널은 절대 자동으로 뜨지 않는다.** 캡처는 흐름을 끊지 않아야 한다.
- **포커스를 절대 뺏지 않는다.** 앱은 `LSUIElement`(Dock 아이콘 없음), 패널은 `.nonactivatingPanel`.
- 메뉴바 아이콘 클릭 → 패널 열림 → 목록, 각 항목 hover 시 삭제 버튼, 하단에 `Copy all (⌘C)`.
- 빈 상태 문구: 제스처를 상기시키는 문장 하나. (습관화 장치)

---

## 3. 아키텍처

의존성은 한 방향으로만 흐른다. 각 층은 아래 층의 **프로토콜**만 알고 구현을 모른다 — 그래야 SwiftUI 프리뷰와 유닛 테스트에서 통째로 mock 할 수 있다 (전역 이벤트 탭은 테스트에서 절대 못 돌린다).

```
┌──────────────────────────────────────────────┐
│ UI          MenuBarExtra / CapturePanel      │  SwiftUI
│             CaptureHUD (NSPanel)             │
├──────────────────────────────────────────────┤
│ State       CaptureStore  (@Observable)      │  단일 진실 원천
├──────────────────────────────────────────────┤
│ Domain      Capture, CaptureSource           │  순수 값 타입
├──────────────────────────────────────────────┤
│ Ports       CaptureTriggering                │  프로토콜 3개
│             SelectionReading                 │
│             NotePersisting                   │
├──────────────────────────────────────────────┤
│ Adapters    ShiftDoubleTapRecognizer         │  AppKit / AX / CG
│             AccessibilitySelectionReader     │
│               └ PasteboardSelectionReader    │  (폴백)
│             MarkdownNoteStore                │
├──────────────────────────────────────────────┤
│ Platform    PermissionGate (AX 권한)         │
└──────────────────────────────────────────────┘
```

조립은 `Magpie/App/AppEnvironment.swift` 한 곳에서만 한다. 트리거 → 리더 체인(AX → 합성 ⌘C) → `CaptureStore.append` → HUD.

### 도메인 모델

`Magpie/Domain/Capture.swift`, `CaptureSource.swift`. 순수 값 타입이고 AppKit도 파일 시스템도 모른다.
파일에 남는 식별자는 UUID가 아니라 4자리 `shortID`다(사람이 파일을 편집해도 살아남아야 하므로).

---

## 4. 기술 상세 — 어려운 부분 3개

### 4.1 Shift 더블탭 인식

**선택:** `NSEvent.addGlobalMonitorForEvents` (읽기 전용, 접근성 권한만 필요).
`CGEvent.tapCreate`는 이벤트를 **삼킬 수** 있어서 더 강력하지만 MVP엔 과함 + Input Monitoring 권한이 추가로 필요하다. 우린 Shift를 소비할 필요가 없으니 NSEvent로 충분.

좌/우 Shift 구분은 `keyCode`가 아니라 **device-dependent 플래그 비트**로 본다:

```swift
private let leftShiftBit:  UInt = 0x02   // NX_DEVICELSHIFTKEYMASK
private let rightShiftBit: UInt = 0x04   // NX_DEVICERSHIFTKEYMASK
```

오탐 방지가 이 인식기의 90%다. 대문자를 빠르게 치면 `⇧↓ A ⇧↑ ⇧↓ B ⇧↑` 시퀀스가 나와서 순진하게 짜면 계속 오발동한다.

**"깨끗한 탭"의 정의 — 세 조건을 모두 만족해야 1탭:**
1. Shift가 눌렸다 떼어지는 동안 **다른 키/마우스 입력이 없었다** (`.keyDown`, `.leftMouseDown` 모니터로 오염 플래그를 세운다)
2. 누르고 있던 시간이 **250ms 미만** (길게 누른 건 의도가 다름)
3. Shift 외 **다른 modifier가 같이 눌려있지 않다**

그리고 **같은 쪽** Shift로 두 번, **350ms 이내**일 때만 발동.

```swift
final class ShiftDoubleTapRecognizer: CaptureTriggering {
    var onTrigger: ((ShiftSide) -> Void)?

    private let tapWindow: TimeInterval = 0.35
    private let maxHold:   TimeInterval = 0.25

    private var monitors: [Any] = []
    private var downAt: Date?
    private var downSide: ShiftSide?
    private var contaminated = false
    private var lastTap: (side: ShiftSide, at: Date)?

    func start() {
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] in
            self?.handleFlags($0)
        } as Any)
        monitors.append(NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.contaminated = true          // 이번 Shift 보유 구간은 무효
        } as Any)
    }

    private func handleFlags(_ e: NSEvent) {
        let raw = e.modifierFlags.rawValue
        let side: ShiftSide? = (raw & leftShiftBit)  != 0 ? .left
                             : (raw & rightShiftBit) != 0 ? .right : nil
        let otherModifiers = e.modifierFlags
            .intersection([.command, .option, .control, .function])
            .isEmpty == false

        if let side {                                   // Shift down
            downAt = otherModifiers ? nil : Date()
            downSide = side
            contaminated = otherModifiers
        } else {                                        // Shift up
            defer { downAt = nil; downSide = nil; contaminated = false }
            guard !contaminated,
                  let downAt, let downSide,
                  Date().timeIntervalSince(downAt) < maxHold else { return }
            registerTap(downSide)
        }
    }

    private func registerTap(_ side: ShiftSide) {
        let now = Date()
        if let last = lastTap, last.side == side,
           now.timeIntervalSince(last.at) < tapWindow {
            lastTap = nil
            onTrigger?(side)
        } else {
            lastTap = (side, now)
        }
    }
}
```

> 좌/우를 구분해 두었으니 v2에서 "왼쪽=발견한 것 / 오른쪽=내 생각" 분기를 공짜로 얻는다.

**M2 검증법:** 발동 시 `NSSound.beep()`만 울리게 해놓고 반나절 평소대로 일해본다. 오발동 0에 가까워야 다음 단계로.

### 4.2 선택 텍스트 읽기 — 2단 전략

**1차: Accessibility API.** 부작용이 없고 빠르지만 앱마다 지원 편차가 크다.

```swift
struct AccessibilitySelectionReader: SelectionReading {
    func readSelection() -> String? {
        let system = AXUIElementCreateSystemWide()
        AXUIElementSetMessagingTimeout(system, 0.25)   // ★ 필수: 응답 없는 앱에서 UI가 멈춘다

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return nil }

        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement, kAXSelectedTextAttribute as CFString, &value) == .success,
              let text = value as? String,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return text
    }
}
```

**2차 폴백: 합성 ⌘C + 클립보드 복원.** PopClip 같은 앱들이 쓰는 표준 우회로. 어디서든 동작하지만 사용자의 클립보드를 건드리므로 **반드시 원복**한다.

```swift
struct PasteboardSelectionReader: SelectionReading {
    func readSelection() -> String? {
        let pb = NSPasteboard.general
        let backup = pb.pasteboardItems?.map { item -> [NSPasteboard.PasteboardType: Data] in
            Dictionary(uniqueKeysWithValues: item.types.compactMap { t in
                item.data(forType: t).map { (t, $0) }
            })
        }
        let before = pb.changeCount
        postCommandC()

        var text: String?
        let deadline = Date().addingTimeInterval(0.2)
        while Date() < deadline {                      // changeCount 폴링 (30ms 간격)
            if pb.changeCount != before { text = pb.string(forType: .string); break }
            usleep(30_000)
        }

        if let backup {                                 // 클립보드 원복
            pb.clearContents()
            for entry in backup {
                let item = NSPasteboardItem()
                for (t, d) in entry { item.setData(d, forType: t) }
                pb.writeObjects([item])
            }
        }
        return text?.isEmpty == false ? text : nil
    }

    private func postCommandC() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: true)  // 'c'
        let up   = CGEvent(keyboardEventSource: src, virtualKey: 0x08, keyDown: false)
        down?.flags = .maskCommand; up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    }
}
```

**주의:** 폴백을 쓰려면 Shift 더블탭 직후 Shift가 완전히 떼어진 상태여야 한다. `⌘C` 합성 시점에 Shift가 눌려 있으면 `⇧⌘C`가 되어 엉뚱한 메뉴가 뜬다. → 트리거는 항상 **Shift up 이후**에 발동시키고(위 인식기가 그렇게 되어 있음), 안전하게 20ms 지연 후 post.

### 4.3 권한

```swift
enum PermissionGate {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestIfNeeded() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
```

- 필요한 건 **손쉬운 사용(Accessibility)** 하나. NSEvent 전역 모니터와 AX 읽기 둘 다 이걸로 커버된다.
- 앱 실행 시 권한이 없으면 패널에 온보딩 화면(권한 설명 + 시스템 설정 딥링크 `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`)만 보여주고 인식기를 시작하지 않는다.
- 권한은 **코드 서명에 묶인다.** 개발 중 서명이 바뀌면 조용히 권한이 죽는다. 증상은 "이벤트가 안 잡힘". 이때:
  `tccutil reset Accessibility <your.bundle.id>` 후 다시 허용.
- **샌드박스는 끈다.** AX + 임의 경로 파일 쓰기 때문. (= Mac App Store 배포 불가, 어차피 개인용)

### 4.4 메뉴바 & 패널

`Magpie/App/MagpieApp.swift`, `Magpie/UI/CapturePanel.swift`. `.menuBarExtraStyle(.window)`는 커스텀 SwiftUI 뷰를 쓰려면 필수.

- **`.window` 스타일 창은 `ScrollView`에 높이를 주지 않는다** → 목록이 0pt로 접혀 개수만 보인다. 게다가 이 창은 커지기만 하고 줄지 않는다. 그래서 목록 높이는 **고정**(360pt)한다. 내용을 따라가면 빈 공간이 남거나 창이 출렁인다.
- **상호작용 중 레이아웃은 움직이지 않는다.** 호버 버튼은 자리를 항상 차지하고 투명도만 바꾸고, 태그 편집은 같은 줄을 같은 크기의 입력창으로 바꿔 끼운다.
- 패널 목록은 날짜 섹션(오늘/어제/날짜)으로 묶고, 출처 앱·태그 칩으로 필터한다. 필터 중 `Copy all`은 보이는 것만 복사한다.
- `Info.plist`에 `LSUIElement = YES` → Dock 아이콘 없음, 포커스 안 뺏김.
- HUD는 `MenuBarExtra`로 못 만든다(패널이 닫혀 있으면 뷰가 없음). 별도 `NSPanel`:
  `styleMask: [.borderless, .nonactivatingPanel]`, `level: .statusBar`, `ignoresMouseEvents = true`, `collectionBehavior: [.canJoinAllSpaces, .stationary]`, 0.8초 후 fade out.
- `Copy all`은 패널 내에서 `.keyboardShortcut("c", modifiers: .command)`로.

### 4.5 저장 포맷

**단일 마크다운 파일.** `~/Library/Application Support/Magpie/notes.md`
(추후 iCloud/Obsidian 폴더로 경로 변경 가능하게 `UserDefaults`에 URL 하나만 둔다.)

메타데이터는 HTML 주석에 숨긴다 → 다른 마크다운 에디터에서 열어도 깨끗하다.

```markdown
## 2026-08-30

- [ ] rate limiting 미들웨어 예제 다시 찾아보기 <!--mc id=8F2A src=Safari at=14:22-->
- [ ] > The double-shift gesture was chosen over binding to copy
      <!--mc id=91C3 src=Arc at=14:31--> #읽을거리
```

- **태그는 메타 주석 뒤에** `#태그`로 쓴다. 본문 안의 `#`(예: `issue #123`)과 섞이지 않고, Obsidian이 태그로 인식한다.

- 쓰기는 **debounce 300ms + atomic write**(`.atomic` 옵션). 캡처마다 즉시 flush 하면 빠른 연속 캡처에서 파일이 깨진다.
- 읽기는 앱 시작 시 1회 파싱. 파싱 실패한 줄은 버리지 말고 원문 그대로 보존(사용자가 직접 편집했을 수 있음).
- 진실 원천은 **파일이 아니라 메모리의 `CaptureStore`**로 둔다. 외부 편집 감지(FSEvents)는 v2.

---

## 5. 구현 순서

각 마일스톤은 "검증법"까지 끝나야 다음으로 넘어간다. 순서의 이유: **가장 불확실한 것부터** 친다. M2와 M3가 실패하면 프로젝트 자체가 성립하지 않으므로 UI보다 먼저 한다.

| M | 내용 | 검증법 |
|---|---|---|
| **M0** | Xcode 프로젝트, `LSUIElement`, 샌드박스 off, 빈 `MenuBarExtra` | 메뉴바 아이콘이 뜨고 Dock에 안 뜬다 |
| **M1** | `PermissionGate` + 온보딩 화면 | 권한 리셋 후 재실행 시 온보딩이 뜬다 |
| **M2** | `ShiftDoubleTapRecognizer` (beep만) | 반나절 평소 작업 중 오발동 0 |
| **M3** | `AccessibilitySelectionReader` + 폴백 체인 (콘솔 출력) | Safari·Chrome·VS Code·Terminal·Slack·Notes 6곳에서 선택 문자열이 찍힘 |
| **M4** | `Capture` 모델 + `MarkdownNoteStore` + 패널 리스트 | 캡처 → 파일에 줄 추가 → 앱 재시작 후에도 목록 유지 |
| **M5** | HUD + 뱃지 + `Copy all` + 항목 삭제 | 패널 안 열고 캡처했다는 걸 알 수 있다 |
| **M6** | 실사용 1주 + 회고 | 하루 평균 캡처 수, 실제로 다시 꺼내 쓴 횟수 기록 |

> **순서 이탈 기록 (2026-10-15).** M2·M3 실사용 검증과 M6 회고 전에, 써보면서 바로 불편했던 두 가지를 먼저 넣었다:
> 패널 날짜 섹션(시간만 보여서 언제 것인지 모름)과 출처 앱 필터 + 수동 태그. 사용량 계측은 아직 써본 양이 적어 보류.

M0~M5는 주말 이틀 규모. 가장 오래 걸리는 건 M2의 튜닝과 M3의 앱별 예외 처리다.

---

## 6. 함정 목록

| 함정 | 증상 | 대응 |
|---|---|---|
| **Secure Input Mode** | 비밀번호 필드가 활성인 앱(터미널 `sudo`, 1Password 등)이 앞에 있으면 전역 이벤트가 아예 안 옴 | 정상 동작으로 간주. `IsSecureEventInputEnabled()`로 감지해 HUD에 안내만 |
| **AX 미지원 앱** | Chrome/Electron 계열에서 `kAXSelectedText`가 빈 값 | 폴백 체인이 처리. Chrome은 `AXManualAccessibility=true`를 set 하면 개선되기도 함 |
| **AX 호출 hang** | 응답 없는 앱을 물으면 UI 전체가 멈춤 | `AXUIElementSetMessagingTimeout` 필수. 절대 메인 스레드에서 긴 AX 순회 금지 |
| **대문자 타이핑 오발동** | 캡처가 마구 쌓임 | §4.1의 "깨끗한 탭" 3조건 |
| **한글 IME** | 조합 중 Shift가 다르게 들어옴 | M2 검증을 반드시 **한글 입력 중에도** 수행 |
| **서명 변경 시 권한 소실** | 어제 되던 게 오늘 안 됨 | `tccutil reset Accessibility <bundleid>` |
| **클립보드 원복 실패** | 사용자 클립보드가 사라짐 | 폴백은 AX 실패 시에만. 복원 실패해도 최소한 캡처한 텍스트는 남기기 |
| **빠른 연속 캡처** | 파일 손상 | debounce + atomic write |

---

## 7. v2 후보 (실사용 1주 뒤에 결정)

Copper 따라가기: 섹션(`# 이름`) + ⌘K 전환 · 체크박스 · 좌/우 Shift 타입 구분 · 이미지 첨부

Copper에 없는 차별화 (여기가 재밌는 쪽):
- **출처 역참조** — 캡처 시 프론트 앱의 URL을 AX(`kAXURLAttribute`)로 같이 저장 → 클릭하면 그 대화/페이지로 복귀
- **Claude / Cursor로 바로 보내기** — 모아둔 캡처를 프롬프트로 조립해 전송
- **Obsidian / iCloud 폴더 직접 쓰기** — 저장 경로만 열어주면 됨 (이미 설계에 자리 있음)
- ~~**자동 태깅** — 출처 앱 기준 기본 태그~~ → 출처 앱 필터 + 수동 `#태그`로 먼저 구현함(2026-10-15)

---

## 참고

- [Copper — shadcn](https://shadcn.com/copper)
- [Copper 런칭 트윗](https://x.com/shadcn/status/2082519375194763675)
- [섹션·그룹 동작 설명 트윗](https://x.com/shadcn/status/2083180011918393519)
- [Coppermind 프리뷰 분석 — explainx.ai](https://explainx.ai/blog/shadcn-coppermind-select-shift-capture-app)
