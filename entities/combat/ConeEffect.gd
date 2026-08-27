extends Node2D
class_name ConeEffect

# 아린 Q의 연속 조준 각도를 보존하는 절차적 부채꼴 연출(#348).
# 판정은 Player._cast_cone_skill()이 시전 순간 처리하며 이 노드는 판정하지 않는다.

const DURATION := 0.25
const ARC_STEPS := 24

var _length: float = 0.0
var _half_angle: float = 0.0
var _color: Color = Color.WHITE
var _time_left: float = DURATION


func setup(direction: Vector2, length: float, half_angle: float, color: Color) -> void:
	_length = maxf(length, 0.0)
	_half_angle = clampf(half_angle, 0.0, PI)
	_color = color
	rotation = direction.angle()
	queue_redraw()


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if _length <= 0.0 or _half_angle <= 0.0:
		return
	var fade := clampf(_time_left / DURATION, 0.0, 1.0)
	var points := PackedVector2Array([Vector2.ZERO])
	for i in ARC_STEPS + 1:
		var t := float(i) / float(ARC_STEPS)
		var angle := lerpf(-_half_angle, _half_angle, t)
		points.append(Vector2.from_angle(angle) * _length)

	var fill := _color
	fill.a = 0.20 * fade
	draw_colored_polygon(points, fill)
	var edge := _color
	edge.a = 0.8 * fade
	draw_polyline(points + PackedVector2Array([Vector2.ZERO]), edge, 3.0, false)

	for angle_ratio in [-0.58, 0.0, 0.58]:
		_draw_electric_strand(_half_angle * angle_ratio, fade)


func _draw_electric_strand(angle: float, fade: float) -> void:
	var forward := Vector2.from_angle(angle)
	var side := forward.orthogonal()
	var strand := PackedVector2Array()
	var segments := maxi(int(_length / 30.0), 2)
	for i in segments + 1:
		var distance := float(i) * _length / float(segments)
		var zigzag := 0.0 if i == 0 else (4.0 if i % 2 == 0 else -4.0)
		strand.append(forward * distance + side * zigzag)
	var color := UITheme.CREAM
	color.a = 0.72 * fade
	draw_polyline(strand, color, 1.0, false)
