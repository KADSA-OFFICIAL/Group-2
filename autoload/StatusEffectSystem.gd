extends Node

# 상태 효과 런타임 (autoload).
#
# 책임: 대상에게 효과를 걸고, 시간을 흘려보내고, 조건이 되면 푼다.
#   - 효과 **정의**는 StatusEffectDatabase(-> StatusEffectData)가 출처다. 여기서 재정의하지 않는다.
#   - 효과 **수치**는 CombatConfig.tuning이 출처다.
#   - 스텟 변경은 PlayerStats의 **버프 채널**로만 나간다(장비 채널과 독립).
#
# 대상(target): PlayerStats를 가진 노드면 무엇이든 된다.
#   조회 API의 target은 타입을 지정하지 않는다. 이미 해제된 노드를 타입 지정 파라미터로
#   넘기면 Godot이 "previously freed" 오류를 내므로, 오래된 참조로 조회해도 죽지 않게 한다.
#   파티 멤버(Player)와 적(EnemyBase)이 둘 다 get_stats()를 제공하므로 구분하지 않는다.
#
# 참고: docs/combat-screen-design.md §8.1

# 대상별로 걸린 효과. target(Node) -> { effect_id(StringName) -> _Instance }
var _active: Dictionary = {}

# tree_exiting을 연결해 둔 대상. 중복 연결을 막는다.
var _watched: Dictionary = {}

# 상태 효과가 아닌 곳에서 들어오는 스텟 기여분.
#   target(Node) -> { source_key(StringName) -> { "flat": Dictionary, "percent": Dictionary } }
#
# 왜 필요한가: PlayerStats.set_buff_bonuses()는 "최종값"을 받으므로 여러 곳에서 호출하면
# 서로 덮어쓴다. 그래서 버프 채널에 쓰는 주체는 이 시스템 하나로 유지한다.
# 그런데 원거리 스택처럼 **정수 단위로 서서히 감소하는** 값은 상태 효과의 만료 모델로
# 표현할 수 없다(만료는 전체가 한 번에 사라진다). 값은 소유자(Player)가 굴리고,
# 채널에 쓰는 일만 여기로 모은다.
var _external: Dictionary = {}


# 한 대상에 걸린 효과 하나의 런타임 상태.
class _Instance:
	var data: StatusEffectData
	var stacks: int = 1
	var time_left: float = 0.0     # 0 이하이고 data.is_permanent()면 무한
	var gauge: int = 0             # GAUGE 전용 누적값
	var tick_left: float = 0.0     # PERIODIC 전용 다음 틱까지 남은 시간
	var source: Node = null

	func _init(effect: StatusEffectData, from: Node) -> void:
		data = effect
		source = from
		time_left = effect.duration
		tick_left = effect.get_tick_interval()


func _ready() -> void:
	name = "StatusEffectSystem"


# ===== 적용 / 해제 (Apply / Remove) =====

# 대상에게 효과를 건다. 성공하면 true.
# 이미 걸려 있으면 StatusEffectData.stacking 규칙대로 처리한다.
func apply(target: Node, effect_id: StringName, source: Node = null) -> bool:
	return _apply_chain(target, effect_id, source, {})


