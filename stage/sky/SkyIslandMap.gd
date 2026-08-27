extends Node2D
class_name SkyIslandMap

# 3챕터(하늘) 전장 맵 — 떠 있는 섬 (#423).
#
# 컨셉은 **구름 사이에 뜬 바위섬**이다. 섬은 밟는 자리이고 섬 사이는 허공이다.
#
# **섬 밖으로는 나가지 못한다** (#429). 허공에 충돌을 놓아 섬이 실제 발판이 되게 한다.
# 파티·적 구분 없이 적용된다 -- 이 프로젝트는 물리 레이어를 지정하지 않으므로
# (전부 기본 레이어 1) 기본 StaticBody2D 하나로 둘 다 막힌다.
#
# **낙하·낙사를 만들지 않는다.** 낙하를 넣으면 새 전투 규칙이 줄줄이 따라온다 --
# 낙하 피해량, 복귀 자리, 복귀 후 무적 시간, 적에게도 적용할지, 넉백으로 밀어
# 떨어뜨리는 것이 정당한 전술인지. 그 전부가 밸런스 결정이고, 하늘 맵 하나 때문에
# 전투 전체가 달라진다. 막기만 하면 **새 규칙이 하나도 생기지 않는다.**
#
# 넉백(EnemyBase.apply_knockback)과 여왕 후퇴가 둘 다 move_and_slide 라서
# 밀려나 떨어지는 일 자체가 없다 -- 그래서 "밀어 떨어뜨리기"를 어떻게 다룰지도
# 정할 필요가 없다.
#
# **Ground 를 전부 채운다.** 섬이 아닌 칸도 허공·구름으로 명시적으로 깐다.
# 채우지 않으면 섬 사이 허공과 **맵 바깥 빈 공간이 화면에서 구별되지 않아**
# 버그인지 연출인지 알 수 없게 된다. 하늘 맵이 특히 걸리기 쉬운 함정이다.
#
# 크기를 초원·해변과 맞춘 이유: GameCamera 는 경계 제한(limit_*)이 없고 맵 크기를 읽지도
# 않는다. zoom 0.85 에서 보이는 세계가 1506x847 이라, 맵이 그보다 작으면 어디를 봐도
# 맵 바깥이 드러난다(#396 이 초원에서 없앤 문제).
#
# 참고: stage/beach/BeachMap.gd, stage/grassland/GrasslandMap.gd, stage/StageMaps.gd

const TILE_SIZE := 24
const MAP_SIZE := Vector2i(96, 64)
const SOURCE_ID := 0

# 허공. 아래로 갈수록 짙다 -- 깊이를 주지 않으면 하늘이 색종이처럼 평평하다.
# 단계를 여섯으로 나눈 이유: 셋이면 단계 폭이 넓어 경계를 디더해도 띠가 보인다.
const VOID_HIGH := Color("6E86A8")
const VOID_DEEP := Color("3E4C63")
const VOID_BANDS := 8

# 섬 바위. 젖은 바위(해변)보다 따뜻하고 마른 돌이다.
# 해변 모래(D9C79B)와 구별되어야 한다 -- 처음 색은 모래빛이라 섬이 모래섬처럼 보였다.
const ROCK_LIGHT := Color("9A9689")
const ROCK_MAIN := Color("7C7A70")
const ROCK_SHADOW := Color("565A55")

# 섬 밑동. 섬이 떠 있다는 것은 **테두리 아래의 짙은 단면**으로 읽힌다.
const ROCK_UNDER := Color("463F36")

# 섬 위 식생. 초원 풀보다 어둡고 채도가 낮다 -- 높은 데서 바람 맞는 풀이다.
const MOSS_LIGHT := Color("7E9161")
const MOSS_MAIN := Color("64764B")
const MOSS_SHADOW := Color("47563A")

@onready var ground: TileMapLayer = $Ground
@onready var overlay: TileMapLayer = $Overlay
@onready var detail: TileMapLayer = $Detail
@onready var decals: Node2D = $Decal
@onready var objects: Node2D = $Objects

# 섬이 덮은 칸.
var _island_cells: Dictionary = {}


func _ready() -> void:
	_mark_islands()
	_build_void()
	_build_islands()
	_build_details()
	_build_void_collision()
	_build_boundaries()


