extends Node2D
class_name StatusRing

# 상태 판정이 끝난 뒤 데이터의 차단 프로필을 발밑 도형으로 번역하는 연출 리스너(#301).
# effect id를 그림에 연결하면 같은 규칙의 새 효과가 추가될 때 표시가 조용히 빠진다.

const RING_RADIUS: float = 19.0
const STUN_INNER_RADIUS: float = 16.0
const STUN_OUTER_RADIUS: float = 22.0
const RING_WIDTH: float = 2.0
const ARC_POINTS: int = 48
const TRAP_SEGMENTS: int = 8
const TRAP_ARC_RATIO: float = 0.56

enum RingStyle {
	DEFAULT,
	MOVEMENT_ONLY,
	MOVEMENT_AND_ATTACK,
}


class RingState extends RefCounted:
	var target: Node2D
	var data: StatusEffectData
	var last_position: Vector2


	func _init(p_target: Node2D, p_data: StatusEffectData) -> void:
		target = p_target
		data = p_data
		last_position = p_target.global_position


var _rings: Dictionary = {}


func _ready() -> void:
	set_process(false)
	if not EventBus.status_effect_applied.is_connected(_on_status_changed):
		EventBus.status_effect_applied.connect(_on_status_changed)
	if not EventBus.status_effect_removed.is_connected(_on_status_changed):
		EventBus.status_effect_removed.connect(_on_status_changed)


func _exit_tree() -> void:
	if EventBus.status_effect_applied.is_connected(_on_status_changed):
		EventBus.status_effect_applied.disconnect(_on_status_changed)
	if EventBus.status_effect_removed.is_connected(_on_status_changed):
		EventBus.status_effect_removed.disconnect(_on_status_changed)
	_rings.clear()


func _on_status_changed(target: Variant, _effect_id: StringName) -> void:
	_sync_target(target)


func _sync_target(target: Variant) -> void:
	var target_node: Node2D = target as Node2D
	if target_node == null or not is_instance_valid(target_node):
		if _rings.erase(target):
			queue_redraw()
		set_process(not _rings.is_empty())
		return

	var selected: StatusEffectData = _select_effect(target_node)
	if selected == null:
		if _rings.erase(target_node):
			queue_redraw()
		set_process(not _rings.is_empty())
		return

	var state: RingState = _rings.get(target_node) as RingState
	if state == null:
		_rings[target_node] = RingState.new(target_node, selected)
	else:
		state.data = selected
		state.last_position = target_node.global_position
	queue_redraw()
	set_process(true)


# 여러 링을 포개면 차단 프로필을 읽을 수 없어 가장 많은 행동을 막는 디버프 하나만 남긴다(#301).
# 같은 심각도는 정렬된 id의 앞쪽을 골라 실행마다 모양이 바뀌지 않게 한다.
func _select_effect(target: Node) -> StatusEffectData:
	var effect_ids: Array = StatusEffectSystem.get_effect_ids(target)
	effect_ids.sort()
	var selected: StatusEffectData = null
	var selected_severity: int = -1
	for raw_id: Variant in effect_ids:
		var effect_id := StringName(raw_id)
		if not StatusEffectDatabase.has_effect(effect_id):
			continue
		var data: StatusEffectData = StatusEffectDatabase.get_effect(effect_id)
		if data == null or not data.is_debuff:
			continue
		var severity: int = _severity(data)
		if severity > selected_severity:
			selected = data
			selected_severity = severity
	return selected


func _severity(data: StatusEffectData) -> int:
	return int(data.blocks_movement) + int(data.blocks_attack) + int(data.blocks_skill)


func _process(_delta: float) -> void:
	var changed: bool = false
	for raw_target: Variant in _rings.keys():
		var state: RingState = _rings.get(raw_target) as RingState
		if state == null or state.target == null or not is_instance_valid(state.target):
			_rings.erase(raw_target)
			changed = true
			continue
		var current_position: Vector2 = state.target.global_position
		if current_position != state.last_position:
			state.last_position = current_position
			changed = true
	if changed:
		queue_redraw()
	set_process(not _rings.is_empty())


func _draw() -> void:
	for raw_target: Variant in _rings.keys():
		var state: RingState = _rings.get(raw_target) as RingState
		if state == null or state.target == null or not is_instance_valid(state.target):
			continue
		var center: Vector2 = to_local(state.target.global_position)
		match _style_for(state.data):
			RingStyle.MOVEMENT_ONLY:
				_draw_segmented_ring(center)
			RingStyle.MOVEMENT_AND_ATTACK:
				_draw_solid_ring(center, STUN_INNER_RADIUS)
				_draw_solid_ring(center, STUN_OUTER_RADIUS)
			_:
				_draw_solid_ring(center, RING_RADIUS)


func _style_for(data: StatusEffectData) -> RingStyle:
	if data.blocks_movement and data.blocks_attack:
		return RingStyle.MOVEMENT_AND_ATTACK
	if data.blocks_movement and not data.blocks_attack:
		return RingStyle.MOVEMENT_ONLY
	return RingStyle.DEFAULT


func _draw_segmented_ring(center: Vector2) -> void:
	var segment_angle: float = TAU / float(TRAP_SEGMENTS)
	for segment: int in range(TRAP_SEGMENTS):
		var start_angle: float = float(segment) * segment_angle
		var end_angle: float = start_angle + segment_angle * TRAP_ARC_RATIO
		draw_arc(center, RING_RADIUS, start_angle, end_angle, 5, UITheme.LILAC, RING_WIDTH)


func _draw_solid_ring(center: Vector2, radius: float) -> void:
	draw_arc(center, radius, 0.0, TAU, ARC_POINTS, UITheme.LILAC, RING_WIDTH)
