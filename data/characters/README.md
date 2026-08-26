# data/characters

캐릭터(`CharacterData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`CharacterDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해 `character_id`로 조회를 제공한다.

- 정의 스키마: [`entities/character/CharacterData.gd`](../../entities/character/CharacterData.gd)

## 로스터는 정확히 6명이다

설계 정본([docs/combat-screen-design.md](../../docs/combat-screen-design.md) §1.1)에 따라 **순혈 3 + 겸직 3**으로 구성한다.
파티는 이 6명 중 3명을 뽑아 만든다.

| 파일 | character_id | 역할 | 색 |
|---|---|---|---|
| `shipduck.tres` | `shipduck` | 탱커 + 버퍼 (겸직) | 파랑 |
| `ranged_tank.tres` | `ranged_tank` | 원거리딜러 + 탱커 (겸직) | 빨강 |
| `harang.tres` | `harang` | 버퍼 + 원거리딜러 (겸직) | 초록 |
| `mina.tres` | `mina` | 탱커 (순혈) | 청록 |
| `taehee.tres` | `taehee` | 원거리딜러 (순혈) | 보라 |
| `seola.tres` | `seola` | 버퍼 (순혈) | 연청 |

**여기에 캐릭터를 더 추가하면 로스터 구조가 깨진다.** 시너지 조합 특성(§8.2)이 "6명 중 3명"을 전제로 계산되어 있다.

## 이 폴더는 로스터 전용이다

`CharacterData` 는 **플레이어가 편성해 쓰는 인물**의 정의다. 역할·`PlayerStats`·장비 슬롯을
갖고 있고, 로스터를 순회하는 시스템들(`PlayerProfile` 의 성장 배수, `EquipmentSystem` 의 착용
저장 등)이 `CharacterDatabase` 에 있는 것은 전부 자기가 다룰 대상이라는 전제로 쓰여 있다.

그래서 로스터가 아닌 인물은 여기 두지 않는다 (#202):

| 인물 | 어디에 |
|---|---|
| 스토리에만 나오는 화자 (소꿉친구 등) | [`data/story/cast`](../story/cast) — `StoryCastData` |
| 적 (여신도 최종보스로 저작 예정) | `data/enemies` — `EnemyData` |

`playable` 플래그(#216)는 편성 목록을 거르는 장치이고, **여기 둘 수 있는 근거가 아니다.**
거르는 것을 기억해야 하는 곳이 계속 늘어나기 때문이다.

## 겸직 지정 방법

겸직은 `role`(주 역할) + `secondary_role`로 표현한다.
`secondary_role`은 `NONE`이 기본값이라 지정하지 않으면 순혈이 된다.

- `Role`: TANK=0, RANGED_DEALER=1, BUFFER=2
- `SecondaryRole`: NONE=0, TANK=1, RANGED_DEALER=2, BUFFER=3 (Role보다 1씩 밀려 있다)

역할 조회는 항상 `get_roles()`를 쓴다. 겸직이면 2개를 반환하며, 시너지 카운트가 이 값을 센다.

## 현재 상태: 플레이스홀더

**`shipduck`·`mina`·`taehee`·`seola`·`harang` 를 제외한 1명(`ranged_tank`)만 역할 구성을 채운 플레이스홀더다.**

> 미나와 shipduck 의 역할은 #259 에서 맞바꿨다 — 미나가 순혈 탱커, shipduck 이 겸직(탱커+버퍼)이다.
> 미나는 로스터에서 유일하게 **스킬 게이지**(`skill_gauge_max` / `skill_gauge_gain_per_attack`)를 갖는다.
> 파티 전체의 평타가 채우고, 고유 스킬 둘이 게이지에 비례해 세지며 시전 시 전량 소모한다.
>
> 설아는 #276 에서 **겸직(버퍼+원거리) -> 순혈 버퍼**로 옮겼다. 태희(#263)와 같은 구조의 이동이다.
> 설아가 비운 겸직 자리는 플레이스홀더 `buffer_ranged` 가 이어받았고, 순혈 자리에 있던 `buffer_pure` 는 삭제했다.
> 그 겸직 자리는 #315 에서 **하랑**(`harang`)이 이름을 받아 확정했다.
> **`buffer_pure` 의 아트(워크 시트 + 초상)는 `buffer_ranged`(지금의 `harang`)가 물려받았다.** `buffer_pure` 는 이름이
> 정해지지 않은 채 아트만 먼저 들어온 플레이스홀더였고, 그 인물은 여전히 로스터에 자리가 필요하다 —
> 아트를 버리면 모션 있는 캐릭터가 4명에서 3명으로 준다. 에셋 **파일 이름은 바꾸지 않았다**
> (`buffer_pure_walk.png` 그대로): 재임포트와 UID 갱신이 따라붙는 변경이라, 이름이 역사적 흔적이라는
> 것을 적어 두는 편이 싸다.
>
> 태희는 #263 에서 **겸직(원거리+탱커) → 순혈 원거리딜러**로 옮겼다. 태희가 비운 겸직 자리는
> 플레이스홀더 `ranged_tank` 가 이어받았고, 태희가 들어간 순혈 자리에 있던 `ranged_pure` 는
> 삭제했다(플레이스홀더가 둘일 이유가 없다). 스텟 프로필은 **슬롯을 따라 맞바꿨다.**
> 태희는 로스터에서 유일하게 **원거리 평타**(`basic_attack_projectile_speed` 등)를 쓴다 —
> 근접/원거리는 역할이 아니라 캐릭터의 성질이라 `CharacterData` 가 소유한다.

- **이름·개성·설정은 미정**이라 표시 이름을 역할로 두었다. 임의로 짓지 않았다.
- **스텟은 `PlayerStats` 기본값**이다. 캐릭터별 밸런스는 미정이다.
- **고유 스킬(`skills`)은 `mina`(#259)·`taehee`(#263)·`seola`(#276) 셋이 저작되어 있고 나머지 3명은 비어 있다.**
  - 설계 제약: 고유 스킬 중 **일부는 힐 또는 보호막을 제공해야 한다.** 버퍼 3단계 시너지가 이를 전제로 하기 때문이다(§3, §8.1). 미나 보호막에 더해 **설아의 힐이 두 번째 출처**가 되었다.
- 외형은 도형 플레이스홀더 단계이므로 **역할별 색**으로만 구분한다. 겸직은 두 역할 색을 섞었다.
  - **예외: `buffer_pure`는 실제 아트(4방향 워크 시트)를 쓴다.** `walk_frames`가 채워져 있으면
    `Player`가 `Sprite2D`(도형)를 숨기고 `AnimatedSprite2D`로 그린다.
    시트 규약과 저작 방법은 [`assets/sprites/characters/README.md`](../../assets/sprites/characters/README.md).
    `tint`는 전투 스프라이트에 입히지 않지만, 메타 화면이 도형 스와치 색으로 계속 쓰므로 값은 남겨 두었다.


각 `.tres`는 **자기 `PlayerStats` 서브리소스**를 갖는다. 공유 인스턴스를 쓰면 한 캐릭터의 스텟 변경이 다른 캐릭터에 번지므로, 새 캐릭터를 추가할 때도 서브리소스를 따로 만든다.
