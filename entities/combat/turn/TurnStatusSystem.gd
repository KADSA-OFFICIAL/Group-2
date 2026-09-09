extends RefCounted
class_name TurnStatusSystem

# 턴 단위 버프/디버프/지속피해 시스템 (#450).
#
# 기존 `StatusEffectSystem`(autoload, 초 단위)과 **별개 축**이다. 그 시스템은 실시간
# 전투가 쓰고 있고 `_process(delta)`로 지속시간을 줄인다. 턴 단위 효과는 "자기 턴
# 시작에 1 감소"로 줄어서, 한 컨테이너에 넣으면 만료 판정이 두 갈래가 된다.
#
# **격파 상태이상 7종을 전부 다르게 설계한 것**이 이 파일의 핵심이다. "그냥 다 도트뎀"으로
# 만들지 않고 CC 계열과 데미지 계열을 섞었다 — 덕분에 약점 속성 맞추기가 단순 최적화가
# 아니라 전략 선택이 된다.
#
# 참고: docs/turn-combat-design.md §상태이상

var rng: RandomNumberGenerator = null
var pipeline: DamagePipeline = null

## 지속 피해가 발생했을 때 호출된다. `func(ctx: DamageContext) -> void`.
## 연출과 로그를 전투가 받아 처리하도록 콜백으로 빼 둔다 — 이 클래스는 연출을 모른다.
var on_damage: Callable = Callable()


func _init(random: RandomNumberGenerator = null, damage_pipeline: DamagePipeline = null) -> void:
	rng = random if random != null else RandomNumberGenerator.new()
	pipeline = damage_pipeline


func _tuning() -> TurnCombatTuning:
	return PlayerStats.get_tuning_turn()


# ===== 격파 상태이상 규격 (Break status spec) =====
#
# 설계서 §4.4.1 의 표를 그대로 옮긴 것이다. **7개가 전부 다르다**:
# 열상은 최대HP 비례, 연소는 공격력 비례 중첩, 동결은 행동 봉인, 감전은 조건부 폭딜,
# 균열은 무한 성장, 속박은 지연 + 폭발, 각인은 속도 감소.
#
# 그리고 **격파 데미지가 낮은 원소(침식·광휘)에 강한 유틸리티**를 준다 — 트레이드오프다.
const BREAK_SPEC := {
	TurnCombat.BreakStatus.BLEED: {
		"turns": 3, "max_stacks": 1, "multiplier": 0.02,
		"scaling": TurnCombat.Scaling.MAX_HP, "from_target": true,
		"stun": false,
	},
	TurnCombat.BreakStatus.BURN: {
		"turns": 3, "max_stacks": 3, "multiplier": 0.60,
		"scaling": TurnCombat.Scaling.ATTACK, "from_target": false,
		"stun": false,
	},
	TurnCombat.BreakStatus.FREEZE: {
		"turns": 1, "max_stacks": 1, "multiplier": 0.0,
		"scaling": TurnCombat.Scaling.ATTACK, "from_target": false,
		"stun": true, "expire_burst": 1.00,
	},
	TurnCombat.BreakStatus.SHOCK: {
		"turns": 3, "max_stacks": 1, "multiplier": 0.50,
		"scaling": TurnCombat.Scaling.ATTACK, "from_target": false,
		"stun": false, "on_skill_extra": 0.40,
	},
	TurnCombat.BreakStatus.FRACTURE: {
		"turns": 3, "max_stacks": 5, "multiplier": 0.25,
		"scaling": TurnCombat.Scaling.ATTACK, "from_target": false,
		"stun": false, "stacks_on_break": 2,
	},
	TurnCombat.BreakStatus.BIND: {
		"turns": 3, "max_stacks": 6, "multiplier": 0.0,
		"scaling": TurnCombat.Scaling.ATTACK, "from_target": false,
		"stun": false, "delay": 0.30, "vulnerability_per_stack": 0.025,
		"expire_burst": 0.55, "expire_burst_per_stack": true,
	},
	TurnCombat.BreakStatus.SIGIL: {
		"turns": 3, "max_stacks": 1, "multiplier": 0.0,
		"scaling": TurnCombat.Scaling.ATTACK, "from_target": false,
		"stun": false, "delay": 0.20, "speed_percent": -0.20, "vulnerability": 0.12,
	},
}


