extends Node

# 해변 맵의 구조·충돌 규약 검증 (#422).
# tests/grassland/VerifyGrasslandMap.gd 와 같은 관례를 따른다.

const BEACH_MAP := preload("res://stage/beach/BeachMap.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	var map := BEACH_MAP.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(map.get_node("Ground") is TileMapLayer, "Ground must be a TileMapLayer")
	_expect(map.get_node("Overlay") is TileMapLayer, "Overlay must be a TileMapLayer")
	_expect(map.get_node("Detail") is TileMapLayer, "Detail must be a TileMapLayer")
	_expect(map.get_node("Ground").tile_set.tile_size == Vector2i(24, 24),
		"world tile size must be 24x24")

	# 크기의 출처는 BeachMap.MAP_SIZE 다. 여기에 숫자를 다시 적으면 맵을 넓힐 때
	# 이 파일이 거짓이 되고, 실패 메시지가 크기 변경을 회귀로 보고한다.
	var expected_cells: int = BeachMap.MAP_SIZE.x * BeachMap.MAP_SIZE.y
	_expect(map.get_node("Ground").get_used_cells().size() == expected_cells,
		"ground must fill the %dx%d map" % [BeachMap.MAP_SIZE.x, BeachMap.MAP_SIZE.y])

	# 초원과 같은 크기여야 한다 — GameCamera 에 경계 제한이 없어서, 더 작으면
	# 어디를 봐도 맵 바깥이 드러난다(#396 이 초원에서 없앤 문제).
	_expect(BeachMap.MAP_SIZE == GrasslandMap.MAP_SIZE,
		"beach map must match the grassland map size (camera has no limits)")

	_expect(map.get_node("Overlay").get_used_cells().size() > 0, "shallow water must exist")
	_expect(map.get_node("Detail").get_used_cells().size() > 0, "sand details must exist")
	_expect(map.get_node("Objects").y_sort_enabled, "object layer must use Y-sort")

	# 물이 맵을 다 덮지도, 없지도 않아야 한다 — "모래밭과 얕은 물이 섞인" 해변이다.
	# 한쪽으로 쏠리면 그건 해변이 아니라 바다나 사막이다.
	var water_cells: int = map.get_node("Overlay").get_used_cells().size()
	var water_ratio := float(water_cells) / float(expected_cells)
	_expect(water_ratio > 0.2 and water_ratio < 0.75,
		"water must cover 20-75%% of the map (got %.1f%%)" % (water_ratio * 100.0))

	var palm := _find_object(map, BeachObject.Kind.PALM)
	var driftwood := _find_object(map, BeachObject.Kind.DRIFTWOOD)
	var rock := _find_object(map, BeachObject.Kind.ROCK_WET)
	var shell := _find_object(map, BeachObject.Kind.SHELL)
	_expect(palm != null, "palm must exist")
	_expect(driftwood != null, "driftwood must exist")
	_expect(rock != null, "wet rock must exist")
	_expect(shell != null, "shell cluster must exist")

	if palm:
		_expect(_footprint_size(palm) == Vector2(48, 32), "palm collision must be 48x32")
	if driftwood:
		_expect(_footprint_size(driftwood) == Vector2(96, 32),
			"driftwood collision must be 96x32")
	if rock:
		_expect(_footprint_size(rock) == Vector2(120, 40), "wet rock collision must be 120x40")
	if shell:
		# 조개는 장식이다. 초원의 넘어진 울타리와 같은 규약으로 Decal 에 있고 길을 막지 않는다.
		_expect(shell.get_parent().name == "Decal", "shells must be in the decal layer")
		_expect(not shell.has_node("Footprint"), "shells must not block movement")

	# 프롭은 외부 PackedScene 인스턴스로 남아야 한다 — BeachMap.tscn 에서 직접
	# 고르고 옮기고 지울 수 있어야 저작이 된다.
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is BeachObject:
				_expect(
					child.scene_file_path.begins_with("res://stage/beach/objects/"),
					"%s must be an independently instanced object scene" % child.name,
				)

	# 파티(맵 로컬 340,340~420)와 적(840,470~920,560)이 놓이는 자리에 막는 프롭이 없어야
	# 한다. 스폰 지점이 막히면 유닛이 프롭 안에 끼어 첫 프레임부터 밀려난다.
	var combat_zone := Rect2(Vector2(280, 300), Vector2(700, 300))
	for child in map.get_node("Objects").get_children():
		if child is BeachObject and child.has_node("Footprint"):
			_expect(not combat_zone.has_point(child.position),
				"%s blocks the spawn area at %s" % [child.name, child.position])

	if _failures.is_empty():
		print("PASS: beach map structure and collision contract")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _find_object(map: Node, object_kind: int) -> BeachObject:
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is BeachObject and child.kind == object_kind:
				return child
	return null


func _footprint_size(object: BeachObject) -> Vector2:
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
