extends Node2D
class_name StrikeEffect

# 아린의 즉발 낙뢰를 판정과 분리해 보여 주는 12fps 연출(#348).
# 피해는 Player._resolve_strike_attack()이 스폰 순간 처리하며 이 노드는 판정하지 않는다.

const FRAME_TIME := 1.0 / 12.0
const TELEGRAPH_FRAMES := 2
const DESCENT_FRAMES := 3
const IMPACT_FRAMES := 4
const TELEGRAPH_DURATION := FRAME_TIME * TELEGRAPH_FRAMES
const DESCENT_DURATION := FRAME_TIME * DESCENT_FRAMES
const IMPACT_DURATION := FRAME_TIME * IMPACT_FRAMES
const DURATION := TELEGRAPH_DURATION + DESCENT_DURATION + IMPACT_DURATION
const BOLT_HEIGHT := 240.0

var _radius: float = 0.0
var _color: Color = Color.WHITE
var _elapsed: float = 0.0


func setup(radius: float, color: Color) -> void:
	_radius = maxf(radius, 0.0)
	_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _radius <= 0.0:
		return
	if _elapsed < TELEGRAPH_DURATION:
		_draw_telegraph()
	elif _elapsed < TELEGRAPH_DURATION + DESCENT_DURATION:
		_draw_descent()
	else:
		_draw_impact()


func _draw_telegraph() -> void:
	var frame := mini(int(_elapsed / FRAME_TIME), TELEGRAPH_FRAMES - 1)
	var ring_color := _color
	ring_color.a = 0.9
	draw_arc(Vector2.ZERO, maxf(_radius - float(frame * 3), 1.0), 0.0, TAU, 48, ring_color, 1.0, false)


func _draw_descent() -> void:
	var local_time := _elapsed - TELEGRAPH_DURATION
	var progress := clampf(local_time / DESCENT_DURATION, 0.0, 1.0)
	var bolt := PackedVector2Array([
		Vector2(0.0, -BOLT_HEIGHT), Vector2(-9.0, -210.0), Vector2(5.0, -180.0),
		Vector2(-7.0, -150.0), Vector2(8.0, -120.0), Vector2(-5.0, -90.0),
		Vector2(4.0, -60.0), Vector2(-3.0, -30.0), Vector2.ZERO,
	])
	var visible := _visible_bolt_points(bolt, lerpf(-BOLT_HEIGHT, 0.0, progress))
	if visible.size() < 2:
		return

	var glow := _darkened(_color, 0.55)
	glow.a = 0.32
	draw_polyline(visible, glow, 7.0, false)
	var main := _color
	main.a = 0.95
	draw_polyline(visible, main, 3.0, false)
	draw_polyline(visible, UITheme.CREAM, 1.0, false)

	if local_time >= FRAME_TIME and progress > 0.48:
		_draw_branch(Vector2(-5.0, -90.0), Vector2(-19.0, -78.0))
		_draw_branch(Vector2(4.0, -60.0), Vector2(19.0, -48.0))


func _visible_bolt_points(points: PackedVector2Array, bottom_y: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		if point.y <= bottom_y:
			result.append(point)
		else:
			break
	return result


func _draw_branch(from: Vector2, to: Vector2) -> void:
	var branch := PackedVector2Array([from, Vector2(to.x, from.y + 6.0), to])
	var main := _color
	main.a = 0.9
	draw_polyline(branch, main, 2.0, false)
	draw_polyline(branch, UITheme.CREAM, 1.0, false)


func _draw_impact() -> void:
	var local_time := _elapsed - TELEGRAPH_DURATION - DESCENT_DURATION
	var frame := mini(int(local_time / FRAME_TIME), IMPACT_FRAMES - 1)
	var fade := 1.0 - float(frame) / float(IMPACT_FRAMES)
	if frame == 0:
		var flash := UITheme.CREAM
		flash.a = 0.8
		draw_circle(Vector2.ZERO, 9.0, flash)

	var spoke_length := lerpf(_radius * 0.35, _radius, float(frame + 1) / float(IMPACT_FRAMES))
	for i in 6:
		var angle := float(i) * TAU / 6.0
		var start := Vector2.from_angle(angle) * 6.0
		var bend := Vector2.from_angle(angle + (0.16 if i % 2 == 0 else -0.16)) * spoke_length * 0.55
		var finish := Vector2.from_angle(angle) * spoke_length
		var spark := _color
		spark.a = fade
		var core := UITheme.CREAM
		core.a = fade
		draw_polyline(PackedVector2Array([start, bend, finish]), spark, 2.0, false)
		draw_polyline(PackedVector2Array([start, bend, finish]), core, 1.0, false)

	if frame == IMPACT_FRAMES - 1:
		for point in [Vector2(-16, -5), Vector2(11, 8), Vector2(21, -2)]:
			var residue := _color
			residue.a = 0.45
			draw_rect(Rect2(point, Vector2.ONE * 2.0), residue)


func _darkened(color: Color, amount: float) -> Color:
	return Color(color.r * amount, color.g * amount, color.b * amount, color.a)
