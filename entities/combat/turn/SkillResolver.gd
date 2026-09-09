extends RefCounted
class_name SkillResolver

# 스킬 실행 — 대상 산출과 효과 적용 (#450).
#
# 실행 순서:
#   1. 코스트 지불 (공명 포인트 / 오의 게이지)
#   2. **피해 효과**를 히트마다 · 대상마다 적용 (다단 히트는 자물쇠를 여러 개 연다)
#   3. **비피해 효과**를 각자의 범위에 한 번 적용 (밀치기 · 버프 · 행동 조작 ...)
#   4. 후처리 (오의 게이지 획득 · 열기 · 권장 행동 · 공명 획득)
#
# 왜 피해와 비피해를 나누는가: 설계서 §5.2.3 의 스킬 스키마를 보면 「종언의 화로」가
# `damage(전체) + push(전체) + buff(아군 전체)`다. 전부 히트 루프 안에서 돌리면 3단
# 히트 스킬이 보호막을 3번 주고 밀치기를 3칸 한다.
#
# 이 클래스는 **연출을 모른다.** 결과를 반환하고, 연출은 `PresentationQueue`가 재생한다.
#
# 참고: docs/turn-combat-design.md §스킬 실행

var rng: RandomNumberGenerator = null
var ranks: RankSystem = null
var timeline: TimelineSystem = null
var resources: TurnResourceSystem = null
var statuses: TurnStatusSystem = null
var toughness: ToughnessSystem = null
var pipeline: DamagePipeline = null

## 전투에 참여하는 유닛 전체. 지속 피해의 출처 조회 등에 쓴다.
var units: Array[TurnUnit] = []


func _tuning() -> TurnCombatTuning:
	return PlayerStats.get_tuning_turn()


# ===== 실행 (Execute) =====

# 스킬 하나를 끝까지 실행한다.
#
# 반환:
# ```
# {
#   "ok": bool,
#   "reason": String,                    # 실패 이유
#   "damage": Array[DamageContext],
#   "breaks": Array[TurnUnit],           # 이 행동으로 격파된 적
#   "nullified": Array[TurnUnit],        # 행동이 무산된 적
#   "kills": Array[TurnUnit],
#   "logs": Array[String],
#   "consumed_turn": bool,
# }
# ```
func execute(actor: TurnUnit, skill: SkillData, primary: TurnUnit = null) -> Dictionary:
	var result := {
		"ok": false, "reason": "",
		"damage": [] as Array[DamageContext],
		"breaks": [] as Array[TurnUnit],
		"nullified": [] as Array[TurnUnit],
		"kills": [] as Array[TurnUnit],
		"logs": [] as Array[String],
		"consumed_turn": false,
	}

	if actor == null or skill == null:
		result["reason"] = "시전자나 스킬이 없습니다"
		return result

	# --- 사용 가능 판정 ---
	var usable := ranks.check_usable(actor, skill)
	if not bool(usable["ok"]):
		result["reason"] = String(usable["reason"])
		return result

	# --- 코스트 ---
	if skill.is_turn_ultimate():
		if not resources.spend_ultimate(actor, skill):
			result["reason"] = resources.ultimate_blocked_reason(actor, skill)
			return result
	elif skill.rp_cost > 0:
		if not resources.spend_resonance(skill.rp_cost):
			result["reason"] = "공명 포인트가 부족합니다 (%d/%d)" \
				% [resources.resonance, skill.rp_cost]
			return result

	result["ok"] = true
	result["consumed_turn"] = skill.consumes_turn()

	var element := skill.resolve_element(actor.element)
	var physical := skill.resolve_physical_type(actor.physical_type)

	_log(result, "%s 이(가) 「%s」 사용 (%s · %s %s)"
		% [actor.display_name, skill.display_name,
			TurnCombat.action_kind_name(skill.turn_action),
			TurnCombat.element_name(element), TurnCombat.physical_name(physical)])

	# --- 피해 효과 ---
	var damage_effects: Array[TurnSkillEffect] = []
	var other_effects: Array[TurnSkillEffect] = []
	for effect in skill.turn_effects:
		if effect == null:
			continue
		if effect.kind == TurnSkillEffect.Kind.DAMAGE \
				or effect.kind == TurnSkillEffect.Kind.TOUGHNESS:
			damage_effects.append(effect)
		else:
			other_effects.append(effect)

	var hits := maxi(skill.turn_hits, 1)
	if not damage_effects.is_empty():
		var expanded := ranks.expand_targets(actor, skill, primary, rng)
		for hit_index in hits:
			for entry in expanded:
				var target: TurnUnit = entry[0]
				var ratio: float = entry[1]
				if target == null or not target.alive:
					continue
				for effect in damage_effects:
					if not _condition_met(actor, target, effect):
						continue
					_apply_damage(actor, skill, effect, target, ratio,
						element, physical, hit_index + 1, hits, result)

	# --- 비피해 효과 ---
	for effect in other_effects:
		if effect.kind == TurnSkillEffect.Kind.RESONANCE and effect.scope == TurnSkillEffect.Scope.SELF:
			# 공명은 파티 공유 자원이므로 대상 순회가 필요 없다.
			_apply_resonance(effect, result)
			continue
		for target in _resolve_scope(actor, skill, primary, effect):
			if target == null or not target.alive:
				continue
			if not _condition_met(actor, target, effect):
				continue
			_apply_other(actor, skill, effect, target, element, result)

	# --- 후처리 ---
	_post_action(actor, skill, element, result)

	return result