# apply() 의 실제 몸통. visited 는 동반 효과 연쇄에서 순환을 끊기 위한 것이다(#328).
#
# 왜 순환을 끊어야 하는가: also_apply_effect_id 는 저작 데이터이므로 A -> B -> A 로 적힐 수 있다.
# 막지 않으면 스택이 터진다. 이미 이번 연쇄에서 건 효과는 다시 걸지 않는다 — 같은 효과를
# 두 번 거는 것은 중첩 규칙(REFRESH/STACK_INTENSITY)이 다룰 일이고, 그것은 **다음** 시전의 몫이다.
func _apply_chain(target: Node, effect_id: StringName, source: Node, visited: Dictionary) -> bool:
	if not _is_valid_target(target):
		return false
	if visited.has(effect_id):
		return false
	visited[effect_id] = true

	var data := StatusEffectDatabase.get_effect(effect_id)
	if data == null:
		return false

	var effects := _effects_of(target)

	if effects.has(effect_id):
		var existing: _Instance = effects[effect_id]
		match data.stacking:
			StatusEffectData.Stacking.IGNORE:
				# 자기 자신은 무시됐지만 동반 효과는 따라가야 한다 — 셋 중 하나만 IGNORE 라고
				# 나머지 둘이 걸리지 않으면, 겹쳐 쓸 때 상태가 조각난다.
				_apply_companion(target, data, source, visited)
				return false
			StatusEffectData.Stacking.REFRESH:
				existing.time_left = data.duration
			StatusEffectData.Stacking.STACK_INTENSITY:
				existing.stacks = mini(existing.stacks + 1, data.get_max_stacks())
				existing.time_left = data.duration
		_sync_stat_mods(target)
		_apply_companion(target, data, source, visited)
		return true

	effects[effect_id] = _Instance.new(data, source)
	_watch_target(target)
	_sync_stat_mods(target)
	EventBus.status_effect_applied.emit(target, effect_id)
	_apply_companion(target, data, source, visited)
	return true


# 함께 걸리는 효과를 이어서 건다. 없으면 아무 일도 하지 않는다.
func _apply_companion(target: Node, data: StatusEffectData, source: Node, visited: Dictionary) -> void:
	if data.also_apply_effect_id == &"":
		return
	_apply_chain(target, data.also_apply_effect_id, source, visited)


# 대상이 트리에서 빠질 때(죽어서 queue_free 되는 등) 그 대상의 효과를 정리한다.
#
# 선제 정리를 하는 이유: 해제된 노드가 _active의 키로 남으면, 그것을 타입이 지정된
# 파라미터(Node)로 넘기는 순간 "previously freed" 오류가 난다. 사후에 걸러내는 것보다
# 애초에 들고 있지 않는 편이 안전하다.
#
# bind된 Callable은 is_connected()로 판별하기 어려워, 감시 중인 대상을 따로 기록한다.
func _watch_target(target: Node) -> void:
	if _watched.has(target):
		return
	_watched[target] = true
	target.tree_exiting.connect(_on_target_exiting.bind(target))


func _on_target_exiting(target: Node) -> void:
	_watched.erase(target)
	_external.erase(target)
	clear(target)


# 대상에게서 효과를 제거한다.
func remove(target, effect_id: StringName) -> bool:
	if not _active.has(target):
		return false
	var effects: Dictionary = _active[target]
	if not effects.has(effect_id):
		return false

	effects.erase(effect_id)
	_sync_stat_mods(target)
	EventBus.status_effect_removed.emit(target, effect_id)
	return true


# 대상의 모든 효과를 제거한다.
func clear(target) -> void:
	if not _active.has(target):
		return
	for effect_id in _active[target].keys():
		remove(target, effect_id)
	_active.erase(target)


# ===== 조회 (Query) =====

func has_effect(target, effect_id: StringName) -> bool:
	if not _active.has(target):
		return false
	return _active[target].has(effect_id)

func get_stacks(target, effect_id: StringName) -> int:
	var inst := _find(target, effect_id)
	return 0 if inst == null else inst.stacks

func get_gauge(target, effect_id: StringName) -> int:
	var inst := _find(target, effect_id)
	return 0 if inst == null else inst.gauge

# 이 효과를 건 주체. 없으면 null.
# 표식 폭발의 추가 피해를 "표식을 건 탱커"의 공격력으로 계산하는 데 쓴다.
func get_source(target, effect_id: StringName) -> Node:
	var inst := _find(target, effect_id)
	if inst == null or not is_instance_valid(inst.source):
		return null
	return inst.source

# 대상에 걸린 효과 id 목록.
func get_effect_ids(target) -> Array:
	if not _active.has(target):
		return []
	return _active[target].keys()

