# data/status_effects

버프/디버프(`StatusEffectData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`StatusEffectDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해
`effect_id`로 조회를 제공한다.

- 정의 스키마: [`entities/combat/StatusEffectData.gd`](../../entities/combat/StatusEffectData.gd)
- 종류(Kind): 스텟 변경(`STAT_MOD`) / 행동 제약(`CONTROL`) / 지속 피해·회복(`PERIODIC`) / 게이지 누적(`GAUGE`) / 행동 부여(`EMPOWER`) / 강제 대상 지정(`TAUNT`)
- 중첩(Stacking): 지속시간 갱신(`REFRESH`) / 세기 누적(`STACK_INTENSITY`) / 무시(`IGNORE`) — 효과별로 지정한다.

## 수치 출처 (단일 출처 원칙)

확정 수치는 [`autoload/CombatConfig.gd`](../../autoload/CombatConfig.gd)가 유일한 출처다.
`.tres`에 같은 값을 다시 적지 말고, 해당 필드를 **0으로 비워** `CombatConfig` 폴백을 쓴다.

- `gauge_threshold` = 0 → `CombatConfig.MARK_THRESHOLD`
- `gauge_gain_per_hit` = 0 → `CombatConfig.MARK_GAIN_PER_HIT`

## 대상 (Target)

캐릭터와 적 모두에 적용된다. `Player.stats`와 `EnemyBase.stats`가 둘 다 `PlayerStats`이므로
`PlayerStats`의 **버프 채널**(`set_buff_bonuses()`)이 공통 적용 지점이다.
이 채널은 장비 채널(`equip_*`)과 독립적이라 서로 덮어쓰지 않는다.

실제 효과 수치/밸런스는 팀이 저작한다.

## EMPOWER — 행동 부여 (#276)

`Kind` 의 다섯 번째 종류다. 스텟(`STAT_MOD`)과 나눈 이유: 흡혈과 처형은 **숫자가 아니라 행동 규칙**이다.
`PlayerStats` 에 채널이 없고, 있어서도 안 된다 — 스텟은 값이고 이쪽은 분기다.

| payload | 하는 일 |
|---|---|
| `grants_lifesteal_percent` | 걸린 동안 대상이 **준 모든 피해** 중 회복되는 비율. 평타뿐 아니라 스킬·광역 패시브까지 전부다. 기준은 **적이 실제로 잃은 체력**이다 — `take_damage()` 가 남은 체력으로 잘라서 반환하므로, 처형처럼 과잉 피해를 넣는 경로도 부풀지 않는다 |
| `grants_execute` | 걸린 동안 대상이 **평타로 처형**할 수 있다. 버퍼 1단계 시너지가 꺼져 있어도, 대상에게 디버프가 없어도 된다 |

**효과가 스스로 무언가를 하지 않는다.** 부여받은 쪽(`Player`)이 매 판정마다
`StatusEffectSystem.get_granted_lifesteal()` / `grants_execute()` 로 물어본다.
지속시간이 끝나면 그 조회가 0/false 로 돌아갈 뿐이다. `CONTROL` 의 `_blocks()` 와 같은 모양이다.

### 기존 채널과 겹친다 (대체하지 않는다)

| | 출처 | 범위 | 조건 |
|---|---|---|---|
| 원거리 3단계 피흡 | `CombatTuning.lifesteal_percent` | **평타로 준 피해**만 | 원거리 3카운트 파티 (상시) |
| EMPOWER 흡혈 | `StatusEffectData.grants_lifesteal_percent` | **준 모든 피해** | 효과가 걸린 동안만 |

둘 다 켜져 있으면 평타는 **양쪽에서** 회복한다. 출처가 다른 별개 효과이므로 의도된 동작이다.
구현도 나뉘어 있다: 평타 한정은 `Player._resolve_attack_hit()` 이, 전체는 `EnemyBase.take_damage()` 가
피해를 준 쪽에 알리는 `on_damage_dealt()` 훅이 담당한다.

**왜 훅이 받는 쪽에 있는가**: "준 모든 피해"는 평타·스킬·광역을 가리지 않는다. 그 전부를 훑으려면
피해를 내는 자리마다 같은 코드를 붙여야 하는데, 피해가 **들어오는** 곳은 한 곳이다.
한 곳에서 알리면 새 피해 경로가 생겨도 자동으로 포함된다.

### 버프이므로 `is_debuff = false` 다

아군에게 걸리는 효과가 디버프로 세어지면 `has_any_debuff()` 가 true 가 되어,
**아군이 버퍼 처형의 조건을 만족시키게 된다.** 이 필드는 표시용이 아니다.

## TAUNT — 강제 대상 지정 (#328)

`Kind` 의 여섯 번째 종류다. 걸린 동안 대상은 **효과를 건 주체만** 공격한다.

**payload 가 없다.** 도발이 필요한 정보는 "누가 걸었는가" 하나이고, 그것은
`StatusEffectSystem` 이 효과 인스턴스마다 이미 들고 있다(`get_source`).

- 조회는 `StatusEffectSystem.get_taunt_source(target)` 다. `CONTROL` 의 `_blocks()`,
  `EMPOWER` 의 `get_granted_lifesteal()` 과 같은 모양이라 부르는 쪽이 효과 목록을 훑지 않는다.
- 판정은 소비하는 쪽(`EnemyBase._resolve_target()`)이 한다. 효과는 "그런 상태이다"만 표시한다.
- **탐지 범위를 무시한다.** 사거리 안에서만 듣는 도발은 이미 오고 있던 적에게는 아무 일도
  하지 않는 것과 같다. 도발의 값어치는 멀리 있는 적을 끌어오는 것이다.
- 여러 도발이 겹치면 **남은 시간이 가장 긴 것**(= 가장 나중에 걸린 것)이 이긴다.
  도발은 "지금 나를 봐"라는 조작이므로 마지막 조작이 유효해야 한다.
- 주체가 죽어 해제되면 조회가 `null` 이 되어 적은 지금까지의 대상 선정으로 돌아간다.
  적이 시체를 향해 계속 걸어가지 않는다.

## 동반 효과 — 종류가 섞인 상태를 담는 법 (#328)

한 `StatusEffectData` 의 `kind` 는 하나다. 그런데 스킬 하나가 만드는 상태는 종류가 섞여 있다 —
하랑 E 는 공속(`STAT_MOD`) + 흡혈(`EMPOWER`) + 자기 지속 피해(`PERIODIC`)를 한꺼번에 건다.

`kind` 를 여러 개 갖게 하지 않았다. 그러면 조회하는 곳(`_sync_stat_mods`,
`get_granted_lifesteal`, `_apply_periodic`)이 전부 "이 효과가 그 종류이기도 한가"를 묻게 되어
종류로 갈라 둔 구조가 사라진다.

대신 **효과는 종류마다 하나로 유지하고, 함께 걸리는 관계만 데이터로 적는다**:
`also_apply_effect_id` 가 다음 효과를 가리키고, `StatusEffectSystem.apply()` 가 연쇄로 건다.

| 사슬 | 효과 | kind | 하는 일 |
|---|---|---|---|
| 1 | `harang_rampage` | `STAT_MOD` | 공속 +200% |
| 2 | `harang_rampage_leech` | `EMPOWER` | 준 모든 피해 50% 흡혈 |
| 3 | `harang_rampage_burn` | `PERIODIC` | 1초마다 자기 최대체력 7% 피해 |

| 사슬 | 효과 | kind | 하는 일 |
|---|---|---|---|
| 1 | `taunt` | `TAUNT` | 도발한 대상만 공격 |
| 2 | `taunt_frenzy` | `STAT_MOD` | 공속 +200% (도발당한 적이 얻는다) |

규약 셋:

- **스킬 쪽에 효과 목록을 두지 않는다.** "이 셋은 늘 같이 걸린다"는 것은 스킬의 성질이 아니라
  효과 자신의 성질이라, 다른 스킬이 같은 상태를 걸 때도 따라와야 한다.
- **해제는 연쇄되지 않는다.** 각자의 `duration` 으로 만료되므로 함께 걸리는 효과들은
  보통 **같은 지속시간**을 갖는다. 하나만 `remove()` 하면 나머지는 남는다.
- **순환은 시스템이 끊는다.** `A -> B -> A` 로 저작되어도 한 번 건 효과는 그 연쇄에서 다시 걸지 않는다.
  `validate()` 는 자기 자신을 가리키는 경우를 저작 단계에서 잡는다.

## 최대 체력 비례 지속 피해 (#328)

`PERIODIC` 의 `tick_damage`(절대값)와 **별개 채널**로 `tick_max_hp_percent` 가 있다. 더해진다.

비율인 이유: "그릇의 몇 퍼센트"가 계약인 피해가 있다(하랑 E 의 자기 피해 = 7초 동안 최대체력 49%).
절대값으로 적으면 성장·장비로 체력이 늘 때마다 같이 고쳐야 한다.

`tick_ignores_defense` 는 **자기 자신에게 내는 대가**에만 쓴다. 방어 공식이 `raw^2/(raw+def)` 라
작은 피해를 크게 깎아서, 그대로 두면 거래가 방어력 스텟에 따라 흔들린다
(하랑의 7% = 63 이 방어를 받으면 14 로 줄어 스펙의 22% 만 들어간다).
**보호막은 그대로 받아 낸다** — 무시하는 것은 방어력뿐이다.
