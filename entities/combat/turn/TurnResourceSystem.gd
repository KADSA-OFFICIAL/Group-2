extends RefCounted
class_name TurnResourceSystem

# 자원 시스템 — 공명 포인트 / 오의 게이지 / 열기 (#450).
#
# 자원을 **서로 다른 시간 스케일**의 3층으로 나눈 것이 전투에 리듬을 만든다.
#
#   공명 포인트(RP) : 파티 공유, 초단기 — "한 명이 강해지면 다른 셋이 굶는다"
#   오의 게이지     : 개인 소유, 중기  — 턴 밖 발동. 이 게임의 심장
#   열기(Heat)      : 파티 공유, 온도  — 같은 스킬 반복 스팸을 억제
#
# **RP가 왜 천재적인가**: 4명이 하나의 지갑을 쓰므로 팀 조합이 자동으로 경제 밸런싱
# 퍼즐이 된다. RP를 먹는 캐릭터(딜러)와 버는 캐릭터(평타 힐러)라는 두 축이 생기고,
# 단순히 "좋은 캐릭 4명 모으기"가 정답이 되지 않는다.
#
# 참고: docs/turn-combat-design.md §자원

# ===== 공명 포인트 (Resonance) =====

## 파티가 공유하는 현재 보유량.
var resonance: int = 0
## 이 전투의 최대치. 캐릭터 특성이 +1~2 확장할 수 있어 튜닝값을 그대로 쓰지 않는다.
var resonance_max: int = 5

# ===== 열기 (Heat) =====

var heat: float = 0.0

## 이번 사이클의 권장 행동. 수행하면 열기가 크게 내려간다.
## `{"kind": int(ActionKind) | -1, "element": int | -1, "rank_min": int, "label": String}`
var recommendation: Dictionary = {}

# ===== 오의 상한 (Ultimate cap) =====

## **한 유닛의 턴 사이에** 발동된 오의 개수. 연쇄 오의 폭주를 막는다.
var ultimates_this_turn: int = 0

## 전투 통계. 결과 화면과 밸런스 시뮬레이터가 읽는다.
var stats_resonance_spent: int = 0
var stats_resonance_gained: int = 0
var stats_bankrupt_turns: int = 0


func _tuning() -> TurnCombatTuning:
	return PlayerStats.get_tuning_turn()


# 전투 개시. `extra_max`는 캐릭터 특성이 확장하는 RP 상한이다.
func reset(extra_max: int = 0) -> void:
	var t := _tuning()
	resonance_max = maxi(t.resonance_max + extra_max, 1)
	resonance = clampi(t.resonance_start, 0, resonance_max)
	heat = clampf(t.heat_start, 0.0, t.heat_max)
	recommendation = {}
	ultimates_this_turn = 0
	stats_resonance_spent = 0
	stats_resonance_gained = 0
	stats_bankrupt_turns = 0


# ===== 공명 포인트 (Resonance) =====

func can_spend_resonance(amount: int) -> bool:
	return amount <= 0 or resonance >= amount


# 공명 포인트를 소모한다. 부족하면 아무것도 하지 않고 false.
func spend_resonance(amount: int) -> bool:
	if amount <= 0:
		return true
	if resonance < amount:
		return false
	resonance -= amount
	stats_resonance_spent += amount
	return true


# 공명 포인트를 번다. 상한을 넘는 분은 버린다(저축되지 않는다).
func gain_resonance(amount: int) -> int:
	if amount <= 0:
		return 0
	var before := resonance
	resonance = mini(resonance + amount, resonance_max)
	var gained := resonance - before
	stats_resonance_gained += gained
	return gained


# 파산 위험인가. UI가 스킬 버튼을 경고색으로 바꾼다.
func is_resonance_bankrupt() -> bool:
	return resonance <= 0


# ===== 오의 게이지 (Energy) =====

# 유닛의 오의 게이지를 채운다. **오의 회복 효율**이 곱연산으로 걸린다.
#
# 반환: 실제로 오른 양.
func gain_energy(unit: TurnUnit, base_amount: int) -> int:
	var max_energy := unit.get_energy_max()
	if max_energy <= 0 or base_amount == 0:
		return 0

	var amount := base_amount
	# 손실(오의 사용)에는 효율을 곱하지 않는다 — 효율은 "획득량 배율"이다.
	if base_amount > 0:
		amount = int(round(float(base_amount) * unit.stats.get_energy_recharge_multiplier()))

	var before := unit.energy
	unit.energy = clampi(unit.energy + amount, 0, max_energy)
	return unit.energy - before


# 행동 종류에 따른 기본 획득량으로 채운다.
func gain_energy_for_action(unit: TurnUnit, kind: int) -> int:
	var t := _tuning()
	match kind:
		TurnCombat.ActionKind.BASIC:
			return gain_energy(unit, t.energy_basic)
		TurnCombat.ActionKind.SKILL:
			return gain_energy(unit, t.energy_skill)
		TurnCombat.ActionKind.ULTIMATE:
			return gain_energy(unit, t.energy_after_ultimate)
		TurnCombat.ActionKind.TRAIT:
			return gain_energy(unit, t.energy_trait)
		_:
			return 0