# 디버프가 하나라도 걸려 있는가.
# 버퍼 처형이 "디버프가 걸린 적"을 조건으로 하므로 이 판정이 필요하다.
# 디버프 여부의 출처는 StatusEffectData.is_debuff이며 여기서 목록을 따로 두지 않는다.
func has_any_debuff(target) -> bool:
	if not _active.has(target):
		return false
	for effect_id in _active[target]:
		var inst: _Instance = _active[target][effect_id]
		if inst.data.is_debuff:
			return true
	return false


# ===== 행동 제약 (Control) =====
# CONTROL 효과가 무엇을 막는지 조회한다. 실제 차단은 소비하는 쪽(Player/EnemyBase)이 판단한다.

func blocks_movement(target) -> bool:
	return _blocks(target, "blocks_movement")

func blocks_attack(target) -> bool:
	return _blocks(target, "blocks_attack")

func blocks_skill(target) -> bool:
	return _blocks(target, "blocks_skill")

func _blocks(target, field: String) -> bool:
	if not _active.has(target):
		return false
	for effect_id in _active[target]:
		var inst: _Instance = _active[target][effect_id]
		if inst.data.kind == StatusEffectData.Kind.CONTROL and inst.data.get(field):
			return true
	return false


# ===== 게이지 (Gauge) =====

# GAUGE 효과를 충전한다. 임계치에 도달하면 터지며 후속 효과를 적용한다.
# amount가 0 이하면 효과 정의의 gauge_gain_per_hit을 쓴다.
# 반환: 이번 충전으로 터졌으면 true.
func add_gauge(target: Node, effect_id: StringName, amount: int = 0) -> bool:
	var inst := _find(target, effect_id)
	if inst == null or inst.data.kind != StatusEffectData.Kind.GAUGE:
		return false

	var gain := amount if amount > 0 else inst.data.get_gauge_gain_per_hit()
	inst.gauge += gain

	if inst.gauge < inst.data.get_gauge_threshold():
		return false

	# 터진다: 후속 효과를 걸고 자신은 소멸한다.
	var follow_up := inst.data.on_threshold_effect_id
	var source := inst.source
	remove(target, effect_id)
	EventBus.status_effect_burst.emit(target, effect_id)

	if not String(follow_up).is_empty():
		apply(target, follow_up, source)
	return true


# ===== 틱 (Tick) =====

func _process(delta: float) -> void:
	if _active.is_empty():
		return

	# 순회 중 제거가 일어나므로 키를 복사해 돈다.
	for target in _active.keys():
		if not _is_valid_target(target):
			_active.erase(target)
			continue
		_process_target(target, delta)


func _process_target(target, delta: float) -> void:
	var effects: Dictionary = _active[target]
	var expired: Array = []

	for effect_id in effects.keys():
		var inst: _Instance = effects[effect_id]

		# 지속 피해/회복
		if inst.data.kind == StatusEffectData.Kind.PERIODIC:
			inst.tick_left -= delta
			if inst.tick_left <= 0.0:
				inst.tick_left += inst.data.get_tick_interval()
				_apply_periodic(target, inst)

		# 지속시간이 무한이면 만료시키지 않는다(수동 해제 또는 GAUGE 임계치까지).
		if inst.data.is_permanent():
			continue

		inst.time_left -= delta
		if inst.time_left <= 0.0:
			expired.append(effect_id)

	for effect_id in expired:
		remove(target, effect_id)


