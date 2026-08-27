@tool
extends Node2D
class_name GrasslandObject

# 초원 맵의 Y-sort 오브젝트. 모든 좌표는 노드 원점(접지점)을 기준으로 위쪽에 그린다(#352).

enum Kind { HUT, FENCE, FENCE_BROKEN, FENCE_FALLEN, TREE_LARGE, TREE_SMALL, BUSH, ROCK_LARGE, ROCK_SMALL, CRATE, SIGN }

const SHADOW := Color(0.18, 0.16, 0.14, 0.35)
const WOOD_LIGHT := Color("B5AC9C")
const WOOD_MAIN := Color("847C6E")
const WOOD_SHADOW := Color("584F44")
const WOOD_DEEP := Color("3B342B")
const ROPE := Color("C4B08A")
const THATCH_LIGHT := Color("B0A06A")
const THATCH_MAIN := Color("857A4E")
const THATCH_SHADOW := Color("5C553A")
const LEAF_LIGHT := Color("82945E")
const LEAF_MAIN := Color("647A4D")
const LEAF_SHADOW := Color("465B3B")
const ROCK_LIGHT := Color("9E9E9E")
const ROCK_MAIN := Color("767676")
const ROCK_SHADOW := Color("4F4F4F")

@export var kind: Kind = Kind.BUSH:
	set(value):
		kind = value
		queue_redraw()
@export_range(0, 2) var variant: int = 0:
	set(value):
		variant = value
		queue_redraw()
var _elapsed := 0.0


func setup(object_kind: int, object_variant: int = 0) -> void:
	kind = object_kind
	variant = object_variant
	name = Kind.keys()[kind].to_pascal_case()
	queue_redraw()


func _ready() -> void:
	_rebuild_collision()
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if kind == Kind.HUT or kind == Kind.TREE_LARGE or kind == Kind.TREE_SMALL:
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.HUT:
			_draw_hut()
		Kind.FENCE, Kind.FENCE_BROKEN:
			_draw_fence(kind == Kind.FENCE_BROKEN)
		Kind.FENCE_FALLEN:
			_draw_fallen_fence()
		Kind.TREE_LARGE:
			_draw_tree(Vector2(216, 288))
		Kind.TREE_SMALL:
			_draw_tree(Vector2(144, 192))
		Kind.BUSH:
			_draw_bush()
		Kind.ROCK_LARGE:
			_draw_rock(Vector2(120, 96))
		Kind.ROCK_SMALL:
			_draw_rock(Vector2(60, 48))
		Kind.CRATE:
			_draw_crate()
		Kind.SIGN:
			_draw_sign()


func _draw_hut() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -9), Vector2(120, 24)), SHADOW)
	draw_rect(Rect2(-120, -94, 240, 94), WOOD_MAIN)
	for x in range(-108, 109, 18):
		draw_line(Vector2(x, -92), Vector2(x + 4, -3), WOOD_SHADOW, 3.0, true)
		draw_line(Vector2(x + 4, -92), Vector2(x + 7, -4), WOOD_LIGHT, 1.5, true)

	# 캐릭터보다 넓은 120×96 출입구. 내부 진입 불가라 벽체 충돌은 유지한다.
	draw_rect(Rect2(-60, -96, 120, 96), WOOD_DEEP)
	var curtain_sway := sin(_elapsed * TAU / 1.0) * 3.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-54, -92), Vector2(54, -92), Vector2(50 + curtain_sway, -45),
		Vector2(8, -30), Vector2(-50 + curtain_sway, -47),
	]), Color("74674C"))

	var roof := PackedVector2Array([Vector2(-144, -94), Vector2(-112, -188), Vector2(0, -264), Vector2(112, -188), Vector2(144, -94)])
	draw_colored_polygon(roof, THATCH_MAIN)
	draw_polyline(roof, THATCH_SHADOW, 4.0, true)
	for x in range(-118, 119, 16):
		var top_x := x * 0.28
		draw_line(Vector2(top_x, -247 + absf(top_x) * 0.15), Vector2(x, -102), THATCH_SHADOW, 2.0, true)
		draw_line(Vector2(top_x + 3, -245), Vector2(x + 4, -104), THATCH_LIGHT, 1.0, true)
	draw_line(Vector2(-112, -158), Vector2(112, -158), ROPE, 3.0, true)
	draw_line(Vector2(-133, -119), Vector2(133, -119), ROPE, 3.0, true)
	for x in [-22, -7, 8, 23]:
		draw_line(Vector2(x, -252), Vector2(x * 1.35, -283 - abs(x) * 0.25), WOOD_SHADOW, 5.0, true)

	# 좌→우 바람을 따르는 6fps 느낌의 연기.
	for i in 4:
		var phase := fmod(_elapsed * 6.0 + float(i) * 1.5, 6.0) / 6.0
		var smoke_pos := Vector2(12 + phase * 34.0, -286 - phase * 58.0)
		var smoke := Color("DCCDAF")
		smoke.a = (1.0 - phase) * 0.34
		draw_circle(smoke_pos, 4.0 + phase * 8.0, smoke)


func _draw_fence(broken: bool) -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -4), Vector2(48, 10)), SHADOW)
	_draw_log(Vector2(-42, -8), Vector2(6, -68), 6.0)
	if not broken:
		_draw_log(Vector2(42, -8), Vector2(-6, -68), 6.0)
	else:
		_draw_log(Vector2(42, -8), Vector2(18, -38), 6.0)
	_draw_log(Vector2(-48, -34), Vector2(48, -34), 7.0)
	_draw_log(Vector2(-48, -8), Vector2(48, -8), 7.0)
	for y in [-40.0, -35.0, -30.0]:
		draw_line(Vector2(-5, y), Vector2(5, y), ROPE, 2.0, true)