func gain_energy_on_damage_taken(unit: TurnUnit) -> int:
	return gain_energy(unit, _tuning().energy_on_hit_taken)


func gain_energy_on_kill(unit: TurnUnit) -> int:
	return gain_energy(unit, _tuning().energy_on_kill)


func gain_energy_on_break(unit: TurnUnit) -> int:
	return gain_energy(unit, _tuning().energy_on_break)


# 오의를 쓸 수 있는가.
#
# 두 조건: 게이지가 찼고, **이번 턴의 오의 상한**을 넘지 않았다.
# 상한이 없으면 오의 회복 특화 4명이 한 턴에 오의를 무한 연쇄한다(설계서 §4.13).
func can_use_ultimate(unit: TurnUnit, skill: SkillData) -> bool:
	if skill == null or not skill.is_turn_ultimate():
		return false
	if not unit.alive:
		return false
	if ultimates_this_turn >= _tuning().ultimate_per_turn_cap:
		return false
	return unit.energy >= skill.get_energy_cost(unit.get_energy_max())


# 오의를 쓸 수 없는 이유. UI가 띄운다.
func ultimate_blocked_reason(unit: TurnUnit, skill: SkillData) -> String:
	if skill == null or not skill.is_turn_ultimate():
		return "오의가 없습니다"
	if not unit.alive:
		return "전투 불능"
	var cap := _tuning().ultimate_per_turn_cap
	if ultimates_this_turn >= cap:
		return "이 턴의 오의 상한(%d개)에 도달했습니다" % cap
	var cost := skill.get_energy_cost(unit.get_energy_max())
	if unit.energy < cost:
		return "오의 게이지 %d/%d" % [unit.energy, cost]
	return ""


# 오의 코스트를 소모한다.
func spend_ultimate(unit: TurnUnit, skill: SkillData) -> bool:
	if not can_use_ultimate(unit, skill):
		return false
	unit.energy -= skill.get_energy_cost(unit.get_energy_max())
	ultimates_this_turn += 1
	return true


# 유닛의 턴이 시작됐다. 오의 상한 카운터를 리셋한다.
#
# "한 유닛의 턴 사이"가 상한의 단위인 이유: 오의는 턴 밖에서 언제든 발동되므로
# 턴 개념으로 셀 수밖에 없다. 턴 사이마다 2개면 사이클당으로는 충분히 여러 번 쓸 수 있다.
func on_turn_start(unit: TurnUnit) -> void:
	ultimates_this_turn = 0
	if is_resonance_bankrupt() and unit.is_ally():
		stats_bankrupt_turns += 1


# ===== 열기 (Heat) =====

# 열기 구간. -1 냉각 / 0 최적 / 1 과열.
func heat_zone() -> int:
	var t := _tuning()
	if heat < t.heat_optimal_min:
		return -1
	if heat > t.heat_optimal_max:
		return 1
	return 0


# 열기 시스템이 켜져 있는가. **선택적 시스템**이라 UI가 이것을 보고 게이지를 그릴지 정한다.
func heat_enabled() -> bool:
	return _tuning().heat_enabled


func heat_zone_name() -> String:
	match heat_zone():
		-1:
			return "냉각"
		1:
			return "과열"
		_:
			return "최적"


# 버킷 G — 열기가 주는 피해 배율 변화분. 최종 배수는 (1.0 + 값).
func heat_damage_modifier() -> float:
	var t := _tuning()
	if not t.heat_enabled:
		return 0.0
	match heat_zone():
		-1:
			return t.heat_cold_damage
		1:
			return t.heat_overheat_damage
		_:
			return t.heat_optimal_damage


# 열기가 주는 **받는 피해** 배율 변화분. 냉각 구간에는 보정이 없다.
func heat_damage_taken_modifier() -> float:
	var t := _tuning()
	if not t.heat_enabled:
		return 0.0
	match heat_zone():
		1:
			return t.heat_overheat_damage_taken
		0:
			return t.heat_optimal_damage_taken
		_:
			return 0.0


func add_heat(amount: float) -> void:
	if not _tuning().heat_enabled:
		return
	heat = clampf(heat + amount, 0.0, _tuning().heat_max)


func add_heat_for_action(kind: int) -> void:
	var t := _tuning()
	match kind:
		TurnCombat.ActionKind.BASIC:
			add_heat(t.heat_gain_basic)
		TurnCombat.ActionKind.SKILL:
			add_heat(t.heat_gain_skill)
		TurnCombat.ActionKind.ULTIMATE:
			add_heat(t.heat_gain_ultimate)


func decay_heat() -> void:
	add_heat(_tuning().heat_decay_per_turn)


