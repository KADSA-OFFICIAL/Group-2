# 일반판 · 검열판 릴리스 (#586)

릴리스는 두 판으로 낸다. 코드는 같고 **캐릭터 초상과 궁극기 컷인 원화만** 다르다.
도트(걷기·전투 SD 스프라이트), 적, 배경, 대사는 두 판이 같다.

| 판 | 그림 | 내보내기 기능 태그 |
|---|---|---|
| 일반판 | `assets/` 원본 | 없음 |
| 검열판(전체이용가) | `assets_censored/` 에 짝이 있으면 그것, 없으면 원본 | `censored` |

## 구조

| 무엇 | 어디 |
|---|---|
| 판 구분 · 경로 규칙(`assets/` ↔ `assets_censored/`) | `entities/edition/GameEdition.gd` |
| 초상 조회 | `PortraitSystem.get_portrait()` / `get_texture()` → `GameEdition` |
| 궁극기 경로 | `UITheme.ultimate_frames_path()` / `ultimate_cutin_path()` → `GameEdition` |
| 스토리 인물(여신 등) 초상 | `story_player_screen._figure_portrait()` → `GameEdition` |
| 내보내기 교체 | `addons/edition_export/` (프로젝트 설정에서 켜져 있다) |

- **에디터·헤드리스**: 화면이 위 조회 함수를 거칠 때 검열판 그림을 고른다. `-- --censored` 를 붙여 실행하면 검열판으로 미리 본다.
- **검열판 내보내기**: 짝이 있는 원본 파일을 **원본 경로 그대로** 검열판 내용으로 바꿔 넣는다. 그래서
  `CharacterData.portrait` 처럼 원본을 직접 참조하는 곳도 검열판 그림이 되고, 원본 텍스처 데이터는 pck 에 들어가지 않는다.
- **일반판 내보내기**: 아무것도 바꾸지 않는다. 프리셋 제외 필터로 `assets_censored/` 를 뺀다.

## 내보내기 프리셋

`export_presets.cfg` 는 사람마다 따로 두고 커밋하지 않는다. 예시: [export_presets.example.cfg](export_presets.example.cfg).
플랫폼(Windows · macOS)마다 프리셋을 두 개씩 둔다:

| 프리셋 | 기능 → 커스텀 | 리소스 → 제외 필터 |
|---|---|---|
| `<플랫폼>` (일반판) | 비움 | `assets_censored/*` |
| `<플랫폼> Censored` (검열판) | `censored` | 비움 |

에디터에서는 프로젝트 → 내보내기 → 프리셋 → **기능** 탭의 "커스텀"과 **리소스** 탭의 "제외 필터"다.

## 릴리스 순서

1. `main` 최신으로 받고 `godot --headless --path . --import`
2. 검열판 그림 상태 확인 — 마지막 줄에 아직 원본을 쓰는 목록이 나온다:
   ```
   godot --headless --path . res://tests/edition/VerifyGameEdition.tscn -- --censored
   ```
3. 네 가지 내보내기:
   ```
   godot --headless --path . --export-release "Windows" export/general/StoneageShipduck.exe
   godot --headless --path . --export-release "Windows Censored" export/censored/StoneageShipduck.exe
   ```
   검열판 내보내기 로그에 `GameEdition: 검열판 내보내기 — assets_censored/ 파일 N개로 원본을 바꿔 넣는다.` 가 찍혀야 한다.
   **0개이거나 이 줄이 없으면** 플러그인이 꺼져 있거나 태그가 빠진 것이다.
4. 압축 파일 이름에 판을 넣는다: `StoneageShipduck-v<버전>-Windows.zip`, `StoneageShipduck-v<버전>-Windows-AllAges.zip` (macOS 도 같은 식)
5. 릴리스 본문의 다운로드 표에 두 판을 모두 적고, 검열판에 "초상·궁극기 그림 순화" 한 줄을 단다.

## 검열판 그림 넣기

[assets_censored/README.md](../assets_censored/README.md). 원화 제작 프롬프트는 [censored-art-prompts.md](censored-art-prompts.md).

## 2026-10-31 확인한 것

임시 검열판 그림(미나 초상 1장 + 궁극기 24장)으로 Windows 두 판을 실제 내보내 비교했다.

- 검열판 pck 에 원본 미나 초상·궁극기 텍스처(`.ctex`)가 없고 검열판 텍스처만 있다. pck 크기는 일반판과 거의 같다(데이터가 두 벌 들어가지 않는다).
- 일반판 pck 에는 `assets_censored/` 파일이 없다.
- 내보낸 검열판 안에서 테스트를 돌려 원본 경로를 직접 읽어도 검열판 그림이 나오는 것을 확인했다.
- 검열판 그림만 바꾸고 원본은 그대로 둔 경우에도 다시 구워지도록, 내보내기 캐시 키에 `assets_censored/` 파일 목록·수정 시각을 넣었다.