# ===== 피해 적용 (Damage) =====

func _apply_damage(actor: TurnUnit, skill: SkillData, effect: TurnSkillEffect,
		target: TurnUnit, ratio: float, element: int, physical: int,
		hit_index: int, hit_count: int, result: Dictionary) -> void:
	var ctx := DamageContext.new()
	ctx.source = actor
	ctx.target = target
	ctx.skill = skill
	ctx.effect = effect
	ctx.element = element
	ctx.physical_type = physical
	ctx.target_ratio = ratio
	ctx.hit_index = hit_index
	ctx.hit_count = hit_count

	# 중첩 비례 추가 배율 (「완성된 초상」의 "속박 중첩당 공격력 55%").
	if effect.per_stack_multiplier > 0.0 and effect.require_status:
		var stacks := target.get_break_status_stacks(effect.require_status_kind)
		if stacks > 0:
			var bonus := TurnSkillEffect.new()
			bonus.kind = TurnSkillEffect.Kind.DAMAGE
			bonus.multiplier = effect.multiplier + effect.per_stack_multiplier * float(stacks)
			bonus.flat = effect.flat
			bonus.scaling = effect.scaling
			bonus.toughness_damage = effect.toughness_damage
			bonus.adjacent_ratio = effect.adjacent_ratio
			ctx.effect = bonus
			ctx.note("중첩 보너스: %s %d중첩 x %.0f%%"
				% [TurnCombat.break_status_name(effect.require_status_kind),
					stacks, effect.per_stack_multiplier * 100.0])

	pipeline.compute(ctx)

	# 인성치·자물쇠는 HP 반영 **전에** 판정한다 — 대상이 이 타격으로 죽으면 격파 연출이
	# 나올 자리가 없어지지만, 자물쇠 해제 사실 자체는 기록되어야 한다(로그와 통계).
	var effects := toughness.on_hit(ctx)

	pipeline.commit(ctx)
	result["damage"].append(ctx)
	_log(result, "  " + ctx.summary())

	if effects["lock_cleared"] != null:
		var lock: TurnLock = effects["lock_cleared"]
		_log(result, "  자물쇠 해제: %s (%d/%d)"
			% [lock.type_name(), target.intent.cleared_locks(), target.intent.total_locks()])

	if bool(effects["nullified"]):
		result["nullified"].append(target)
		_log(result, "  ★ %s 의 행동이 무산되었다" % target.display_name)

	if bool(effects["broke"]):
		result["breaks"].append(target)
		_log(result, "  ★ 약점 격파! %s" % target.display_name)
		var break_ctx = effects["break_context"]
		if break_ctx != null:
			result["damage"].append(break_ctx)
			_log(result, "  " + break_ctx.summary())
		# 격파 성공은 시전자의 오의 게이지를 채운다.
		resources.gain_energy_on_break(actor)
		# 격파 상태이상이 요구하는 행동 지연을 타임라인에 적용한다.
		var delay := statuses.break_delay_ratio(TurnCombat.element_break_status(element))
		if delay > 0.0:
			timeline.delay_action(target, delay)
			_log(result, "  %s 행동 지연 %.0f%%" % [target.display_name, delay * 100.0])

	var over_ctx = effects["overbreak_context"]
	if over_ctx != null:
		result["damage"].append(over_ctx)
		_log(result, "  " + over_ctx.summary())

	# 피격은 대상의 오의 게이지를 채운다.
	if ctx.hp_damage > 0:
		resources.gain_energy_on_damage_taken(target)

	if ctx.killed:
		_on_kill(actor, target, result)

	# --- 특성 발동 ---
	#
	# `_in_trait`로 재귀를 막는다. 반격이 반격을 유발하면 두 탱커가 서로를 때려
	# 스택이 터진다. 특성이 특성을 낳지 않는 것이 규칙이다.
	if not _in_trait:
		_in_trait = true
		if ctx.hp_damage > 0 and target.alive:
			_merge(result, fire_traits(target, SkillData.TraitTrigger.ON_DAMAGE_TAKEN, ctx))
		if ctx.hp_damage > 0:
			_merge(result, fire_traits(actor, SkillData.TraitTrigger.ON_DAMAGE_DEALT, ctx))
		if ctx.hits_weakness:
			_merge(result, fire_traits(actor, SkillData.TraitTrigger.ON_WEAKNESS_HIT, ctx))
		if ctx.killed:
			_merge(result, fire_traits(actor, SkillData.TraitTrigger.ON_KILL, ctx))
		_in_trait = false


