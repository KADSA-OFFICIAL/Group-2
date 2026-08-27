extends Node2D
class_name SkyObject

# 하늘 맵의 프롭 (#423). GrasslandObject/BeachObject 와 같은 규약을 따른다:
#   kind 하나로 그림과 충돌을 정하고, 실제 배치는 SkyIslandMap.tscn 이 인스턴스로 저작한다.
#
# 왜 BeachObject 를 재사용하지 않는가: 그쪽 Kind 는 야자수·유목처럼 해변의 물건들이고
# 색 상수도 모래·소금기 계열이다. 바위탑·수정을 거기 끼워 넣으면 한 enum 이 두 맵의
# 물건을 다 담아 어느 맵에 무엇이 있는지 알 수 없게 된다.
#
# 원점은 **밑면 중앙**이다(y=0 이 땅, 위로 갈수록 음수). 다른 맵 프롭과 같아야
# Y-sort 와 충돌 오프셋이 같은 방식으로 동작한다.
#
# 참고: stage/beach/BeachObject.gd, stage/grassland/GrasslandObject.gd

enum Kind {
	SPIRE,      # 바위탑 — 섬의 큰 수직 요소
	ARCH,       # 돌 아치 — 풍화로 뚫린 바위
	CRYSTAL,    # 하늘 수정 — 빛나는 덩어리
	WIND_GRASS, # 바람풀 — 장식(이동을 막지 않는다)
}

const SHADOW := Color(0.16, 0.18, 0.24, 0.32)

# 바위. 섬 단면(SkyIslandMap.ROCK_*)과 같은 계열이되 프롭이라 조금 더 또렷하다.
const ROCK_LIGHT := Color("A99C8B")
const ROCK_MAIN := Color("83786A")
const ROCK_SHADOW := Color("5B5349")
const ROCK_DEEP := Color("3C362E")

# 수정. 하늘색을 띤 발광체 — 이 맵에서 유일하게 스스로 밝은 물건이다.
const CRYSTAL_CORE := Color("DFF3FF")
const CRYSTAL_MAIN := Color("8FD3F0")
const CRYSTAL_SHADOW := Color("4E9CC4")
const CRYSTAL_DEEP := Color("2E6E93")

# 풀. 섬 잔디(TURF_*)와 같은 계열.
const GRASS_LIGHT := Color("A6C97C")
const GRASS_MAIN := Color("7BA35A")
const GRASS_SHADOW := Color("55793D")

@export var kind: Kind = Kind.WIND_GRASS:
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
	# 바람풀과 수정만 움직인다(흔들림·맥동). 바위는 정지물이라 매 프레임 다시 그릴
	# 이유가 없다 — 절차적 맵은 프롭 수가 많아 이 구분이 실제로 비용이다.
	if kind == Kind.WIND_GRASS or kind == Kind.CRYSTAL:
		queue_redraw()


func _draw() -> void:
	match kind:
		Kind.SPIRE:
			_draw_spire()
		Kind.ARCH:
			_draw_arch()
		Kind.CRYSTAL:
			_draw_crystal()
		Kind.WIND_GRASS:
			_draw_wind_grass()


# ===== 그림 =====

# 바위탑. 위로 갈수록 좁아지는 기둥이고, 층진 결이 있다.
func _draw_spire() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -6), Vector2(34, 11)), SHADOW)

	var height := 116.0 + float(variant) * 14.0
	var lean := (float(variant) - 1.0) * 9.0
	# 몸통을 사다리꼴 여러 층으로 쌓는다. 폴리곤 하나로 그리면 매끈한 삼각형이
	# 되어 바위가 아니라 천막처럼 보인다.
	var layers := 6
	var previous_w := 30.0
	var previous_y := 0.0
	for i in range(1, layers + 1):
		var t := float(i) / float(layers)
		var y := -height * t
		var w := lerpf(30.0, 8.0, t)
		var x := lean * t * t
		var shade := ROCK_MAIN
		if i % 2 == 0:
			shade = ROCK_SHADOW
		draw_colored_polygon(PackedVector2Array([
			Vector2(x - w, y), Vector2(x + w, y),
			Vector2(lean * pow(float(i - 1) / float(layers), 2.0) + previous_w, previous_y),
			Vector2(lean * pow(float(i - 1) / float(layers), 2.0) - previous_w, previous_y),
		]), shade)
		# 층 경계의 밝은 선 — 위에서 빛을 받는 면이다.
		draw_line(Vector2(x - w, y), Vector2(x + w, y), ROCK_LIGHT, 2.0, true)
		previous_w = w
		previous_y = y

	# 밑동의 그늘.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30, 0), Vector2(30, 0), Vector2(22, -10), Vector2(-22, -10),
	]), ROCK_DEEP)