# ===== 부여 (Apply) =====

# 상태 하나를 붙인다. 같은 id가 이미 있으면 중첩/지속시간을 갱신한다.
#
# 반환: 실제로 붙은(또는 갱신된) 상태. 확률 판정에 실패하면 null.
func apply(source: TurnUnit, target: TurnUnit, status: TurnStatus,
		chance: float = 0.0) -> TurnStatus:
	if not target.alive:
		return null

	if chance > 0.0 and not roll_debuff(source, target, chance):
		return null

	var existing := target.find_status(status.id)
	if existing != null:
		existing.refresh(status.stacks, status.turns_left)
		_recompute(target)
		return existing

	target.statuses.append(status)
	_recompute(target)
	return status


# 디버프 부여 확률 판정 (효과 적중 / 효과 저항 / Pity).
#
# **Pity가 있는 이유**: 확률 3회 연속 실패는 억울하다. 다키스트 던전이 미표기 확률과
# 연속 빗나감으로 유저를 이탈시킨 지점이고, 설계 3원칙("랜덤으로 지는 일이 없어야 한다")에
# 정면으로 어긋난다. 4회차는 확정 성공이다.
func roll_debuff(source: TurnUnit, target: TurnUnit, base_chance: float) -> bool:
	var t := _tuning()

	if target.debuff_failures >= t.debuff_pity_after_failures:
		target.debuff_failures = 0
		return true

	var hit := source.stats.get_effect_hit() if source != null else 0.0
	var res := target.stats.get_effect_res()
	var chance := clampf(base_chance * (1.0 + hit) * (1.0 - res), 0.0, 1.0)

	if rng.randf() < chance:
		target.debuff_failures = 0
		return true

	target.debuff_failures += 1
	return false


# 격파 상태이상을 부여한다. 원소가 어느 상태이상을 거는지는 `TurnCombat.BREAK_STATUS`가 정한다.
#
# 반환: 붙은 상태. 규격이 없으면 null.
func apply_break_status(source: TurnUnit, target: TurnUnit, element: int) -> TurnStatus:
	var break_status := TurnCombat.element_break_status(element)
	var spec: Dictionary = BREAK_SPEC.get(break_status, {})
	if spec.is_empty():
		return null

	var status := build_break_status(source, break_status, element,
		int(spec.get("stacks_on_break", 1)))
	var applied := apply(source, target, status)

	# 부수 효과: 행동 지연은 상태가 아니라 타임라인 조작이므로 전투가 처리한다
	# (여기서는 상태에 기록만 하고, `BattleManager`가 읽어 `TimelineSystem`에 넘긴다).
	return applied


