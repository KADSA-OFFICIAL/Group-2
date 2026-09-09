extends Resource
class_name TurnCombatTuning

# 턴제 전투 튜닝 수치의 정의 스키마 (#450).
#
# 실제 값은 `data/combat/turn_combat_tuning.tres`에 저작하며 **그 파일이 수치의 단일 출처**다.
# `TurnCombatConfig`(autoload)가 로드해 `TurnCombatConfig.tuning.<필드>`로 제공한다.
# 기존 실시간 전투의 `CombatTuning`과 같은 패턴이며, **그 리소스를 대체하지 않는다** —
# 실시간 수치(대시·쿨다운·감지 범위)와 턴제 수치(AV·인성치·버킷)는 서로 다른 축이다.
#
# 값의 성격: 아래 전부 **[임시값]**이다. 출처는 설계서 §4.15 기준선이며 밸런싱 대상이다.
#
# 참고: docs/turn-combat-design.md

# ===== 행동값 / 타임라인 (Action Value) =====
@export_group("행동값")
## `AV = av_scale / SPD`. 설계서는 HSR의 1/10 스케일(1000)을 쓴다 — 숫자를 작게 유지해
## 타임라인 UI에 그대로 띄울 수 있게 하려는 것이다.
@export var av_scale: float = 1000.0
## 1사이클이 끝나는 누적 AV. 이후 사이클마다 `cycle_step`씩 늘어난다.
## N사이클 종료 누적 AV = `cycle_first + cycle_step x (N - 1)`.
@export var cycle_first: float = 15.0
@export var cycle_step: float = 10.0
## 타임라인에 미리 보여주는 행동 개수. 설계서 체크리스트는 8개 이상을 요구한다.
@export var timeline_preview_count: int = 8

# ===== 행동 조작 가드레일 (Action manipulation) =====
@export_group("행동 조작")
## 같은 대상에게 행동 앞당김을 **연속으로** 걸었을 때 2회차부터 곱해지는 효율.
## 무한 턴 루프를 막는 장치다 (설계서 §4.13). 1.0으로 두면 루프가 성립한다.
@export var advance_repeat_efficiency: float = 0.5
## 한 턴 안에 얻을 수 있는 추가 턴의 하드캡.
@export var extra_turn_cap: int = 2
## 속도 소프트캡. 초과분은 `speed_softcap_efficiency`만큼만 반영한다.
@export var speed_softcap: int = 220
@export var speed_softcap_efficiency: float = 0.5

# ===== 공명 포인트 (Resonance) =====
@export_group("공명 포인트")
## 파티 공유 최대치. 특정 캐릭터가 +1~2 확장할 수 있다.
@export var resonance_max: int = 5
## 전투 시작 시 보유량.
@export var resonance_start: int = 3
## 일반공격이 버는 양.
@export var resonance_gain_basic: int = 1

# ===== 오의 게이지 (Ultimate energy) =====
@export_group("오의")
@export var energy_basic: int = 20
@export var energy_skill: int = 30
@export var energy_on_hit_taken: int = 10
@export var energy_on_kill: int = 10
@export var energy_on_break: int = 15
@export var energy_after_ultimate: int = 5
@export var energy_trait: int = 10
## **한 유닛의 턴 사이에** 발동할 수 있는 오의 개수. 연쇄 오의 폭주 방지 (설계서 §4.3.2).
@export var ultimate_per_turn_cap: int = 2