func _on_kill(actor: TurnUnit, target: TurnUnit, result: Dictionary) -> void:
	if result["kills"].has(target):
		return
	result["kills"].append(target)
	_log(result, "  %s 전투 불능" % target.display_name)
	resources.gain_energy_on_kill(actor)
	ranks.remove(target)
	timeline.remove_unit(target)


# ===== 비피해 효과 (Other effects) =====

func _apply_other(actor: TurnUnit, skill: SkillData, effect: TurnSkillEffect,
		target: TurnUnit, element: int, result: Dictionary) -> void:
	match effect.kind:
		TurnSkillEffect.Kind.HEAL:
			var amount := int(round(
				(effect.multiplier * float(actor.get_scaling_value(effect.scaling))
					+ float(effect.flat))
				* actor.stats.get_heal_boost_multiplier()))
			var before := target.current_hp
			target.current_hp = mini(target.current_hp + amount, target.get_max_hp())
			var healed := target.current_hp - before
			_log(result, "  %s 회복 +%d (%d/%d)"
				% [target.display_name, healed, target.current_hp, target.get_max_hp()])

		TurnSkillEffect.Kind.SHIELD:
			var shield := statuses.build_from_effect(actor, effect)
			statuses.apply(actor, target, shield)
			_log(result, "  %s 보호막 %d (%d턴)"
				% [target.display_name, shield.shield_amount, shield.turns_left])

		TurnSkillEffect.Kind.BUFF, TurnSkillEffect.Kind.TAUNT, \
		TurnSkillEffect.Kind.ANCHOR:
			var status := statuses.build_from_effect(actor, effect)
			statuses.apply(actor, target, status)
			_log(result, "  %s %s" % [target.display_name, status.format_badge()])

		TurnSkillEffect.Kind.DEBUFF:
			var debuff := statuses.build_from_effect(actor, effect)
			var applied := statuses.apply(actor, target, debuff, effect.chance)
			if applied != null:
				_log(result, "  %s %s" % [target.display_name, applied.format_badge()])
			else:
				_log(result, "  %s 디버프 저항 (%s)"
					% [target.display_name, effect.get_label()])

		TurnSkillEffect.Kind.DOT:
			# 중첩 폭발형: 요구 상태를 터뜨린다.
			if effect.consume_status and effect.require_status:
				var burst := statuses.detonate(actor, target, effect.require_status_kind,
					effect.per_stack_multiplier, true)
				if burst != null:
					result["damage"].append(burst)
					_log(result, "  " + burst.summary())
					if burst.killed:
						_on_kill(actor, target, result)
					if not target.alive:
						return
			var dot := statuses.build_from_effect(actor, effect)
			var dot_applied := statuses.apply(actor, target, dot, effect.chance)
			if dot_applied != null:
				_log(result, "  %s %s" % [target.display_name, dot_applied.format_badge()])
			else:
				_log(result, "  %s %s 저항"
					% [target.display_name, TurnCombat.break_status_name(effect.break_status)])

		TurnSkillEffect.Kind.PUSH:
			var moved := ranks.push(target, effect.distance)
			_log(result, "  %s 밀치기 %d칸 → %s%d"
				% [target.display_name, moved, "E" if target.is_enemy() else "A", target.rank])

		TurnSkillEffect.Kind.PULL:
			var pulled := ranks.pull(target, effect.distance)
			_log(result, "  %s 끌어당기기 %d칸 → %s%d"
				% [target.display_name, pulled, "E" if target.is_enemy() else "A", target.rank])

		TurnSkillEffect.Kind.SHIFT:
			var shifted := ranks.shift(target, effect.distance)
			_log(result, "  %s 자리바꿈 %d칸 → A%d"
				% [target.display_name, shifted, target.rank])

		TurnSkillEffect.Kind.ADVANCE:
			var reduced := timeline.advance_action(target, effect.value)
			_log(result, "  %s 행동 앞당김 %.0f%% (AV -%.2f)"
				% [target.display_name, effect.value * 100.0, reduced])

		TurnSkillEffect.Kind.DELAY:
			var added := timeline.delay_action(target, effect.value)
			_log(result, "  %s 행동 지연 %.0f%% (AV +%.2f)"
				% [target.display_name, effect.value * 100.0, added])

		TurnSkillEffect.Kind.EXTRA_TURN:
			var granted := timeline.grant_extra_turn(target)
			_log(result, "  %s 추가 턴 %s"
				% [target.display_name, "획득" if granted else "상한 도달(무시)"])

		TurnSkillEffect.Kind.ENERGY:
			var gained := resources.gain_energy(target, effect.amount)
			_log(result, "  %s 오의 게이지 %+d (%d/%d)"
				% [target.display_name, gained, target.energy, target.get_energy_max()])

		TurnSkillEffect.Kind.RESONANCE:
			_apply_resonance(effect, result)

		TurnSkillEffect.Kind.CLEANSE:
			var removed := statuses.cleanse(target, effect.amount)
			_log(result, "  %s 디버프 %d개 해제" % [target.display_name, removed])

		TurnSkillEffect.Kind.BATON:
			# 배턴 터치: 추가 턴을 아군에게 양도하고, 받은 쪽이 강화된다.
			# 누적 최대 3회 = 공격력 +60% (버킷 A에 들어간다).
			target.baton_stacks = mini(target.baton_stacks + 1, 3)
			var passed := timeline.grant_extra_turn(target)
			_log(result, "  배턴 → %s (%d중첩, 추가 턴 %s)"
				% [target.display_name, target.baton_stacks,
					"획득" if passed else "상한 도달"])

		TurnSkillEffect.Kind.HEAT:
			resources.add_heat(float(effect.amount))
			_log(result, "  열기 %+d → %.0f (%s)"
				% [effect.amount, resources.heat, resources.heat_zone_name()])

		_:
			_log(result, "  (미구현 효과: %s)" % effect.get_label())


