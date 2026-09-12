extends RefCounted
class_name TurnEnemyAI

# 적 AI — 행동 선택 · 예고 생성 · 자물쇠 조합 (#450).
#
# **턴제 게임의 긴장감은 90%가 행동 예고에서 나온다.** 다음 턴에 쓸 강력한 기술을
# 미리 알리면 플레이어가 보호막·힐·CC로 대응할 기회가 생기고, 그 대응이 실력이 된다.
# 예고가 없으면 큰 피해는 그냥 억울한 사고다.
#
# 그리고 설계서는 여기서 한 걸음 더 나간다: 예고에 **봉인 조건(자물쇠)**을 붙여
# "이번 턴에 무엇을 해야 하는가"를 화면에 명시한다.
#
# 이 클래스가 **하지 않는** 것: 실행. 예고를 만들고, 예고된 것을 실행할 때가 되면
# `SkillResolver`에 넘긴다. 예고와 실행이 분리되어 있어야 "예고한 대로 온다"가 지켜진다.
#
# 참고: docs/turn-combat-design.md §적 설계

var rng: RandomNumberGenerator = null
var ranks: RankSystem = null
var resolver: SkillResolver = null
var toughness: ToughnessSystem = null


## 저작되지 않은 적을 위한 기본 평타. 적이 아무것도 하지 않고 서 있는 것보다 낫다.
##
## `static var`로 한 번만 만든다 — 매 턴 새로 만들면 같은 스킬 객체가 수백 개 생긴다.
static var _fallback_basic: SkillData = null


func _tuning() -> TurnCombatTuning:
	return PlayerStats.get_tuning_turn()


static func fallback_basic() -> SkillData:
	if _fallback_basic != null:
		return _fallback_basic

	var skill := SkillData.new()
	skill.skill_id = &"enemy_fallback_basic"
	skill.display_name = "공격"
	skill.turn_action = TurnCombat.ActionKind.BASIC
	skill.turn_targeting = TurnCombat.Targeting.SINGLE
	skill.turn_hits = 1

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.scope = TurnSkillEffect.Scope.TARGET
	effect.multiplier = 1.0
	effect.scaling = TurnCombat.Scaling.ATTACK
	effect.toughness_damage = 0
	effect.label = "공격력 100% 피해"
	skill.turn_effects = [effect]

	_fallback_basic = skill
	return skill


# ===== 예고 (Intent) =====

# 이 적의 다음 행동을 정하고 예고를 만든다.
#
# 예고 시점에 확정하는 것: 스킬 · 대상 · 예상 피해 · 자물쇠 조합.
# **대상까지 확정한다** — 예고한 대상과 실제 대상이 다르면 공개한 정보가 거짓말이 된다.
func build_intent(unit: TurnUnit, all_units: Array[TurnUnit]) -> TurnIntent:
	var intent := TurnIntent.new()
	intent.skill = choose_skill(unit)

	if intent.skill == null:
		return intent

	# 대상 선택. 스킬의 타격 랭크 조건을 어그로 계산에 넘긴다 —
	# 대형이 무너져 조건을 만족하는 아군이 없으면 위력이 떨어진 대체 행동이 된다.
	var allowed: Array[int] = []
	for rank in intent.skill.target_ranks:
		allowed.append(rank)

	if intent.skill.needs_target_pick():
		var target := ranks.pick_aggro_target(unit, rng, allowed)
		if target != null:
			intent.target_ids = [target.unit_id]
			intent.expected_damage = resolver.expected_damage(unit, intent.skill, target)
	else:
		var expanded := ranks.expand_targets(unit, intent.skill, null, null)
		for entry in expanded:
			var t: TurnUnit = entry[0]
			if t != null:
				intent.target_ids.append(t.unit_id)
		intent.expected_damage = resolver.expected_damage(unit, intent.skill, null)

	# 자물쇠 조합.
	intent.locks = toughness.generate_locks(unit)
	intent.recalculate_power()

	return intent


