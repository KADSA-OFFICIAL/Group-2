# 강지 새 그림체 — #548

하랑·미나·설아·태희와 그림체를 맞춘 강지의 LD 초상 1장과 SD 전투 원화 14장이다.
디자인(갈색 웨이브 단발, 나뭇잎 핀, 크림 카디건, 갈색 치마, 노란 구슬 나무 지팡이)은 유지했다.

| 파일 | 내용 |
|---|---|
| `gangji_portrait_source.png` | 승인된 v4 초상 원본(1024×1536, 투명 배경). 게임용은 정규화본 |
| `gangji_sd_prompts.json` | 초상·SD 14컷 생성 프롬프트(내장 image_gen) |
| `gangji_sd_repairs.json` | attack_1·attack_2 발 위치 교정 프롬프트 |
| `gangji_validation.json` | 제작 쪽 검증값(해상도·모서리 색·SHA-256) |

SD 원화 14장은 `art/battle-animation/source-plates/gangji/` 에 들어 있다.

## 게임에 넣은 경로

```sh
# 초상: 92% 인물 높이 · 비율 0.5566 캔버스로 정규화(리샘플링 없음 → 918×1650)
godot --headless --path . --script res://tools/normalize_portrait.gd -- res://assets/sprites/characters/portraits/gangji.png
# SD: 자홍 배경 제거 · 224×336 축소 · 밑변 맞춤
python tools/prepare_animation_frames.py art/battle-animation/manifest.json --unit=gangji
cp assets/sprites/characters/battle/frames/gangji/idle_0.png assets/sprites/characters/battle/char_gangji_battle.png
godot --headless --path . --editor --import --quit
godot --headless --path . --script tools/build_battle_frames.gd
```

- 얼굴 범위 `data/portraits/portrait_meta.tres` 의 `gangji` 를 새 초상에 맞춰 다시 쟀다.
- 원화의 자홍 배경이 고르지 않고(R/B 231~241, G 13~16) attack_1·2 발이 30~60px 떠 있었지만,
  처리 도구가 색 허용 범위로 배경을 빼고 가장 낮은 점을 밑변에 붙이므로 따로 고치지 않았다.
- 대기 실루엣 높이 290px(224×336 칸) — 다른 아군 278~292px 범위 안이다.

## 남은 것

- 4방향 워크 시트(`assets/sprites/characters/gangji_walk_frames.tres`)는 예전 그림체 그대로다.
- 오의 LD 클립(#546/#549)은 예전 초상 기준이라 #549 에서 새 초상으로 다시 만든다.
