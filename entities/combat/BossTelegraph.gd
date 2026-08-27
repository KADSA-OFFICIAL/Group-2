extends Node2D
class_name BossTelegraph

# 보스 특별 스킬의 **예고** 표시 (#376).
#
# 이 게임에서 대상 최대 체력 비례 피해(60% / 30%)는 맞으면 죽을 수 있는 무게다.
# 그 무게가 성립하려면 **피할 수 있어야** 하고, 피하려면 어디가 위험한지 먼저 보여야 한다.
# 이 노드가 그 "먼저"다.
#
# 규약 (docs/vfx-guide.md):
#   §1.1 판정하지 않는다 — Area2D 도 피해 함수도 없다. 판정은 보스가 따로 한다.
#   §1.2 그리는 크기 = 판정 크기 — 반경·길이·폭을 보스가 SkillData 에서 읽어 그대로 넘긴다.
#         보기 좋으라고 키우거나 줄이면 화면이 거짓말을 한다.
#   §1.4 색은 UITheme 에서 — 적이 주는 피해라 HOSTILE 이다.
#   §1.6 도형인 것이 드러나게 — 반투명 채움 + 뚜렷한 외곽선.
#   §1.7 부모는 전장 — 보스가 죽거나 움직여도 예고는 그 자리에 남는다.

enum Shape {
	CIRCLE,  # 내리찍기 착지 지점
	BEAM,    # 직선 돌진 경로
}

# 채움은 옅게, 선은 뚜렷하게(§1.6).
const FILL_ALPHA: float = 0.16
const LINE_ALPHA: float = 0.85
const LINE_WIDTH: float = 3.0

# 남은 시간이 이 비율 아래로 떨어지면 깜박인다 — "곧 온다"가 읽혀야 한다.
const BLINK_FROM_RATIO: float = 0.35
const BLINK_HZ: float = 6.0

var _shape: Shape = Shape.CIRCLE
var _radius: float = 0.0
var _length: float = 0.0
var _width: float = 0.0
var _direction: Vector2 = Vector2.RIGHT

var _duration: float = 0.0
var _left: float = 0.0


# 발밑 링 무리와 같은 띠에 둔다. 상태 링(50)·게이지 링(49) **바로 아래**다 —
# 이쪽은 넓은 면이라 위에 오면 그 작은 링들을 덮는다.
#
# 음수로 두면 안 된다: 전장 바닥(stage/grassland/GrasslandMap.tscn)이 -5 ~ -2 를 쓰므로
# 예고가 맵 아래 묻혀 **보이지 않는다.** 실제로 -5 로 두었다가 스크린샷에서 사라져 찾았다.
const Z_INDEX: int = 48


func _ready() -> void:
	# 캐릭터(기본 0)보다 위, 체력 바(100)보다 아래다. 체력 바를 가리지 않는다(vfx-guide §1.5).
	z_index = Z_INDEX


# 착지 지점 예고. origin 은 전역 좌표다.
func setup_circle(origin: Vector2, radius: float, duration: float) -> void:
	_shape = Shape.CIRCLE
	global_position = origin
	_radius = radius
	_begin(duration)


# 돌진 경로 예고. origin 에서 direction 방향으로 length 만큼, 폭 width 인 띠다.
func setup_beam(origin: Vector2, direction: Vector2, length: float, width: float,
		duration: float) -> void:
	_shape = Shape.BEAM
	global_position = origin
	_direction = direction.normalized() if direction.length() > 0.0 else Vector2.RIGHT
	_length = length
	_width = width
	_begin(duration)


func _begin(duration: float) -> void:
	_duration = maxf(duration, 0.01)
	_left = _duration
	queue_redraw()


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	queue_redraw()


# 예고를 지금 끝낸다. 준비자세가 중간에 끊겼을 때(보스가 죽거나 기절) 부른다 —
# 예고만 남아 있으면 오지 않을 공격을 피하게 된다.
func cancel() -> void:
	queue_free()


func _draw() -> void:
	var color := UITheme.HOSTILE
	var alpha := 1.0

	# 마지막 구간에서 깜박인다. 남은 시간이 곧 회피 창이라 그것이 화면에 드러나야 한다.
	var ratio := _left / _duration
	if ratio < BLINK_FROM_RATIO:
		alpha = 0.45 + 0.55 * absf(sin(_left * BLINK_HZ * TAU * 0.5))

	var fill := Color(color.r, color.g, color.b, FILL_ALPHA * alpha)
	var line := Color(color.r, color.g, color.b, LINE_ALPHA * alpha)

	match _shape:
		Shape.CIRCLE:
			draw_circle(Vector2.ZERO, _radius, fill)
			draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, line, LINE_WIDTH)
		Shape.BEAM:
			# 로컬 좌표에서 그린 뒤 방향으로 회전시킨다. 원점이 띠의 **시작 가운데**다.
			var half := _width * 0.5
			var points := PackedVector2Array([
				Vector2(0.0, -half), Vector2(_length, -half),
				Vector2(_length, half), Vector2(0.0, half),
			])
			var angle := _direction.angle()
			for i in points.size():
				points[i] = points[i].rotated(angle)
			draw_colored_polygon(points, fill)
			# 닫힌 외곽선. 마지막 점에서 첫 점으로 돌아온다.
			var outline := points.duplicate()
			outline.append(points[0])
			draw_polyline(outline, line, LINE_WIDTH)
