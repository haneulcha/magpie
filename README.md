# Mini Copper

어디서든 텍스트를 선택하고 **Shift를 두 번** 치면, 메뉴바 노트에 쌓이고, 나중에 `⌘C`로 통째로 꺼내 쓴다.

설계는 [`design.md`](design.md)에 있다. 이 README는 빌드/실행법만 다룬다.

## 요구사항

macOS 14+ · Xcode 26+ (Swift 6)

## 실행

```sh
open MiniCopper.xcodeproj     # ⌘R
# 또는
xcodebuild -project MiniCopper.xcodeproj -scheme MiniCopper -configuration Debug build
xcodebuild -project MiniCopper.xcodeproj -scheme MiniCopper test
```

앱은 `LSUIElement`라 **Dock에 뜨지 않는다.** 메뉴바 우측의 트레이 아이콘을 찾으면 된다.
첫 실행 시 손쉬운 사용 권한을 요청한다. 허용하면 폴링이 감지해 **재실행 없이** 인식기가 켜진다.

## 권한

필요한 건 **손쉬운 사용(Accessibility)** 하나뿐. 전역 이벤트 모니터와 AX 읽기 둘 다 이걸로 커버된다.

권한은 **코드 서명에 묶인다.** 이 프로젝트는 Apple Development 인증서로 자동 서명하도록
설정돼 있어(`CODE_SIGN_STYLE = Automatic`, 팀 지정됨) TCC가 권한을 이렇게 저장한다:

```
identifier "com.haneul.MiniCopper" and anchor apple generic
and certificate leaf[subject.CN] = "Apple Development: ..."
```

번들 ID + 인증서 기준이므로 **리빌드해도 권한이 유지된다.** 한 번만 허용하면 된다.

> ⚠️ ad-hoc 서명(`CODE_SIGN_IDENTITY = "-"`)으로 되돌리면 TCC는 신원을 잡을 수 없어
> **바이너리 해시(cdhash)로 권한을 고정한다.** 그러면 빌드할 때마다 권한이 죽고, 더 나쁘게는
> 시스템 설정 목록에는 항목이 남아 있어서 켜도 아무 효과가 없는 유령 항목이 된다
> (증상: DB는 허용인데 `AXIsProcessTrusted()`가 계속 false).
> 그럴 땐 `./scripts/reset-permission.sh`로 항목을 지우고 다시 허용해야 한다.

권한이 안 먹는 것 같으면 TCC가 **무엇을 기준으로** 저장했는지부터 확인한다.
`cdhash H"..."`가 나오면 유령 항목이니 리셋해야 하고, `identifier ... and certificate ...`면 정상이다:

```sh
sqlite3 "/Library/Application Support/com.apple.TCC/TCC.db" \
  "select hex(csreq) from access where service='kTCCServiceAccessibility' \
   and client='com.haneul.MiniCopper';" | xxd -r -p > /tmp/csreq.bin
csreq -r /tmp/csreq.bin -t
```

샌드박스는 꺼져 있다(AX + 임의 경로 파일 쓰기 때문). = Mac App Store 배포 불가, 어차피 개인용.

## 노트 파일

`~/Library/Application Support/MiniCopper/notes.md`
(경로는 `NoteLocation`이 `UserDefaults`의 `noteURL` 하나만 보므로 나중에 Obsidian/iCloud 폴더로 바꿀 수 있다.)

```markdown
## 2026-08-30

- [ ] rate limiting 미들웨어 예제 <!--mc id=8F2A src="Safari" bid=com.apple.Safari at=14:22-->
```

메타데이터는 HTML 주석에 숨긴다. **사람이 직접 쓴 줄은 파싱에 실패해도 버리지 않고** 원래 날짜 섹션에 그대로 되돌려 쓴다.

## 구조

의존성은 한 방향으로만 흐른다. 상위 층은 아래 층의 **프로토콜**만 안다 —
전역 이벤트 탭은 테스트에서 절대 못 돌리므로, 그 경계가 곧 테스트 경계다.

```
MiniCopper/
├── App/        MiniCopperApp · AppEnvironment(조립은 여기 한 곳)
├── UI/         RootView · CapturePanel · OnboardingView · CaptureHUD
├── State/      CaptureStore (@Observable, 단일 진실 원천)
├── Domain/     Capture · CaptureSource (순수 값 타입)
├── Ports/      CaptureTriggering · SelectionReading · NotePersisting
├── Adapters/   ShiftDoubleTapRecognizer · Accessibility/Pasteboard/ChainedSelectionReader · MarkdownNoteStore
└── Platform/   PermissionGate · NoteLocation · CaptureSource+Frontmost
```

Xcode 16+의 synchronized folder를 쓰므로 **파일을 추가할 때 `.xcodeproj`를 건드릴 필요가 없다.**
디렉터리에 `.swift`를 만들면 자동으로 타깃에 들어간다.

## 현재 상태

| M | 내용 | 상태 |
|---|---|---|
| M0 | 프로젝트, `LSUIElement`, 샌드박스 off, `MenuBarExtra` | ✅ |
| M1 | `PermissionGate` + 온보딩 화면 | ✅ |
| M2 | `ShiftDoubleTapRecognizer` | 동작 확인 — **반나절 실사용 오발동 검증은 아직** |
| M3 | AX 리더 + 폴백 체인 | 동작 확인 — **앱 6곳 개별 검증은 아직** |
| M4 | `MarkdownNoteStore` + 패널 리스트 | ✅ (유닛 테스트 12개) |
| M5 | HUD + 뱃지 + `Copy all` + 삭제 | ✅ |
| M6 | 실사용 1주 + 회고 | — |

M2·M3는 **기계가 검증할 수 없는 마일스톤**이다. `design.md` §5의 검증법대로 직접 써봐야 한다:
M2는 반나절 평소 작업(한글 입력 포함) 중 오발동 0, M3는 Safari·Chrome·VS Code·Terminal·Slack·Notes 6곳에서 선택 문자열이 잡히는지.