func _apply_resonance(effect: TurnSkillEffect, result: Dictionary) -> void:
	if effect.amount >= 0:
		var gained := resources.gain_resonance(effect.amount)
		_log(result, "  공명 포인트 +%d (%d/%d)"
			% [gained, resources.resonance, resources.resonance_max])
	else:
		resources.spend_resonance(-effect.amount)
		_log(result, "  공명 포인트 %d (%d/%d)"
			% [effect.amount, resources.resonance, resources.resonance_max])


# ===== 범위 산출 (Scope) =====

func _resolve_scope(actor: TurnUnit, skill: SkillData, primary: TurnUnit,
		effect: TurnSkillEffect) -> Array[TurnUnit]:
	var enemy_side := TurnCombat.Side.ENEMY if actor.is_ally() else TurnCombat.Side.ALLY
	var out: Array[TurnUnit] = []

	match effect.scope:
		TurnSkillEffect.Scope.SELF:
			out.append(actor)

		TurnSkillEffect.Scope.TARGET:
			if primary != null:
				out.append(primary)
			elif skill.turn_targeting == TurnCombat.Targeting.ALL_ENEMIES:
				out.append_array(ranks.living(enemy_side))
			elif skill.targets_allies():
				out.append_array(ranks.living(actor.side))

		TurnSkillEffect.Scope.TARGET_ADJACENT:
			if primary != null:
				out.append_array(ranks.adjacent(primary))

		TurnSkillEffect.Scope.ALL_ENEMIES:
			out.append_array(ranks.living(enemy_side))

		TurnSkillEffect.Scope.ALL_ALLIES:
			out.append_array(ranks.living(actor.side))

		TurnSkillEffect.Scope.ALLY_SINGLE:
			if primary != null and primary.side == actor.side:
				out.append(primary)
			else:
				out.append(actor)

		TurnSkillEffect.Scope.LOWEST_HP_ALLY:
			var lowest: TurnUnit = null
			for ally in ranks.living(actor.side):
				if lowest == null or ally.get_hp_ratio() < lowest.get_hp_ratio():
					lowest = ally
			if lowest != null:
				out.append(lowest)

		TurnSkillEffect.Scope.ALL_BROKEN:
			for unit in ranks.living(enemy_side):
				if unit.is_broken:
					out.append(unit)

	return out


