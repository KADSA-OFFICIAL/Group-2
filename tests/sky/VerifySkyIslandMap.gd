extends Node

# 하늘 맵(떠 있는 섬)의 구조·충돌 규약 검증 (#423).
# tests/beach/VerifyBeachMap.gd 와 같은 관례를 따른다.

const SKY_MAP := preload("res://stage/sky/SkyIslandMap.tscn")

# 유닛이 놓이는 자리(맵 로컬 좌표). Stage.spawn_party 는 세계 (100, 100+i*40),
# stage_1_1.tres 의 적은 (600~680, 230~320) 이고, 맵이 스테이지 안에서 (-240,-240)
# 에 놓이므로 맵 로컬은 각각 +240 이다.
#
# 이 자리들이 섬으로 덮여 있지 않으면 **전투가 허공에서 시작된다.** 하늘 맵에만
# 있는 위험이라 여기서 검사한다(초원·해변은 바닥이 맵 전체다).
const SPAWN_POINTS := [
	Vector2(340, 340), Vector2(340, 380), Vector2(340, 420),  # 파티 3인
	Vector2(840, 470), Vector2(840, 560), Vector2(920, 560),  # 적
]

var _failures: Array[String] = []


func _ready() -> void:
	var map := SKY_MAP.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	var ground: TileMapLayer = map.get_node("Ground")
	var islands: TileMapLayer = map.get_node("Overlay")

	_expect(ground is TileMapLayer, "Ground must be a TileMapLayer")
	_expect(islands is TileMapLayer, "Overlay must be a TileMapLayer")
	_expect(map.get_node("Detail") is TileMapLayer, "Detail must be a TileMapLayer")
	_expect(ground.tile_set.tile_size == Vector2i(24, 24), "world tile size must be 24x24")

	# 허공도 반드시 채운다. 채우지 않으면 섬 사이 허공과 맵 바깥이 구별되지 않는다.
	var expected_cells: int = SkyIslandMap.MAP_SIZE.x * SkyIslandMap.MAP_SIZE.y
	_expect(ground.get_used_cells().size() == expected_cells,
		"void must fill the whole %dx%d map (no empty cells)"
			% [SkyIslandMap.MAP_SIZE.x, SkyIslandMap.MAP_SIZE.y])

	# 초원·해변과 같은 크기여야 한다 — GameCamera 에 경계 제한이 없어서, 더 작으면
	# 어디를 봐도 맵 바깥이 드러난다(#396 이 초원에서 없앤 문제).
	_expect(SkyIslandMap.MAP_SIZE == GrasslandMap.MAP_SIZE,
		"sky map must match the grassland map size (camera has no limits)")

	# 섬이 맵을 다 덮지도, 없지도 않아야 한다. 다 덮으면 "떠 있는 섬"이 아니라 그냥 땅이고,
	# 너무 적으면 싸울 자리가 없다.
	var island_cells: int = islands.get_used_cells().size()
	var island_ratio := float(island_cells) / float(expected_cells)
	_expect(island_ratio > 0.15 and island_ratio < 0.6,
		"islands must cover 15-60%% of the map (got %.1f%%)" % (island_ratio * 100.0))
	_expect(map.get_node("Detail").get_used_cells().size() > 0, "island details must exist")
	_expect(map.get_node("Objects").y_sort_enabled, "object layer must use Y-sort")

	# 구름은 타일이 아니라 별도 노드가 맵 전체를 한 캔버스로 두고 그린다.
	# 섬보다 아래에 있어야 발밑이 흐려지지 않는다.
	var clouds := map.get_node_or_null("Clouds")
	_expect(clouds is SkyClouds, "Clouds node must exist and use SkyClouds")
	if clouds != null:
		_expect(clouds.z_index > ground.z_index and clouds.z_index < islands.z_index,
			"clouds must draw above the void but below the islands")

	# **전투가 허공에서 시작되지 않아야 한다.** 스폰 자리가 모두 섬 위여야 한다.
	for point in SPAWN_POINTS:
		var cell := Vector2i(int(point.x) / 24, int(point.y) / 24)
		_expect(islands.get_cell_source_id(cell) != -1,
			"spawn point %s (cell %s) must be on an island, not in the void" % [point, cell])

	var stone := _find_object(map, SkyObject.Kind.STANDING_STONE)
	var tree := _find_object(map, SkyObject.Kind.WIND_TREE)
	var boulder := _find_object(map, SkyObject.Kind.BOULDER)
	var tuft := _find_object(map, SkyObject.Kind.GRASS_TUFT)
	_expect(stone != null, "standing stone must exist")
	_expect(tree != null, "wind-bent tree must exist")
	_expect(boulder != null, "boulder must exist")
	_expect(tuft != null, "grass tuft must exist")

	if stone:
		_expect(_footprint_size(stone) == Vector2(48, 24),
			"standing stone collision must be 48x24")
	if tree:
		_expect(_footprint_size(tree) == Vector2(48, 32), "wind tree collision must be 48x32")
	if boulder:
		_expect(_footprint_size(boulder) == Vector2(96, 32), "boulder collision must be 96x32")
	if tuft:
		# 장식이다. 해변의 조개, 초원의 넘어진 울타리와 같은 규약.
		_expect(tuft.get_parent().name == "Decal", "grass tufts must be in the decal layer")
		_expect(not tuft.has_node("Footprint"), "grass tufts must not block movement")

	# 프롭은 외부 PackedScene 인스턴스로 남아야 한다 — 씬에서 직접 고르고 옮길 수 있어야 한다.
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is SkyObject:
				_expect(
					child.scene_file_path.begins_with("res://stage/sky/objects/"),
					"%s must be an independently instanced object scene" % child.name,
				)

	# 막는 프롭이 스폰 영역에 있으면 유닛이 프롭 안에 끼어 첫 프레임부터 밀려난다.
	var combat_zone := Rect2(Vector2(280, 300), Vector2(700, 300))
	for child in map.get_node("Objects").get_children():
		if child is SkyObject and child.has_node("Footprint"):
			_expect(not combat_zone.has_point(child.position),
				"%s blocks the spawn area at %s" % [child.name, child.position])

	# 프롭은 섬 위에 있어야 한다. 허공에 떠 있으면 발판인지 장식인지 알 수 없다.
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is SkyObject:
				var cell := Vector2i(int(child.position.x) / 24, int(child.position.y) / 24)
				_expect(islands.get_cell_source_id(cell) != -1,
					"%s at %s floats in the void" % [child.name, child.position])

	# ===== 허공 충돌 (#429) =====
	#
	# 섬 밖으로 나가지 못해야 한다. 물리 질의로 확인한다 -- 이동을 흉내내면
	# 프레임 수·속도에 결과가 달라져 무엇을 검증했는지 알 수 없다.
	var block := map.get_node_or_null("VoidBlock")
	_expect(block is StaticBody2D, "VoidBlock static body must exist")
	if block != null:
		var void_cells := 0
		for y in SkyIslandMap.MAP_SIZE.y:
			for x in SkyIslandMap.MAP_SIZE.x:
				if islands.get_cell_source_id(Vector2i(x, y)) == -1:
					void_cells += 1
		var shapes := block.get_child_count()
		print("  허공 칸 %d개 -> 충돌 형상 %d개" % [void_cells, shapes])
		# 칸마다 하나씩이면 병합이 안 된 것이다. 여유를 크게 둔다 -- 정확한 수는
		# 섬 배치에 따라 달라지고, 여기서 검증할 것은 "합쳐졌다"는 사실뿐이다.
		_expect(shapes > 0 and shapes < void_cells / 4,
			"void collision must merge horizontal runs (%d shapes for %d cells)"
				% [shapes, void_cells])

	# 허공은 막히고, 섬 안쪽과 스폰 자리는 막히지 않아야 한다.
	# 스폰 자리가 막히면 유닛이 첫 프레임부터 충돌 안에 끼어 밀려난다 -- 가장 위험한 실패다.
	for point in SPAWN_POINTS:
		_expect(not _is_blocked(map, point),
			"spawn point %s must not be blocked by void collision" % point)

	var island_interior := _find_island_interior(islands)
	if island_interior != Vector2.INF:
		_expect(not _is_blocked(map, island_interior),
			"island interior %s must not be blocked" % island_interior)

	var open_void := _find_open_void(islands)
	if open_void != Vector2.INF:
		_expect(_is_blocked(map, open_void),
			"open void %s must be blocked" % open_void)

	# 맵 네 변의 경계가 **이름으로** 찾힌다 (#446).
	#
	# 예전에는 "VoidBlock 이 아닌 StaticBody2D 자식"으로 셌다 — 넷 다 "MapBoundary" 로
	# 지어져 Godot 이 중복 이름을 갈아치우는 탓이었다. 이름이 유일해진 뒤로는 그 우회가
	# 필요 없고, 정적 몸이 하나 더 늘어도 이 검사가 깨지지 않는다.
	for direction in ["North", "South", "West", "East"]:
		var boundary := map.get_node_or_null("MapBoundary" + direction)
		_expect(boundary is StaticBody2D, "MapBoundary%s must exist" % direction)

	if _failures.is_empty():
		print("PASS: sky island map structure and collision contract")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


