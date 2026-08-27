extends Node2D
class_name SkyIslandMap

# 3챕터(하늘) 전장 맵 — 떠 있는 섬 (#423).
#
# 컨셉은 **구름 사이에 뜬 바위섬 조각들**이다. 섬은 밟을 수 있고 섬 밖은 허공이다.
#
# **허공은 시각적 배경이지 장애물이 아니다.** 낙하·낙사·이동 봉쇄는 전투 규칙이고
# 이 맵이 정할 일이 아니다(#423 Non-goals). 그래서 섬 밖으로 걸어 나갈 수 있고
# 아무 일도 일어나지 않는다 — 대신 섬을 넉넉하게 두어 전투가 자연히 섬 위에서
# 일어나게 만든다.
#
# BeachMap/GrasslandMap 과 같은 구조를 따른다(Ground/Overlay/Detail/Decal/Objects,
# 24px 타일, 색에서 만든 절차적 타일). 구조를 맞춘 이유는 프롭·데칼 규약과 검증
# 씬을 그대로 쓸 수 있기 때문이다 — Stage._place_map() 은 루트가 Node2D 인 것만
# 요구한다.
#
# **레이어를 해변과 같은 방식으로 나눈다**: 해변은 Ground=모래(전부) / Overlay=물
# (마스크)이었다. 여기서는 Ground=허공·구름(전부) / Overlay=섬 표면(마스크)이다.
# 뒤집어서 Ground 를 섬으로 두면 섬이 아닌 칸이 빈 셀이 되고, 그러면 맵 바깥의
# 빈 공간과 화면에서 구별되지 않는다 — 버그인지 연출인지 알 수 없게 된다.
#
# **크기를 초원과 맞춘 이유**: GameCamera 는 경계 제한(limit_*)이 없고 맵 크기를
# 읽지도 않는다. zoom 0.85 / 뷰포트 1280x720 에서 보이는 세계가 1506x847 이라,
# 맵이 그보다 작으면 어디를 봐도 맵 바깥의 빈 공간이 드러난다. 하늘 맵은 이 함정에
# 걸리기 특히 쉽다 — "섬만 만들면 된다"고 생각하면 채워진 범위가 섬 크기가 된다.
#
# 참고: stage/beach/BeachMap.gd, stage/grassland/GrasslandMap.gd, stage/StageMaps.gd

const TILE_SIZE := 24
const MAP_SIZE := Vector2i(96, 64)
const SOURCE_ID := 0

# 허공. 위가 밝고 아래로 갈수록 짙은 하늘이다 — 아래를 내려다보는 느낌을 색이 만든다.
const VOID_HIGH := Color("8FB6D8")
const VOID_MID := Color("6E93BC")
const VOID_LOW := Color("4F6E96")

# 구름. 허공 위에 얹히는 밝은 덩어리다.
const CLOUD_LIGHT := Color("EDF3F8")
const CLOUD_MAIN := Color("CFDEEC")
const CLOUD_SHADOW := Color("A8BFD6")

# 섬 윗면(밟는 자리). 풀이 덮인 바위다.
const TURF_LIGHT := Color("8FB86A")
const TURF_MAIN := Color("6D9850")
const TURF_SHADOW := Color("4E7139")

# 섬 바위. 윗면 아래로 드러나는 단면이다.
const ROCK_LIGHT := Color("9A8F80")
const ROCK_MAIN := Color("776D60")
const ROCK_SHADOW := Color("534B41")
const ROCK_DEEP := Color("39332C")

@onready var ground: TileMapLayer = $Ground
@onready var overlay: TileMapLayer = $Overlay
@onready var detail: TileMapLayer = $Detail
@onready var decals: Node2D = $Decal
@onready var objects: Node2D = $Objects

# 섬이 덮은 칸. 섬 타일을 놓을 자리와, 디테일(풀·돌)을 놓을 자리를 같은 출처로 쓴다.
# 두 곳에서 따로 판단하면 경계가 어긋나 허공 위에 풀이 뜬다.
var _island_cells: Dictionary = {}

# 섬 가장자리에서 아래로 드리우는 바위 단면의 칸. 섬 아래 몇 칸이다.
# 이것이 없으면 섬이 **종잇장**처럼 보인다 — 두께가 있어야 떠 있는 것이 된다.
var _cliff_cells: Dictionary = {}

# 구름이 덮은 칸.
var _cloud_cells: Dictionary = {}

