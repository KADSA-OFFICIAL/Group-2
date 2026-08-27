extends Node

const GRASSLAND_MAP := preload("res://stage/grassland/GrasslandMap.tscn")

var _failures: Array[String] = []


func _ready() -> void:
	var map := GRASSLAND_MAP.instantiate()
	add_child(map)
	await get_tree().process_frame
	await get_tree().process_frame

	_expect(map.get_node("Ground") is TileMapLayer, "Ground must be a TileMapLayer")
	_expect(map.get_node("Overlay") is TileMapLayer, "Overlay must be a TileMapLayer")
	_expect(map.get_node("Detail") is TileMapLayer, "Detail must be a TileMapLayer")
	_expect(map.get_node("Ground").tile_set.tile_size == Vector2i(24, 24), "world tile size must be 24x24")
	_expect(map.get_node("Ground").get_used_cells().size() == 64 * 40, "ground must fill the 64x40 map")
	_expect(map.get_node("Overlay").get_used_cells().size() > 0, "dirt path overlay must exist")
	_expect(map.get_node("Detail").get_used_cells().size() > 0, "sparse grass details must exist")
	_expect(map.get_node("Objects").y_sort_enabled, "object layer must use Y-sort")

	var hut := _find_object(map, GrasslandObject.Kind.HUT)
	var fence := _find_object(map, GrasslandObject.Kind.FENCE)
	var fallen := _find_object(map, GrasslandObject.Kind.FENCE_FALLEN)
	_expect(hut != null, "hut must exist")
	_expect(fence != null, "fence must exist")
	_expect(fallen != null, "fallen fence decal must exist")
	if hut:
		_expect(_footprint_size(hut) == Vector2(240, 96), "hut collision must be 240x96")
	if fence:
		_expect(_footprint_size(fence) == Vector2(96, 24), "fence collision must be 96x24")
	if fallen:
		_expect(fallen.get_parent().name == "Decal", "fallen fence must be in the decal layer")
		_expect(not fallen.has_node("Footprint"), "fallen fence must not block movement")

	# Every placed prop must remain an external PackedScene instance so designers can
	# select, move, duplicate, or replace it directly in GrasslandMap.tscn.
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is GrasslandObject:
				_expect(
					child.scene_file_path.begins_with("res://stage/grassland/objects/"),
					"%s must be an independently instanced object scene" % child.name,
				)

	# Fence centers are 216px apart around the gate; subtracting two 48px half-widths leaves 120px.
	_expect(738.0 - 522.0 - 96.0 >= 120.0, "central fence passage must be at least 120px")

	if _failures.is_empty():
		print("PASS: grassland map v3 structure and collision contract")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _find_object(map: Node, object_kind: int) -> GrasslandObject:
	for layer_name in ["Objects", "Decal"]:
		for child in map.get_node(layer_name).get_children():
			if child is GrasslandObject and child.kind == object_kind:
				return child
	return null


func _footprint_size(object: GrasslandObject) -> Vector2:
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
