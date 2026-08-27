extends Node2D
class_name StrikeEffect

# 낙뢰 평타가 떨어진 자리를 잠깐 그리고 사라지는 표시(#336).
#
# **피해 판정을 하지 않는다.** 판정은 시전한 쪽(Player._resolve_strike_attack)이 떨어뜨리는
# 순간에 이미 끝냈다(ConeEffect·BeamEffect 와 같은 규약).
#
# 이 표시가 특히 필요한 이유: 낙뢰는 **날아가는 탄이 없다.** 투사체는 날아가는 동안 무엇이
# 일어나는지 보이지만, 낙뢰는 그 자리에 즉시 떨어지므로 표시가 없으면 원거리에서 무슨 일이
# 일어났는지 화면에 아무 단서가 남지 않는다.
#
# 아트가 없다. 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다.

## 표시가 남아 있는 시간(초). 평타는 자주 나가므로 빔·부채꼴보다 짧다.
const DURATION := 0.12

var _radius: float = 0.0
var _color: Color = Color.WHITE
var _time_left: float = DURATION


func setup(radius: float, color: Color) -> void:
	_radius = maxf(radius, 0.0)
	_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	queue_redraw()


# 원을 채우고 테두리를 덧그린다. 채우는 이유는 AuraZone 과 같다 — 원 안 전체가 판정 범위다.
func _draw() -> void:
	if _radius <= 0.0:
		return
	var fade: float = clampf(_time_left / DURATION, 0.0, 1.0)

	var fill := _color
	fill.a = 0.35 * fade
	draw_circle(Vector2.ZERO, _radius, fill)

	var ring := _color
	ring.a = 0.95 * fade
	draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 32, ring, 3.0)