# 돌 아치. 가운데가 뚫려 있어 뒤의 허공이 비친다 — 이 맵에서 "떠 있음"을
# 가장 잘 말하는 물건이다.
func _draw_arch() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -6), Vector2(46, 12)), SHADOW)

	var height := 96.0
	var span := 34.0
	# 두 다리.
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var outer := side * (span + 15.0)
		var inner := side * span
		draw_colored_polygon(PackedVector2Array([
			Vector2(outer, 0), Vector2(inner, 0),
			Vector2(inner + side * 3.0, -height * 0.62),
			Vector2(outer - side * 2.0, -height * 0.62),
		]), ROCK_MAIN if side < 0.0 else ROCK_SHADOW)

	# 상판 — 다리 둘을 잇는 활. 선분을 이어 만든다.
	var steps := 12
	var previous := Vector2(-(span + 15.0), -height * 0.62)
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		var x := lerpf(-(span + 15.0), span + 15.0, t)
		var y := -height * 0.62 - sin(t * PI) * (height * 0.34)
		draw_line(previous, Vector2(x, y), ROCK_MAIN, 15.0, true)
		draw_line(previous, Vector2(x, y), ROCK_LIGHT, 4.0, true)
		previous = Vector2(x, y)

	# 안쪽 그늘. 아치 밑은 빛이 안 든다.
	draw_line(Vector2(-span, -height * 0.6), Vector2(span, -height * 0.6),
		ROCK_DEEP, 4.0, true)


# 하늘 수정. 이 맵에서 유일하게 스스로 빛나는 물건이라 눈에 띄는 표적이 된다.
func _draw_crystal() -> void:
	draw_colored_polygon(_ellipse(Vector2(0, -4), Vector2(26, 9)), SHADOW)

	# 아주 느린 맥동. 전투 중 배경이 눈을 끌면 안 되므로 폭을 작게 둔다.
	var pulse := 0.5 + 0.5 * sin(_elapsed * 1.3 + float(variant))
	var height := 74.0 + float(variant) * 8.0

	# 큰 결정 하나 + 작은 것 둘. 하나만 두면 이정표처럼 보인다.
	_draw_shard(Vector2(0, 0), height, 15.0, pulse)
	_draw_shard(Vector2(-17, 0), height * 0.52, 9.0, pulse * 0.8)
	_draw_shard(Vector2(15, 0), height * 0.42, 8.0, pulse * 0.6)


func _draw_shard(base: Vector2, height: float, half_width: float, glow: float) -> void:
	var tip := base + Vector2(0, -height)
	var left := base + Vector2(-half_width, -height * 0.34)
	var right := base + Vector2(half_width, -height * 0.34)
	draw_colored_polygon(PackedVector2Array([base, left, tip, right]), CRYSTAL_MAIN)
	# 왼쪽 면은 그늘, 오른쪽은 더 짙게 — 면이 셋인 기둥으로 읽히게 한다.
	draw_colored_polygon(PackedVector2Array([base, left, tip]), CRYSTAL_SHADOW)
	draw_colored_polygon(PackedVector2Array([base, tip, right]), CRYSTAL_DEEP)
	# 가운데 심. 맥동은 밝기가 아니라 **굵기**로 준다 — 색을 흔들면 화면에서 깜빡인다.
	draw_line(base, tip, CRYSTAL_CORE, 1.5 + glow * 2.0, true)


# 바람풀. 장식이라 이동을 막지 않는다(Decal 레이어에 놓는다).
func _draw_wind_grass() -> void:
	var sway := sin(_elapsed * 1.1 + float(variant) * 1.7) * 0.16
	var blades := 9 + variant * 2
	for i in blades:
		var offset := -22.0 + float(i) * (44.0 / float(blades))
		var height := 20.0 + float((i * 7 + variant * 3) % 11)
		var tip := Vector2(offset + sway * height, -height)
		var shade := GRASS_MAIN
		if i % 3 == 0:
			shade = GRASS_LIGHT
		elif i % 3 == 1:
			shade = GRASS_SHADOW
		draw_line(Vector2(offset, 0), tip, shade, 2.0, true)


# ===== 충돌 =====

func _rebuild_collision() -> void:
	var old_footprint := get_node_or_null("Footprint")
	if old_footprint:
		remove_child(old_footprint)
		old_footprint.queue_free()
	if kind == Kind.WIND_GRASS:
		return

	var body := StaticBody2D.new()
	body.name = "Footprint"

	match kind:
		Kind.SPIRE:
			_add_shape(body, Vector2(56, 28), 0.0)
		Kind.ARCH:
			# **다리 둘만 막는다.** 아치는 가운데가 뚫려 있고 그게 이 물건의 전부다 —
			# 폭 전체를 막으면 그림에는 지나갈 구멍이 보이는데 몸이 막힌다.
			# 다리는 x ±34~±49 에 있으므로 그 자리에 하나씩 둔다.
			_add_shape(body, Vector2(20, 24), -41.5)
			_add_shape(body, Vector2(20, 24), 41.5)
		Kind.CRYSTAL:
			_add_shape(body, Vector2(44, 22), 0.0)

	if body.get_child_count() == 0:
		body.queue_free()
		return
	add_child(body)


func _add_shape(body: StaticBody2D, size: Vector2, offset_x: float) -> void:
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = Vector2(offset_x, -size.y * 0.5)
	body.add_child(collision)


func _ellipse(center: Vector2, radius: Vector2, steps: int = 28) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