# 이 적이 다음에 쓸 스킬을 고른다.
#
# 규칙(설계서 §4.8.3 보스 패턴을 데이터로 표현할 수 있게 최소한만 코드에 둔다):
#   - 오의 게이지가 찼으면 오의
#   - 그 외에는 저작된 전투 스킬 중 무작위, 없으면 평타
#
# 더 복잡한 패턴(페이즈 전환, 스택 강화)은 스킬의 조건 필드(`require_target_hp_below` 등)와
# 저작으로 표현한다 — 패턴을 코드에 박으면 적을 늘릴 때마다 이 파일을 고쳐야 한다.
func choose_skill(unit: TurnUnit) -> SkillData:
	if unit.enemy == null:
		return fallback_basic()

	# 오의.
	var ultimates := unit.enemy.get_turn_skills(TurnCombat.ActionKind.ULTIMATE)
	for ultimate in ultimates:
		var cost := ultimate.get_energy_cost(unit.get_energy_max())
		if unit.energy >= cost and ranks.is_usable(unit, ultimate):
			return ultimate

	# 전투 스킬 — 지금 쓸 수 있는 것만 후보로.
	var candidates: Array[SkillData] = []
	for skill in unit.enemy.get_turn_skills(TurnCombat.ActionKind.SKILL):
		if ranks.is_usable(unit, skill):
			candidates.append(skill)

	if not candidates.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1)]

	# 평타.
	var basics := unit.enemy.get_turn_skills(TurnCombat.ActionKind.BASIC)
	for basic in basics:
		if ranks.is_usable(unit, basic):
			return basic

	# 저작된 것 중 쓸 수 있는 게 없다 — 대형이 무너져 조건이 깨진 상태다.
	# **약한 대체 행동**을 한다. 이것이 위치 조작이 예방적 방어가 되는 지점이다.
	return fallback_basic()


# ===== 실행 (Act) =====

# 예고된 행동을 실행한다.
#
# 자물쇠가 일부 해제되었으면 **그 비율만큼만 위력**을 낸다. 부분 성공에도 보상이 있어야
# 좌절이 적다(설계서 §4.4.2 규칙 4).
#
# 반환: `SkillResolver.execute()`의 결과 + `{"weakened": float}`.
func act(unit: TurnUnit, all_units: Array[TurnUnit]) -> Dictionary:
	if unit.intent == null or unit.intent.skill == null:
		unit.intent = build_intent(unit, all_units)

	var intent := unit.intent

	# 무산됐다 — 자물쇠를 전부 열었다. 행동하지 않는다.
	if intent.nullified:
		var blocked := {
			"ok": true, "reason": "무산",
			"damage": [] as Array[DamageContext],
			"breaks": [] as Array[TurnUnit],
			"nullified": [] as Array[TurnUnit],
			"kills": [] as Array[TurnUnit],
			"logs": ["%s 의 「%s」이(가) 무산되었다"
				% [unit.display_name, intent.skill.display_name]] as Array[String],
			"consumed_turn": true,
			"weakened": 0.0,
		}
		unit.intent = build_intent(unit, all_units)
		return blocked

	var skill := intent.skill
	var primary := _find(all_units, intent.target_ids[0]) if not intent.target_ids.is_empty() else null

	# 예고한 대상이 죽었으면 다시 고른다 — 죽은 대상을 때리면 적 턴이 통째로 사라진다.
	if primary != null and not primary.alive:
		var allowed: Array[int] = []
		for rank in skill.target_ranks:
			allowed.append(rank)
		primary = ranks.pick_aggro_target(unit, rng, allowed)

	# 위력 감소를 적용하기 위해 스킬을 복제한다. 원본 배율을 고치면 저작 데이터가 오염된다.
	var executed := skill
	if intent.power_ratio < 1.0:
		executed = _weakened_copy(skill, intent.power_ratio)

	var result := resolver.execute(unit, executed, primary)
	result["weakened"] = 1.0 - intent.power_ratio

	if intent.power_ratio < 1.0:
		result["logs"].insert(0, "  (자물쇠 %d/%d 해제 → 위력 %.0f%%)"
			% [intent.cleared_locks(), intent.total_locks(), intent.power_ratio * 100.0])

	# 감전이 걸린 적이 스킬을 쓰면 추가 피해를 받는다 — 전격 격파의 조건부 폭딜이다.
	var shock := unit.find_break_status(TurnCombat.BreakStatus.SHOCK)
	if shock != null and not skill.is_turn_basic():
		var burst := resolver.statuses.detonate(unit, unit, TurnCombat.BreakStatus.SHOCK,
			resolver.statuses.shock_extra_multiplier(), false)
		if burst != null:
			result["damage"].append(burst)
			result["logs"].append("  감전 추가 피해: " + burst.summary())

	# 행동을 마쳤으니 다음 예고를 만든다. **자물쇠 조합이 매번 달라진다.**
	unit.intent = build_intent(unit, all_units)

	return result


