extends Node2D
class_name BeamEffect

# 직선 범위 스킬이 지나간 자리를 잠깐 그리고 사라지는 표시(#263).
#
# **피해 판정을 하지 않는다.** 판정은 시전한 쪽(Player._cast_beam_skill)이 발사 순간에
# 이미 끝냈다. 이 노드는 "무엇이 일어났는지"를 보여 주기만 한다 — 판정을 여기로 옮기면
# 빔이 그려지는 동안 들어온 적까지 맞아, 데이터에 적힌 것과 실제 동작이 갈라진다.
#
# 아트가 없다. 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다
# (Projectile·적 플레이스홀더와 같은 규약).

## 표시가 남아 있는 시간(초). 판정과 무관한 연출값이라 SkillData 가 아니라 여기 있다.
const DURATION := 0.18

var _length: float = 0.0
var _width: float = 0.0
var _color: Color = Color.WHITE
var _time_left: float = DURATION


# 발사 직후 한 번 호출한다. direction 은 정규화하지 않아도 된다.
func setup(direction: Vector2, length: float, width: float, color: Color) -> void:
	_length = maxf(length, 0.0)
	_width = maxf(width, 0.0)
	_color = color
	rotation = direction.angle()
	queue_redraw()


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	queue_redraw()


# 로컬 좌표계는 rotation 으로 이미 발사 방향에 맞춰져 있다. 그래서 +X 로 뻗는 띠만 그리면 된다.
func _draw() -> void:
	if _length <= 0.0 or _width <= 0.0:
		return
	var fade: float = clampf(_time_left / DURATION, 0.0, 1.0)
	var rect := Rect2(0.0, -_width * 0.5, _length, _width)
	var fill := _color
	fill.a = 0.55 * fade
	draw_rect(rect, fill)
	var edge := Color(1, 1, 1, 0.8 * fade)
	draw_rect(rect, edge, false, 2.0)