# ===== 섬의 자리 =====
#
# 본섬은 **전투 구역을 덮어야 한다.** 파티는 맵 로컬 (340, 340~420), 적은
# (840, 470)~(920, 560) 에 놓인다(Stage.spawn_party / StageData.spawns 기준,
# 맵이 스테이지 안에서 (-240,-240) 에 놓이므로 세계 좌표에 240 을 더한 값이다).
# 본섬이 그 자리를 덮지 않으면 전투가 허공에서 시작된다.
func _mark_islands() -> void:
	# 본섬. 셀 (2..46, 7..33) -> 로컬 (48..1128, 168..816). 위 스폰 자리를 모두 덮는다.
	_mark_island(Vector2i(24, 20), Vector2(22.0, 13.0))

	# 주변 섬들. 크기와 거리를 달리 둔다 -- 같은 크기로 늘어놓으면 발판처럼 보인다.
	_mark_island(Vector2i(72, 22), Vector2(13.0, 9.0))
	_mark_island(Vector2i(52, 7), Vector2(9.0, 5.0))
	_mark_island(Vector2i(38, 48), Vector2(11.0, 7.0))
	_mark_island(Vector2i(80, 47), Vector2(9.0, 6.0))
	_mark_island(Vector2i(60, 38), Vector2(5.0, 3.0))
	_mark_island(Vector2i(12, 45), Vector2(6.0, 4.0))
	_mark_island(Vector2i(88, 10), Vector2(5.0, 4.0))


# 타원 섬 하나. 둘레를 일그러뜨려 완전한 타원이 되지 않게 한다 --
# 반듯한 타원은 섬이 아니라 접시처럼 보인다.
func _mark_island(center: Vector2i, radius: Vector2) -> void:
	var reach := Vector2i(int(ceil(radius.x)) + 2, int(ceil(radius.y)) + 2)
	for y in range(center.y - reach.y, center.y + reach.y + 1):
		for x in range(center.x - reach.x, center.x + reach.x + 1):
			var cell := Vector2i(x, y)
			if not _inside(cell):
				continue
			# 방향에 따라 반지름을 흔든다. 셀별 hash 로 흔들면 테두리가 톱날이 된다.
			var angle := atan2(float(y - center.y), float(x - center.x))
			var wobble := 1.0 \
				+ sin(angle * 3.0 + float(center.x)) * 0.09 \
				+ sin(angle * 5.0 + float(center.y)) * 0.06
			var distance := Vector2(
				float(x - center.x) / (radius.x * wobble),
				float(y - center.y) / (radius.y * wobble)).length()
			if distance <= 1.0:
				_island_cells[cell] = true


# ===== 허공 =====
#
# 섬이 아닌 칸도 반드시 채운다(위 파일 주석 참고).
func _build_void() -> void:
	# 위에서 아래로 짙어지는 단계들. 구름은 여기서 그리지 않는다 --
	# 타일로 깔았더니 타일마다 같은 타원이 반복되어 흰 벽돌 부스러기처럼 보였다.
	# 구름은 SkyClouds(Decal 위 별도 노드)가 맵 전체를 한 캔버스로 두고 그린다.
	var tiles: Array[Image] = []
	for band in VOID_BANDS:
		tiles.append(_make_void_tile(band))

	ground.tile_set = _make_tile_set(tiles)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	for y in MAP_SIZE.y:
		# 높이를 단계 사이의 **실수 위치**로 둔다. 그 소수부를 셀별 임계값과 비교해
		# 아래/위 단계를 섞는다(비율 디더링).
		#
		# 단계를 그냥 잘라 쓰면 단계가 바뀌는 높이에 **맵 폭을 가로지르는 직선**이 생긴다.
		# 경계에 ±몇 칸 지터만 주면 그 직선이 각진 노이즈 띠로 바뀔 뿐이다 --
		# 둘 다 미리보기에서 드러났다. 비율 디더링은 모든 행이 두 단계의 섞임이라
		# 경계가 아예 없다.
		var t := float(y) / float(MAP_SIZE.y) * float(VOID_BANDS - 1)
		var low := int(floor(t))
		var frac := t - float(low)
		for x in MAP_SIZE.x:
			var threshold := float(_hash_cell(x, y, 57) % 128) / 128.0
			var band := clampi(low + (1 if frac > threshold else 0), 0, VOID_BANDS - 1)
			ground.set_cell(Vector2i(x, y), SOURCE_ID, Vector2i(band, 0))


