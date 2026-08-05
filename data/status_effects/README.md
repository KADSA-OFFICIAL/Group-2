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