# 섬 = 타원 목록. (중심 셀, 반지름 셀).
#
# **가운데 큰 섬이 전투 구역을 덮어야 한다.** 파티는 맵 로컬 (340,340) 근처,
# 적은 (840,470) 근처에 놓인다 — 셀로는 x 11~41, y 12~25 다. 그 자리가 허공이면
# 전투가 통째로 허공에서 벌어진다.
const ISLANDS := [
	# 중앙 본섬 — 전투 구역을 넉넉히 덮는다.
	[Vector2i(27, 19), Vector2(19.0, 11.0)],
	# 본섬에 붙은 혹. 완전한 타원은 섬이 아니라 접시로 보인다.
	[Vector2i(41, 24), Vector2(9.0, 7.0)],
	[Vector2i(14, 26), Vector2(8.0, 6.0)],
	# 떨어져 뜬 조각들. 허공이 "비어 있는 곳"이 아니라 "사이"로 읽히게 한다.
	[Vector2i(66, 14), Vector2(12.0, 8.0)],
	[Vector2i(80, 33), Vector2(10.0, 7.0)],
	[Vector2i(56, 44), Vector2(11.0, 7.0)],
	[Vector2i(22, 50), Vector2(10.0, 6.0)],
	[Vector2i(84, 56), Vector2(8.0, 5.0)],
	[Vector2i(6, 8), Vector2(7.0, 5.0)],
]

# 섬 아래로 바위 단면이 드리우는 칸 수.
const CLIFF_DEPTH := 4

# 허공의 높이 단계 수. 단계를 늘리고 경계를 흩뜨려 이음매를 없앤다.
const VOID_LEVELS := 6


func _ready() -> void:
	_mark_islands()
	_mark_clouds()
	_build_void()
	_build_islands()
	_build_details()
	_build_boundaries()


# ===== 섬의 자리 =====

func _mark_islands() -> void:
	for entry in ISLANDS:
		_mark_island(entry[0], entry[1])

	# 섬 아래 바위 단면. 섬 칸 바로 아래 CLIFF_DEPTH 칸을 표시하되,
	# 그 자리가 다른 섬이면 두지 않는다(섬 위에 절벽이 겹치면 얼룩이 된다).
	for cell in _island_cells:
		for depth in range(1, CLIFF_DEPTH + 1):
			var below: Vector2i = cell + Vector2i(0, depth)
			if not _inside(below) or _island_cells.has(below):
				continue
			# 아래로 갈수록 좁아진다 — 섬 밑면이 둥글게 깎인 모양이다.
			# 가장자리 칸에서는 얕게 둔다.
			if depth > 1 and _hash_cell(below.x, below.y, 41) % 5 < depth - 1:
				continue
			_cliff_cells[below] = maxi(int(_cliff_cells.get(below, 0)), depth)


func _mark_island(center: Vector2i, radius: Vector2) -> void:
	var reach := Vector2i(int(ceil(radius.x)) + 2, int(ceil(radius.y)) + 2)
	for y in range(center.y - reach.y, center.y + reach.y + 1):
		for x in range(center.x - reach.x, center.x + reach.x + 1):
			var cell := Vector2i(x, y)
			if not _inside(cell):
				continue
			# 둘레를 일그러뜨린다. 완전한 타원은 섬이 아니라 접시로 보인다.
			var wobble := 1.0 + float(_hash_cell(x, y, 53) % 7) * 0.045
			var distance := Vector2(
				float(x - center.x) / (radius.x * wobble),
				float(y - center.y) / (radius.y * wobble)).length()
			if distance <= 1.0:
				_island_cells[cell] = true


# 구름 덩어리. 섬이 아닌 칸에만 얹는다 — 섬 위에 구름이 오면 밟는 자리가 가려진다.
#
# **사인으로 만들면 안 된다.** 처음에 사인 둘을 겹쳐 띠를 만들었더니 y 계수가 작아
# 띠가 거의 수평이 됐고, 한 칸씩 켜졌다 꺼지며 **블라인드 같은 가로 줄무늬**가 나왔다
# (미리보기에서 바로 드러났다). 셀 해시를 그대로 써도 안 된다 — 한 칸짜리 점이 된다.
# 굵은 격자에서 값을 뽑아 부드럽게 이어야 덩어리가 된다.
func _mark_clouds() -> void:
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if _island_cells.has(cell) or _cliff_cells.has(cell):
				continue
			# 굵은 덩어리 + 잔결. 두 배율을 겹쳐 가장자리가 밋밋하지 않게 한다.
			var value := _cloud_noise(x, y, 13.0, 5) * 0.75 + _cloud_noise(x, y, 5.0, 71) * 0.25
			if value > 0.60:
				_cloud_cells[cell] = true


