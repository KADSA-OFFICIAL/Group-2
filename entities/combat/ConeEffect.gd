extends Node2D
class_name ConeEffect

# 부채꼴 스킬이 지나간 자리를 잠깐 그리고 사라지는 표시(#336).
#
# **피해 판정을 하지 않는다.** 판정은 시전한 쪽(Player._cast_cone_skill)이 시전 순간에
# 이미 끝냈다. 이 노드는 "무엇이 일어났는지"를 보여 주기만 한다 — 판정을 여기로 옮기면
# 그림이 남아 있는 동안 들어온 적까지 맞아, 데이터에 적힌 것과 실제 동작이 갈라진다.
# (BeamEffect 와 같은 규약이고, 반대쪽 예가 Shockwave·AuraZone 이다 — 그쪽은 판정 노드다.)
#
# 아트가 없다. 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다.

## 표시가 남아 있는 시간(초). 판정과 무관한 연출값이라 SkillData 가 아니라 여기 있다.
const DURATION := 0.18

## 호를 몇 조각으로 나눠 그릴지. 각도가 넓어도 각져 보이지 않을 만큼이면 된다.
const ARC_STEPS := 24

var _length: float = 0.0
var _half_angle: float = 0.0
var _color: Color = Color.WHITE
var _time_left: float = DURATION


# 시전 직후 한 번 호출한다. direction 은 정규화하지 않아도 된다.
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


# 로컬 좌표계는 rotation 으로 이미 조준 방향에 맞춰져 있다. 그래서 +X 를 축으로 삼아
# -_half_angle ~ +_half_angle 사이를 부채꼴로 그리면 된다.
func _draw() -> void:
	if _length <= 0.0 or _half_angle <= 0.0:
		return

	var fade: float = clampf(_time_left / DURATION, 0.0, 1.0)

	# 꼭짓점 + 호 위의 점들로 부채꼴을 만든다.
	var points := PackedVector2Array()
	points.append(Vector2.ZERO)
	for i in ARC_STEPS + 1:
		var t := float(i) / float(ARC_STEPS)
		var angle := lerpf(-_half_angle, _half_angle, t)
		points.append(Vector2(cos(angle), sin(angle)) * _length)

	var fill := _color
	fill.a = 0.28 * fade
	draw_colored_polygon(points, fill)

	# 테두리를 덧그려 어디까지가 범위였는지 또렷하게 남긴다.
	var edge := _color
	edge.a = 0.85 * fade
	draw_polyline(points + PackedVector2Array([Vector2.ZERO]), edge, 3.0)
