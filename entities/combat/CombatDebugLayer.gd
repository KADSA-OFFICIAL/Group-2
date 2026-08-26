extends Node2D
class_name CombatDebugLayer

# 후속 이펙트가 실제 판정과 같은 크기인지 겹쳐 보는 개발 도구(#295).
# 판정값이 없는 노드를 도형 크기로 추정하면 검수 기준 자체가 거짓말이 되므로 건너뛴다.

const DEBUG_GROUP: StringName = &"combat_debug"
const RADIUS_PROPERTIES: Array[StringName] = [&"body_radius", &"hit_radius", &"radius"]
const OUTLINE_WIDTH: float = 1.5
const ARC_POINTS: int = 48


class DebugCircle extends RefCounted:
	var position: Vector2
	var radius: float
	var time_left: float


	func _init(p_position: Vector2, p_radius: float, p_ttl: float) -> void:
		position = p_position
		radius = p_radius
		time_left = p_ttl


class DebugLine extends RefCounted:
	var from: Vector2
	var to: Vector2
	var width: float
	var time_left: float


	func _init(p_from: Vector2, p_to: Vector2, p_width: float, p_ttl: float) -> void:
		from = p_from
		to = p_to
		width = p_width
		time_left = p_ttl


var _enabled: bool = false
var _circles: Array[DebugCircle] = []
var _lines: Array[DebugLine] = []


func _ready() -> void:
	add_to_group(DEBUG_GROUP)
	visible = false
	set_process(false)


# 레이어가 빠진 빌드에서도 호출부에 조건문을 퍼뜨리지 않기 위한 진입점이다(#295).
static func add_circle(position: Vector2, radius: float, ttl: float) -> void:
	var layer: CombatDebugLayer = _resolve()
	if layer != null:
		layer._add_circle(position, radius, ttl)


# 선의 폭도 시전 순간 계산된 판정값을 그대로 받는다. 보기 좋게 보정하지 않는다(#295).
static func add_line(from: Vector2, to: Vector2, width: float, ttl: float) -> void:
	var layer: CombatDebugLayer = _resolve()
	if layer != null:
		layer._add_line(from, to, width, ttl)


static func _resolve() -> CombatDebugLayer:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group(DEBUG_GROUP) as CombatDebugLayer


func _add_circle(position: Vector2, radius: float, ttl: float) -> void:
	if not _enabled or radius <= 0.0 or ttl <= 0.0:
		return
	_circles.append(DebugCircle.new(position, radius, ttl))
	queue_redraw()


func _add_line(from: Vector2, to: Vector2, width: float, ttl: float) -> void:
	if not _enabled or width <= 0.0 or ttl <= 0.0:
		return
	_lines.append(DebugLine.new(from, to, width, ttl))
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key_event: InputEventKey = event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F3 and key_event.physical_keycode != KEY_F3:
		return

	_enabled = not _enabled
	visible = _enabled
	set_process(_enabled)
	if _enabled:
		queue_redraw()
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_tick_circles(delta)
	_tick_lines(delta)
	# 켜진 동안만 움직이는 판정 노드를 다시 그린다. 꺼지면 이 함수 자체가 돌지 않는다(#295).
	queue_redraw()


func _tick_circles(delta: float) -> void:
	for index: int in range(_circles.size() - 1, -1, -1):
		var circle: DebugCircle = _circles[index]
		circle.time_left -= delta
		if circle.time_left <= 0.0:
			_circles.remove_at(index)


func _tick_lines(delta: float) -> void:
	for index: int in range(_lines.size() - 1, -1, -1):
		var line: DebugLine = _lines[index]
		line.time_left -= delta
		if line.time_left <= 0.0:
			_lines.remove_at(index)


func _draw() -> void:
	if not _enabled:
		return

	for enemy: Variant in GameManager.get_all_enemies():
		_draw_node_radius(enemy as Node2D)
	for member: Node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		_draw_node_radius(member as Node2D)

	var stage_root: Node = get_parent()
	if stage_root != null:
		_draw_projectiles(stage_root)

	for circle: DebugCircle in _circles:
		_draw_circle_outline(circle.position, circle.radius)
	for line: DebugLine in _lines:
		_draw_line_outline(line.from, line.to, line.width)


func _draw_projectiles(node: Node) -> void:
	if node is Projectile:
		_draw_node_radius(node as Node2D)
	for child: Node in node.get_children():
		_draw_projectiles(child)


func _draw_node_radius(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var radius: float = _read_radius(node)
	if radius <= 0.0:
		return
	_draw_circle_outline(node.global_position, radius)


func _read_radius(node: Object) -> float:
	for property_name: StringName in RADIUS_PROPERTIES:
		if not _has_property(node, property_name):
			continue
		var value: Variant = node.get(property_name)
		if value is float or value is int:
			return maxf(float(value), 0.0)
	return 0.0


func _has_property(node: Object, property_name: StringName) -> bool:
	for property: Dictionary in node.get_property_list():
		if StringName(property.get("name", &"")) == property_name:
			return true
	return false


func _draw_circle_outline(position: Vector2, radius: float) -> void:
	draw_arc(to_local(position), radius, 0.0, TAU, ARC_POINTS, UITheme.CREAM, OUTLINE_WIDTH)


func _draw_line_outline(from: Vector2, to: Vector2, width: float) -> void:
	var local_from: Vector2 = to_local(from)
	var local_to: Vector2 = to_local(to)
	var direction: Vector2 = local_to - local_from
	if direction.is_zero_approx():
		draw_arc(local_from, width * 0.5, 0.0, TAU, ARC_POINTS, UITheme.CREAM, OUTLINE_WIDTH)
		return

	var normal: Vector2 = direction.normalized().orthogonal() * width * 0.5
	var outline := PackedVector2Array([
		local_from + normal,
		local_to + normal,
		local_to - normal,
		local_from - normal,
		local_from + normal,
	])
	draw_polyline(outline, UITheme.CREAM, OUTLINE_WIDTH)