# 위력이 깎인 스킬 복제본. 배율과 인성치 피해에만 비율을 곱한다.
#
# 왜 지속시간과 위치 이동에는 곱하지 않는가: 0.25턴이나 0.25칸은 표현할 수 없고,
# 반올림하면 "3개 해제했는데 밀치기는 그대로"라는 어긋남이 생긴다. 위력 감소는
# **수치에만** 적용하는 것이 규칙이다.
func _weakened_copy(skill: SkillData, ratio: float) -> SkillData:
	var copy := skill.duplicate(true) as SkillData
	var weakened: Array[TurnSkillEffect] = []
	for effect in copy.turn_effects:
		if effect == null:
			continue
		var e := effect.duplicate(true) as TurnSkillEffect
		e.multiplier *= ratio
		e.flat = int(round(float(e.flat) * ratio))
		e.toughness_damage = int(round(float(e.toughness_damage) * ratio))
		weakened.append(e)
	copy.turn_effects = weakened
	return copy


func _find(units: Array[TurnUnit], id: StringName) -> TurnUnit:
	for unit in units:
		if unit.unit_id == id:
			return unit
	return null


# ===== 아군 자동 전투 (Auto battle) =====
#
# 반복 플레이가 필수인 장르에서 **반복을 빠르게 만드는 기능이 곧 게임 수명**이다.
# 여기 인색하면 아무리 시스템이 좋아도 죽는다(설계서 §11.4).

