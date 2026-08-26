# assets/sprites/characters

파티 캐릭터의 **실제 아트**. 도형 플레이스홀더([`assets/sprites/placeholder`](../placeholder/README.md))를 대체한다.

| 파일 | 내용 |
|---|---|
| `buffer_pure_walk.png` | 4방향 x 3프레임 워크 시트 (셀 396x492, 시트 1188x1968) |
| `buffer_pure_walk_frames.tres` | 위 시트를 잘라 담은 `SpriteFrames` |
| `seola_walk.png` | 설아. 4방향 x 3프레임 워크 시트 (셀 356x448, 시트 1068x1792) |
| `seola_walk_frames.tres` | 위 시트를 잘라 담은 `SpriteFrames` |
| `mina_walk.png` | 미나. 4방향 x 3프레임 워크 시트 (셀 420x448, 시트 1260x1792) |
| `mina_walk_frames.tres` | 위 시트를 잘라 담은 `SpriteFrames` |
| `taehee_walk.png` | 태희. 4방향 x 3프레임 워크 시트 (셀 420x448, 시트 1260x1792) |
| `taehee_walk_frames.tres` | 위 시트를 잘라 담은 `SpriteFrames` |

> **`buffer_pure_walk.png` 의 이름은 역사적 흔적이다**(#276, #315). 이 아트를 쓰던 `buffer_pure` 는
> 설아가 순혈 버퍼 슬롯을 이어받으면서 삭제됐고, 아트는 겸직 플레이스홀더 `buffer_ranged` 를 거쳐
> 지금은 **하랑**(`harang`)의 것이다 — 이름이 정해지지 않은 채 아트가 먼저 들어온 인물이었고,
> #315 에서 이름이 붙었다. 파일 이름을 바꾸지 않은 이유: 재임포트와 UID 갱신이 따라붙는 변경이라, 이름이
> 옛 id 를 가리킨다는 것을 여기 적어 두는 편이 싸다.

`seola_walk.png` 의 셀 안 발 기준선은 중심 기준 **+215** 다.
`walk_sprite_scale = 0.25`, Player 충돌 캡슐 높이 30(F = 15) 이면
`walk_sprite_offset.y = 15 / 0.25 - 215 = -155` 이고 화면 키는 432 x 0.25 = 108px 다.

`mina_walk.png` 도 발 기준선 **+215**, 내용 높이 432 로 설아와 **같은 수치**다(셀 폭만 420 으로 넓다 — 정면 프레임의 머리카락이 더 퍼진다).
그래서 오프셋 계산도 같다: `walk_sprite_offset.y = -155`, 화면 키 108px.

`taehee_walk.png` 도 셀 420x448 / 발 기준선 **+215** / 내용 높이 432 로 미나와 **완전히 같은 격자**다.
`walk_sprite_offset.y = -155`, 화면 키 108px.

## 시트 규약

적 시트와 **같은 규약**이다. 정본은 [`assets/sprites/enemies/README.md`](../enemies/README.md)이며,
애니메이션 이름과 방향 판정의 단일 출처는 [`WalkAnimation`](../../../entities/shared/WalkAnimation.gd)이다.

요약: 가로 3프레임(워크 사이클) x 세로 4방향, 행 순서는 화면 방향 기준 **하 / 좌 / 상 / 우**
(`walk_down` / `walk_left` / `walk_up` / `walk_right`). 프레임은 `0 → 1 → 2` 반복이고 **0번이 정지 포즈**다.

## 원본 시트를 규약에 맞추는 방법

생성기 산출물은 그대로 쓸 수 없다. 셀 폭이 정수로 나뉘지 않고, 프레임마다 캐릭터가
셀 안에서 한쪽으로 흘러가서(측정값 약 29px/프레임) 그대로 재생하면 제자리걸음이 아니라 미끄러진다.

[`tools/normalize_walk_sheet.gd`](../../../tools/normalize_walk_sheet.gd)가 이 정규화를 한다.

```bash
godot --headless --path . --script res://tools/normalize_walk_sheet.gd -- <입력png> <출력res경로>
```

도구는 정규화한 PNG를 쓰고, 저작에 필요한 수치(셀 크기, 발 기준선, `SpriteFrames` region,
`walk_sprite_offset` 계산식)를 콘솔에 출력한다. 프레임 폭이 행 안에서 어긋나면
(= 겹친 부분이 잘렸다는 신호) 경고를 낸다.

## 배정 규칙

`CharacterData.walk_frames`에 `SpriteFrames`를 지정하고, 씬에 `AnimatedSprite2D` 노드를 둔다.
`Player._apply_data()`가 둘이 모두 있을 때만 애니메이션 경로를 켜고 `Sprite2D`(도형)를 숨긴다.
`walk_frames`를 비우면 지금까지처럼 `sprite_texture` 정지 이미지로 돌아간다.

- `walk_sprite_scale`: 표시 배율. 시트마다 원본 해상도가 달라 `sprite_scale`과 따로 둔다.
- `walk_sprite_offset`: 표시 오프셋(px, 배율 적용 전). **셀이 캐릭터보다 크므로 반드시 맞춰야 한다.**
  안 맞추면 스프라이트가 발밑이 아니라 몸 한가운데를 원점으로 잡아 캐릭터가 공중에 뜬다.

`tint`는 전투 스프라이트에 **입히지 않는다** — 색이 있는 실제 아트에 곱하면 색이 죽는다.
단 메타 화면(캐릭터/편성/주문 등)은 `tint`를 도형 스와치 색으로 계속 쓰므로 값은 남겨 둔다.

### `buffer_pure` 실측값

셀 높이 492, 아래 여백 8 → 셀 안 발 기준선은 `y = 483`, 셀 중심 기준 `+237`이다.
`Player`의 충돌 캡슐(높이 30)의 바닥인 `y = +15`에 발을 맞추려면:

```
offset.y = 15 / 0.25 - 237 = -177
```

배율 `0.25`에서 캐릭터 키는 `474 x 0.25 ≈ 119px`로, 도형 플레이스홀더(64px x 2 = 128px)와 비슷하다.

## 조종 표시

`Player._refresh_control_visual()`이 **지금 보이는 노드**의 `modulate`를 어둡게 해 비조종 멤버를 구분한다.
워크 시트를 쓰면 `Sprite2D`가 숨으므로 `AnimatedSprite2D` 쪽에 걸린다.
`self_modulate`가 아니라 `modulate`인 이유: `self_modulate`는 `tint`가 쓰고 있어 같은 채널에 겹쳐 쓰면 서로를 지운다.
