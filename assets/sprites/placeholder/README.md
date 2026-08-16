# assets/sprites/placeholder

전투 화면용 **도형 플레이스홀더**. 실제 아트가 정해지기 전까지 쓴다.
(설계 정본 [docs/combat-screen-design.md](../../../docs/combat-screen-design.md) §0: 아트는 무시하고 도형으로 대체한다.)

| 파일 | 도형 | 쓰는 곳 |
|---|---|---|
| `shape_tank.svg` | 사각형 | 탱커 |
| `shape_ranged.svg` | 삼각형 | 원거리딜러 |
| `shape_buffer.svg` | 마름모 | 버퍼 |
| `shape_enemy.svg` | 육각형 | 적 |

## 색은 여기서 정하지 않는다

도형은 **흰색**이다. 실제 색은 각 `CharacterData` / `EnemyData`의 `tint`가 `self_modulate`로 입힌다.
흰색이어야 `tint` 값이 곱해졌을 때 그 색 그대로 나온다.

## 배정 규칙

- `sprite_texture` 필드에 지정한다. `Player._apply_data()`와 `EnemyBase._apply_data()`가 이 값을 읽어 스프라이트에 넣으므로 **스크립트 변경 없이 데이터만으로** 바뀐다.
- **겸직 캐릭터는 주 역할(`role`)의 도형**을 쓴다. 두 역할을 한 도형으로 표현할 방법이 없어서다.

실제 아트가 정해지면 이 폴더를 통째로 대체하고 `sprite_texture`만 바꿔 끼우면 된다.
