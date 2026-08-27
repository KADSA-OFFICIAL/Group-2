extends Node

# 하늘 맵의 구조·충돌 규약 검증 (#423).
# tests/beach/VerifyBeachMap.gd 와 같은 관례를 따른다.

const SKY_MAP := preload("res://stage/sky/SkyIslandMap.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	var map := SKY_MAP.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(map.get_node("Ground") is TileMapLayer, "Ground must be a TileMapLayer")
	_expect(map.get_node("Overlay") is TileMapLayer, "Overlay must be a TileMapLayer")
	_expect(map.get_node("Detail") is TileMapLayer, "Detail must be a TileMapLayer")
	_expect(map.get_node("Ground").tile_set.tile_size == Vector2i(24, 24),
		"world tile size must be 24x24")

	# 크기의 출처는 SkyIslandMap.MAP_SIZE 다. 여기에 숫자를 다시 적으면 맵을 넓힐 때
	# 이 파일이 거짓이 되고, 실패 메시지가 크기 변경을 회귀로 보고한다.
	var expected_cells: int = SkyIslandMap.MAP_SIZE.x * SkyIslandMap.MAP_SIZE.y

	# **빈 셀이 0 이어야 한다**(#423). 섬이 아닌 칸을 비워 두면 맵 바깥의 빈 공간과
	# 화면에서 구별되지 않아 버그인지 연출인지 알 수 없게 된다.
	_expect(map.get_node("Ground").get_used_cells().size() == expected_cells,
		"ground must fill the %dx%d map with no empty cells"
			% [SkyIslandMap.MAP_SIZE.x, SkyIslandMap.MAP_SIZE.y])

	# 초원과 같은 크기여야 한다 — GameCamera 에 경계 제한이 없어서, 더 작으면
	# 어디를 봐도 맵 바깥이 드러난다(#396 이 초원에서 없앤 문제).
	_expect(SkyIslandMap.MAP_SIZE == GrasslandMap.MAP_SIZE,
		"sky map must match the grassland map size (camera has no limits)")

	_expect(map.get_node("Overlay").get_used_cells().size() > 0, "islands must exist")
	_expect(map.get_node("Detail").get_used_cells().size() > 0, "island details must exist")
	_expect(map.get_node("Objects").y_sort_enabled, "object layer must use Y-sort")

	# 섬이 맵을 다 덮지도, 없지도 않아야 한다 — "구름 사이에 뜬 섬"이다.
	# 다 덮으면 그냥 육지이고, 너무 적으면 싸울 자리가 없다.
	var island_cells: int = map.get_node("Overlay").get_used_cells().size()
	var island_ratio := float(island_cells) / float(expected_cells)
	_expect(island_ratio > 0.2 and island_ratio < 0.7,
		"islands must cover 20-70%% of the map (got %.1f%%)" % (island_ratio * 100.0))

	var spire := _find_object(map, SkyObject.Kind.SPIRE)
	var arch := _find_object(map, SkyObject.Kind.ARCH)
	var crystal := _find_object(map, SkyObject.Kind.CRYSTAL)
	var grass := _find_object(map, SkyObject.Kind.WIND_GRASS)
	_expect(spire != null, "rock spire must exist")
	_expect(arch != null, "stone arch must exist")
	_expect(crystal != null, "sky crystal must exist")
	_expect(grass != null, "wind grass must exist")

	if spire:
		_expect(_footprint_size(spire) == Vector2(56, 28), "spire collision must be 56x28")
	if arch:
		# 아치는 **다리 둘**을 따로 막는다 — 가운데는 지나갈 수 있어야 한다.
		var arch_shapes := _footprint_shapes(arch)
		_expect(arch_shapes.size() == 2,
			"arch must block its two legs separately (got %d shapes)" % arch_shapes.size())
		if arch_shapes.size() == 2:
			var leg_a := (arch_shapes[0].shape as RectangleShape2D).size
			var leg_b := (arch_shapes[1].shape as RectangleShape2D).size
			_expect(leg_a == Vector2(20, 24) and leg_b == Vector2(20, 24),
				"each arch leg must be 20x24")
			var span := absf(arch_shapes[1].position.x - arch_shapes[0].position.x)
			var gap := span - leg_a.x
			_expect(gap > 48.0, "arch opening must be walkable (got %.0fpx)" % gap)
	if crystal:
		_expect(_footprint_size(crystal) == Vector2(44, 22),
			"crystal collision must be 44x22")
	if grass:
		# 바람풀은 장식이다. 해변의 조개와 같은 규약으로 Decal 에 있고 길을 막지 않는다.
		_expect(grass.get_parent().name == "Decal", "wind grass must be in the decal layer")
		_expect(not grass.has_node("Footprint"), "wind grass must not block movement")

	# 프롭은 외부 PackedScene 인스턴스로 남아야 한다 — SkyIslandMap.tscn 에서 직접
	# 고르고 옮기고 지울 수 있어야 저작이 된다.
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is SkyObject:
				_expect(
					child.scene_file_path.begins_with("res://stage/sky/objects/"),
					"%s must be an independently instanced object scene" % child.name,
				)

	# **프롭은 섬 위에 있어야 한다.** 하늘 맵에만 있는 함정이다 — 초원·해변에서는
	# 어디에 놓아도 땅이지만 여기는 대부분이 허공이라, 좌표를 손으로 적다가 한 칸만
	# 빗나가도 바위탑이 허공에 뜬다. 그림으로는 알아채기 어렵고(허공도 하늘색이라
	# 그림자가 안 보인다) 저작할 때마다 반복되는 실수라 검사로 잡는다.
	var island_set := _island_cells(map)
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is SkyObject:
				var cell := Vector2i(
					int(floor(child.position.x / float(SkyIslandMap.TILE_SIZE))),
					int(floor(child.position.y / float(SkyIslandMap.TILE_SIZE))))
				_expect(island_set.has(cell),
					"%s stands in the void at %s (cell %s)"
						% [child.name, child.position, cell])

	# 파티(맵 로컬 340,340~420)와 적(840,470~920,560)이 놓이는 자리에 막는 프롭이 없어야
	# 한다. 스폰 지점이 막히면 유닛이 프롭 안에 끼어 첫 프레임부터 밀려난다.
	var combat_zone := Rect2(Vector2(280, 300), Vector2(700, 300))
	for child in map.get_node("Objects").get_children():
		if child is SkyObject and child.has_node("Footprint"):
			_expect(not combat_zone.has_point(child.position),
				"%s blocks the spawn area at %s" % [child.name, child.position])

	# 전투 구역이 통째로 섬 위여야 한다. 하늘 맵에서 가장 눈에 띄는 사고가
	# "허공에서 싸우는 것"인데, 셀 수·비율 검사로는 안 걸린다.
	var step := SkyIslandMap.TILE_SIZE
	var y := int(combat_zone.position.y)
	while y < int(combat_zone.end.y):
		var x := int(combat_zone.position.x)
		while x < int(combat_zone.end.x):
			var cell := Vector2i(x / step, y / step)
			_expect(island_set.has(cell),
				"combat zone cell %s is void — the fight would happen in mid-air" % cell)
			x += step
		y += step

	# StageMaps 에 실제로 등록됐는가. 맵만 만들고 등록을 잊으면 3챕터가 조용히
	# 초원으로 물러난다(경고는 콘솔에만 남는다).
	_expect(StageMaps.has_map_for_concept(StageData.Concept.SKY),
		"SKY concept must have a registered map")
	_expect(StageMaps.scene_path_for_concept(StageData.Concept.SKY)
			== "res://stage/sky/SkyIslandMap.tscn",
		"SKY must resolve to SkyIslandMap.tscn")

	if _failures.is_empty():
		print("PASS: sky island map structure and collision contract")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


# 섬(밟는 자리) 칸 집합. Overlay 에는 섬 윗면과 그 아래 절벽이 함께 들어 있으므로
# 맵이 쥔 목록을 그대로 쓰지 않고 **윗면 타일만** 고른다 — 절벽은 밟는 자리가 아니다.
func _island_cells(map: Node) -> Dictionary:
	var cells := {}
	var overlay: TileMapLayer = map.get_node("Overlay")
	for cell in overlay.get_used_cells():
		# 윗면은 아틀라스 0~15(마스크), 절벽은 16 이상이다.
		if overlay.get_cell_atlas_coords(cell).x < 16:
			cells[cell] = true
	return cells


func _find_object(map: Node, object_kind: int) -> SkyObject:
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is SkyObject and child.kind == object_kind:
				return child
	return null


# 프롭의 충돌 도형들. 아치는 둘이고 나머지는 하나다.
func _footprint_shapes(object: SkyObject) -> Array[CollisionShape2D]:
	var shapes: Array[CollisionShape2D] = []
	var body := object.get_node_or_null("Footprint")
	if body == null:
		return shapes
	for child in body.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			shapes.append(child)
	shapes.sort_custom(func(a, b): return a.position.x < b.position.x)
	return shapes


func _footprint_size(object: SkyObject) -> Vector2:
	var body := object.get_node_or_null("Footprint")
	if body == null:
		return Vector2.ZERO
	for child in body.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			return (child.shape as RectangleShape2D).size
	return Vector2.ZERO


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
