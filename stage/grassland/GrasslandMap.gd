extends Node2D
class_name GrasslandMap

# v3 초원 맵 스펙을 실제 24px TileMapLayer와 Y-sort 오브젝트로 구성한다(#352).

const TILE_SIZE := 24
# 96x64 x 24px = 2304x1536 (#396). 64x40(1536x960) 이었을 때는 카메라를 zoom 0.8 로
# 물리면 보이는 폭 1600 이 맵 폭 1536 을 넘어 어디를 봐도 맵 바깥이 드러났다.
#
# 타일은 원점에서 +방향으로 생성되므로 **동쪽·남쪽으로만** 넓어진다 —
# 기존 프롭(움막·울타리)과 길의 세계 좌표는 그대로다.
const MAP_SIZE := Vector2i(96, 64)
const SOURCE_ID := 0
const GRASS_BASE := Color("75885A")
const GRASS_LIGHT := Color("899867")
const GRASS_SHADOW := Color("5D704A")
const DIRT_LIGHT := Color("C0AE86")
const DIRT_MAIN := Color("9C8B68")
const DIRT_SHADOW := Color("74674C")

@onready var ground: TileMapLayer = $Ground
@onready var overlay: TileMapLayer = $Overlay
@onready var detail: TileMapLayer = $Detail
@onready var decals: Node2D = $Decal
@onready var objects: Node2D = $Objects

var _path_cells: Dictionary = {}


func _ready() -> void:
	_build_ground()
	_build_path()
	_build_details()
	_build_boundaries()


func _build_ground() -> void:
	var tiles: Array[Image] = []
	for variant in 4:
		tiles.append(_make_grass_tile(variant))
	ground.tile_set = _make_tile_set(tiles)
	ground.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var variant := _hash_cell(x, y, 19) % 4
			ground.set_cell(Vector2i(x, y), SOURCE_ID, Vector2i(variant, 0))


func _build_path() -> void:
	for x in MAP_SIZE.x:
		var center_y := 14 + int(round(sin(float(x) * 0.18) * 2.0 + float(x) * 0.11))
		for offset_y in range(-2, 3):
			_path_cells[Vector2i(x, center_y + offset_y)] = true
	# 움막 쪽으로 갈라지는 짧은 지선.
	for y in range(8, 17):
		for x in range(22, 27):
			_path_cells[Vector2i(x, y)] = true

	var path_tiles: Array[Image] = []
	for mask in 16:
		path_tiles.append(_make_dirt_tile(mask))
	overlay.tile_set = _make_tile_set(path_tiles)
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for cell in _path_cells:
		if not _inside(cell):
			continue
		var mask := 0
		if _path_cells.has(cell + Vector2i.UP): mask |= 1
		if _path_cells.has(cell + Vector2i.RIGHT): mask |= 2
		if _path_cells.has(cell + Vector2i.DOWN): mask |= 4
		if _path_cells.has(cell + Vector2i.LEFT): mask |= 8
		overlay.set_cell(cell, SOURCE_ID, Vector2i(mask, 0))


func _build_details() -> void:
	var tiles: Array[Image] = []
	for kind in 6:
		tiles.append(_make_detail_tile(kind))
	detail.tile_set = _make_tile_set(tiles)
	detail.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for y in MAP_SIZE.y:
		for x in MAP_SIZE.x:
			var cell := Vector2i(x, y)
			if _path_cells.has(cell):
				continue
			var value := _hash_cell(x, y, 73)
			if value % 23 == 0:
				detail.set_cell(cell, SOURCE_ID, Vector2i(value % 6, 0))


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


func _make_tile_set(tiles: Array[Image]) -> TileSet:
	var atlas := Image.create(TILE_SIZE * tiles.size(), TILE_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color.TRANSPARENT)
	for i in tiles.size():
		atlas.blit_rect(tiles[i], Rect2i(Vector2i.ZERO, Vector2i(TILE_SIZE, TILE_SIZE)), Vector2i(i * TILE_SIZE, 0))
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


func _make_grass_tile(variant: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(GRASS_BASE)
	for y in TILE_SIZE:
		for x in TILE_SIZE:
			var value := _hash_cell(x + variant * 11, y, 31)
			if value % 47 == 0:
				image.set_pixel(x, y, GRASS_LIGHT)
			elif value % 53 == 0:
				image.set_pixel(x, y, GRASS_SHADOW)
	for i in 3:
		var x := 4 + ((_hash_cell(variant, i, 7) + i * 7) % 16)
		var y := 5 + ((_hash_cell(i, variant, 13) + i * 5) % 14)
		image.set_pixel(x, y, GRASS_SHADOW)
		if y > 0: image.set_pixel(x, y - 1, GRASS_LIGHT)
	return image


func _make_dirt_tile(mask: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
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
			var color := DIRT_MAIN
			var value := _hash_cell(x, y, mask + 41)
			if value % 41 == 0: color = DIRT_LIGHT
			elif value % 37 == 0: color = DIRT_SHADOW
			image.set_pixel(x, y, color)
	return image


func _make_detail_tile(kind: int) -> Image:
	var image := Image.create(TILE_SIZE, TILE_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	match kind:
		0, 1:
			for x in [7, 11, 15]:
				for height in range(1, 7 + kind * 2):
					image.set_pixel(x + (height % 2), 21 - height, GRASS_SHADOW)
			image.set_pixel(11, 13, GRASS_LIGHT)
		2:
			for point in [Vector2i(9, 17), Vector2i(13, 14), Vector2i(16, 18)]:
				image.set_pixelv(point, Color("A8C07A"))
				image.set_pixelv(point + Vector2i.UP, Color("DCCDAF"))
		3:
			for y in range(16, 21):
				for x in range(6, 18):
					if _hash_cell(x, y, 5) % 3 != 0: image.set_pixel(x, y, Color("767676"))
		4:
			for x in range(5, 20, 3):
				draw_image_line(image, Vector2i(12, 21), Vector2i(x, 10), Color("857A4E"))
		5:
			for y in range(6, 19):
				for x in range(5, 20):
					if _hash_cell(x, y, 91) % 9 == 0: image.set_pixel(x, y, Color(0.35, 0.42, 0.28, 0.28))
	return image


func draw_image_line(image: Image, from: Vector2i, to: Vector2i, color: Color) -> void:
	var delta := to - from
	var steps := maxi(abs(delta.x), abs(delta.y))
	for i in steps + 1:
		var t := float(i) / float(maxi(steps, 1))
		var point := Vector2i(round(Vector2(from).lerp(Vector2(to), t)))
		if point.x >= 0 and point.y >= 0 and point.x < TILE_SIZE and point.y < TILE_SIZE:
			image.set_pixelv(point, color)


func _inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE.x and cell.y < MAP_SIZE.y


func _hash_cell(x: int, y: int, salt: int) -> int:
	var value := x * 374761393 + y * 668265263 + salt * 69069
	value = (value ^ (value >> 13)) * 1274126177
	return absi(value ^ (value >> 16))
