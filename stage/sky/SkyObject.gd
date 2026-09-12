extends Node2D
class_name SkyObject

# 하늘 맵(떠 있는 섬)의 프롭 (#423).
# GrasslandObject / BeachObject 와 같은 규약을 따른다:
#   kind 하나로 그림과 충돌을 정하고, 배치는 SkyIslandMap.tscn 이 인스턴스로 저작한다.
#   원점은 밑면 중앙이고(y=0 이 땅), 막는 것만 "Footprint" StaticBody2D 를 갖는다.
#
# 왜 또 별도 파일인가: BeachObject 를 만들 때와 같은 이유다. 한 enum 이 세 맵의 물건을
# 다 담으면 어느 맵에 무엇이 있는지 알 수 없고, 색 상수도 서로 맞지 않는다.
#
# 참고: stage/beach/BeachObject.gd

enum Kind {
	STANDING_STONE,  # 선돌 — 섬의 큰 수직 요소
	WIND_TREE,       # 바람에 휜 나무
	BOULDER,         # 바위 덩이
	GRASS_TUFT,      # 풀 무리 — 장식(이동을 막지 않는다)
}

const SHADOW := Color(0.16, 0.15, 0.18, 0.34)

# 바위. SkyIslandMap 의 섬 색과 같은 계열이어야 프롭이 섬에서 떠 보이지 않는다.
const ROCK_LIGHT := Color("A79C8C")
const ROCK_MAIN := Color("8B8071")
const ROCK_SHADOW := Color("635A4E")
const ROCK_DEEP := Color("463F36")

# 나무. 높은 데서 바람 맞는 나무라 잎이 적고 색이 가라앉는다.
const BARK_LIGHT := Color("8A7B67")
const BARK_MAIN := Color("665B4C")
const BARK_SHADOW := Color("453D33")

const LEAF_LIGHT := Color("7E9161")
const LEAF_MAIN := Color("64764B")
const LEAF_SHADOW := Color("47563A")

@export var kind: Kind = Kind.GRASS_TUFT:
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
	# 바람에 흔들리는 것만 다시 그린다. 돌은 정지물이다.
	if kind == Kind.WIND_TREE or kind == Kind.GRASS_TUFT:
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.STANDING_STONE:
			_draw_standing_stone()
		Kind.WIND_TREE:
			_draw_wind_tree()
		Kind.BOULDER:
			_draw_boulder()
		Kind.GRASS_TUFT:
			_draw_grass_tuft()


# ===== 그림 =====

func _draw_standing_stone() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -5), Vector2(30, 9)), SHADOW)

	# 위로 갈수록 좁아지는 판돌. 좌우 폭을 variant 로 바꿔 세워 놓은 것이
	# 복사본처럼 보이지 않게 한다.
	var height := 116.0 + float(variant) * 14.0
	var half_bottom := 22.0 + float(variant) * 2.0
	var half_top := 13.0
	var tilt := (float(variant) - 1.0) * 5.0

	draw_colored_polygon(PackedVector2Array([
		Vector2(-half_bottom, 0), Vector2(half_bottom, 0),
		Vector2(half_top + tilt, -height), Vector2(-half_top + tilt, -height),
	]), ROCK_MAIN)
	# 왼쪽 면이 빛을 받는다.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half_bottom, 0), Vector2(-half_bottom + 9, 0),
		Vector2(-half_top + tilt + 6, -height), Vector2(-half_top + tilt, -height),
	]), ROCK_LIGHT)
	# 오른쪽은 그늘.
	draw_colored_polygon(PackedVector2Array([
		Vector2(half_bottom - 8, 0), Vector2(half_bottom, 0),
		Vector2(half_top + tilt, -height), Vector2(half_top + tilt - 5, -height),
	]), ROCK_SHADOW)

	# 돌 표면의 금 몇 줄.
	for i in 3:
		var y := -22.0 - float(i) * 28.0
		var x0 := -half_bottom * 0.5 + float((i * 7) % 9)
		draw_line(Vector2(x0, y), Vector2(x0 + 13.0, y + 5.0), ROCK_SHADOW, 1.5, true)

	# 밑동이 땅에 묻힌 자리.
	draw_colored_polygon(_ellipse(Vector2(0, -3), Vector2(half_bottom, 5)), ROCK_DEEP)