# 자동 전투가 고를 아군 행동. `{"skill": SkillData, "target": TurnUnit}`.
#
# 정책(단순하지만 설계 원칙을 따른다):
#   1. **아군이 위태로우면 먼저 살린다** — 회복/보호막 스킬을 쓴다
#   2. 자물쇠를 열 수 있는 스킬을 고른다 — 매 턴의 미니 퍼즐이 목표다
#   3. 공명 포인트가 남으면 전투 스킬, 부족하면 일반공격 — 파산을 스스로 피한다
#
# 1번이 없으면 어떻게 되는가 (실제로 겪은 문제): 대상 목록을 적으로만 걸렀더니
# **회복 스킬이 후보에 아예 오르지 않아** 치유자가 평타만 쳤다. 자동 전투 승률이
# 정예전에서 0/5 였는데 원인이 밸런스가 아니라 이 필터였다.
func choose_ally_action(unit: TurnUnit, all_units: Array[TurnUnit]) -> Dictionary:
	var out := {"skill": null, "target": null}
	if unit.character == null:
		return out

	var basic := unit.character.get_turn_basic()
	var skills := unit.character.get_turn_skills(TurnCombat.ActionKind.SKILL)
	var enemies := ranks.living(TurnCombat.Side.ENEMY)
	if enemies.is_empty():
		return out

	var resources := resolver.resources

	# --- 1) 위태로운 아군을 먼저 살린다 ---
	var allies := ranks.living(TurnCombat.Side.ALLY)
	var weakest: TurnUnit = null
	for ally in allies:
		if weakest == null or ally.get_hp_ratio() < weakest.get_hp_ratio():
			weakest = ally

	if weakest != null and weakest.get_hp_ratio() < HEAL_THRESHOLD:
		for skill in skills:
			if not _supports_heal(skill):
				continue
			if skill.rp_cost > resources.resonance or not ranks.is_usable(unit, skill):
				continue
			out["skill"] = skill
			out["target"] = weakest
			return out

	# --- 2) 보호막·도발이 걸려 있지 않으면 깔아 둔다 (수호자) ---
	if _party_needs_guard(allies):
		for skill in skills:
			if not _supports_guard(skill):
				continue
			if skill.rp_cost > resources.resonance or not ranks.is_usable(unit, skill):
				continue
			out["skill"] = skill
			out["target"] = unit
			return out

	# --- 3) 자물쇠를 가장 많이 여는 공격 ---
	var best_skill: SkillData = null
	var best_target: TurnUnit = null
	var best_score := -1

	var candidates: Array[SkillData] = []
	if resources.resonance > 0:
		for skill in skills:
			if skill.turn_deals_damage():
				candidates.append(skill)
	if basic != null:
		candidates.append(basic)

	for skill in candidates:
		if not ranks.is_usable(unit, skill):
			continue
		if skill.rp_cost > resources.resonance:
			continue
		for target in ranks.valid_targets(unit, skill):
			if target.is_ally():
				continue
			# 자물쇠를 여는 개수 x 10 + 스킬 여부. 자물쇠가 최우선이다.
			var score := toughness.count_openable_locks(unit, skill, target) * 10
			if not skill.is_turn_basic():
				score += 2
			# 격파된 적을 계속 때리는 것이 이득이다 (받는 피해 +25%).
			if target.is_broken:
				score += 3
			if score > best_score:
				best_score = score
				best_skill = skill
				best_target = target

	# 아무것도 못 고르면 평타로 가장 앞의 적을 때린다.
	if best_skill == null and basic != null:
		best_skill = basic
		var fallback := ranks.valid_targets(unit, basic)
		best_target = fallback[0] if not fallback.is_empty() else null

	out["skill"] = best_skill
	out["target"] = best_target
	return out


## 자동 전투가 회복을 쓰기 시작하는 HP 비율.
const HEAL_THRESHOLD := 0.7


# 이 스킬이 회복 수단인가.
func _supports_heal(skill: SkillData) -> bool:
	for effect in skill.turn_effects:
		if effect != null and (effect.kind == TurnSkillEffect.Kind.HEAL
				or effect.kind == TurnSkillEffect.Kind.CLEANSE):
			return true
	return false


# 이 스킬이 보호막·도발을 깔아 주는가.
func _supports_guard(skill: SkillData) -> bool:
	for effect in skill.turn_effects:
		if effect != null and (effect.kind == TurnSkillEffect.Kind.SHIELD
				or effect.kind == TurnSkillEffect.Kind.TAUNT):
			return true
	return false


# 파티에 보호막이나 도발이 없는가. 있으면 다시 깔지 않는다 — 갱신은 낭비다.
func _party_needs_guard(allies: Array[TurnUnit]) -> bool:
	for ally in allies:
		if ally.get_shield_total() > 0 or ally.is_taunting():
			return false
	return true


# 자동 전투가 오의를 쓸 것인가.
#
# 게이지가 찼으면 쓴다. 턴 밖 발동의 타이밍 최적화(적 큰 공격 직전에 보호막 등)는
# 사람이 잡는 판단이라 자동에 맡기지 않는다 — 자동은 "빠른 반복"이 목적이다.
func should_use_ultimate(unit: TurnUnit) -> bool:
	if unit.character == null:
		return false
	var ultimate := unit.character.get_turn_ultimate()
	if ultimate == null:
		return false
	return resolver.resources.can_use_ultimate(unit, ultimate)
