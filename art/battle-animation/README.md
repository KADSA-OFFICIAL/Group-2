# 전투 애니메이션 아트 · #491 → #533 재작업

> **#533 (2026-09-30):** 12체 × 14컷 168장 전부를 초상 그림체·약 5등신(다리를 줄인 비율)으로 교체했다.
> `idle_0` 도 이제 생성 원본(`source-plates/<id>/idle_0.png`, 사용자 승인본)이며, 정지 스프라이트
> `char_<id>_battle.png` / `enemy_<id>_battle.png` 는 처리된 `idle_0` 과 같은 파일이다.
> 원본 플레이트의 자홍색이 고르지 않아(R/B 233~252, G 3~37) 처리 도구를 Python 으로 옮겼다(아래).

[제작 규격](specification.ko.md)에 따라 기존 캐릭터 외형을 유지하면서 낱장 PNG로 제작한다. 관련 런타임은 #487 / PR #488이다.

## 구성

- [재생·프레임 검수](review.html): 저장소를 내려받은 뒤 브라우저로 열면 된다.
- `source-plates/<id>/<anim>_<n>.png`: 이미지 생성 도구가 만든 원본. 자홍색은 투명 배경 추출용이다.
- `manifest.json`: 생성 프롬프트와 원본/결과 경로. `corrections.json`에 있는 컷은 후속 수정 프롬프트가 최종본이다.
- `../../assets/sprites/characters/battle/frames`, `../../assets/sprites/enemies/battle/frames`: 실제 투명 PNG 및 SpriteFrames.
- 최초 대기 프레임 `idle_0.png`는 기존 전투 PNG의 바이트 단위 복사본이다.

## 규격

| 동작 | 낱장 수 | 초당 프레임 | 반복 |
|---|---:|---:|---|
| idle | 4 | 6 | 반복 |
| attack | 4 | 14 | 1회 후 대기 |
| hit | 2 | 16 | 1회 후 대기 |
| death | 4 | 8 | 마지막 컷에서 정지 |

목표는 12체 × 14컷 = 168 PNG다. 제작 캔버스는 아군 224×336, 적 248×312다. 표시 크기의 정본은 TurnBattle이며, 최신 #492 변경으로 아군 101×151 / 적 112×140 칸에 비율을 유지해 표시한다. 첨부 문서의 예전 표시 크기에서 커졌지만 PNG를 다시 확대 제작할 필요는 없다. 배경을 제거한 뒤 원본 캔버스를 같은 비율로 축소하고 밑변을 맞춘다. 쓰러진 인물을 다시 전체 높이로 확대하지 않는다. 아린은 승인된 원본의 석궁을 유지했다.

사망 동작은 마지막 컷까지 재생한 뒤 그 자세로 멈춰 기존 사라짐 효과를 적용한다. 이전의 0.35초 사라짐 효과가 0.5초 사망 동작을 가리는 문제를 보완했다.

대기 컷은 원본 idle_0의 실루엣 높이를 기준으로 +2 / +4 / +2 픽셀의 호흡 높이에 맞추고, 발 부분의 중심을 정렬한다. 생성 과정에서 생긴 여백·크기 차이를 줄이는 후처리다. 공격·피격·쓰러짐에는 이 높이 보정을 적용하지 않으며, 낮아진 자세와 비율을 보존한다. `idle_0` 은 배경 제거·축소·밑변 맞춤만 한다(키를 맞추지 않는다).

#533 에서 더한 규칙(`tools/prepare_animation_frames.py`):

- **모든 컷의 가장 낮은 점을 밑변에 붙인다.** 생성 원본은 쓰러짐 컷이 최대 170px(화면 약 17px), 피격·공격 컷이 약 30px 떠 있었다.
- **공격 궤적은 옅은 흰색.** attack_1 의 분홍·보라 곡선은 자홍색 배경과 섞여 배경 제거 뒤 보라로 남는다. 굵은 획만 궤적으로 보고(얇은 경계 테두리는 제외) 흰색 반투명으로 바꾼다.
- **반투명은 배경 바로 옆에서만.** 색만으로는 "자홍색과 섞인 경계"와 "원래 보라로 그린 장식"(아린 석궁의 번개 문양 216,104,240)을 구분할 수 없어, 배경에서 떨어진 픽셀은 불투명으로 지킨다.
- 공격 중 발이 옆으로 옮겨지는 컷(설아·서아·강지·하랑·여왕, 원본 50~120px)은 앞으로 내딛는 동작이라 그대로 둔다. 대상 앞까지의 이동은 전투 화면이 따로 한다(#531).

## 다시 조립하기

저장소 루트에서 Godot 4.6.3으로 실행한다.

```sh
python tools/prepare_animation_frames.py art/battle-animation/manifest.json
# (정지 스프라이트 = idle_0) 12체의 frames/<id>/idle_0.png 를 char_<id>_battle.png / enemy_<id>_battle.png 로 복사
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/build_battle_frames.gd
godot --headless --path . res://tests/combat/VerifyAuthoredBattleAnimations.tscn
godot --headless --path . res://tests/combat/VerifyBattleFrames.tscn
godot --headless --path . res://tests/combat/VerifyBattleSprites.tscn
godot --headless --path . res://tests/combat/VerifyTurnCombat.tscn
godot --headless --path . res://tests/combat/VerifyTurnStageBattle.tscn
```

실제 화면 증거는 headless 옵션 없이 `VerifyBattleSprites.tscn -- --capture <저장 폴더>`로 만든다.

## 검수 상태

2026-09-12: 12체 / 168 PNG / 12 SpriteFrames 제작·연결 및 검수 완료. [최종 검수 보고서와 캐릭터별 비교표](VERIFICATION.md), [파일·크기·SHA-256 목록](frame-index.csv)을 확인할 수 있다.