# ===== 열기 (Heat) =====
#
# 파티 공유 온도 게이지. 같은 스킬 반복 스팸을 시스템적으로 억제한다.
# 설계서가 **선택적 시스템**으로 표시한 축이다 — 재미가 검증되지 않으면
# `heat_enabled = false`로 끄면 나머지 시스템은 온전히 굴러간다.
@export_group("열기")
@export var heat_enabled: bool = true
@export var heat_max: float = 100.0
@export var heat_start: float = 20.0
## 냉각/최적 구간의 경계. 0~40 냉각, 40~70 최적, 70~100 과열.
@export var heat_optimal_min: float = 40.0
@export var heat_optimal_max: float = 70.0
@export var heat_gain_skill: float = 8.0
@export var heat_gain_ultimate: float = 15.0
@export var heat_gain_basic: float = -5.0
@export var heat_decay_per_turn: float = -3.0
## 구간별 피해 배율 변화분. 최종 배수는 (1.0 + 값).
@export var heat_cold_damage: float = -0.10
@export var heat_optimal_damage: float = 0.15
@export var heat_overheat_damage: float = -0.20
## 구간별 **받는 피해** 배율 변화분.
@export var heat_optimal_damage_taken: float = -0.10
@export var heat_overheat_damage_taken: float = 0.25
## 매 턴 제시되는 권장 행동을 수행했을 때 내려가는 열기.
@export var heat_recommended_relief: float = -10.0

# ===== 데미지 (Damage) =====
@export_group("데미지")
## `방어계수 = DEF / (DEF + defense_constant + defense_level_coefficient x 공격자레벨)`.
@export var defense_constant: float = 150.0
@export var defense_level_coefficient: float = 8.0
## 최종 피해에 곱하는 랜덤 변동 폭. 0.03 = ±3%.
## **좁게 유지한다** — "계산 가능한 게임"이 설계 3원칙의 첫 줄이다.
@export var damage_variance: float = 0.03
## 피해 하한. 0이면 무적과 구분되지 않는다.
@export var damage_min: int = 1
## 확산 공격의 인접 대상 배율.
@export var blast_adjacent_ratio: float = 0.5
## 치명타 확률 상한. 초과분은 `crit_overflow_to_damage` 비율로 치명타 피해로 전환된다.
@export var crit_rate_cap: float = 1.0
@export var crit_overflow_to_damage: float = 0.5

# ===== 인성치 / 격파 (Toughness / Break) =====
@export_group("인성치와 격파")
## 인성치가 남아 있는 적이 받는 피해 감소. 격파 자체가 곧 딜 증폭이 되게 한다.
@export var unbroken_damage_reduction: float = 0.10
## 격파 지속 중 적이 받는 피해 증가 (버킷 D).
@export var broken_vulnerability: float = 0.25
## 격파 지속 중 적의 방어력 감소 (버킷 B).
@export var broken_defense_reduction: float = 0.30
## 격파 시 적이 행동하지 못하는 턴 수. 설계서는 옥토패스식 "이번 턴 + 다음 턴"을 택했다.
@export var break_stun_turns: int = 2
## 격파 데미지 기준값의 레벨 곡선. `기준값 = break_base_at_1 x (레벨 ^ break_base_exponent)`.
## 설계서 §4.15 표(Lv20:480, Lv40:1750, Lv60:4200, Lv80:8600)에 맞춘 근사다.
@export var break_base_at_1: float = 0.75
@export var break_base_exponent: float = 2.05
## 격파 데미지의 인성치 배율 = `break_toughness_offset + 최대인성치 / break_toughness_divisor`.
@export var break_toughness_offset: float = 0.5
@export var break_toughness_divisor: float = 40.0
## 격파 해제까지 걸리는 인성치 회복 턴 수 (기본값. 적별로 덮어쓸 수 있다).
@export var break_recover_turns: int = 2
## 초격파: 격파 상태의 적에게 넣은 인성치 피해 1점이 전환되는 피해 계수.
@export var overbreak_conversion: float = 12.0

# ===== 어그로 (Aggro) =====
@export_group("어그로")
## 랭크별 어그로 가중치 계수 (A1, A2, A3, A4 순서). 설계서 §4.8.4.
@export var aggro_rank_weights: Array[float] = [1.5, 1.2, 0.8, 0.6]
## 도발이 걸린 대상의 가중치. 사실상 강제 지정.
@export var aggro_taunt_weight: float = 999.0
## HP가 낮은 아군에게 붙는 가중치 배수와 그 임계 비율.
@export var aggro_low_hp_threshold: float = 0.3
@export var aggro_low_hp_weight: float = 1.3

