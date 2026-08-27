extends Node

const GRASSLAND_MAP := preload("res://stage/grassland/GrasslandMap.tscn")


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(viewport)

	var world := Node2D.new()
	viewport.add_child(world)
	world.add_child(GRASSLAND_MAP.instantiate())
	var camera := Camera2D.new()
	camera.position = Vector2(720, 420)
	camera.enabled = true
	world.add_child(camera)

	for frame in 5:
		await get_tree().process_frame
	var output_path := "user://grassland-map-preview.png"
	var error := viewport.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save grassland preview: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("PREVIEW: %s" % ProjectSettings.globalize_path(output_path))
	get_tree().quit(0)
