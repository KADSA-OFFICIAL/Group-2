# data/characters

캐릭터(`CharacterData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`CharacterDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해 `character_id`로 조회를 제공한다.

- 정의 스키마: [`entities/character/CharacterData.gd`](../../entities/character/CharacterData.gd)

## 로스터는 정확히 6명이다

설계 정본([docs/combat-screen-design.md](../../docs/combat-screen-design.md) §1.1)에 따라 **순혈 3 + 겸직 3**으로 구성한다.
파티는 이 6명 중 3명을 뽑아 만든다.

| 파일 | character_id | 역할 | 색 |
|---|---|---|---|
| `shipduck.tres` | `shipduck` | 탱커 (순혈) | 파랑 |
| `ranged_pure.tres` | `ranged_pure` | 원거리딜러 (순혈) | 빨강 |
| `buffer_pure.tres` | `buffer_pure` | 버퍼 (순혈) | 초록 |
| `mina.tres` | `mina` | 탱커 + 버퍼 (겸직) | 청록 |
| `ranged_tank.tres` | `ranged_tank` | 원거리딜러 + 탱커 (겸직) | 보라 |
| `buffer_ranged.tres` | `buffer_ranged` | 버퍼 + 원거리딜러 (겸직) | 노랑 |

**여기에 캐릭터를 더 추가하면 로스터 구조가 깨진다.** 시너지 조합 특성(§8.2)이 "6명 중 3명"을 전제로 계산되어 있다.

## 겸직 지정 방법

겸직은 `role`(주 역할) + `secondary_role`로 표현한다.
`secondary_role`은 `NONE`이 기본값이라 지정하지 않으면 순혈이 된다.

- `Role`: TANK=0, RANGED_DEALER=1, BUFFER=2
- `SecondaryRole`: NONE=0, TANK=1, RANGED_DEALER=2, BUFFER=3 (Role보다 1씩 밀려 있다)

역할 조회는 항상 `get_roles()`를 쓴다. 겸직이면 2개를 반환하며, 시너지 카운트가 이 값을 센다.

## 현재 상태: 플레이스홀더

**`shipduck`을 제외한 5명은 역할 구성만 채운 플레이스홀더다.**

- **이름·개성·설정은 미정**이라 표시 이름을 역할로 두었다. 임의로 짓지 않았다.
- **스텟은 `PlayerStats` 기본값**이다. 캐릭터별 밸런스는 미정이다.
- **고유 스킬(`skills`)은 비어 있다.**
  - 설계 제약: 고유 스킬 중 **일부는 힐 또는 보호막을 제공해야 한다.** 버퍼 3단계 시너지가 이를 전제로 하기 때문이다(§3, §8.1).
- 외형은 도형 플레이스홀더 단계이므로 **역할별 색**으로만 구분한다. 겸직은 두 역할 색을 섞었다.
  - **예외: `buffer_pure`는 실제 아트(4방향 워크 시트)를 쓴다.** `walk_frames`가 채워져 있으면
    `Player`가 `Sprite2D`(도형)를 숨기고 `AnimatedSprite2D`로 그린다.
    시트 규약과 저작 방법은 [`assets/sprites/characters/README.md`](../../assets/sprites/characters/README.md).
    `tint`는 전투 스프라이트에 입히지 않지만, 메타 화면이 도형 스와치 색으로 계속 쓰므로 값은 남겨 두었다.


각 `.tres`는 **자기 `PlayerStats` 서브리소스**를 갖는다. 공유 인스턴스를 쓰면 한 캐릭터의 스텟 변경이 다른 캐릭터에 번지므로, 새 캐릭터를 추가할 때도 서브리소스를 따로 만든다.