func _apply_periodic(target: Node, inst: _Instance) -> void:
	var amount_damage := inst.data.tick_damage * inst.stacks
	var amount_heal := inst.data.tick_heal * inst.stacks

	# 최대 체력 비례분(#328). 절대값과 **더한다** — 두 채널을 함께 쓰는 효과가 있어도 된다.
	# 대상의 그릇을 물어보는 것이므로 여기서 계산한다(효과는 비율만 안다).
	if inst.data.tick_max_hp_percent > 0.0:
		var stats := _stats_of(target)
		if stats != null:
			amount_damage += int(round(float(stats.get_max_hp()) * inst.data.tick_max_hp_percent)) * inst.stacks

	if amount_damage > 0 and target.has_method("take_damage"):
		# 방어 무시가 켜져 있으면 세 번째 인자로 알린다. 옛 시그니처(2 인자)만 가진 대상이
		# 있을 수 있어 무시하지 않는 경우에는 지금까지처럼 2 인자로 부른다.
		if inst.data.tick_ignores_defense:
			target.take_damage(amount_damage, inst.source, true)
		else:
			target.take_damage(amount_damage, inst.source)
	if amount_heal > 0 and target.has_method("heal"):
		target.heal(amount_heal)


# ===== 외부 기여분 (External Contributions) =====
# 상태 효과가 아닌 메커니즘(원거리 스택 등)이 스텟 버프에 기여할 때 쓴다.
# 키(source_key)별로 덮어쓰므로, 소유자는 값이 바뀔 때마다 그냥 다시 넣으면 된다.

func set_external_bonus(target, source_key: StringName, flat: Dictionary = {}, percent: Dictionary = {}) -> void:
	if not _is_valid_target(target):
		return
	if not _external.has(target):
		_external[target] = {}
	_external[target][source_key] = {"flat": flat, "percent": percent}
	if target is Node:
		_watch_target(target)
	_sync_stat_mods(target)


func clear_external_bonus(target, source_key: StringName) -> void:
	if not _external.has(target):
		return
	_external[target].erase(source_key)
	if _external[target].is_empty():
		_external.erase(target)
	_sync_stat_mods(target)


# ===== 스텟 변경 반영 (Stat Mods) =====

# 대상에 걸린 모든 STAT_MOD를 합산해 PlayerStats의 버프 채널에 한 번에 밀어 넣는다.
#
# 합산 후 한 번에 넣는 이유: set_buff_bonuses()가 "최종값"을 받는 구조이므로,
# 효과마다 따로 호출하면 마지막 것이 앞의 것을 덮어쓴다.
# 장비 채널(equip_*)은 건드리지 않으므로 장비 보너스와 함께 합산된다.
func _sync_stat_mods(target) -> void:
	var stats := _stats_of(target)
	if stats == null:
		return

	var flat := {}
	var percent := {}

	if _active.has(target):
		for effect_id in _active[target]:
			var inst: _Instance = _active[target][effect_id]
			if inst.data.kind != StatusEffectData.Kind.STAT_MOD:
				continue
			for key in inst.data.stat_flat:
				flat[key] = int(flat.get(key, 0)) + int(inst.data.stat_flat[key]) * inst.stacks
			for key in inst.data.stat_percent:
				percent[key] = float(percent.get(key, 0.0)) + float(inst.data.stat_percent[key]) * inst.stacks


	# 외부 기여분(원거리 스택 등)도 같은 합에 넣는다.
	if _external.has(target):
		for source_key in _external[target]:
			var entry: Dictionary = _external[target][source_key]
			for key in entry["flat"]:
				flat[key] = int(flat.get(key, 0)) + int(entry["flat"][key])
			for key in entry["percent"]:
				percent[key] = float(percent.get(key, 0.0)) + float(entry["percent"][key])
	stats.set_buff_bonuses(flat, percent)


# ===== 내부 (Internal) =====

func _find(target, effect_id: StringName) -> _Instance:
	if not _active.has(target):
		return null
	return _active[target].get(effect_id)

func _effects_of(target: Node) -> Dictionary:
	if not _active.has(target):
		_active[target] = {}
	return _active[target]

func _is_valid_target(target) -> bool:
	return target != null and is_instance_valid(target)

# 대상의 PlayerStats를 얻는다. 파티 멤버와 적이 둘 다 get_stats()를 제공한다.
func _stats_of(target) -> PlayerStats:
	if not _is_valid_target(target):
		return null
	if target.has_method("get_stats"):
		return target.get_stats()
	return null