# 이번 사이클의 권장 행동을 정한다.
#
# **의도**: 같은 스킬을 반복 스팸하는 것을 시스템적으로 억제하고 매 턴 다른 판단을
# 강요한다. 턴제 게임의 최대 고질병(최적 스킬만 반복)에 대한 가장 우아한 해법이다
# (체인드 에코즈 응용).
#
# 결정론: `rng`를 받아 시드로부터 뽑는다.
func roll_recommendation(rng: RandomNumberGenerator) -> void:
	if not _tuning().heat_enabled:
		recommendation = {}
		return

	var options: Array[Dictionary] = [
		{"kind": TurnCombat.ActionKind.BASIC, "element": -1, "rank_min": 0,
			"label": "일반공격으로 행동하면 열기가 내려간다"},
		{"kind": TurnCombat.ActionKind.ULTIMATE, "element": -1, "rank_min": 0,
			"label": "오의로 행동하면 열기가 내려간다"},
		{"kind": -1, "element": -1, "rank_min": 3,
			"label": "후열(A3~A4) 캐릭터가 행동하면 열기가 내려간다"},
	]
	# 원소 권장도 후보에 넣는다 — 팀 안의 원소 다양성을 쓰게 만드는 축이다.
	var element: int = rng.randi_range(0, TurnCombat.ELEMENT_NAME.size() - 1)
	options.append({
		"kind": -1, "element": element, "rank_min": 0,
		"label": "%s 공격으로 행동하면 열기가 내려간다" % TurnCombat.element_name(element),
	})

	recommendation = options[rng.randi_range(0, options.size() - 1)]


# 방금 한 행동이 권장 행동이었는가. 맞으면 열기를 크게 내린다.
func apply_recommendation(unit: TurnUnit, kind: int, element: int) -> bool:
	if recommendation.is_empty():
		return false

	var want_kind := int(recommendation.get("kind", -1))
	if want_kind >= 0 and want_kind != kind:
		return false

	var want_element := int(recommendation.get("element", -1))
	if want_element >= 0 and want_element != element:
		return false

	var rank_min := int(recommendation.get("rank_min", 0))
	if rank_min > 0 and unit.rank < rank_min:
		return false

	add_heat(_tuning().heat_recommended_relief)
	return true


func recommendation_label() -> String:
	return String(recommendation.get("label", ""))


# ===== 편성 예측 (Formation forecast) =====

# 이 팀의 **사이클당 RP 예상 수지**. 편성 화면이 사전 경고한다 (설계서 §4.3.1).
#
# 계산: 캐릭터마다 사이클당 행동 횟수 x (평타 획득 - 스킬 소모)를 더한다.
# 스킬을 항상 쓴다고 가정하되, 특성으로 RP를 버는 캐릭터는 그 값을 더한다.
#
# **왜 필요한가**: RP 소비 캐릭 3명 이상은 파산해서 평타만 치는 턴이 생긴다. 그것을
# 전투에 들어가 봐야 알게 되면 편성이 도박이 된다.
static func forecast_resonance_balance(party: Array[CharacterData], cycles: int = 1) -> float:
	var t := PlayerStats.get_tuning_turn()
	var window := t.cycle_end_av(maxi(cycles, 1))
	var total := 0.0

	for character in party:
		if character == null:
			continue
		var actions := t.actions_in_window(float(character.get_stats().get_speed()), window)
		if actions <= 0:
			continue

		var skill: SkillData = null
		for candidate in character.get_turn_skills(TurnCombat.ActionKind.SKILL):
			skill = candidate
			break

		# 스킬이 있으면 스킬을 쓴다고 본다(가장 나쁜 경우). 없으면 평타만 친다.
		var per_action := float(t.resonance_gain_basic)
		if skill != null:
			per_action = -float(skill.rp_cost)

		total += per_action * float(actions)

		# 특성이 RP를 버는 경우 (「연산 보조」처럼 턴 시작마다 +1).
		for trait_skill in character.get_turn_skills(TurnCombat.ActionKind.TRAIT):
			for effect in trait_skill.turn_effects:
				if effect != null and effect.kind == TurnSkillEffect.Kind.RESONANCE:
					total += float(effect.amount) * float(actions)

	return total / float(maxi(cycles, 1))


# 수지 경고 문구. 편성 화면이 그대로 띄운다.
static func forecast_label(balance: float) -> String:
	if balance >= 0.5:
		return "%+.1f/사이클 → 여유" % balance
	if balance >= 0.0:
		return "%+.1f/사이클 → 균형" % balance
	if balance >= -0.5:
		return "%+.1f/사이클 → 주의" % balance
	return "%+.1f/사이클 → 위험 (공명 파산)" % balance


# ===== 디버그 (Debug) =====

func describe() -> String:
	return "공명 %d/%d  열기 %.0f (%s)  이번 턴 오의 %d" \
		% [resonance, resonance_max, heat, heat_zone_name(), ultimates_this_turn]