# 굵은 격자 값 잡음(0~1). 격자점의 해시를 부드럽게(smoothstep) 잇는다.
func _cloud_noise(x: int, y: int, scale: float, salt: int) -> float:
	var fx := float(x) / scale
	var fy := float(y) / scale
	var x0 := int(floor(fx))
	var y0 := int(floor(fy))
	var tx := fx - float(x0)
	var ty := fy - float(y0)
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := float(_hash_cell(x0, y0, salt) % 1000) * 0.001
	var b := float(_hash_cell(x0 + 1, y0, salt) % 1000) * 0.001
	var c := float(_hash_cell(x0, y0 + 1, salt) % 1000) * 0.001
	var d := float(_hash_cell(x0 + 1, y0 + 1, salt) % 1000) * 0.001
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)


# ===== 허공 =====
#
# **모든 칸을 채운다.** 섬이 아닌 칸을 비워 두면 맵 바깥의 빈 공간과 화면에서
# 구별되지 않는다(#423). Ground 에 빈 셀이 0 이어야 한다.
func _build_void() -> void:
	# 아틀라스: 높이 단계 VOID_LEVELS x 변형 4 + 구름 마스크 16.
	var tiles: Array[Image] = []
	for level in VOID_LEVELS:
		for variant in 4:
			tiles.append(_make_void_tile(level, variant))
	for mask in 16:
		tiles.append(_make_cloud_tile(mask))
	ground.tile_set = _make_tile_set(tiles)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if _cloud_cells.has(cell):
				var mask := 0
				if _is_cloud(cell + Vector2i.UP): mask |= 1
				if _is_cloud(cell + Vector2i.RIGHT): mask |= 2
				if _is_cloud(cell + Vector2i.DOWN): mask |= 4
				if _is_cloud(cell + Vector2i.LEFT): mask |= 8
				ground.set_cell(cell, SOURCE_ID, Vector2i(VOID_LEVELS * 4 + mask, 0))
				continue
			ground.set_cell(cell, SOURCE_ID,
				Vector2i(_void_level(x, y) * 4 + (_hash_cell(x, y, 17) % 4), 0))


# 구름인가 — **맵 밖은 구름이 아니라고 본다.** 해변의 물(_is_open_water)과 반대다:
# 저기는 바다가 맵 끝에서 끊기면 안 되지만, 여기 구름은 띠라서 맵 밖까지 이어질
# 이유가 없다. 테두리에서 구름이 닫히는 편이 자연스럽다.
func _is_cloud(cell: Vector2i) -> bool:
	if not _inside(cell):
		return false
	return _cloud_cells.has(cell)


# ===== 섬 =====
#
# 해변의 물과 같은 4방향 마스크 방식이다. 마스크가 없으면 섬 테두리가 타일 격자
# 그대로 각져 보인다 — 떠 있는 섬에서는 그 각짐이 특히 눈에 걸린다(둘레가 전부
# 허공과 맞닿아 있어서 대비가 가장 크다).
func _build_islands() -> void:
	# 아틀라스: 섬 윗면 마스크 16 + 절벽 깊이 4.
	var tiles: Array[Image] = []
	for mask in 16:
		tiles.append(_make_turf_tile(mask))
	for depth in CLIFF_DEPTH:
		tiles.append(_make_cliff_tile(depth))
	overlay.tile_set = _make_tile_set(tiles)
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	# 절벽을 먼저 놓고 섬을 덮는다 — 같은 레이어라 나중 것이 이긴다.
	for cell in _cliff_cells:
		if not _inside(cell):
			continue
		var depth: int = clampi(int(_cliff_cells[cell]) - 1, 0, CLIFF_DEPTH - 1)
		overlay.set_cell(cell, SOURCE_ID, Vector2i(16 + depth, 0))

	for cell in _island_cells:
		if not _inside(cell):
			continue
		var mask := 0
		if _is_island(cell + Vector2i.UP): mask |= 1
		if _is_island(cell + Vector2i.RIGHT): mask |= 2
		if _is_island(cell + Vector2i.DOWN): mask |= 4
		if _is_island(cell + Vector2i.LEFT): mask |= 8
		overlay.set_cell(cell, SOURCE_ID, Vector2i(mask, 0))


# 섬인가 — **맵 밖은 섬이 아니다.** 맵 테두리에 걸친 섬은 거기서 잘려야 한다
# (해변의 물과 반대다: 바다는 이어져야 하고 섬은 끝나야 한다).
func _is_island(cell: Vector2i) -> bool:
	if not _inside(cell):
		return false
	return _island_cells.has(cell)


