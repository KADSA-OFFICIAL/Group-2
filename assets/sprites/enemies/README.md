# assets/sprites/enemies

적의 **실제 아트**. 도형 플레이스홀더([`assets/sprites/placeholder`](../placeholder/README.md))를 대체한다.

| 파일 | 내용 |
|---|---|
| `stone_spearman_walk.png` | 돌창병. 4방향 x 3프레임 워크 시트 (셀 524x492, 시트 1572x1968) |
| `stone_spearman_walk_frames.tres` | 위 시트를 잘라 담은 `SpriteFrames` |
| `mammoth_beastfolk_walk.png` | 매머드 수인. 4방향 x 3프레임 워크 시트 (셀 424x496, 시트 1272x1984) |
| `mammoth_beastfolk_walk_frames.tres` | 위 시트를 잘라 담은 `SpriteFrames` |
| `velociraptor_beastfolk_walk.png` | 벨로시랩터 수인. 4방향 x 3프레임 워크 시트 (셀 396x492, 시트 1188x1968) |
| `velociraptor_beastfolk_walk_frames.tres` | 위 시트를 잘라 담은 `SpriteFrames` |
| `velociraptor_beastfolk_2_walk.png` | 벨로시랩터 수인 2. 4방향 x 3프레임 워크 시트 (셀 424x496, 시트 1272x1984) |
| `velociraptor_beastfolk_2_walk_frames.tres` | 위 시트를 잘라 담은 `SpriteFrames` |
| `pterosaur_queen_walk.png` | 익룡 여왕 SD. 4방향 x 3프레임 워크 시트 (셀 96x96, 시트 288x384) |
| `pterosaur_queen_walk_frames.tres` | 위 시트를 잘라 담은 `SpriteFrames` (8fps) |

## 시트 규약

**격자**: 가로 3프레임(워크 사이클) x 세로 4방향. **셀 크기는 시트마다 다르다**(돌창병 524x492, 매머드 424x496, 벨로시랩터 396x492) — 정규화 도구가 그 시트의 내용 폭에 맞춰 정한다(벨로시랩터 2 는 424x496). 한 시트 안에서는 모든 셀이 같다.

**행 순서**는 화면 방향 기준 **하 / 좌 / 상 / 우**이며, Godot의 `+y`가 아래인 좌표계를 따른다.

| 행 | 애니메이션 이름 | 보는 방향 |
|---|---|---|
| 0 | `walk_down` | 정면(아래) |
| 1 | `walk_left` | 왼쪽 |
| 2 | `walk_up` | 뒷모습(위) |
| 3 | `walk_right` | 오른쪽 |

**프레임 순서**는 `0 → 1 → 2` 반복이다. 0번과 2번이 좌·우 접지 포즈이고 1번이 중간 스트라이드라
그대로 이으면 표준 3프레임 보행이 된다. **0번이 정지 포즈**이며, 적이 멈추면 여기에 고정된다.

이름 목록과 방향 판정의 단일 출처는 [`WalkAnimation`](../../../entities/shared/WalkAnimation.gd)다(적과 플레이어가 같이 쓴다).
이 규약만 지키면 시트를 갈아끼워도 스크립트를 고칠 필요가 없다.

## 배정 규칙

`EnemyData.walk_frames`에 `SpriteFrames`를 지정하고, 씬에 `AnimatedSprite2D` 노드를 둔다.
`EnemyBase._apply_data()`가 둘이 모두 있을 때만 애니메이션 경로를 켜고 `Sprite2D`(도형)를 숨긴다.
`walk_frames`를 비우면 지금까지처럼 `sprite_texture` 정지 이미지로 돌아간다.

- `walk_sprite_scale`: 표시 배율. 시트마다 원본 해상도가 달라 `sprite_scale`과 따로 둔다.
- `walk_sprite_offset`: 표시 오프셋(px, 배율 적용 전). **셀이 캐릭터보다 크므로 반드시 맞춰야 한다.**
  안 맞추면 스프라이트가 발밑이 아니라 몸 한가운데를 원점으로 잡아 캐릭터가 공중에 뜬다.

`tint`는 **입히지 않는다**. `tint`는 흰색 도형 플레이스홀더를 칠하려고 둔 값이라,
색이 있는 실제 아트에 곱하면 색이 죽는다.

