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
	if not _is_valid_target(target):
		return false

	var data := StatusEffectDatabase.get_effect(effect_id)
	if data == null:
		return false

	var effects := _effects_of(target)

	if effects.has(effect_id):
		var existing: _Instance = effects[effect_id]
		match data.stacking:
			StatusEffectData.Stacking.IGNORE:
				return false
			StatusEffectData.Stacking.REFRESH:
				existing.time_left = data.duration
			StatusEffectData.Stacking.STACK_INTENSITY:
				existing.stacks = mini(existing.stacks + 1, data.get_max_stacks())
				existing.time_left = data.duration
		_sync_stat_mods(target)
		return true

	effects[effect_id] = _Instance.new(data, source)
	_watch_target(target)
	_sync_stat_mods(target)
	EventBus.status_effect_applied.emit(target, effect_id)
	return true


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

	if amount_damage > 0 and target.has_method("take_damage"):
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
