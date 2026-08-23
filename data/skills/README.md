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
| `mina_attack_heal_burst.tres` | `mina` (탱커+버퍼) | **회복** | 평타 패시브 (아래) |

나머지 5명의 고유 스킬은 미정이다(§3 [미정]).

## 입력 슬롯 (input_slot)

고유 스킬 키는 **`Q` 와 `E`** 다(docs §4). 어느 키에 걸리는지는 **스킬 자신이 선언한다**
(`SkillData.input_slot`) — `CharacterData.skills` 는 배열이라 순서만 있고, 그 배열에는
키로 쓰지 않는 평타 패시브도 함께 들어 있어 순서로 슬롯을 정할 수 없다.

| 슬롯 | 뜻 |
|---|---|
| `NONE` (기본) | 키로 발동하지 않는다 (평타 패시브 등) |
| `Q` / `E` | 그 키로 발동한다 |

조회는 항상 `CharacterData.get_skill_for_slot()` 을 쓴다. 화면·입력이 배열을 각자 훑으면
슬롯 해석이 흩어진다(`get_roles()` 와 같은 이유).

| 캐릭터 | `Q` | `E` |
|---|---|---|
| `mina` | (비어 있음) | `mina_shield_burst` |

## 평타 패시브 (every_n_attacks)

`every_n_attacks` 가 0 보다 크면 **플레이어가 쓰는 발동형 스킬이 아니라 평타 주기 패시브**다.
`Player.try_attack()` 이 쿨다운을 소비한 직후 평타 횟수를 세고, 주기가 맞으면 발동한다.

- **"발생" 기준이고 적중이 아니다.** 처형으로 끝난 평타와 적을 죽인 평타도 세어진다.
  (지금은 사거리 안에 적이 없으면 평타 자체가 나가지 않아 발생 = 적중이다.)
- 시너지가 아니라 캐릭터 개성(§3 티어2)이므로 **파티 구성과 무관하게 항상 작동한다.**
- 패시브를 저작하지 않은 캐릭터의 평타는 이전과 완전히 같다 — 데이터가 없으면 아무 일도 하지 않는다.

`heal_missing_hp_percent` 는 **최대 체력이 아니라 잃은 체력** 기준이다. 체력이 가득 차 있으면
회복이 0이고, `heal_to_aoe_damage_percent` 가 회복량에 비례하므로 광역 피해도 0이 된다.
몰릴수록 세지는 역전 장치인 것이 의도다.

버퍼 3단계(`CombatTuning.heal_to_damage_percent`)와 발상이 같지만 **별개 채널**이다.
그쪽은 파티 구성에 따라 켜지고 꺼지는 시너지고, 이쪽은 캐릭터에 붙어 항상 있다.

## 수치는 전부 [임시값]이다

발동 로직이 아직 없어 실측이 불가능하다. 지금 값은 기존 수치와의 상대 비교로 잡은 것이다.

| 값 | 기준 |
|---|---|
| `shield_percent` | 원거리 3단계 보호막 한도(`CombatTuning.shield_max_percent` = 0.3)의 절반 |
| `aoe_radius` | 근접 공격 사거리(`EnemyData.attack_range` 기본값 45)의 2배 |
| `base_power` | 선례 없음 — 발동 구현 후 조정 |
| `every_n_attacks` | 3 — 사용자 확정 (임시값 아님) |
| `heal_missing_hp_percent` | 0.2 — 잃은 체력의 1/5. 탱커 3단계 기절 회복(`stun_heal_percent` 0.05, 최대 체력 기준)과 다른 기준이라 직접 비교는 안 된다 |
| `heal_to_aoe_damage_percent` | 0.5 — 버퍼 3단계 `heal_to_damage_percent` 와 같은 비율에서 출발 |

`base_power` 는 `scales_with_faith` 가 켜져 있으면 `PlayerStats.get_goddess_skill_boost()`
배수를 탄다. 신앙심이 높은 캐릭터의 스킬이 더 세지는 것이 이 필드의 목적이다.

## 대상·트리거는 아직 필드가 아니다

"누구에게 주는가"와 "언제 터지는가"는 `description` 이 들고 있다.
저작된 스킬이 1종뿐이라 표본 하나로 프레임워크를 만들면 그 모양이 한 캐릭터 기준으로 굳는다.
발동을 구현하는 이슈에서 6종을 함께 보고 필드로 승격한다.
