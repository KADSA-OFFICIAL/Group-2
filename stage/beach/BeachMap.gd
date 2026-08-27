extends Node2D
class_name BeachMap

# 2챕터(바다) 전장 맵 — 해변 (#422).
#
# 컨셉은 **모래밭과 얕은 물이 섞인 평지**다. 물은 밟을 수 있다 —
# 밟을 수 없는 물을 넣으면 그건 이동 봉쇄이고, 전투 규칙이라 이 맵이 정할 일이 아니다.
# 그래서 여기서 물은 **재질이 다른 바닥**이지 장애물이 아니다.
#
# GrasslandMap 과 같은 구조를 따른다(Ground/Overlay/Detail/Decal/Objects, 24px 타일,
# 색에서 만든 절차적 타일). 구조를 맞춘 이유는 프롭·데칼 규약과 검증 씬을 그대로 쓸 수
# 있기 때문이다 -- Stage._place_map() 은 루트가 Node2D 인 것만 요구한다.
#
# **크기를 초원과 맞춘 이유**: GameCamera 는 경계 제한(limit_*)이 없고 맵 크기를 읽지도
# 않는다. zoom 0.85 / 뷰포트 1280x720 에서 보이는 세계가 1506x847 이라, 맵이 그보다
# 작으면 어디를 봐도 맵 바깥의 빈 공간이 드러난다. 초원이 #396 에서 96x64 로 넓혀
# 없앤 문제이고, 여기서 작게 만들면 그 문제가 되살아난다.
#
# 참고: stage/grassland/GrasslandMap.gd, stage/StageMaps.gd

const TILE_SIZE := 24
const MAP_SIZE := Vector2i(96, 64)
const SOURCE_ID := 0

# 모래. 초원의 흙길(DIRT_*)보다 밝고 노랗다 — 젖지 않은 마른 모래다.
const SAND_BASE := Color("D9C79B")
const SAND_LIGHT := Color("E8DAB4")
const SAND_SHADOW := Color("BCA87C")

# 젖은 모래. 물가와 마른 모래 사이의 띠다. 이 띠가 없으면 물이 모래 위에
# 오려 붙인 것처럼 보인다.
const SAND_WET := Color("A89372")

# 얕은 물. 깊어지는 방향으로 세 단계.
const WATER_SHALLOW := Color("7FA9A6")
const WATER_MID := Color("5D8C92")
const WATER_DEEP := Color("456F7A")
const FOAM := Color("EDF2EC")

@onready var ground: TileMapLayer = $Ground
@onready var overlay: TileMapLayer = $Overlay
@onready var detail: TileMapLayer = $Detail
@onready var decals: Node2D = $Decal
@onready var objects: Node2D = $Objects

# 물이 덮은 칸. 물 타일을 놓을 자리와, 디테일(조개·자갈)을 피할 자리를 같은 출처로 쓴다.
var _water_cells: Dictionary = {}

# 물 칸의 깊이 단계(0 얕음 / 1 중간 / 2 깊음). 물가로부터의 거리로 정한다.
# 타일 안에서 그라데이션을 칠하지 않는 이유는 _make_water_tile 주석에 적었다.
var _water_depth: Dictionary = {}

# 깊이 단계 수. 타일 아틀라스가 16(마스크) x 이 값만큼 만들어진다.
const DEPTH_LEVELS := 3

# 물가에서 한 칸 안쪽(젖은 모래) 칸.
var _wet_cells: Dictionary = {}


func _ready() -> void:
	_mark_water()
	_build_ground()
	_build_water()
	_build_details()
	_build_boundaries()


