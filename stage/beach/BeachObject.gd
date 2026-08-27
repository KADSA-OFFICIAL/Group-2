extends Node2D
class_name BeachObject

# 해변 맵의 프롭 (#422). GrasslandObject 와 같은 규약을 따른다:
#   kind 하나로 그림과 충돌을 정하고, 실제 배치는 BeachMap.tscn 이 인스턴스로 저작한다.
#
# 왜 GrasslandObject 를 재사용하지 않는가: 그쪽 Kind 는 움막·울타리·나무처럼
# 초원의 물건들이고, 색 상수도 풀·초가지붕 계열이다. 야자수·유목을 거기 끼워 넣으면
# 한 enum 이 두 맵의 물건을 다 담아 어느 맵에 무엇이 있는지 알 수 없게 된다.
#
# 원점은 **밑면 중앙**이다(y=0 이 땅, 위로 갈수록 음수). GrasslandObject 와 같아야
# Y-sort 와 충돌 오프셋이 같은 방식으로 동작한다.
#
# 참고: stage/grassland/GrasslandObject.gd

enum Kind {
	PALM,       # 야자수 — 해변의 큰 수직 요소
	DRIFTWOOD,  # 유목 — 밀려온 통나무
	ROCK_WET,   # 젖은 바위 — 물가에 놓는 덩치
	SHELL,      # 조개 무리 — 장식(이동을 막지 않는다)
}

const SHADOW := Color(0.18, 0.16, 0.14, 0.35)

# 나무·유목 계열. 초원의 나무색보다 바래고 회끼가 있다 — 소금기에 마른 나무다.
const WOOD_LIGHT := Color("C0B49E")
const WOOD_MAIN := Color("968A76")
const WOOD_SHADOW := Color("6B6153")
const WOOD_DEEP := Color("453E34")

# 야자 잎. 초원 잎(LEAF_*)보다 푸르고 채도가 높다.
const FROND_LIGHT := Color("8FA86A")
const FROND_MAIN := Color("6B8A4F")
const FROND_SHADOW := Color("4A6338")

# 젖은 바위. 마른 바위보다 어둡고 살짝 푸르다.
const ROCK_LIGHT := Color("8E9490")
const ROCK_MAIN := Color("6A706D")
const ROCK_SHADOW := Color("474C4A")

# 조개.
const SHELL_LIGHT := Color("F2E4D0")
const SHELL_MAIN := Color("DCC6A8")
const SHELL_SHADOW := Color("B3997A")

@export var kind: Kind = Kind.SHELL:
	set(value):
		kind = value
		_rebuild_collision()
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
	# 야자 잎만 흔들린다. 바위·유목·조개는 정지물이라 매 프레임 다시 그릴 이유가 없다.
	if kind == Kind.PALM:
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.PALM:
			_draw_palm()
		Kind.DRIFTWOOD:
			_draw_driftwood()
		Kind.ROCK_WET:
			_draw_rock()
		Kind.SHELL:
			_draw_shell()


# ===== 그림 =====

func _draw_palm() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -6), Vector2(30, 10)), SHADOW)

	# 줄기는 한쪽으로 휜다. variant 로 휘는 방향을 바꿔 같은 씬을 여러 번 놓아도
	# 복사한 것처럼 보이지 않게 한다.
	var lean := 1.0 if variant % 2 == 0 else -1.0
	var height := 132.0 + float(variant) * 10.0
	var segments := 11
	var previous := Vector2(0, 0)
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var point := Vector2(lean * 26.0 * t * t, -height * t)
		var width := 13.0 - 6.0 * t
		draw_line(previous, point, WOOD_SHADOW, width + 2.0, true)
		draw_line(previous, point, WOOD_MAIN, width, true)
		# 줄기 마디. 야자 줄기의 결이다.
		if i % 2 == 0:
			draw_line(point + Vector2(-width * 0.4, 0), point + Vector2(width * 0.4, 0),
				WOOD_SHADOW, 1.5, true)
		previous = point

	# 잎. 흔들림은 아주 작게 둔다 — 전투 중 배경이 눈을 끌면 안 된다.
	var crown := previous
	var sway := sin(_elapsed * 0.9 + float(variant)) * 0.05
	var count := 7
	for i in count:
		var angle := PI + (TAU / float(count)) * float(i) + sway
		_draw_frond(crown, angle, 54.0 + float(i % 3) * 8.0)

	# 열매 몇 개.
	for i in 3:
		var offset := Vector2(-8.0 + float(i) * 8.0, 4.0 + float(i % 2) * 3.0)
		draw_circle(crown + offset, 4.5, WOOD_DEEP)
		draw_circle(crown + offset + Vector2(-1, -1), 2.5, WOOD_SHADOW)


func _draw_frond(from: Vector2, angle: float, length: float) -> void:
	var direction := Vector2(cos(angle), sin(angle) * 0.62)
	var tip := from + direction * length
	# 잎대.
	draw_line(from, tip, FROND_SHADOW, 3.5, true)
	# 잎날은 잎대 양쪽으로 짧은 선을 세워 만든다. 폴리곤 하나로 그리면
	# 야자 잎의 갈라진 결이 사라져 그냥 삼각형처럼 보인다.
	var normal := Vector2(-direction.y, direction.x).normalized()
	for i in range(2, 11):
		var t := float(i) / 11.0
		var base := from.lerp(tip, t)
		var spread := (1.0 - t) * 15.0 + 4.0
		var color := FROND_MAIN if i % 2 == 0 else FROND_LIGHT
		draw_line(base, base + normal * spread, color, 2.0, true)
		draw_line(base, base - normal * spread, color, 2.0, true)


