# data/status_effects

버프/디버프(`StatusEffectData`) 리소스(`*.tres`)를 이 폴더에 저작한다.
`StatusEffectDatabase`(autoload)가 시작 시 이 폴더의 모든 `.tres`를 로드해
`effect_id`로 조회를 제공한다.

- 정의 스키마: [`entities/combat/StatusEffectData.gd`](../../entities/combat/StatusEffectData.gd)
- 종류(Kind): 스텟 변경(`STAT_MOD`) / 행동 제약(`CONTROL`) / 지속 피해·회복(`PERIODIC`) / 게이지 누적(`GAUGE`)
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
