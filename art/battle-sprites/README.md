# 전투 대기 일러스트 12체 — #480

턴제 전투의 `battle_sprite` 슬롯에 아군 6명·적 6체의 이미지 생성 일러스트를 연결했다.
`feat-478-combat-hud-shape-language`의 `a306f47`에 준비된 슬롯을 사용한다.
전투 수치, 표시 칸, 실시간 이동 시트와 기존 초상은 변경하지 않는다.

## 제작

- 내장 이미지 생성 도구로 유닛마다 한 장씩 제작했다. 코드로 캐릭터 도형을 그린 플레이스홀더가 아니다.
- 미나 한 명을 먼저 생성하고 84px 축소 및 검은 실루엣을 확인한 다음 같은 스타일 참조로 나머지 11체를 생성했다.
- 아군 6명과 벨로시랩터 2종·서아는 저장소 초상을 직접 참조했다. 매머드 우두머리는 일반 매머드 생성본을 종/화풍 참조로 삼았다.
- 4등신 전투 대기 자세, 아군 오른쪽/적 왼쪽 3/4 시점, 좌상단 광원. 얼굴·머리·꼬리·의상 장식은 초상을 단순화했다. 전투용 의상은 불투명하게 정리했다.
- 실제 생성 요청은 `prompts.json`, 선택된 고해상도 생성 원본은 `source-plates/`, 출력 규격과 팔레트는 `manifest.json`에 보관한다.
- 최초 미나의 투명 요청은 RGB 체크무늬 배경으로 반환되었다. 배경만 균일한 `#FF00FF`로 바꾸도록 이미지 생성 도구에 편집 요청했다. 나머지도 같은 단색 배경 원본을 받아 기계적으로 제거했다. **게임에 연결된 PNG는 실제 알파 투명**이다.
- 재출력 스크립트는 배경 제거, 비율 유지 축소, 발 기준 정렬, 4색 매핑만 수행한다. 전경의 형태를 새로 그리지 않는다. 원소 장식 영역은 비슷한 흰색 머리/피부와 분리하여 양자화한다.

## 파일과 연결

| 대상 | 파일 | 캔버스 | 게임 표시 칸 |
|---|---|---|---|
| 아군 6명 | `assets/sprites/characters/battle/char_<id>_battle.png` | 224×336 | 56×84 |
| 적 6체 | `assets/sprites/enemies/battle/enemy_<id>_battle.png` | 248×312 | 62×78 |

각 `data/characters/*.tres` 및 `data/enemies/*.tres`에서 `battle_sprite`를 연결한다.
텍스처의 `.import`도 포함한다. 발의 가장 아래 픽셀은 캔버스 밑변에 닿고,
좌우/상단에는 최소 5% 여백이 있다. 넓은 꼬리와 무기도 자르거나 늘리지 않고 칸에 맞춘다.
PNG의 불투명/반투명 픽셀 RGB는 4색 이내이며 알파로 외곽을 처리한다.
접지 그림자는 기존 전투 화면이 별도로 그린다.

원소는 첨부 문서의 오래된 적 표보다 현재 `.tres`와 `TurnCombat.ELEMENT_COLOR`를 우선했다.
매머드 우두머리는 화염 `#FF6B35`, 서아는 광휘 `#FFD54F`, 익룡 여왕은 풍압 `#66D9A6`이다.
일반 매머드와 벨로시랩터 2종은 충격 `#E8E8E8`이다. 약점과 원소는 바꾸지 않았다.
아군 원소는 문서와 동일하다. 태희는 초상에 이미 있는 날카로운 발톱을 참격 무기로 유지했다.

## 검수 자료

- `review/battle-art-overview.png`: 12체 4열 비교, 이름 표시.
- `review/battle-contact-sheet.png`: 아군 6명/적 6체 순서. 각 행 위는 게임 표시 칸 크기, 아래는 2배 확대.
- `review/battle-silhouettes.png`: 동일한 순서의 검은 실루엣. 대검/방패/긴 꼬리/발톱/석궁/지팡이 및 적 종별 형태를 비교한다.
- `review/battle-party-a.png`, `review/battle-party-b.png`: 실제 `TurnBattle` 렌더링. 두 조우를 합쳐 12체 모두 확인했다.

## 재출력 및 검증

Godot 4.6.3에서 저장소 루트를 기준으로 실행한다. `godot`은 설치된 실행 파일로 대체할 수 있다.

```sh
godot --headless --path . --import
godot --headless --path . --script tools/prepare_battle_sprites.gd -- res://art/battle-sprites/manifest.json
godot --headless --path . --import
godot --headless --path . res://tests/combat/VerifyBattleSprites.tscn
godot --headless --path . res://tests/combat/VerifyTurnCombat.tscn
godot --headless --path . res://tests/combat/VerifyTurnStageBattle.tscn
```

렌더링 검수 이미지는 그래픽 드라이버가 있는 환경에서 다음처럼 저장한다.

```sh
godot --path . --rendering-method gl_compatibility --resolution 1280x720 --windowed res://tests/combat/VerifyBattleSprites.tscn -- --capture /absolute/review/directory
```

2026-09-10 확인 결과:

- Import 성공. 리소스 파싱 오류 없음.
- 전용 아트 검사 **204개 통과**, 실제 장면의 TextureRect에서 **12체 모두 관측**, 실패 0.
- 그래픽 렌더링 검사 **208개 통과**. 1280×720, NVIDIA/OpenGL Compatibility. 오류/종료 경고 없음.
- 전투 코어 **411개 통과**, 종료 코드 0.
- 스테이지 연동 **135개 통과**, 종료 코드 0. 기존 테스트의 종료 시 리소스 정리 경고는 남아 있다. 기능 검사 실패는 없으며, 해당 정리 문제는 이 아트 변경 범위에 포함하지 않았다.
- `git diff --check` 통과.

`source-plates/`는 마젠타 배경의 제작 원본이며 게임용 파일이 아니다.
이 폴더의 `.gdignore`로 원본/검수 자료를 Godot 에셋 가져오기 대상에서 제외했다.