# ===== 섬 =====
#
# 해변의 물과 같은 4방향 마스크다. 마스크가 없으면 섬 테두리가 24px 계단이 된다
# (해변에서 실제로 겪었다 -- 젖은 모래에 마스크가 없어 계단으로 보였다).
func _build_islands() -> void:
	var tiles: Array[Image] = []
	for mask in 16:
		tiles.append(_make_island_tile(mask))
	overlay.tile_set = _make_tile_set(tiles)
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	for cell in _island_cells:
		if not _inside(cell):
			continue
		# 맵 밖은 **섬이 아니다**(허공과 반대 규약). 섬이 맵 끝에 닿으면 거기서
		# 잘린 게 아니라 테두리가 그려져야 한다 -- 섬은 유한한 물체다.
		var mask := 0
		if _island_cells.has(cell + Vector2i.UP): mask |= 1
		if _island_cells.has(cell + Vector2i.RIGHT): mask |= 2
		if _island_cells.has(cell + Vector2i.DOWN): mask |= 4
		if _island_cells.has(cell + Vector2i.LEFT): mask |= 8
		overlay.set_cell(cell, SOURCE_ID, Vector2i(mask, 0))


# ===== 디테일 =====
#
# 섬 위에만 놓는다. 허공에 자갈·풀이 뜨면 그게 발판인지 장식인지 알 수 없다.
func _build_details() -> void:
	var tiles: Array[Image] = []
	for kind in 5:
		tiles.append(_make_detail_tile(kind))
	detail.tile_set = _make_tile_set(tiles)
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	for cell in _island_cells:
		if not _inside(cell):
			continue
		# 테두리 칸은 비운다. 섬 끝에 풀이 걸치면 테두리 단면이 지워져
		# 떠 있는 느낌이 사라진다.
		if not (_island_cells.has(cell + Vector2i.UP)
				and _island_cells.has(cell + Vector2i.DOWN)
				and _island_cells.has(cell + Vector2i.LEFT)
				and _island_cells.has(cell + Vector2i.RIGHT)):
			continue
		var value := _hash_cell(cell.x, cell.y, 73)
		if value % 7 == 0:
			detail.set_cell(cell, SOURCE_ID, Vector2i(value % 5, 0))


# ===== 허공 충돌 (#429) =====
#
# 섬 밖으로 나가지 못하게 허공 칸을 막는다.
#
# **왜 섬 둘레 한 칸만 막지 않는가**: 벽 두께가 24px 이면 한 프레임에 그보다 많이
# 움직이는 이동이 뚫고 지나갈 수 있다(터널링). 지금 이 맵에 그런 이동이 있는지는
# 확실하지 않다 -- 여왕 후퇴가 700px/s(60fps 에서 12px/프레임)라 여유가 있지만,
# 나중에 붙는 적이 어떤 속도를 가질지는 알 수 없다.
#
# 허공을 전부 채우면 그 걱정이 아예 없어지고, **가로 병합 후에는 둘레만 막는 것보다
# 비싸지도 않다**(둘레도 병합하면 비슷한 수의 사각형이 된다). 그래서 안전한 쪽을 골랐다.
#
# **왜 칸마다 몸을 만들지 않는가**: 허공이 4천 칸이 넘는다. 가로로 이어진 칸을 사각형
# 하나로 합치면 형상 수가 수백 개로 줄고, 물리 몸은 하나면 된다.
#
# 세로로도 합치면(2D 직사각형 분할) 더 줄지만, 가로 병합만으로 이미 충분히 적고
# 코드가 훨씬 단순하다. 실제 형상 수는 검증에서 실측한다.
func _build_void_collision() -> void:
	var body := StaticBody2D.new()
	body.name = "VoidBlock"
	add_child(body)

	for y in MAP_SIZE.y:
		var run_start := -1
		# x == MAP_SIZE.x 까지 도는 이유: 마지막 칸에서 끝나는 구간을 닫아야 한다.
		for x in range(MAP_SIZE.x + 1):
			var is_void := x < MAP_SIZE.x and not _island_cells.has(Vector2i(x, y))
			if is_void:
				if run_start < 0:
					run_start = x
				continue
			if run_start >= 0:
				_add_void_run(body, run_start, x - 1, y)
				run_start = -1


# 한 행의 [from_x, to_x] 구간을 사각형 하나로 막는다.
func _add_void_run(body: StaticBody2D, from_x: int, to_x: int, y: int) -> void:
	var cells := to_x - from_x + 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(float(cells * TILE_SIZE), float(TILE_SIZE))
	collision.shape = shape
	collision.position = Vector2(
		float(from_x * TILE_SIZE) + shape.size.x * 0.5,
		float(y * TILE_SIZE) + float(TILE_SIZE) * 0.5)
	body.add_child(collision)


# ===== 경계 =====

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