# 격파 상태이상 인스턴스를 규격에서 만든다.
func build_break_status(source: TurnUnit, break_status: int, element: int,
		stacks: int = 1) -> TurnStatus:
	var spec: Dictionary = BREAK_SPEC.get(break_status, {})
	var id := StringName("break_%d" % break_status)

	var kind := TurnStatus.Kind.STUN if bool(spec.get("stun", false)) else TurnStatus.Kind.DOT
	var status := TurnStatus.new(id, kind, int(spec.get("turns", 1)))
	status.break_status = break_status
	status.element = element
	status.display_name = TurnCombat.break_status_name(break_status)
	status.stacks = maxi(stacks, 1)
	status.max_stacks = int(spec.get("max_stacks", 1))
	status.dot_multiplier = float(spec.get("multiplier", 0.0))
	status.dot_scaling = int(spec.get("scaling", TurnCombat.Scaling.ATTACK))
	status.dot_from_target = bool(spec.get("from_target", false))
	status.source_id = source.unit_id if source != null else &""
	status.expire_burst_multiplier = float(spec.get("expire_burst", 0.0))
	status.expire_burst_per_stack = bool(spec.get("expire_burst_per_stack", false))

	# 스탯 변화가 있는 상태이상은 `mods`로 담는다 (각인 = 속도 -20% + 받는피해 +12%).
	if spec.has("speed_percent"):
		status.add_mod(&"speed", float(spec["speed_percent"]))
	if spec.has("vulnerability"):
		status.add_mod(&"vulnerability", float(spec["vulnerability"]))
	if spec.has("vulnerability_per_stack"):
		# 중첩당 값이므로 `all_mods()`가 중첩을 곱해 준다.
		status.add_mod(&"vulnerability", float(spec["vulnerability_per_stack"]))

	return status


# 이 격파 상태이상이 부여와 동시에 걸어야 하는 행동 지연 비율. 없으면 0.
func break_delay_ratio(break_status: int) -> float:
	var spec: Dictionary = BREAK_SPEC.get(break_status, {})
	return float(spec.get("delay", 0.0))


# 감전이 걸린 적이 스킬을 쓸 때 터지는 추가 피해 배율. 없으면 0.
func shock_extra_multiplier() -> float:
	return float(BREAK_SPEC[TurnCombat.BreakStatus.SHOCK].get("on_skill_extra", 0.0))


# 스킬 효과(`TurnSkillEffect`)로부터 상태를 만든다.
func build_from_effect(source: TurnUnit, effect: TurnSkillEffect) -> TurnStatus:
	match effect.kind:
		TurnSkillEffect.Kind.DOT:
			var dot := build_break_status(source, effect.break_status,
				source.element, effect.stacks)
			if effect.duration > 0:
				dot.turns_left = effect.duration
			if effect.multiplier > 0.0:
				dot.dot_multiplier = effect.multiplier
				dot.dot_scaling = effect.scaling
				dot.dot_from_target = false
			return dot

		TurnSkillEffect.Kind.SHIELD:
			var shield := TurnStatus.new(
				StringName("shield_%s" % effect.get_label()),
				TurnStatus.Kind.SHIELD, maxi(effect.duration, 1))
			shield.display_name = "보호막"
			shield.shield_amount = int(round(
				effect.multiplier * float(source.get_scaling_value(effect.scaling))
					+ float(effect.flat)))
			return shield

		TurnSkillEffect.Kind.TAUNT:
			var taunt := TurnStatus.new(&"taunt", TurnStatus.Kind.TAUNT,
				maxi(effect.duration, 1))
			taunt.display_name = "도발"
			return taunt

		TurnSkillEffect.Kind.ANCHOR:
			var anchor := TurnStatus.new(&"anchor", TurnStatus.Kind.ANCHOR,
				maxi(effect.duration, 1))
			anchor.display_name = "고정"
			return anchor

		TurnSkillEffect.Kind.BATON:
			var baton := TurnStatus.new(&"baton", TurnStatus.Kind.BATON, 1)
			baton.display_name = "배턴"
			return baton

		_:  # BUFF / DEBUFF
			var kind := TurnStatus.Kind.DEBUFF \
				if effect.kind == TurnSkillEffect.Kind.DEBUFF else TurnStatus.Kind.BUFF
			var status := TurnStatus.new(
				StringName("%s_%s" % ["debuff" if kind == TurnStatus.Kind.DEBUFF else "buff",
					String(effect.stat_key)]),
				kind, maxi(effect.duration, 1))
			status.stat_key = effect.stat_key
			status.value = effect.value
			status.is_flat = effect.stat_is_flat
			status.bucket = effect.bucket
			status.max_stacks = 1
			status.display_name = effect.get_label()
			return status


