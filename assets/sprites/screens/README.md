# assets/sprites/screens

메타 화면의 **배경 아트**. `HUDKit.make_backdrop(art)` 가 단색 바닥 대신 이 그림을 깐다(#287).

| 파일 | 화면 | 장면 |
|---|---|---|
| `craft.png` | `screens/craft/CraftScreen.tscn` | 대장간 실내 — 모루, 걸린 연장, 쌓아 둔 장작 |
| `shop.png` | `screens/shop/ShopScreen.tscn` | 시장 좌판 — 차양 아래 늘어놓은 물건 |
| `storage.png` | `screens/storage/StorageScreen.tscn` | 곳간 — 초가지붕 창고와 항아리 |
| `sanctum.png` | `screens/story/StoryScreen.tscn` | 사당 — 선돌과 뼈 장식, 안에 앉은 석상 |

## 이름은 화면이 아니라 건물 id 다

`data/order/buildings/*.tres` 의 `building_id` 를 그대로 쓴다. 뜰에서 그 건물을 눌러
들어온 화면이라 그렇다. 그래서 성소(`sanctum`)의 배경 파일 이름이 `story` 가 아니다 —
성소가 여는 화면이 스토리 화면일 뿐이다(`sanctum.tres` 의 `screen_path`).

## 규격

- **1280x720 뷰포트에 맞춰 16:9**. 현재 960x540 이다.
  - 생성기 산출물은 1216x832(=1.46:1)로 나온다. **그대로 넣으면 세로 약 18% 가 잘려 나간다** —
    저장하고 VRAM 에 올려도 화면에 안 나오는 픽셀이다. 스토리 배경이 #272 에서 겪은 것과 같다.
  - 가로 960 은 스토리 배경(#272)이 정한 관례를 따른 것이다. 배경은 UI 와 스크림 뒤에 깔리는
    그림이라 원본 해상도를 지켜서 얻는 것이 없다.
- **불투명 PNG**(RGB8). 배경은 무엇 뒤에도 놓이지 않아 알파가 필요 없다.
- **사람을 그리지 않는다.** 배경은 기능 화면 뒤에 깔리는 자리이고, 인물이 있으면 패널에
  가려 잘린 사람이 된다.
- **가운데를 비워 둔다.** 좌우 기둥(`RAIL_WIDTH` 280 / `DETAIL_WIDTH` 340)과 중앙 패널이
  화면 대부분을 덮는다. 실제로 보이는 것은 가장자리와 패널 사이 틈이다.

## 스크림

화면은 배경 위에 바닥색을 `HUDKit.BACKDROP_SCRIM_ALPHA`(0.62) 만큼 덮는다.
**그림 파일은 원본 그대로 둔다** — 미리 어둡게 구우면 되돌릴 수 없고 세기를 바꿀 때마다
에셋을 다시 만들어야 한다. 세기는 상수 하나로 조절한다.

## 새 배경을 넣는 법

1. 생성한 원본을 규격에 맞춘다. **자르는 위치는 그림마다 다르므로** 도구의 `ANCHORS` 에
   한 줄 추가한다(주제가 아래에 깔린 그림은 위를 더 버려야 한다).

```bash
godot --headless --path . --script res://tools/normalize_screen_backdrop.gd -- <입력png>:<이름>
```

2. 그 화면의 `make_backdrop()` 호출을 `make_backdrop(HUDKit.load_backdrop("<이름>"))` 으로 바꾼다.

파일이 없으면 `load_backdrop()` 이 `null` 을 돌려주고 화면은 단색 바닥으로 돌아간다.
그러니 아트가 아직 없는 화면도 미리 호출을 넣어 둘 수 있다.
