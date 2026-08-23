# data/skills

캐릭터 고유 스킬(`SkillData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`CharacterData.skills` 가 이 리소스를 직접 참조한다 — 스킬 전용 `Database` autoload 는 없다.
스킬은 캐릭터에 속하므로 조회 경로가 `CharacterDatabase` → `CharacterData.skills` 하나면 충분하다.

- 정의 스키마: [`entities/character/SkillData.gd`](../../entities/character/SkillData.gd)

## 스킬은 캐릭터별 고유 6종이다

설계 정본([docs/combat-screen-design.md](../../docs/combat-screen-design.md) §3):

- **역할 단위 스킬은 존재하지 않는다.** 역할 메커니즘(표식/기절, 평타 스택, 처형)은
  **시너지 1단계가 제공**하고(§8.1), 고유 스킬은 그 위에 얹히는 **개별 유닛 개성**(§8 티어2)이다.
- 그래서 새 스킬을 저작할 때 표식·스택·처형을 다시 만들지 않는다. 그것은 시너지의 몫이다.

### [확정 제약] 힐 또는 보호막

**고유 스킬 중 일부는 힐 또는 보호막을 제공해야 한다.** 버퍼 3단계가
*"제공한 힐/보호막 양에 비례한 추가 피해"*이고, 문서에 있는 다른 보호막 출처(원거리 3단계)는
§8.2 상 버퍼 3단계와 **절대 동시에 켜지지 않기** 때문이다.

| 스킬 | 캐릭터 | 힐/보호막 | 비고 |
|---|---|---|---|
| `mina_shield_burst.tres` | `mina` (탱커+버퍼) | **보호막** | 이 제약을 충족하는 스킬 |

나머지 5명의 고유 스킬은 미정이다(§3 [미정]).

## 수치는 전부 [임시값]이다

발동 로직이 아직 없어 실측이 불가능하다. 지금 값은 기존 수치와의 상대 비교로 잡은 것이다.

| 값 | 기준 |
|---|---|
| `shield_percent` | 원거리 3단계 보호막 한도(`CombatTuning.shield_max_percent` = 0.3)의 절반 |
| `aoe_radius` | 근접 공격 사거리(`EnemyData.attack_range` 기본값 45)의 2배 |
| `base_power` | 선례 없음 — 발동 구현 후 조정 |

`base_power` 는 `scales_with_faith` 가 켜져 있으면 `PlayerStats.get_goddess_skill_boost()`
배수를 탄다. 신앙심이 높은 캐릭터의 스킬이 더 세지는 것이 이 필드의 목적이다.

## 대상·트리거는 아직 필드가 아니다

"누구에게 주는가"와 "언제 터지는가"는 `description` 이 들고 있다.
저작된 스킬이 1종뿐이라 표본 하나로 프레임워크를 만들면 그 모양이 한 캐릭터 기준으로 굳는다.
발동을 구현하는 이슈에서 6종을 함께 보고 필드로 승격한다.
