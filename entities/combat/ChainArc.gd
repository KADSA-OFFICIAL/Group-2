extends Node2D
class_name ChainArc

# 탄이 **튕긴 순간**을 보여 주는 짧은 표시(#329).
#
# 태희 Q 는 평타 탄이 다음 적으로 넘어가게 한다(#263). 그런데 탄은 방향만 틀고 같은 노드를
# 재사용해서(Projectile._try_chain), 화면에서는 탄 하나가 꺾이는 것으로만 보인다. 탄속이
# 620px/s 라 체인 구간을 0.35초에 지나므로 눈으로 따라가기도 어렵다 — 결과적으로 Q 를 켠
# 것과 안 켠 것이 구분되지 않았다.
#
# **피해 판정을 하지 않는다.** 튕김 대상 선정도 피해도 _try_chain()/_deliver() 가 이미
# 끝냈다. 이 노드는 "무엇이 일어났는지"만 그린다(vfx-guide §1.1, BeamEffect 와 같은 규약).
#
# 아트가 없다. 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다
# (vfx-guide §1.6).

## 표시가 남아 있는 시간(초).
##
## 판정과 무관한 **순수 연출값**이라 SkillData 가 아니라 여기 있다(vfx-guide §1.3,
## BeamEffect.DURATION 이 선례). 체인 한 구간을 지나는 시간(약 0.35초)보다 짧게 둔다 —
## 더 길면 연사 중에 선이 화면에 쌓여 어느 것이 방금 것인지 알 수 없다.
const DURATION := 0.22

## 튕긴 자리 쪽 굵기(px).
const WIDTH_FROM := 7.0

## 다음 대상 쪽 굵기(px). FROM 보다 얇아야 어느 방향으로 넘어갔는지가 선 모양으로 읽힌다.
const WIDTH_TO := 2.0

## 튕긴 자리에 그리는 링의 반지름(px). 선만 있으면 선 끝이 곧 튕긴 자리라는 것을
## 알아채기 어렵다.
const NODE_RADIUS := 9.0

var _to: Vector2 = Vector2.ZERO      # 로컬 좌표. 이 노드는 튕긴 자리에 선다.
var _color: Color = Color.WHITE
var _time_left: float = DURATION


# 튕긴 직후 한 번 호출한다. 두 점은 **전역 좌표**다.
#
# 이 노드를 튕긴 자리에 세우고 대상까지를 로컬 좌표로 들고 있는다 — 전역 좌표 두 개를
# 그대로 들고 그리면 부모가 움직일 때 선이 따로 논다.
func setup(from_global: Vector2, to_global: Vector2, color: Color) -> void:
	global_position = from_global
	_to = to_global - from_global
	_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	queue_redraw()


# 한쪽이 좁아지는 띠 + 튕긴 자리의 링.
#
# draw_line 은 굵기가 일정해서 방향을 못 보여 준다. 사다리꼴 폴리곤으로 그려
# 튕긴 자리를 굵게, 넘어간 쪽을 가늘게 만든다.
func _draw() -> void:
	var length := _to.length()
	if length <= 0.001:
		return

	var fade: float = clampf(_time_left / DURATION, 0.0, 1.0)
	# 진행 방향과 그 수직. 폭을 이 수직 방향으로 벌린다.
	var side := Vector2(-_to.y, _to.x) / length

	var a := side * (WIDTH_FROM * 0.5)
	var b := side * (WIDTH_TO * 0.5)
	var band := PackedVector2Array([
		a, _to + b, _to - b, -a,
	])

	var fill := _color
	fill.a = 0.55 * fade
	draw_colored_polygon(band, fill)

	var edge := Color(1, 1, 1, 0.8 * fade)
	draw_polyline(PackedVector2Array([a, _to + b, _to - b, -a, a]), edge, 1.5)

	# 튕긴 자리 표시. 채우지 않는다 — 채우면 탄 자신의 원과 헷갈린다.
	var ring := _color
	ring.a = 0.9 * fade
	draw_arc(Vector2.ZERO, NODE_RADIUS, 0.0, TAU, 20, ring, 2.0)
