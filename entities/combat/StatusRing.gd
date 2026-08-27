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
const BUFF_SEGMENTS: int = 4
const BUFF_ARC_RATIO: float = 0.22
# 전장 상태를 반드시 읽어야 하는 두 버프만 표시한다. 모든 이로운 효과를 넣으면 발밑 링이
# 상시 UI가 되어 디버프 경고가 묻힌다(#403).
const VISIBLE_BUFF_IDS := {
	&"empowered": true,
	&"gangji_zone": true,
}

enum RingStyle {
	DEFAULT,
	MOVEMENT_ONLY,
	MOVEMENT_AND_ATTACK,
	BENEFICIAL,
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


# 여러 링을 포개면 상태를 읽을 수 없어 하나만 남긴다. 디버프가 언제나 버프보다 우선하고,
# 디버프끼리는 가장 많은 행동을 막는 것을 고른다. 같은 우선순위는 정렬된 id의 앞쪽이다.
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
		if data == null:
			continue
		var is_visible_buff: bool = not data.is_debuff and VISIBLE_BUFF_IDS.has(effect_id)
		if not data.is_debuff and not is_visible_buff:
			continue
		# 버프는 0~3의 디버프 심각도보다 낮다. 디버프가 하나라도 있으면 반드시 그쪽이 이긴다.
		var severity: int = _severity(data) if data.is_debuff else -1
		if severity > selected_severity:
			selected = data
			selected_severity = severity
		elif selected == null and is_visible_buff:
			selected = data
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
			RingStyle.BENEFICIAL:
				_draw_buff_ring(center)
			RingStyle.MOVEMENT_ONLY:
				_draw_segmented_ring(center)
			RingStyle.MOVEMENT_AND_ATTACK:
				_draw_solid_ring(center, STUN_INNER_RADIUS)
				_draw_solid_ring(center, STUN_OUTER_RADIUS)
			_:
				_draw_solid_ring(center, RING_RADIUS)


func _style_for(data: StatusEffectData) -> RingStyle:
	if not data.is_debuff:
		return RingStyle.BENEFICIAL
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


func _draw_buff_ring(center: Vector2) -> void:
	draw_arc(center, RING_RADIUS, 0.0, TAU, ARC_POINTS, UITheme.LEAF, RING_WIDTH + 1.0)
	var segment_angle: float = TAU / float(BUFF_SEGMENTS)
	for segment: int in range(BUFF_SEGMENTS):
		var start_angle: float = float(segment) * segment_angle - segment_angle * BUFF_ARC_RATIO * 0.5
		var end_angle: float = start_angle + segment_angle * BUFF_ARC_RATIO
		draw_arc(center, RING_RADIUS - 3.0, start_angle, end_angle, 4, UITheme.CREAM, RING_WIDTH)