# band 는 타일 **전체**의 높이 단계다. 타일 안에서 위아래로 칠하면 24px 마다
# 같은 그라데이션이 반복되어 가로 줄무늬가 생긴다(해변의 물에서 실제로 겪었다).
func _make_void_tile(band: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	var t := float(band) / float(maxi(VOID_BANDS - 1, 1))
	var base := VOID_HIGH.lerp(VOID_DEEP, t)
	image.fill(base)

	# 아주 잔 얼룩만. 하늘은 결이 없어야 멀리 있어 보인다.
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var value := _hash_cell(x + band * 13, y, 31)
			if value % 37 == 0:
				image.set_pixel(x, y, base.lightened(0.06))
			elif value % 41 == 0:
				image.set_pixel(x, y, base.darkened(0.05))
	return image


# 마스크는 이웃한 섬의 방향이다(1 위, 2 오른쪽, 4 아래, 8 왼쪽).
# 이웃이 섬이 아닌 쪽은 안쪽으로 물러나고, 그 자리에 **밑동 단면**을 둔다 --
# 섬이 떠 있다는 것은 테두리 아래의 짙은 띠로 읽힌다.
func _make_island_tile(mask: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)

	for y in TILE_SIZE:
		for x in TILE_SIZE:
			# ±2px. ±3 으로 두면 테두리가 털처럼 성겨 보였다(미리보기에서 드러났다).
			var wave_x := (_hash_cell(y, mask, 29) % 5) - 2
			var wave_y := (_hash_cell(x, mask, 37) % 5) - 2
			var left := 0 if (mask & 8) != 0 else 3 + wave_x
			var right := TILE_SIZE if (mask & 2) != 0 else TILE_SIZE - 3 + wave_x
			var top := 0 if (mask & 1) != 0 else 3 + wave_y
			var bottom := TILE_SIZE if (mask & 4) != 0 else TILE_SIZE - 3 + wave_y
			if x < left or x >= right or y < top or y >= bottom:
				continue

			# 아래쪽 테두리는 밑동이다. 위쪽 테두리는 바위 하이라이트가 된다.
			var near_bottom := (mask & 4) == 0 and y >= bottom - 4
			var near_top := (mask & 1) == 0 and y < top + 2
			var near_side := ((mask & 8) == 0 and x < left + 2) \
				or ((mask & 2) == 0 and x >= right - 2)

			var color := ROCK_MAIN
			if near_bottom:
				color = ROCK_UNDER
			elif near_top:
				color = ROCK_LIGHT
			elif near_side:
				color = ROCK_SHADOW

			var value := _hash_cell(x, y, mask + 41)
			if value % 19 == 0:
				color = color.lightened(0.10)
			elif value % 23 == 0:
				color = color.darkened(0.10)
			image.set_pixel(x, y, color)
	return image


func _make_detail_tile(kind: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	match kind:
		0, 1:
			# 이끼 무리. 섬 위가 완전히 맨 바위면 죽은 돌처럼 보인다.
			for y in range(9, 18):
				for x in range(5, 20):
					if _hash_cell(x + kind * 7, y, 3) % 4 == 0:
						image.set_pixel(x, y, MOSS_MAIN)
					elif _hash_cell(x, y + kind, 9) % 13 == 0:
						image.set_pixel(x, y, MOSS_LIGHT)
		2:
			# 바람에 눕는 풀 몇 촉. 전부 한쪽으로 기운다 -- 높은 데라 바람이 있다.
			for i in 3:
				var x := 8 + i * 4
				for height in range(1, 6 + i):
					image.set_pixel(x + height / 2, 18 - height, MOSS_SHADOW)
				image.set_pixel(x + 2, 13 - i, MOSS_LIGHT)
		3:
			# 잔 돌.
			for i in 3:
				var x := 6 + ((_hash_cell(kind, i, 11) + i * 6) % 13)
				var y := 11 + ((_hash_cell(i, kind, 5) + i * 4) % 7)
				image.set_pixel(x, y, ROCK_SHADOW)
				image.set_pixel(x + 1, y, ROCK_SHADOW)
				image.set_pixel(x, y - 1, ROCK_LIGHT)
		4:
			# 바위 갈라진 자리.
			var y0 := 10
			for i in 9:
				var x := 7 + i
				image.set_pixel(x, y0 + (i % 3), ROCK_SHADOW)
	return image


# ===== 공용 =====

func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y


func _hash_cell(x: int, y: int, salt: int) -> int:
	var value := x * 374761393 + y * 668265263 + salt * 69069
	value = (value ^ (value >> 13)) * 1274126177
	return absi(value ^ (value >> 16))