# 이 맵 로컬 좌표에 충돌이 있는가. 맵이 원점에 놓여 있으므로 로컬 == 전역이다.
#
# 점 질의를 쓰는 이유: 유닛을 실제로 움직여 보면 프레임 수·속도·미끄러짐에 따라
# 결과가 달라지고, 실패했을 때 충돌이 없는 것인지 이동이 모자란 것인지 알 수 없다.
func _is_blocked(map: Node2D, local_point: Vector2) -> bool:
	var space := map.get_world_2d().direct_space_state
	var query := PhysicsPointQueryParameters2D.new()
	query.position = map.to_global(local_point)
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return not space.intersect_point(query, 1).is_empty()


# 사방이 섬으로 둘러싸인 칸 하나의 중심. 테두리 칸을 고르면 타일 안쪽 흔들림 때문에
# 충돌 경계(칸 격자)와 그림 경계가 몇 px 어긋나 판정이 흔들린다.
func _find_island_interior(islands: TileMapLayer) -> Vector2:
	for y in range(1, SkyIslandMap.MAP_SIZE.y - 1):
		for x in range(1, SkyIslandMap.MAP_SIZE.x - 1):
			var cell := Vector2i(x, y)
			if islands.get_cell_source_id(cell) == -1:
				continue
			var surrounded := true
			for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if islands.get_cell_source_id(cell + offset) == -1:
					surrounded = false
			if surrounded:
				return Vector2(float(x) + 0.5, float(y) + 0.5) * 24.0
	return Vector2.INF


# 사방이 허공인 칸 하나의 중심.
func _find_open_void(islands: TileMapLayer) -> Vector2:
	for y in range(1, SkyIslandMap.MAP_SIZE.y - 1):
		for x in range(1, SkyIslandMap.MAP_SIZE.x - 1):
			var cell := Vector2i(x, y)
			if islands.get_cell_source_id(cell) != -1:
				continue
			var open := true
			for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				if islands.get_cell_source_id(cell + offset) != -1:
					open = false
			if open:
				return Vector2(float(x) + 0.5, float(y) + 0.5) * 24.0
	return Vector2.INF


func _find_object(map: Node, object_kind: int) -> SkyObject:
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is SkyObject and child.kind == object_kind:
				return child
	return null


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