# ===== 정화 (Cleanse) =====

# 디버프를 앞에서부터 `count`개 제거한다. 0 이하면 전부.
#
# 반환: 제거한 개수.
func cleanse(target: TurnUnit, count: int = 0) -> int:
	var removed := 0
	var kept: Array[TurnStatus] = []

	for status in target.statuses:
		var is_bad := status.kind == TurnStatus.Kind.DEBUFF \
			or status.kind == TurnStatus.Kind.DOT \
			or status.kind == TurnStatus.Kind.STUN
		if is_bad and (count <= 0 or removed < count):
			removed += 1
			continue
		kept.append(status)

	target.statuses = kept
	if removed > 0:
		_recompute(target)
	return removed


func remove(target: TurnUnit, id: StringName) -> bool:
	var before := target.statuses.size()
	target.statuses = target.statuses.filter(func(s: TurnStatus) -> bool: return s.id != id)
	if target.statuses.size() != before:
		_recompute(target)
		return true
	return false


func clear_all(target: TurnUnit) -> void:
	target.statuses.clear()
	_recompute(target)


# ===== 턴 진행 (Tick) =====

# 유닛의 턴이 시작됐다. 지속 피해를 터뜨리고 지속시간을 줄인다.
#
# 순서가 중요하다: **먼저 발동하고 나중에 줄인다.** 반대로 하면 1턴짜리 효과가
# 한 번도 발동하지 않고 사라진다.
#
# 반환: 이 턴에 발생한 피해 컨텍스트들. 연출과 로그가 쓴다.
func tick_turn_start(target: TurnUnit, units: Array[TurnUnit]) -> Array[DamageContext]:
	var out: Array[DamageContext] = []
	if not target.alive:
		return out

	# 1) 지속 피해 발동.
	for status in target.statuses.duplicate():
		if status.kind != TurnStatus.Kind.DOT or status.dot_multiplier <= 0.0:
			continue
		var ctx := _apply_dot(status, target, units)
		if ctx != null:
			out.append(ctx)
			if not target.alive:
				return out

	# 2) 지속시간 감소 + 만료 처리.
	var expired: Array[TurnStatus] = []
	for status in target.statuses:
		status.tick_down()
		if status.is_expired():
			expired.append(status)

	for status in expired:
		var burst := _apply_expire_burst(status, target, units)
		if burst != null:
			out.append(burst)

	if not expired.is_empty():
		target.statuses = target.statuses.filter(
			func(s: TurnStatus) -> bool: return not s.is_expired())
		_recompute(target)

	return out


# 지속 피해 한 건을 터뜨린다.
func _apply_dot(status: TurnStatus, target: TurnUnit,
		units: Array[TurnUnit]) -> DamageContext:
	if pipeline == null:
		return null

	var source := _find(units, status.source_id)
	if source == null:
		source = target  # 출처가 죽어 사라졌으면 대상 기준으로 계산한다(효과가 조용히 사라지지 않게).

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = status.dot_multiplier * float(status.stacks)
	effect.scaling = status.dot_scaling
	effect.toughness_damage = 0

	var ctx := DamageContext.new()
	# **지속 피해는 치명타가 나지 않고 인성치를 깎지 않는다.**
	ctx.is_dot = true
	ctx.source = target if status.dot_from_target else source
	ctx.target = target
	ctx.effect = effect
	ctx.element = status.element if status.element >= 0 else source.element
	ctx.physical_type = ctx.source.physical_type
	ctx.note("지속 피해: %s %d중첩" % [status.get_display_name(), status.stacks])

	pipeline.resolve(ctx)
	_emit(ctx)
	return ctx