# ===== 확률 보정 (Pity) =====
@export_group("확률")
## 디버프 부여가 이 횟수만큼 연속 실패하면 다음은 확정 성공한다 (설계서 §4.13).
## 억울함을 없애는 장치다 — 다키스트 던전이 미표기 확률로 겪은 이탈을 피한다.
@export var debuff_pity_after_failures: int = 3
## 효과 저항 상한.
@export var effect_res_cap: float = 0.8

# ===== 자물쇠 (Lock) =====
@export_group("자물쇠")
## 등급별 자물쇠 개수 범위 (잡몹 / 정예 / 보스).
@export var lock_count_minion: Vector2i = Vector2i(1, 2)
@export var lock_count_elite: Vector2i = Vector2i(3, 4)
@export var lock_count_boss: Vector2i = Vector2i(4, 6)
## 자물쇠 1개를 해제할 때 함께 깎이는 인성치. 최대 인성치를 자물쇠 개수로 나눈 값에 곱한다.
@export var lock_toughness_share: float = 1.0

# ===== 연출 (Presentation) =====
#
# 로직과 연출은 완전히 분리되어 있어 이 값을 0으로 두면 연출이 사라지고 로직만 남는다
# (헤드리스 테스트와 연출 감소 모드가 같은 경로를 쓴다).
@export_group("연출")
@export var presentation_enabled: bool = true
## 배속. 1.0 / 2.0 / 3.0.
@export var presentation_speed: float = 1.0


func validate() -> Array[String]:
	var problems: Array[String] = []

	if av_scale <= 0.0:
		problems.append("av_scale은 0보다 커야 합니다.")
	if cycle_first <= 0.0 or cycle_step <= 0.0:
		problems.append("cycle_first / cycle_step은 0보다 커야 합니다.")
	if timeline_preview_count < 8:
		problems.append("timeline_preview_count는 8 이상이어야 합니다(설계서 체크리스트 1번).")
	if advance_repeat_efficiency < 0.0 or advance_repeat_efficiency >= 1.0:
		problems.append("advance_repeat_efficiency는 0 이상 1 미만이어야 합니다(1.0이면 무한 턴 루프).")
	if extra_turn_cap < 1:
		problems.append("extra_turn_cap은 1 이상이어야 합니다.")
	if speed_softcap < 1:
		problems.append("speed_softcap은 1 이상이어야 합니다.")
	if resonance_max < 1:
		problems.append("resonance_max는 1 이상이어야 합니다.")
	if resonance_start < 0 or resonance_start > resonance_max:
		problems.append("resonance_start는 0과 resonance_max 사이여야 합니다.")
	if ultimate_per_turn_cap < 1:
		problems.append("ultimate_per_turn_cap은 1 이상이어야 합니다.")
	if heat_max <= 0.0:
		problems.append("heat_max는 0보다 커야 합니다.")
	if heat_optimal_min >= heat_optimal_max:
		problems.append("heat_optimal_min은 heat_optimal_max보다 작아야 합니다.")
	if heat_optimal_max > heat_max:
		problems.append("heat_optimal_max는 heat_max를 넘을 수 없습니다.")
	if defense_constant < 0.0:
		problems.append("defense_constant는 0 이상이어야 합니다.")
	if damage_variance < 0.0 or damage_variance > 0.2:
		problems.append("damage_variance는 0과 0.2 사이여야 합니다(±3% 권장).")
	if damage_min < 1:
		problems.append("damage_min은 1 이상이어야 합니다.")
	if blast_adjacent_ratio < 0.0 or blast_adjacent_ratio > 1.0:
		problems.append("blast_adjacent_ratio는 0과 1 사이여야 합니다.")
	if crit_rate_cap <= 0.0:
		problems.append("crit_rate_cap은 0보다 커야 합니다.")
	if break_stun_turns < 1:
		problems.append("break_stun_turns는 1 이상이어야 합니다.")
	if break_toughness_divisor <= 0.0:
		problems.append("break_toughness_divisor는 0보다 커야 합니다.")
	if break_recover_turns < 1:
		problems.append("break_recover_turns는 1 이상이어야 합니다.")
	if aggro_rank_weights.size() != TurnCombat.ALLY_RANK_COUNT:
		problems.append("aggro_rank_weights는 아군 랭크 수(%d)와 같아야 합니다."
			% TurnCombat.ALLY_RANK_COUNT)
	if debuff_pity_after_failures < 1:
		problems.append("debuff_pity_after_failures는 1 이상이어야 합니다.")
	if effect_res_cap < 0.0 or effect_res_cap > 1.0:
		problems.append("effect_res_cap은 0과 1 사이여야 합니다.")
	if presentation_speed <= 0.0:
		problems.append("presentation_speed는 0보다 커야 합니다.")

	return problems