# ===== 조건 (Condition) =====

func _condition_met(actor: TurnUnit, target: TurnUnit, effect: TurnSkillEffect) -> bool:
	if effect.require_broken and not target.is_broken:
		return false
	if effect.require_status and target.find_break_status(effect.require_status_kind) == null:
		# 중첩 폭발형 효과는 상태가 없으면 발동하지 않는다. 단, 재부여가 목적인 DOT
		# 효과는 상태가 없어도 걸어야 하므로 `consume_status`가 꺼져 있으면 통과시킨다.
		if effect.consume_status:
			return false
	if effect.require_target_hp_below > 0.0 \
			and target.get_hp_ratio() > effect.require_target_hp_below:
		return false
	return true


# ===== 후처리 (Post) =====

func _post_action(actor: TurnUnit, skill: SkillData, element: int,
		result: Dictionary) -> void:
	# 오의 게이지 획득.
	var gained := resources.gain_energy_for_action(actor, skill.turn_action)
	if gained > 0:
		_log(result, "  %s 오의 게이지 +%d (%d/%d)"
			% [actor.display_name, gained, actor.energy, actor.get_energy_max()])

	# 일반공격은 공명 포인트를 번다. **파티 공유 지갑**이므로 팀 전체가 이득을 본다.
	if skill.is_turn_basic():
		var rp := resources.gain_resonance(_tuning().resonance_gain_basic)
		if rp > 0:
			_log(result, "  공명 포인트 +%d (%d/%d)"
				% [rp, resources.resonance, resources.resonance_max])

	# 열기.
	resources.add_heat_for_action(skill.turn_action)
	if resources.apply_recommendation(actor, skill.turn_action, element):
		_log(result, "  ★ 권장 행동 달성 — 열기 %.0f (%s)"
			% [resources.heat, resources.heat_zone_name()])

	# 배턴은 자기 턴을 쓰면 사라진다 — 릴레이의 끝은 딜러 한 명이어야 한다.
	if skill.consumes_turn() and actor.baton_stacks > 0:
		actor.baton_stacks = 0
		statuses.remove(actor, &"baton")