# 만료 폭발. 동결의 "해제 시 피해", 속박의 "해제 시 폭발"이 여기로 온다.
func _apply_expire_burst(status: TurnStatus, target: TurnUnit,
		units: Array[TurnUnit]) -> DamageContext:
	if pipeline == null or status.expire_burst_multiplier <= 0.0:
		return null

	var source := _find(units, status.source_id)
	if source == null:
		return null

	var multiplier := status.expire_burst_multiplier
	if status.expire_burst_per_stack:
		multiplier *= float(status.stacks)

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = multiplier
	effect.scaling = TurnCombat.Scaling.ATTACK

	var ctx := DamageContext.new()
	ctx.is_additional = true  # 추가 피해 — 치명타 불가, 인성치 피해 없음.
	ctx.source = source
	ctx.target = target
	ctx.effect = effect
	ctx.element = status.element if status.element >= 0 else source.element
	ctx.physical_type = source.physical_type
	ctx.note("%s 해제 폭발 (배율 %.0f%%)" % [status.get_display_name(), multiplier * 100.0])

	pipeline.resolve(ctx)
	_emit(ctx)
	return ctx


# 속박 중첩을 즉시 폭발시킨다 (「완성된 초상」의 오의처럼 스킬이 강제로 터뜨릴 때).
func detonate(source: TurnUnit, target: TurnUnit, break_status: int,
		per_stack_multiplier: float, consume: bool) -> DamageContext:
	var status := target.find_break_status(break_status)
	if status == null or pipeline == null:
		return null

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = per_stack_multiplier * float(status.stacks)
	effect.scaling = TurnCombat.Scaling.ATTACK

	var ctx := DamageContext.new()
	ctx.is_additional = true
	ctx.source = source
	ctx.target = target
	ctx.effect = effect
	ctx.element = source.element
	ctx.physical_type = source.physical_type
	ctx.note("%s %d중첩 폭발 (중첩당 %.0f%%)"
		% [status.get_display_name(), status.stacks, per_stack_multiplier * 100.0])

	pipeline.resolve(ctx)
	_emit(ctx)

	if consume:
		remove(target, status.id)

	return ctx


# ===== 스탯 재계산 (Recompute) =====
#
# 걸린 상태 전부를 합산해 `PlayerStats`의 버프 채널에 한 번에 밀어 넣는다.
#
# **왜 합산해서 한 번에 넣는가**: `PlayerStats`의 버프 채널은 "지금 걸린 것 전체의 합"을
# 담는 자리다(실시간 `set_buff_bonuses()`와 같은 규약). 상태마다 더하기/빼기를 하면
# 만료 순서에 따라 값이 어긋나 버프가 영구히 남는 버그가 생긴다.
func _recompute(target: TurnUnit) -> void:
	var flat: Dictionary = {}
	var percent: Dictionary = {}

	for status in target.statuses:
		if not status.is_stat_modifier():
			continue
		for mod in status.all_mods():
			var key: StringName = mod["key"]
			if String(key).is_empty():
				continue
			var bucket_dict: Dictionary = flat if bool(mod["flat"]) else percent
			bucket_dict[key] = float(bucket_dict.get(key, 0.0)) + float(mod["value"])

	target.stats.set_turn_buff_bonuses(flat, percent)

	# 실시간 채널과 공유하는 키(공격력·방어력·최대HP)는 그쪽 통로에도 밀어 넣는다.
	# 두 채널은 독립적이라 서로 덮어쓰지 않는다.
	target.stats.set_buff_bonuses(flat, percent)


# 전투 시작 시 호출. 저작 데이터에 남아 있을 수 있는 버프 채널을 비운다.
func reset(target: TurnUnit) -> void:
	target.statuses.clear()
	target.stats.clear_turn_buff_bonuses()
	target.stats.clear_buff_bonuses()
	target.debuff_failures = 0


func _find(units: Array[TurnUnit], id: StringName) -> TurnUnit:
	for unit in units:
		if unit.unit_id == id:
			return unit
	return null


func _emit(ctx: DamageContext) -> void:
	if on_damage.is_valid():
		on_damage.call(ctx)