### `stone_spearman` 실측값

셀 높이 492, 아래 여백 8 → 셀 안 발 기준선은 `y = 483`, 셀 중심 기준 `+237`이다.
충돌 캡슐(높이 28)의 바닥인 `y = +14`에 발을 맞추려면:

```
offset.y = 14 / 0.25 - 237 = -181
```

배율 `0.25`에서 캐릭터 키는 `474 x 0.25 ≈ 119px`로, 파티 멤버(64px 도형 x 2 = 128px)와 비슷하다.

## 새 시트를 추가할 때

[`tools/normalize_walk_sheet.gd`](../../../tools/normalize_walk_sheet.gd)가 아래 정규화를 대신 한다.

```bash
godot --headless --path . --script res://tools/normalize_walk_sheet.gd -- <입력png> <출력res경로>
```

도구는 셀 크기·발 기준선·`SpriteFrames` region·`walk_sprite_offset` 계산식을 출력하고,
**내부 절단선 위에 내용 픽셀이 있으면**(= 프레임이 겹쳐 잘렸다는 뜻) 경고를 낸다.
프레임 폭 차이는 잘림의 근거가 아니라 포즈 차이이므로 정보성 안내로만 나온다.

### 시트별 손실 여부

| 시트 | 프레임 겹침 | 손실 |
|---|---|---|
| `stone_spearman_walk.png` | 뒷모습 행에서 겹침 | 머리카락 끝 7px·9px (폭 507px의 1.5% 미만) |
| `mammoth_beastfolk_walk.png` | 없음 | **없음** |
| `velociraptor_beastfolk_walk.png` | 없음 | **없음** |
| `velociraptor_beastfolk_2_walk.png` | 없음 | **없음** |

## 원본에서 돌창병 시트를 만든 방법

생성기 산출물(1603x2200)은 그대로 쓸 수 없었다.

1. **셀 폭이 정수로 나뉘지 않았다** (1603 / 3). 3행(뒷모습)은 머리카락이 셀 경계를 넘어
   옆 프레임과 겹쳐서, 균등 격자로 자르면 잘려 나갔다.
2. **옆모습 행(1, 3)은 프레임마다 캐릭터가 셀 안에서 왼쪽으로 약 29px씩 흘러갔다.**
   그대로 재생하면 제자리걸음이 아니라 옆으로 미끄러진다.

그래서 프레임별 내용 경계상자를 재서 균일 격자로 다시 배치했다.

- **가로**: 프레임마다 경계상자 중심을 셀 중심에 맞췄다. 한 행 안에서 경계상자 **폭이 모두 같아서**
  이 이동은 순수 평행이동 제거이고 포즈 정보를 잃지 않는다.
- **세로**: 행 단위로 맞췄다. 행 안 프레임끼리의 높이차(발 들기)는 보존하고, 행의 바닥선만
  모든 행이 공유하는 기준선에 맞췄다.
- **리샘플링은 하지 않았다.** 정수 픽셀 복사만 해서 원본 해상도를 그대로 유지한다.
  (원본은 세로 배율 5.0, 가로 4.96으로 업스케일되어 있어 정수 격자가 아니다.
  5배 다운스케일하면 5x5 블록의 7.9%가 색이 섞여 픽셀이 뭉개진다.)

**알려진 손실**: 3행(뒷모습)의 0·1번 프레임은 옆 프레임과 겹친 구간을 열 밀도 골짜기에서
잘랐다. 바깥쪽 머리카락 끝이 각각 7px, 9px(전체 폭 507px의 1.5% 미만) 빠져 있다.
매머드 수인 시트는 프레임이 겹치지 않아 이 손실이 없다.

임포트는 `mipmaps/generate=true`로 두었다. 원본이 크고 화면에서는 0.25배로 줄여 그리므로
밉맵이 없으면 이동할 때 픽셀이 지글거린다.

익룡 여왕은 SD 비율과 금장·헤드피스 디테일을 보존하기 위해 96x96 셀을 2배 확대한다.
화면 키는 기존 설계와 같은 144px이다. `PterosaurQueen.tscn`의
`AnimatedSprite2D.texture_filter`를 nearest로 고정해 경계가 흐려지지 않게 한다.
