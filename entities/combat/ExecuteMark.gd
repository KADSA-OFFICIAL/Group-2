extends Node2D
class_name ExecuteMark

# 처형이 성사된 자리에 잠깐 남는 표식(#331).
#
# 처형은 버퍼 1단계 시너지의 정체성이고 설아 E 가 파티 전원에게 부여하기도 하는데(#276),
# 화면에서는 적이 그냥 사라졌다. 일반 사망 연출도 없어서 **처형으로 죽은 것과 맞아 죽은
# 것이 완전히 같아 보였다** — 즉사시키는 메커니즘인데 즉사한 티가 안 났다.
#
# **피해 판정을 하지 않는다.** 처형 판정도 피해도 Player._try_execute() 가 이미 끝냈다.
# 이 노드는 "무엇이 일어났는지"만 그린다(vfx-guide §1.1, BeamEffect 와 같은 규약).
#
# 아트가 없다. 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다
# (vfx-guide §1.6).

## 표식이 남아 있는 시간(초). 판정과 무관한 순수 연출값이라 노드가 소유한다
## (vfx-guide §1.3, BeamEffect.DURATION 이 선례).
const DURATION := 0.28

## 링이 조여들기 시작하는 반지름(px).
##
## **범위가 아니라 표식의 크기다.** vfx-guide §1.2(이펙트 지름 = 판정 지름)는 광역 연출의
## 규약인데, 처형은 단일 대상이라 판정 반경 자체가 없다. 대상 덩치에 따라 바꾸지 않는 편이
## 오히려 읽기 쉽다 — 같은 사건은 같은 모양이어야 한다.
const START_RADIUS := 38.0

## 링 선 굵기(px).
const RING_WIDTH := 3.0

## 가운데 X 표식의 팔 길이(px).
const CROSS_ARM := 13.0

## X 가 떠오르기 시작하는 시점(0~1). 링이 어느 정도 조여든 뒤에 나와야
## "닫히고 -> 끝났다" 순서로 읽힌다.
const CROSS_START := 0.45

var _color: Color = Color.WHITE
var _time_left: float = DURATION


# 처형 직후 한 번 호출한다. 자리는 **전역 좌표**다(대상이 있던 자리).
func setup(at_global: Vector2, color: Color) -> void:
	global_position = at_global
	_color = color
	queue_redraw()


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		queue_free()
		return
	queue_redraw()


# 밖에서 안으로 조여드는 링 + 뒤늦게 뜨는 X.
#
# 왜 수축인가: 이미 쓰는 연출 어휘와 겹치지 않아야 한다. Shockwave 는 퍼지고,
# ChainArc 는 잇고, StatusRing 은 머문다. 수축은 아직 아무도 쓰지 않았고
# "끝났다"는 뜻과도 맞는다. 퍼지는 링을 또 쓰면 파동과 헷갈린다.
func _draw() -> void:
	# 0 에서 1 로 흐르는 진행도. _time_left 는 줄어드는 값이라 뒤집는다.
	var t: float = clampf(1.0 - _time_left / DURATION, 0.0, 1.0)
	var fade: float = 1.0 - t

	# 링: 처음에 빠르게 조여들고 끝에서 느려진다.
	var eased: float = 1.0 - pow(1.0 - t, 2.0)
	var radius: float = START_RADIUS * (1.0 - eased)
	if radius > 0.5:
		var ring := _color
		ring.a = 0.9 * fade
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, ring, RING_WIDTH)

	# X: 링이 조여든 뒤에 뜬다.
	if t < CROSS_START:
		return
	var cross_t: float = (t - CROSS_START) / (1.0 - CROSS_START)
	# 짧게 커졌다가 그대로 사라진다.
	var arm: float = CROSS_ARM * minf(cross_t * 2.5, 1.0)
	var mark := _color
	mark.a = 0.95 * (1.0 - cross_t)
	var edge := Color(1, 1, 1, 0.85 * (1.0 - cross_t))
	# 배열 리터럴에서 꺼낸 값은 Variant 라 := 로는 타입이 안 잡힌다. 명시한다.
	var arms: Array[Vector2] = [Vector2(1, 1), Vector2(1, -1)]
	for d in arms:
		var a: Vector2 = d.normalized() * arm
		draw_line(-a, a, edge, RING_WIDTH + 2.0)
		draw_line(-a, a, mark, RING_WIDTH)