# ===== 물의 자리 =====
#
# 어디가 물인지 먼저 정한다. Ground(모래)와 Overlay(물)를 각각 순회하면서 따로
# 판단하면 두 곳의 경계가 어긋나 물 밑에 마른 모래가 보인다.
func _mark_water() -> void:
	# 바다는 **남쪽**이다. 물가(waterline)가 x 에 따라 출렁이게 두어 직선이 되지 않게 한다.
	# 진폭을 크게 두면 전투 공간이 들쭉날쭉해져 파티가 낄 자리가 생긴다 -- 6칸 안에서 흔든다.
	for x in MAP_SIZE.x:
		# sine 만 쓰면 완만한 구간에서 같은 y 가 여러 칸 이어지다 한 번에 한 칸 튄다.
		# 그 결과가 **24px 계단**이다 — 색 대비가 큰 젖은 모래에서 특히 눈에 걸린다.
		# 열마다 ±1 칸을 흔들어 긴 직선 구간을 깬다. 지터가 커지면 해안선이
		# 톱날처럼 보이므로 한 칸까지만 둔다.
		var jitter := (_hash_cell(x, 0, 97) % 3) - 1
		var waterline := 30 + jitter + int(round(
			sin(float(x) * 0.11) * 3.0 + sin(float(x) * 0.037 + 1.7) * 3.0))
		for y in range(waterline, MAP_SIZE.y):
			var cell := Vector2i(x, y)
			_water_cells[cell] = true
			# 물가에서 멀어질수록 깊다. 경계를 살짝 어긋나게 두어(hash) 깊이 띠가
			# 물가와 나란한 직선으로 보이지 않게 한다.
			var distance := y - waterline + (_hash_cell(x, y, 83) % 3)
			if distance >= 11:
				_water_depth[cell] = 2
			elif distance >= 4:
				_water_depth[cell] = 1
			else:
				_water_depth[cell] = 0
		# 젖은 모래는 물가 바로 위 세 칸이다.
		for offset in range(1, 4):
			var cell := Vector2i(x, waterline - offset)
			if _inside(cell):
				_wet_cells[cell] = true

	# 조수 웅덩이 둘. 물가에서 떨어진 마른 모래 위에 물이 고여 있으면
	# 해변이 "위는 모래, 아래는 물"로 반듯하게 나뉘지 않는다.
	_mark_pool(Vector2i(10, 7), Vector2(7.0, 4.0))
	_mark_pool(Vector2i(70, 16), Vector2(7.0, 4.0))


# 타원 웅덩이 하나를 물로 표시하고, 그 둘레를 젖은 모래로 만든다.
func _mark_pool(center: Vector2i, radius: Vector2) -> void:
	var reach := Vector2i(int(ceil(radius.x)) + 3, int(ceil(radius.y)) + 3)
	for y in range(center.y - reach.y, center.y + reach.y + 1):
		for x in range(center.x - reach.x, center.x + reach.x + 1):
			var cell := Vector2i(x, y)
			if not _inside(cell):
				continue
			# 둘레를 살짝 일그러뜨린다. 완전한 타원은 웅덩이보다 그릇처럼 보인다.
			var wobble := 1.0 + float(_hash_cell(x, y, 61) % 5) * 0.05
			var distance := Vector2(
				float(x - center.x) / (radius.x * wobble),
				float(y - center.y) / (radius.y * wobble)).length()
			if distance <= 1.0:
				_water_cells[cell] = true
				# 웅덩이는 고인 물이라 전부 얕다. 물가처럼 깊어지지 않는다.
				_water_depth[cell] = 0
			elif distance <= 1.45:
				_wet_cells[cell] = true


# ===== 바닥 =====

func _build_ground() -> void:
	# 0..3 마른 모래 변형, 4..19 젖은 모래(4방향 마스크).
	#
	# 젖은 모래에도 마스크가 필요한 이유: 평평한 타일 하나로 깔면 마른 모래와의 경계가
	# 타일 격자 그대로 **24px 계단**이 된다. 전투 줌에서 그 계단이 그대로 보여
	# 해안선이 아니라 픽셀 계단처럼 읽힌다(실제로 미리보기에서 드러났다).
	# 물(Overlay)은 처음부터 마스크를 썼는데 젖은 모래만 빠져 있었다.
	var tiles: Array[Image] = []
	for variant in 4:
		tiles.append(_make_dry_sand_tile(variant))
	for mask in 16:
		tiles.append(_make_wet_sand_tile(mask))

	ground.tile_set = _make_tile_set(tiles)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			# 물 밑에도 모래를 깐다. 물 타일이 반투명이라 밑이 비고, 무엇보다
			# Ground 가 전부 채워져 있어야 맵 밖과 구별된다.
			if not (_wet_cells.has(cell) or _water_cells.has(cell)):
				ground.set_cell(cell, SOURCE_ID, Vector2i(_hash_cell(x, y, 19) % 4, 0))
				continue

			var mask := 0
			if _is_damp(cell + Vector2i.UP): mask |= 1
			if _is_damp(cell + Vector2i.RIGHT): mask |= 2
			if _is_damp(cell + Vector2i.DOWN): mask |= 4
			if _is_damp(cell + Vector2i.LEFT): mask |= 8
			ground.set_cell(cell, SOURCE_ID, Vector2i(4 + mask, 0))