func _draw_fallen_fence() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -2), Vector2(50, 10)), SHADOW)
	_draw_log(Vector2(-46, -8), Vector2(44, 8), 7.0)
	_draw_log(Vector2(-38, 6), Vector2(32, -12), 6.0)
	for x in [-18.0, 0.0, 18.0]:
		draw_line(Vector2(x - 4, -4), Vector2(x + 4, 2), ROPE, 2.0, true)


func _draw_tree(size: Vector2) -> void:
	var half_w := size.x * 0.5
	var height := size.y
	var sway := sin(_elapsed * TAU / 1.0) * 2.0
	draw_colored_polygon(_ellipse(Vector2(0, -8), Vector2(half_w * 0.45, 18)), SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-16, -12), Vector2(-11, -height * 0.48), Vector2(9, -height * 0.48), Vector2(18, -12),
	]), WOOD_MAIN)
	draw_line(Vector2(-7, -18), Vector2(-4, -height * 0.45), WOOD_LIGHT, 3.0, true)
	var centers := [
		Vector2(-half_w * 0.40 + sway, -height * 0.60),
		Vector2(half_w * 0.34 + sway, -height * 0.63),
		Vector2(sway, -height * 0.80),
		Vector2(-half_w * 0.12 + sway, -height * 0.48),
	]
	for i in centers.size():
		var radius := half_w * (0.52 if i < 2 else 0.46)
		draw_circle(centers[i] + Vector2(3, 7), radius, LEAF_SHADOW)
		draw_circle(centers[i], radius * 0.92, LEAF_MAIN)
		draw_circle(centers[i] + Vector2(-radius * 0.18, -radius * 0.16), radius * 0.42, LEAF_LIGHT)


func _draw_bush() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -4), Vector2(34, 9)), SHADOW)
	for item in [Vector3(-22, -20, 20), Vector3(0, -28, 27), Vector3(23, -18, 19)]:
		draw_circle(Vector2(item.x, item.y), item.z, LEAF_SHADOW)
		draw_circle(Vector2(item.x - 2, item.y - 3), item.z * 0.82, LEAF_MAIN)
	draw_circle(Vector2(-8, -34), 9.0, LEAF_LIGHT)


func _draw_rock(size: Vector2) -> void:
	var w := size.x * 0.5
	var h := size.y
	draw_colored_polygon(_ellipse(Vector2(0, -4), Vector2(w, h * 0.15)), SHADOW)
	var points := PackedVector2Array([
		Vector2(-w, -8), Vector2(-w * 0.72, -h * 0.62), Vector2(-w * 0.18, -h),
		Vector2(w * 0.58, -h * 0.82), Vector2(w, -h * 0.28), Vector2(w * 0.76, -7),
	])
	draw_colored_polygon(points, ROCK_MAIN)
	draw_polyline(points, ROCK_SHADOW, 3.0, true)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-w * 0.67, -h * 0.58), Vector2(-w * 0.18, -h * 0.92), Vector2(w * 0.24, -h * 0.72), Vector2(-w * 0.18, -h * 0.55),
	]), ROCK_LIGHT)


func _draw_crate() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -4), Vector2(30, 10)), SHADOW)
	draw_rect(Rect2(-30, -68, 60, 64), WOOD_MAIN)
	draw_rect(Rect2(-27, -65, 54, 58), WOOD_SHADOW, false, 4.0)
	draw_line(Vector2(-25, -60), Vector2(25, -12), WOOD_LIGHT, 4.0, true)
	draw_line(Vector2(25, -60), Vector2(-25, -12), WOOD_DEEP, 4.0, true)


func _draw_sign() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -3), Vector2(22, 7)), SHADOW)
	draw_rect(Rect2(-5, -58, 10, 55), WOOD_SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, -84), Vector2(23, -84), Vector2(31, -70), Vector2(23, -56), Vector2(-30, -56),
	]), WOOD_MAIN)
	draw_line(Vector2(-24, -77), Vector2(20, -77), WOOD_LIGHT, 2.0, true)


func _draw_log(from: Vector2, to: Vector2, width: float) -> void:
	draw_line(from + Vector2(2, 2), to + Vector2(2, 2), WOOD_DEEP, width + 2.0, true)
	draw_line(from, to, WOOD_MAIN, width, true)
	draw_line(from + Vector2(-1, -1), to + Vector2(-1, -1), WOOD_LIGHT, 1.5, true)


func _rebuild_collision() -> void:
	var old_footprint := get_node_or_null("Footprint")
	if old_footprint:
		remove_child(old_footprint)
		old_footprint.queue_free()
	if kind == Kind.FENCE_FALLEN or kind == Kind.BUSH:
		return
	var footprint := Vector2.ZERO
	match kind:
		Kind.HUT:
			footprint = Vector2(240, 96)
		Kind.FENCE, Kind.FENCE_BROKEN:
			footprint = Vector2(96, 24)
		Kind.TREE_LARGE:
			footprint = Vector2(72, 48)
		Kind.TREE_SMALL:
			footprint = Vector2(48, 48)
		Kind.ROCK_LARGE:
			footprint = Vector2(120, 48)
		Kind.ROCK_SMALL:
			footprint = Vector2(48, 24)
		Kind.CRATE:
			footprint = Vector2(48, 48)
		Kind.SIGN:
			footprint = Vector2(48, 24)
	if footprint == Vector2.ZERO:
		return
	var body := StaticBody2D.new()
	body.name = "Footprint"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = footprint
	collision.shape = shape
	collision.position = Vector2(0, -footprint.y * 0.5)
	body.add_child(collision)
	add_child(body)


func _ellipse(center: Vector2, radius: Vector2, steps: int = 32) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