func _draw_wind_tree() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -5), Vector2(26, 9)), SHADOW)

	# 줄기가 한쪽으로 크게 휜다. 바람이 부는 곳이라는 표시다.
	var lean := 1.0 if variant % 2 == 0 else -1.0
	var height := 104.0 + float(variant) * 8.0
	var segments := 9
	var previous := Vector2(0, 0)
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var point := Vector2(lean * 34.0 * t * t, -height * t)
		var width := 11.0 - 6.0 * t
		draw_line(previous, point, BARK_SHADOW, width + 2.0, true)
		draw_line(previous, point, BARK_MAIN, width, true)
		previous = point
	draw_line(Vector2(0, 0), Vector2(lean * 4.0, -height * 0.35), BARK_LIGHT, 2.5, true)

	# 잎은 바람 방향으로 몰려 있다. 사방으로 두면 바람이 없어 보인다.
	var sway := sin(_elapsed * 1.1 + float(variant)) * 3.0
	var crown := previous
	for i in 5:
		var offset := Vector2(
			lean * (10.0 + float(i) * 9.0) + sway,
			-6.0 + float((i * 5) % 14))
		var radius := 15.0 - float(i) * 1.8
		draw_colored_polygon(_ellipse(crown + offset, Vector2(radius, radius * 0.66)),
			LEAF_MAIN if i % 2 == 0 else LEAF_SHADOW)
		draw_colored_polygon(
			_ellipse(crown + offset + Vector2(0, -2), Vector2(radius * 0.5, radius * 0.34)),
			LEAF_LIGHT)

	# 가지 둘.
	for i in 2:
		var from := crown + Vector2(lean * -4.0, 12.0 + float(i) * 14.0)
		draw_line(from, from + Vector2(lean * 22.0, -6.0), BARK_MAIN, 3.0, true)


func _draw_boulder() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -5), Vector2(42, 10)), SHADOW)

	draw_colored_polygon(PackedVector2Array([
		Vector2(-38, -3), Vector2(-28, -30), Vector2(-4, -42),
		Vector2(22, -36), Vector2(38, -18), Vector2(40, -3),
	]), ROCK_MAIN)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-24, -28), Vector2(-4, -39), Vector2(12, -34), Vector2(0, -21),
	]), ROCK_LIGHT)
	draw_colored_polygon(PackedVector2Array([
		Vector2(16, -34), Vector2(38, -18), Vector2(40, -3), Vector2(18, -5),
	]), ROCK_SHADOW)

	# 금 한 줄. 매끈한 덩이는 공처럼 보인다.
	draw_line(Vector2(-14, -30), Vector2(-2, -8), ROCK_SHADOW, 1.5, true)
	draw_colored_polygon(_ellipse(Vector2(0, -3), Vector2(38, 5)), ROCK_DEEP)


func _draw_grass_tuft() -> void:
	# 장식이라 그림자를 옅게 둔다.
	draw_colored_polygon(_ellipse(Vector2(0, -2), Vector2(16, 4)),
		Color(SHADOW.r, SHADOW.g, SHADOW.b, 0.16))

	# 전부 한쪽으로 눕는다 -- 섬 위 바람은 SkyIslandMap 의 디테일 타일과 같은 방향이다.
	var sway := sin(_elapsed * 1.4 + float(variant) * 0.7) * 2.0
	for i in 7:
		var base := Vector2(-15.0 + float(i) * 5.0, 0.0)
		var height := 16.0 + float((i * 5 + variant) % 9)
		var tip := base + Vector2(9.0 + sway, -height)
		var color := LEAF_MAIN if i % 2 == 0 else LEAF_SHADOW
		draw_line(base, tip, color, 2.0, true)
		if i % 3 == 0:
			draw_line(base, tip + Vector2(-2, 2), LEAF_LIGHT, 1.0, true)


# ===== 충돌 =====

func _rebuild_collision() -> void:
	var old_footprint := get_node_or_null("Footprint")
	if old_footprint:
		remove_child(old_footprint)
		old_footprint.queue_free()
	if kind == Kind.GRASS_TUFT:
		return

	var footprint := Vector2.ZERO
	match kind:
		Kind.STANDING_STONE:
			footprint = Vector2(48, 24)
		Kind.WIND_TREE:
			footprint = Vector2(48, 32)
		Kind.BOULDER:
			footprint = Vector2(96, 32)
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
