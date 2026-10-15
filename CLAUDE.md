# Magpie

제품 정의·설계 결정은 `design.md`, 빌드·권한은 `README.md`. 기능을 더하기 전에 `design.md` §1(MVP에 안 넣는 것)과 §7(v2 후보)을 먼저 본다. 순서를 바꿨으면 §5에 이유를 남긴다.

## 빌드 · 실행 · 테스트

```sh
xcodebuild -project Magpie.xcodeproj -scheme Magpie -configuration Debug -derivedDataPath build -allowProvisioningUpdates build
open build/Build/Products/Debug/Magpie.app
xcodebuild -project Magpie.xcodeproj -scheme Magpie -derivedDataPath build -allowProvisioningUpdates test
```

- `-allowProvisioningUpdates`가 없으면 CLI 빌드가 서명 에러로 실패한다.
- `test`는 앱을 test host로 띄우므로 실행 중인 Magpie가 종료된다. 테스트 후 다시 `open`.
- ad-hoc 서명(`-`)으로 바꾸지 말 것. 빌드마다 접근성 권한이 죽는다(README §권한).

## UI 확인

유닛 테스트는 패널 레이아웃을 보지 않는다. UI를 바꿨으면 실제 메뉴바 패널을 열어 확인한다:

```sh
osascript -e 'tell application "System Events" to tell process "Magpie" to click menu bar item 1 of menu bar 2'
osascript -e 'tell application "System Events" to tell process "Magpie" to get size of every window'
```

높이가 41pt(푸터만)면 목록이 접힌 것이다. `MenuBarExtra(.window)` 안의 `ScrollView`는 높이를 받지 못한다.

## 노트 파일

실제 데이터: `~/Library/Application Support/Magpie/notes.md`. 포맷을 바꾸면 기존 파일을 그대로 읽을 수 있어야 하고, `MagpieTests/MarkdownNoteStoreTests.swift`에 왕복 테스트를 추가한다.