# ===== 특성 (Traits) =====
#
# 특성은 플레이어가 누르지 않는다. 조건이 맞을 때 자동으로 터진다. 이 축이 만드는 것:
# "턴 수를 늘리지 않고 **행동 수**를 늘리는 우회로"(추가공격 팀)와, 적 속도가 빠를수록
# 강해지는 역설적 팀(반격 팀)이다.
#
# `context`: 발동을 유발한 피해. 반격 대상과 비례 회복량을 여기서 읽는다.
# `turn_index`: 이 유닛이 지금까지 행동한 턴 수. 주기 판정에 쓴다.
#
# 반환: 발동한 특성들의 실행 결과를 합친 것.
func fire_traits(unit: TurnUnit, trigger: int, context: DamageContext = null,
		turn_index: int = 1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if unit == null or not unit.alive:
		return out

	var traits := _trait_skills(unit)
	for skill in traits:
		if skill.trait_trigger != trigger:
			continue
		if not skill.trait_ready(turn_index):
			continue
		if skill.trait_require_self_status \
				and not unit.has_status_kind(skill.trait_self_status_kind):
			continue
		if skill.trait_per_turn_cap > 0:
			var fired := int(_trait_fires.get(_trait_key(unit, skill), 0))
			if fired >= skill.trait_per_turn_cap:
				continue
			_trait_fires[_trait_key(unit, skill)] = fired + 1

		# 반격은 **때린 쪽**을 대상으로 한다. 그 외 특성은 자기 효과 범위를 따른다.
		var target: TurnUnit = null
		if trigger == SkillData.TraitTrigger.ON_DAMAGE_TAKEN and context != null:
			target = context.source
		elif context != null:
			target = context.target

		var result := _execute_trait(unit, skill, target, context)
		if bool(result.get("ok", false)):
			out.append(result)

	return out


# 특성 실행. 코스트와 랭크 조건을 건너뛴다 — 특성은 자동 발동이고, 조건은
# `trait_trigger`가 이미 판정했다. 랭크 조건까지 걸면 대형이 무너질 때 특성이
# 조용히 사라져 "왜 반격이 안 나오는가"를 알 수 없게 된다.
func _execute_trait(unit: TurnUnit, skill: SkillData, target: TurnUnit,
		context: DamageContext) -> Dictionary:
	var result := {
		"ok": true, "reason": "",
		"damage": [] as Array[DamageContext],
		"breaks": [] as Array[TurnUnit],
		"nullified": [] as Array[TurnUnit],
		"kills": [] as Array[TurnUnit],
		"logs": [] as Array[String],
		"consumed_turn": false,
	}

	var element := skill.resolve_element(unit.element)
	var physical := skill.resolve_physical_type(unit.physical_type)
	_log(result, "특성 「%s」 발동 (%s)" % [skill.display_name, unit.display_name])

	for effect in skill.turn_effects:
		if effect == null:
			continue

		# 자신이 넣은 피해에 비례하는 효과(수혈). 배율 대신 실제 피해량을 쓴다.
		var scaled := effect
		if skill.trait_damage_ratio > 0.0 and context != null:
			scaled = effect.duplicate(true) as TurnSkillEffect
			scaled.multiplier = 0.0
			scaled.flat = int(round(float(context.hp_damage) * skill.trait_damage_ratio))

		for scope_target in _resolve_scope(unit, skill, target, scaled):
			if scope_target == null or not scope_target.alive:
				continue
			if not _condition_met(unit, scope_target, scaled):
				continue

			if scaled.kind == TurnSkillEffect.Kind.DAMAGE \
					or scaled.kind == TurnSkillEffect.Kind.TOUGHNESS:
				_apply_damage(unit, skill, scaled, scope_target, 1.0,
					element, physical, 1, 1, result)
			else:
				_apply_other(unit, skill, scaled, scope_target, element, result)

	# 특성도 오의 게이지를 조금 채운다(설계서 §7.1 — 추가공격 +10).
	resources.gain_energy_for_action(unit, TurnCombat.ActionKind.TRAIT)
	return result


func _trait_skills(unit: TurnUnit) -> Array[SkillData]:
	var out: Array[SkillData] = []
	var source: Array[SkillData] = []
	if unit.character != null:
		source = unit.character.get_turn_skills(TurnCombat.ActionKind.TRAIT)
	elif unit.enemy != null:
		source = unit.enemy.get_turn_skills(TurnCombat.ActionKind.TRAIT)
	for skill in source:
		if skill != null and skill.is_turn_trait():
			out.append(skill)
	return out


## 이번 턴에 각 특성이 몇 번 발동했는가. `unit_id|skill_id` -> 횟수.
## 턴이 끝나면 전투가 `reset_trait_fires()`로 비운다.
var _trait_fires: Dictionary = {}


## 지금 특성을 실행 중인가. 특성이 특성을 낳는 재귀를 막는다.
var _in_trait: bool = false


# 특성 실행 결과를 원래 결과에 합친다.
func _merge(result: Dictionary, extras: Array[Dictionary]) -> void:
	for extra in extras:
		result["damage"].append_array(extra.get("damage", []))
		result["breaks"].append_array(extra.get("breaks", []))
		result["nullified"].append_array(extra.get("nullified", []))
		for killed in extra.get("kills", []):
			if not result["kills"].has(killed):
				result["kills"].append(killed)
		for line in extra.get("logs", []):
			result["logs"].append("  " + String(line))


func _trait_key(unit: TurnUnit, skill: SkillData) -> String:
	return "%s|%s" % [unit.unit_id, skill.skill_id]


func reset_trait_fires() -> void:
	_trait_fires.clear()


func _log(result: Dictionary, line: String) -> void:
	result["logs"].append(line)


# ===== 예상 피해 (Expected damage) =====

# 이 스킬이 각 대상에게 넣을 **예상 피해**를 계산한다. 상태를 바꾸지 않는다.
#
# 적 행동 예고의 "예상 피해 840 x 3회"와 아군 스킬 툴팁이 같은 함수를 쓴다 —
# 두 곳이 다른 계산을 하면 공개한 수치를 신뢰할 수 없게 된다.
#
# 반환: `unit_id` -> 예상 피해 총합.
func expected_damage(actor: TurnUnit, skill: SkillData,
		primary: TurnUnit = null) -> Dictionary:
	var out: Dictionary = {}
	if actor == null or skill == null:
		return out

	var element := skill.resolve_element(actor.element)
	var physical := skill.resolve_physical_type(actor.physical_type)
	var hits := maxi(skill.turn_hits, 1)
	var expanded := ranks.expand_targets(actor, skill, primary, null)

	for effect in skill.turn_effects:
		if effect == null or effect.kind != TurnSkillEffect.Kind.DAMAGE:
			continue
		for entry in expanded:
			var target: TurnUnit = entry[0]
			var ratio: float = entry[1]
			if target == null or not target.alive:
				continue

			var ctx := DamageContext.new()
			ctx.source = actor
			ctx.target = target
			ctx.skill = skill
			ctx.effect = effect
			ctx.element = element
			ctx.physical_type = physical
			ctx.target_ratio = ratio
			ctx.preview_mode = true
			pipeline.compute(ctx)

			var total := maxi(int(round(ctx.damage)), 1) * hits
			out[target.unit_id] = int(out.get(target.unit_id, 0)) + total

	return out


# 이 스킬을 쓰면 타임라인이 어떻게 바뀌는가. `TimelineSystem.preview_if_acted()`에 넘길
# `av_changes`를 만든다 (설계서 §4.2.5 타임라인 프리뷰).
#
# 반환: `{"av_changes": Dictionary, "grants_extra": bool}`
func timeline_effects(actor: TurnUnit, skill: SkillData,
		primary: TurnUnit = null) -> Dictionary:
	var changes: Dictionary = {}
	var grants_extra := false
	if actor == null or skill == null:
		return {"av_changes": changes, "grants_extra": grants_extra}

	for effect in skill.turn_effects:
		if effect == null:
			continue
		match effect.kind:
			TurnSkillEffect.Kind.ADVANCE:
				for target in _resolve_scope(actor, skill, primary, effect):
					changes[target.unit_id] = -effect.value
			TurnSkillEffect.Kind.DELAY:
				for target in _resolve_scope(actor, skill, primary, effect):
					changes[target.unit_id] = effect.value
			TurnSkillEffect.Kind.EXTRA_TURN, TurnSkillEffect.Kind.BATON:
				grants_extra = true
			_:
				pass

	# 격파 상태이상이 걸 지연도 반영한다 — 격파가 예상되는 타격이면 순서가 실제로 바뀐다.
	return {"av_changes": changes, "grants_extra": grants_extra}