func _draw_driftwood() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -4), Vector2(50, 9)), SHADOW)

	# 누운 통나무. 밑면 중앙이 원점이므로 위로 살짝 올려 그린다.
	draw_colored_polygon(_ellipse(Vector2(0, -16), Vector2(48, 15)), WOOD_MAIN)
	draw_colored_polygon(_ellipse(Vector2(-2, -20), Vector2(42, 8)), WOOD_LIGHT)
	draw_colored_polygon(_ellipse(Vector2(4, -10), Vector2(40, 6)), WOOD_SHADOW)

	# 결. 소금기에 마른 나무의 갈라진 자리다.
	for i in 5:
		var y := -26.0 + float(i) * 5.0
		var x0 := -40.0 + float((i * 13) % 20)
		draw_line(Vector2(x0, y), Vector2(x0 + 26.0 + float(i % 3) * 8.0, y),
			WOOD_SHADOW, 1.5, true)

	# 잘린 단면 둘.
	draw_colored_polygon(_ellipse(Vector2(-46, -16), Vector2(7, 14)), WOOD_DEEP)
	draw_colored_polygon(_ellipse(Vector2(46, -16), Vector2(6, 13)), WOOD_SHADOW)

	# 가지 그루터기 하나. 통나무가 완전한 원통이면 인공물처럼 보인다.
	draw_line(Vector2(18, -26), Vector2(30, -44), WOOD_MAIN, 6.0, true)
	draw_line(Vector2(18, -26), Vector2(30, -44), WOOD_SHADOW, 3.0, true)


func _draw_rock() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -5), Vector2(50, 11)), SHADOW)

	# 덩치 하나 + 작은 것 둘. 하나만 놓으면 돌멩이처럼 보인다.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-46, -4), Vector2(-34, -34), Vector2(-8, -46),
		Vector2(20, -42), Vector2(40, -22), Vector2(46, -4),
	]), ROCK_MAIN)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, -30), Vector2(-8, -42), Vector2(14, -38), Vector2(2, -24),
	]), ROCK_LIGHT)
	draw_colored_polygon(PackedVector2Array([
		Vector2(18, -40), Vector2(40, -22), Vector2(46, -4), Vector2(22, -6),
	]), ROCK_SHADOW)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-58, -2), Vector2(-50, -18), Vector2(-38, -16), Vector2(-36, -2),
	]), ROCK_SHADOW)
	draw_colored_polygon(PackedVector2Array([
		Vector2(40, -2), Vector2(50, -14), Vector2(60, -10), Vector2(58, -2),
	]), ROCK_MAIN)

	# 물에 젖은 밑동. 위쪽보다 어둡다 — 물가에 있다는 표시다.
	draw_colored_polygon(_ellipse(Vector2(0, -3), Vector2(48, 6)), ROCK_SHADOW)


func _draw_shell() -> void:
	# 장식이라 그림자를 아주 옅게 둔다.
	draw_colored_polygon(_ellipse(Vector2(0, -2), Vector2(20, 5)),
		Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.18))

	# 조개 셋을 흩어 놓는다. 위치는 variant 로 조금씩 달라진다.
	for i in 3:
		var center := Vector2(-14.0 + float(i) * 13.0 + float(variant) * 2.0,
			-5.0 - float((i + variant) % 2) * 4.0)
		var radius := 8.0 - float(i % 2) * 2.0
		draw_colored_polygon(_ellipse(center, Vector2(radius, radius * 0.72)), SHELL_MAIN)
		draw_colored_polygon(_ellipse(center + Vector2(0, -1),
			Vector2(radius * 0.6, radius * 0.4)), SHELL_LIGHT)
		# 조개의 부채 결.
		for spoke in 4:
			var angle := PI + (PI / 5.0) * float(spoke + 1)
			draw_line(center, center + Vector2(cos(angle), sin(angle) * 0.72) * radius,
				SHELL_SHADOW, 1.0, true)


# ===== 충돌 =====
#
# GrasslandObject 와 같은 규약: 노드 이름은 "Footprint", 사각형 하나, 밑면 기준으로 올려 놓는다.
# 밟고 지나갈 수 있는 것(조개)은 몸을 만들지 않는다 — 초원의 수풀·넘어진 울타리와 같다.
func _rebuild_collision() -> void:
	var old_footprint := get_node_or_null("Footprint")
	if old_footprint:
		remove_child(old_footprint)
		old_footprint.queue_free()
	if kind == Kind.SHELL:
		return

	var footprint := Vector2.ZERO
	match kind:
		Kind.PALM:
			footprint = Vector2(48, 32)
		Kind.DRIFTWOOD:
			footprint = Vector2(96, 32)
		Kind.ROCK_WET:
			footprint = Vector2(120, 40)
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


func _ellipse(center: Vector2, radius: Vector2, steps: int = 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
