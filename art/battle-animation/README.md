# 전투 애니메이션 아트 · #491

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

대기 컷은 원본 idle_0의 실루엣 높이를 기준으로 +2 / +4 / +2 픽셀의 호흡 높이에 맞추고, 발 부분의 중심을 정렬한다. 생성 과정에서 생긴 여백·크기 차이를 줄이는 후처리다. 공격·피격·쓰러짐에는 이 높이 보정을 적용하지 않으며, 낮아진 자세와 비율을 보존한다. `idle_0` 자체는 수정하지 않는다.

## 다시 조립하기

저장소 루트에서 Godot 4.6.3으로 실행한다.

```sh
godot --headless --path . --script tools/prepare_animation_frames.gd -- res://art/battle-animation/manifest.json
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