# ===== 파생 계산 (Derived) =====

# 속도로부터 행동값(AV)을 구한다. 속도 소프트캡을 여기서 적용한다.
#
# 소프트캡을 AV 계산 지점에 두는 이유: 속도를 표시하는 곳이 여러 개(스텟 화면, 편성,
# 타임라인)인데 각자 캡을 적용하면 화면마다 다른 숫자가 나온다. **행동값이 실제 효과이므로
# 캡은 행동값을 만들 때 한 번만 적용한다.**
func action_value_for_speed(speed: float) -> float:
	var effective := effective_speed(speed)
	if effective <= 0.0:
		return av_scale  # 속도 0은 최대한 느린 것으로 취급한다(0으로 나누지 않는다).
	return av_scale / effective

# 소프트캡이 적용된 유효 속도.
func effective_speed(speed: float) -> float:
	if speed <= float(speed_softcap):
		return maxf(speed, 0.0)
	return float(speed_softcap) + (speed - float(speed_softcap)) * speed_softcap_efficiency

# N사이클이 끝나는 누적 AV.
func cycle_end_av(cycle: int) -> float:
	if cycle < 1:
		return 0.0
	return cycle_first + cycle_step * float(cycle - 1)

# 누적 AV가 몇 번째 사이클에 있는가. 1부터 센다.
func cycle_at_av(elapsed_av: float) -> int:
	if elapsed_av < cycle_first:
		return 1
	return 2 + int(floor((elapsed_av - cycle_first) / cycle_step))

# 다음 속도 구간까지 몇 포인트가 필요한가 (설계서 §4.2.3 UI 요구사항).
#
# "구간"은 주어진 사이클 수 안에서 행동 횟수가 1회 늘어나는 지점이다. 커뮤니티
# 계산기에 의존하게 만들지 않으려고 게임이 직접 알려 준다.
func speed_to_next_breakpoint(speed: float, cycles: int = 3) -> int:
	var window := cycle_end_av(maxi(cycles, 1))
	var current_actions := actions_in_window(speed, window)
	# 한 번 더 행동하려면 AV가 window / (n+1) 이하여야 한다 -> 속도가 그 역수.
	var needed_av := window / float(current_actions + 1)
	var needed_speed := av_scale / needed_av
	# 소프트캡 위에서는 표시된 속도가 더 많이 필요하다(효율이 절반이므로).
	if needed_speed > float(speed_softcap):
		needed_speed = float(speed_softcap) \
			+ (needed_speed - float(speed_softcap)) / maxf(speed_softcap_efficiency, 0.01)
	return maxi(int(ceil(needed_speed - speed)), 1)

# 주어진 누적 AV 창 안에서 몇 번 행동하는가.
func actions_in_window(speed: float, window_av: float) -> int:
	var av := action_value_for_speed(speed)
	if av <= 0.0:
		return 0
	# 첫 행동이 av 시점, 두 번째가 2*av ... 이므로 floor(window / av).
	return int(floor(window_av / av))