# ===== EMPOWER 조회 (#276) =====
#
# "지금 이 대상이 무엇을 할 수 있는가"를 묻는 통로다. CONTROL 의 _blocks() 와 같은 모양이라,
# 부르는 쪽(Player)이 효과 목록을 직접 훑지 않는다.

# 걸려 있는 EMPOWER 효과들이 주는 흡혈 비율의 **합**. 없으면 0.0.
#
# 합인 이유: 서로 다른 스킬이 준 흡혈은 별개 출처다. 큰 쪽 하나만 남기면 두 번째 버프가
# 조용히 아무 일도 하지 않게 된다.
func get_granted_lifesteal(target) -> float:
	if not _active.has(target):
		return 0.0
	var total := 0.0
	for effect_id in _active[target]:
		var inst: _Instance = _active[target][effect_id]
		if inst.data.kind != StatusEffectData.Kind.EMPOWER:
			continue
		total += maxf(inst.data.grants_lifesteal_percent, 0.0)
	return total


# ===== TAUNT 조회 (#328) =====

# 지금 이 대상이 **강제로 공격해야 하는** 상대. 도발이 걸려 있지 않으면 null.
#
# 여러 도발이 겹치면 **가장 나중에 걸린 것**이 이긴다. 사전순이나 최초 것이 이기면
# 방금 도발한 탱커가 아무 일도 하지 못하는 순간이 생긴다 — 도발은 "지금 나를 봐"라는
# 조작이므로 마지막 조작이 유효해야 한다.
#
# 주체가 이미 죽어 해제됐으면 null 이다(효과는 남아 있어도 끌 대상이 없다).
# 그때 부르는 쪽은 지금까지의 대상 선정으로 돌아간다 — 도발한 탱커가 죽었는데 적이
# 아무도 공격하지 않고 서 있으면 안 된다.
func get_taunt_source(target) -> Node:
	if not _active.has(target):
		return null

	var newest: Node = null
	var newest_time := -1.0
	for effect_id in _active[target]:
		var inst: _Instance = _active[target][effect_id]
		if inst.data.kind != StatusEffectData.Kind.TAUNT:
			continue
		if inst.source == null or not is_instance_valid(inst.source):
			continue
		# 무한 도발은 남은 시간으로 비교할 수 없으므로 최우선으로 본다.
		# (validate() 가 막고 있지만 저작이 어긋난 데이터에서도 죽지 않게 둔다.)
		if inst.data.is_permanent():
			return inst.source
		# 남은 시간이 가장 긴 것이 가장 나중에 걸린 것이다 — 지속시간이 같은 도발끼리는
		# 이 비교가 곧 "누가 마지막으로 걸었나"다.
		if inst.time_left > newest_time:
			newest = inst.source
			newest_time = inst.time_left
	return newest


# 걸려 있는 EMPOWER 효과 중 하나라도 **무적**을 부여하는가(#334).
#
# 부르는 쪽(take_damage 맨 앞)이 이것으로 갈라진다. 무적은 감소가 아니라 분기이므로
# 스텟 배수(get_damage_taken_multiplier)와 섞이지 않는다.
func grants_invulnerable(target) -> bool:
	if not _active.has(target):
		return false
	for effect_id in _active[target]:
		var inst: _Instance = _active[target][effect_id]
		if inst.data.kind == StatusEffectData.Kind.EMPOWER and inst.data.grants_invulnerable:
			return true
	return false


# 걸려 있는 EMPOWER 효과 중 하나라도 처형을 부여하는가.
func grants_execute(target) -> bool:
	if not _active.has(target):
		return false
	for effect_id in _active[target]:
		var inst: _Instance = _active[target][effect_id]
		if inst.data.kind == StatusEffectData.Kind.EMPOWER and inst.data.grants_execute:
			return true
	return false
