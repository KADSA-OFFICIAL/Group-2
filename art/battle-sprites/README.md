# 전투 대기 일러스트 12체 — #485

하랑·미나·설아의 기존 초상을 화풍 참조로 사용해 아군 6명과 적 6체를 이미지 생성으로 재작업했다.
강지·아린의 공유 초상과 전신·얼굴 아이콘·컷인도 같은 얇은 선과 밝은 파스텔 표현으로 다시 제작했다.

## 변경

- 피부·머리·의상을 별도 색군으로 유지한다. #480 내보내기의 **전경 전체 4색 양자화를 제거**했다.
- 하랑·설아·태희의 살색 피부와 머리/의상을 구분했다. 미나의 흰 셔츠·붉은 넥타이를 유지했다.
- 태희는 붉은 눈·이빨 스카프와 짧은 쌍곡도, 벨로 1은 낮은 자세·긴 꼬리, 벨로 2는 선 자세·짧게 치켜든 꼬리·완장으로 구분한다.
- 매머드 2종·여왕을 사람 얼굴의 여성 수인으로 교체했다. 우두머리는 같은 얼굴에 밝은 털·뼈 왕관·어깨 갑옷·상아 금속띠를 더했다.
- 서아는 피부를 유지하며 머리·옷·부츠만 다시 밝고 낮은 채도로 생성 편집했다.
- 강지·아린 패키지: [개별 일러스트](../character-assets/v2/README.md).

## 제작과 연결

실제 이미지 생성 요청은 `prompts.json`, 선택된 생성 원본은 `source-plates/`에 보관한다.
외형/화풍 참조는 저장소 초상이다. 개별 수정도 이미지 생성 도구로 처리했다.
주요 색군은 피부·눈·원소 장식·선·안티앨리어싱과 별개다. RGB 색 수를 4개로 제한하지 않는다.

배경 제거·비율 유지 축소·발 정렬만 Godot으로 처리한다. 전경을 다시 칠하거나 양자화하지 않는다.
게임 PNG는 실제 알파 투명이며 마젠타 제작 원본은 게임에 표시하지 않는다.
무기에는 작은 원소 장식만 남기며 발광·접지 그림자를 굽지 않는다.

| 대상 | 게임 파일 | 캔버스 | 화면 표시 칸 |
|---|---|---|---|
| 아군 6명 | `assets/sprites/characters/battle/char_<id>_battle.png` | 224×336 | 56×84 |
| 적 6체 | `assets/sprites/enemies/battle/enemy_<id>_battle.png` | 248×312 | 62×78 |

기존 파일명·.tres 연결·.import를 유지했다. 아군 오른쪽/적 왼쪽, 발은 밑변, 상단·좌우 최소 5% 여백이다.
현재 게임 원소도 유지했다: 서아 광휘, 우두머리 화염, 여왕 풍압. `manifest.json`에 기록한다.

```sh
godot --headless --path . --script tools/prepare_battle_sprites.gd -- res://art/battle-sprites/manifest.json /absolute/review/directory
godot --headless --path . --script tools/prepare_character_restyle.gd
godot --headless --path . --import
godot --headless --path . res://tests/combat/VerifyBattleSprites.tscn
godot --headless --path . res://tests/combat/VerifyTurnCombat.tscn
godot --headless --path . res://tests/combat/VerifyTurnStageBattle.tscn
```

## 검수

`review/`: 12체 비교표, 실제 표시 크기/2배 확대, 검은 실루엣, 실제 전투 조우 2장.
강지·아린 공유 초상은 편성·대화·HUD·기존 컷인에서 사용하며 얼굴 크롭 좌표도 추가했다.

2026-09-11, Godot 4.6.3:
- 가져오기 성공.
- 전용 검사 **238개**, 12체 관측, 실패 0. 종전 204개에서 피부색·마젠타 잔존·공유 초상 검사를 추가했다.
- 렌더링 **242개**, 실패 0. NVIDIA/OpenGL Compatibility, 1280×720.
- 전투 코어 **411개**, 스테이지 연동 **135개** 통과.
- 스테이지 테스트에는 기존 종료 시 리소스 정리 경고가 남으나 종료 코드 0, 기능 검사 실패 0.
- 기존 6인 패키지 PNG 42개도 지정 크기·알파·전신 10% 여백·컷인 왼쪽 40% 투명 검사를 통과했다.

형태·색감은 원본과 육안 비교했다. 포즈별 피부/의상 면적이 다르므로 모든 유닛의 전체 평균 채도가 원본 이하라는 수치 인증은 하지 않는다.
기존 사각 접지 그림자와 별도 리그·애니메이션은 이번 정지 이미지 교체 범위 밖이다.
`art/`의 제작 원본과 검수 자료는 .gdignore로 게임 가져오기 대상에서 제외한다.