# ===== 디테일 =====
#
# 섬 위에만 놓는다. 허공에 풀·돌 그림이 뜨면 떠 있는 물체로 보인다.
func _build_details() -> void:
	var tiles: Array[Image] = []
	for kind in 5:
		tiles.append(_make_detail_tile(kind))
	detail.tile_set = _make_tile_set(tiles)
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	for cell in _island_cells:
		if not _inside(cell):
			continue
		var value := _hash_cell(cell.x, cell.y, 73)
		if value % 13 == 0:
			detail.set_cell(cell, SOURCE_ID, Vector2i(value % 5, 0))


# ===== 경계 =====
#
# 초원·해변과 같다. 맵 밖으로 걸어 나가지 못하게 네 변에 벽을 세운다.
# **섬 가장자리에는 벽을 세우지 않는다** — 그건 이동 봉쇄이고 전투 규칙이다(#423).
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


# 허공. 단색으로 두면 96x64 가 통째로 한 색이라 하늘이 아니라 배경천으로 보인다.
# 아주 옅은 얼룩을 넣어 면이 살아 있게 한다.
func _make_void_tile(level: int, variant: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	# 위에서 아래로 잇는다. 3단계였을 때는 y 의 1/3, 2/3 자리에 **직선 이음매**가
	# 화면을 가로질렀다 — 하늘이 아니라 배경천 두 장을 이어 붙인 것으로 보였다.
	var t := float(level) / float(VOID_LEVELS - 1)
	var base := VOID_HIGH.lerp(VOID_MID, t * 2.0)
	if t >= 0.5:
		base = VOID_MID.lerp(VOID_LOW, (t - 0.5) * 2.0)
	image.fill(base)
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var value := _hash_cell(x + variant * 31, y + level * 17, 11)
			if value % 23 == 0:
				image.set_pixel(x, y, base.lightened(0.06))
			elif value % 29 == 0:
				image.set_pixel(x, y, base.darkened(0.06))
	return image


# 구름. 이웃이 구름이 아닌 쪽은 안쪽으로 물러나 둥근 덩어리가 된다
# (마스크 규약은 물 타일과 같다: 1 위, 2 오른쪽, 4 아래, 8 왼쪽).
func _make_cloud_tile(mask: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	# 밑은 허공이다 — 구름이 덜 채운 자리로 하늘이 비쳐야 한다.
	image.fill(VOID_MID)
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var wave_x := (_hash_cell(y, mask, 31) % 7) - 3
			var wave_y := (_hash_cell(x, mask, 43) % 7) - 3
			var left := 0 if (mask & 8) != 0 else 4 + wave_x
			var right := TILE_SIZE if (mask & 2) != 0 else TILE_SIZE - 4 - wave_x
			var top := 0 if (mask & 1) != 0 else 4 + wave_y
			var bottom := TILE_SIZE if (mask & 4) != 0 else TILE_SIZE - 4 - wave_y
			if x < left or x >= right or y < top or y >= bottom:
				continue
			# **드러난 변에만 음영을 준다.** 타일마다 위를 밝게 아래를 어둡게 칠했더니
			# 구름 안쪽에서 그 음영이 24px 주기로 반복돼 **블라인드 줄무늬**가 됐다
			# (미리보기에서 드러났다). 이웃이 구름인 쪽은 덩어리 속이라 음영이 없어야
			# 이어 붙은 한 덩어리로 보인다.
			var shade := CLOUD_MAIN
			if (mask & 1) == 0 and y < top + 5:
				shade = CLOUD_LIGHT
			elif (mask & 4) == 0 and y >= bottom - 5:
				shade = CLOUD_SHADOW
			elif _hash_cell(x, y + mask * 3, 83) % 17 == 0:
				# 잔결. 없으면 덩어리 속이 완전한 단색이라 종이 오린 것처럼 보인다.
				shade = CLOUD_LIGHT
			image.set_pixel(x, y, shade)
	return image


# 섬 윗면. 이웃이 섬이 아닌 쪽은 안쪽으로 물러나고, 그 가장자리에 밝은 테를 준다 —
# 위에서 빛을 받는 잔디 끝이다. 이 테가 섬과 허공을 화면에서 가른다.
func _make_turf_tile(mask: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var wave_x := (_hash_cell(y, mask, 23) % 5) - 2
			var wave_y := (_hash_cell(x, mask, 37) % 5) - 2
			var left := 0 if (mask & 8) != 0 else 3 + wave_x
			var right := TILE_SIZE if (mask & 2) != 0 else TILE_SIZE - 3 - wave_x
			var top := 0 if (mask & 1) != 0 else 3 + wave_y
			var bottom := TILE_SIZE if (mask & 4) != 0 else TILE_SIZE - 3 - wave_y
			if x < left or x >= right or y < top or y >= bottom:
				continue
			var shade := TURF_MAIN
			# 바깥으로 드러난 변에 테를 두른다.
			if (x <= left + 1 and (mask & 8) == 0) or (y <= top + 1 and (mask & 1) == 0):
				shade = TURF_LIGHT
			elif (x >= right - 2 and (mask & 2) == 0) \
					or (y >= bottom - 2 and (mask & 4) == 0):
				shade = TURF_SHADOW
			elif _hash_cell(x, y + mask * 7, 19) % 11 == 0:
				shade = TURF_LIGHT
			elif _hash_cell(x + mask * 5, y, 13) % 13 == 0:
				shade = TURF_SHADOW
			image.set_pixel(x, y, shade)
	return image


# 섬 밑의 바위 단면. 깊을수록 좁고 어둡다 — 아래로 갈수록 사라지는 뿌리다.
# 이것이 섬에 두께를 준다. 없으면 섬이 하늘에 붙인 종잇장으로 보인다.
func _make_cliff_tile(depth: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var inset := 2 + depth * 4
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var jag := (_hash_cell(x, y + depth * 11, 47) % 5) - 2
			if x < inset + jag or x >= TILE_SIZE - inset - jag:
				continue
			var shade := ROCK_MAIN
			if depth == 0 and y < 6:
				shade = ROCK_LIGHT
			elif depth >= 2:
				shade = ROCK_DEEP if y > TILE_SIZE / 2 else ROCK_SHADOW
			elif y > TILE_SIZE - 8:
				shade = ROCK_SHADOW
			# 세로 결. 바위 단면이 매끈하면 돌이 아니라 색 덩어리다.
			if _hash_cell(x, y, 59) % 9 == 0:
				shade = shade.darkened(0.12)
			image.set_pixel(x, y, shade)
	return image


# 섬 위 디테일. 허공에는 안 놓는다.
func _make_detail_tile(kind: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	match kind:
		0, 1:
			# 풀포기.
			for i in 3 + kind:
				var x := 5 + ((_hash_cell(kind, i, 11) + i * 7) % 14)
				var top := 9 + ((_hash_cell(i, kind, 5) + i * 3) % 5)
				for y in range(top, 18):
					image.set_pixel(x, y, TURF_SHADOW)
				image.set_pixel(x, top - 1, TURF_LIGHT)
		2:
			# 흩어진 돌 몇 개.
			for i in 3:
				var x := 6 + ((_hash_cell(i, kind, 17) + i * 5) % 13)
				var y := 10 + ((_hash_cell(kind, i, 7) + i * 4) % 8)
				image.set_pixel(x, y, ROCK_LIGHT)
				image.set_pixel(x + 1, y, ROCK_MAIN)
				image.set_pixel(x, y + 1, ROCK_SHADOW)
				image.set_pixel(x + 1, y + 1, ROCK_SHADOW)
		3:
			# 드러난 바위 결.
			for y in range(11, 16):
				for x in range(5, 19):
					if (x + y) % 4 == 0:
						image.set_pixel(x, y, ROCK_MAIN)
		4:
			# 옅은 풀 얼룩.
			for y in range(7, 18):
				for x in range(5, 20):
					if _hash_cell(x, y, 91) % 6 == 0:
						image.set_pixel(x, y, Color(TURF_LIGHT.r, TURF_LIGHT.g,
							TURF_LIGHT.b, 0.35))
	return image


# ===== 공용 =====

# 이 칸의 허공 밝기 단계. 경계를 해시로 흩뜨려 단계 사이가 직선으로 갈리지 않게 한다.
func _void_level(x: int, y: int) -> int:
	var t := float(y) / float(MAP_SIZE.y - 1)
	var jitter := (float(_hash_cell(x, y, 67) % 100) * 0.01 - 0.5) / float(VOID_LEVELS)
	return clampi(int(round((t + jitter) * float(VOID_LEVELS - 1))), 0, VOID_LEVELS - 1)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y


func _hash_cell(x: int, y: int, salt: int) -> int:
	var value := x * 374761393 + y * 668265263 + salt * 69069
	value = (value ^ (value >> 13)) * 1274126177
	return absi(value ^ (value >> 16))