# 젖어 있는 칸인가 — 젖은 모래와 물 둘 다다(물은 젖은 모래 위에 있다).
# 맵 **밖은 젖어 있다고 본다**: 그러지 않으면 맵 테두리에 마른 모래 띠가 생겨
# 바다가 맵 끝에서 갑자기 멈춘 것처럼 보인다.
func _is_damp(cell: Vector2i) -> bool:
	if not _inside(cell):
		return true
	return _wet_cells.has(cell) or _water_cells.has(cell)


# 물인가 — 맵 밖도 물로 본다(위 _is_damp 와 같은 이유: 테두리에 가짜 경계를 만들지 않는다).
#
# 조수 웅덩이는 이 규칙에서 손해를 보지 않는다: 웅덩이는 맵 안쪽에 있어서
# 이웃이 실제로 마른 모래이므로 둘레에 거품이 그대로 그려진다.
func _is_open_water(cell: Vector2i) -> bool:
	if not _inside(cell):
		return true
	return _water_cells.has(cell)


# ===== 물 =====
#
# 초원의 흙길과 같은 4방향 마스크 방식이다. 마스크가 없으면 물 덩어리의 테두리가
# 타일 격자 그대로 각져 보인다.
func _build_water() -> void:
	# 아틀라스는 깊이 단계마다 16개 마스크를 갖는다. 인덱스 = depth * 16 + mask.
	var tiles: Array[Image] = []
	for depth in DEPTH_LEVELS:
		for mask in 16:
			tiles.append(_make_water_tile(mask, depth))
	overlay.tile_set = _make_tile_set(tiles)
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	for cell in _water_cells:
		if not _inside(cell):
			continue
		# 맵 밖은 물로 본다. 그러지 않으면 바다가 맵 테두리에서 이웃을 못 찾아
		# 네 변에 **거품 점선**이 그려진다 -- 실제로 미리보기에서 흰 테두리로 드러났다.
		var mask := 0
		if _is_open_water(cell + Vector2i.UP): mask |= 1
		if _is_open_water(cell + Vector2i.RIGHT): mask |= 2
		if _is_open_water(cell + Vector2i.DOWN): mask |= 4
		if _is_open_water(cell + Vector2i.LEFT): mask |= 8
		var depth: int = int(_water_depth.get(cell, 0))
		overlay.set_cell(cell, SOURCE_ID, Vector2i(depth * 16 + mask, 0))


# ===== 디테일 =====
#
# 마른 모래 위에만 놓는다. 물 위에 자갈·조개 그림이 뜨면 물이 얕다는 느낌이 아니라
# 물 위에 떠 있는 것처럼 보인다.
func _build_details() -> void:
	var tiles: Array[Image] = []
	for kind in 6:
		tiles.append(_make_detail_tile(kind))
	detail.tile_set = _make_tile_set(tiles)
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if _water_cells.has(cell):
				continue
			var value := _hash_cell(x, y, 73)
			if value % 19 == 0:
				detail.set_cell(cell, SOURCE_ID, Vector2i(value % 6, 0))


# ===== 경계 =====
#
# 초원과 같다. 맵 밖으로 걸어 나가지 못하게 네 변에 벽을 세운다 --
# 남쪽이 물이라도 벽은 있다. 바다로 계속 걸어 들어가는 것은 이 맵이 다룰 일이 아니다.
func _build_boundaries() -> void:
	var world_size := Vector2(MAP_SIZE * TILE_SIZE)
	_add_boundary(Vector2(world_size.x * 0.5, -12), Vector2(world_size.x, 24))
	_add_boundary(Vector2(world_size.x * 0.5, world_size.y + 12), Vector2(world_size.x, 24))
	_add_boundary(Vector2(-12, world_size.y * 0.5), Vector2(24, world_size.y))
	_add_boundary(Vector2(world_size.x + 12, world_size.y * 0.5), Vector2(24, world_size.y))


func _add_boundary(position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = "MapBoundary"
	body.position = position
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)


# ===== 타일 그림 =====

func _make_tile_set(tiles: Array[Image]) -> TileSet:
	var atlas := Image.create(TILE_SIZE * tiles.size(), TILE_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for i in tiles.size():
		atlas.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)),
			Vector2i(i * TILE_SIZE, 0))
	var texture := ImageTexture.create_from_image(atlas)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	for i in tiles.size():
		source.create_tile(Vector2i(i, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, SOURCE_ID)
	return tile_set


func _make_dry_sand_tile(variant: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(SAND_BASE)
	_scatter_grain(image, variant, SAND_BASE, SAND_LIGHT, SAND_SHADOW)

	# 바람이 만든 잔물결 자국. 마른 모래에만 있다.
	for i in 2:
		var y := 5 + ((_hash_cell(variant, i, 7) + i * 9) % 14)
		for x in TILE_SIZE:
			if (x + y) % 3 == 0:
				image.set_pixel(x, y, SAND_SHADOW)
	return image


# 젖은 모래. 마른 모래를 밑에 깔고, 이웃이 젖지 않은 쪽은 안쪽으로 물러난다
# (물 타일과 같은 마스크 규약: 1 위, 2 오른쪽, 4 아래, 8 왼쪽).
func _make_wet_sand_tile(mask: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(SAND_BASE)
	_scatter_grain(image, mask, SAND_BASE, SAND_LIGHT, SAND_SHADOW)

	for y in TILE_SIZE:
		for x in TILE_SIZE:
			# 흔들림을 물 타일보다 크게 둔다(±3px). 젖은 모래는 마른 모래와 색 대비가 커서
			# 타일 경계가 직선이면 바로 눈에 걸린다.
			var wave_x := (_hash_cell(y, mask, 29) % 7) - 3
			var wave_y := (_hash_cell(x, mask, 37) % 7) - 3
			var left := 0 if (mask & 8) != 0 else 3 + wave_x
			var right := TILE_SIZE if (mask & 2) != 0 else TILE_SIZE - 3 + wave_x
			var top := 0 if (mask & 1) != 0 else 3 + wave_y
			var bottom := TILE_SIZE if (mask & 4) != 0 else TILE_SIZE - 3 + wave_y
			if x < left or x >= right or y < top or y >= bottom:
				continue
			var color := SAND_WET
			var value := _hash_cell(x, y, mask + 53)
			if value % 17 == 0:
				color = color.lightened(0.10)
			elif value % 23 == 0:
				color = color.darkened(0.10)
			image.set_pixel(x, y, color)
	return image


# 모래알. 초원의 풀보다 촘촘하고 대비가 약하다 -- 모래는 결이 잘다.
func _scatter_grain(image: Image, salt: int, base: Color, light: Color, shadow: Color) -> void:
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var value := _hash_cell(x + salt * 11, y, 31)
			if value % 17 == 0:
				image.set_pixel(x, y, light)
			elif value % 23 == 0:
				image.set_pixel(x, y, shadow)


# 마스크는 이웃한 물의 방향이다(1 위, 2 오른쪽, 4 아래, 8 왼쪽).
# 이웃이 물이 아닌 쪽은 타일 안쪽으로 물러나며 거품 선을 둔다.
#
# depth 는 타일 **전체**의 깊이 단계다(0 얕음 / 1 중간 / 2 깊음). 타일 안에서
# 아래로 갈수록 어둡게 칠하면 안 된다 — 그러면 24px 마다 같은 그라데이션이 반복되어
# 바다 전체에 **가로 줄무늬**가 생긴다(실제로 그렇게 만들었다가 미리보기에서 드러났다).
# 깊이는 물가로부터의 거리로 정해지므로 맵이 알고 있고(_water_depth), 타일은 그 단계를 받는다.
func _make_water_tile(mask: int, depth: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	var base := WATER_SHALLOW
	if depth == 1:
		base = WATER_MID
	elif depth >= 2:
		base = WATER_DEEP
	# 깊을수록 밑이 덜 비친다.
	var alpha := 0.78 + float(mini(depth, 2)) * 0.06

	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var wave_x := (_hash_cell(y, mask, 17) % 3) - 1
			var wave_y := (_hash_cell(x, mask, 23) % 3) - 1
			var left := 0 if (mask & 8) != 0 else 3 + wave_x
			var right := TILE_SIZE if (mask & 2) != 0 else TILE_SIZE - 3 + wave_x
			var top := 0 if (mask & 1) != 0 else 3 + wave_y
			var bottom := TILE_SIZE if (mask & 4) != 0 else TILE_SIZE - 3 + wave_y
			if x < left or x >= right or y < top or y >= bottom:
				continue

			# 가장자리(이웃이 물이 아닌 쪽의 첫 두 픽셀)는 거품이다.
			var on_edge := (mask & 1) == 0 and y < top + 2 \
				or (mask & 4) == 0 and y >= bottom - 2 \
				or (mask & 8) == 0 and x < left + 2 \
				or (mask & 2) == 0 and x >= right - 2
			if on_edge:
				image.set_pixel(x, y, FOAM)
				continue

			# 잔결만 얹는다. 방향성 있는 그라데이션은 타일 경계에서 반복이 드러난다.
			var color := base
			var value := _hash_cell(x, y, mask + depth * 7 + 41)
			if value % 23 == 0:
				color = color.lightened(0.12)
			elif value % 29 == 0:
				color = color.darkened(0.10)
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return image


func _make_detail_tile(kind: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	match kind:
		0, 1:
			# 잔 자갈.
			for i in 3 + kind:
				var x := 5 + ((_hash_cell(kind, i, 11) + i * 7) % 14)
				var y := 8 + ((_hash_cell(i, kind, 5) + i * 5) % 11)
				image.set_pixel(x, y, SAND_SHADOW)
				image.set_pixel(x + 1, y, SAND_SHADOW)
				image.set_pixel(x, y - 1, SAND_LIGHT)
		2:
			# 작은 조개 껍데기 하나.
			for offset in range(-3, 4):
				image.set_pixel(12 + offset, 14, Color("EDDFC6"))
				image.set_pixel(12 + offset, 13, Color("D6C0A2"))
			image.set_pixel(12, 12, Color("EDDFC6"))
		3:
			# 마른 해초 뭉치.
			for i in 4:
				var x := 7 + i * 3
				for y in range(12, 19):
					if _hash_cell(x, y, 3) % 3 != 0:
						image.set_pixel(x, y, Color("6E6B45"))
		4:
			# 발자국처럼 남은 얕은 파임 둘.
			for spot in [Vector2i(8, 13), Vector2i(15, 17)]:
				for y in range(spot.y, spot.y + 3):
					for x in range(spot.x, spot.x + 4):
						image.set_pixel(x, y, SAND_SHADOW)
				image.set_pixel(spot.x, spot.y - 1, SAND_LIGHT)
		5:
			# 아주 옅은 물기 얼룩. 마른 모래 위 습기다.
			for y in range(7, 18):
				for x in range(5, 20):
					if _hash_cell(x, y, 91) % 7 == 0:
						image.set_pixel(x, y, Color(0.42, 0.38, 0.28, 0.20))
	return image


# ===== 공용 =====

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y


func _hash_cell(x: int, y: int, salt: int) -> int:
	var value := x * 374761393 + y * 668265263 + salt * 69069
	value = (value ^ (value >> 13)) * 1274126177
	return absi(value ^ (value >> 16))
