extends Node

# 하늘 맵 미리보기 PNG 를 뽑는다 (#423).
# tests/beach/RenderBeachPreview.gd 와 같은 관례다.
#
# 절차적 생성 맵은 셀 수·충돌 규약이 다 맞아도 **보기에 엉망일 수 있다.**
# 그래서 수치 검증(VerifySkyIslandMap)과 별도로 눈으로 볼 그림이 필요하다.
#
# 하늘 맵에는 특히 필요하다: 인수 조건이 "섬이 화면에서 허공과 구별된다"인데
# 그건 셀 수로 잴 수 없다. 섬과 허공의 명도 차가 모자라면 검사는 전부 통과하면서
# 화면은 파란 얼룩이 된다.
#
# 두 장을 뽑는다:
#   - combat: 실제 전투가 벌어지는 framing (파티 340,340 / 적 840,470 근처).
#             여기가 본섬 위인지, 섬 가장자리와 허공이 갈리는지 본다.
#   - overview: 맵 전체. 섬 배치와 구름 띠, 프롭 분포를 한눈에 본다.

const SKY_MAP := preload("res://stage/sky/SkyIslandMap.tscn")


func _ready() -> void:
	var ok := true
	ok = await _render("combat", Vector2(700, 500), 1.0) and ok
	ok = await _render("overview", Vector2(1152, 768), 0.32) and ok
	get_tree().quit(0 if ok else 1)


func _render(label: String, camera_position: Vector2, zoom: float) -> bool:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = \
		Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
	add_child(viewport)

	var world := Node2D.new()
	viewport.add_child(world)
	world.add_child(SKY_MAP.instantiate())

	var camera := Camera2D.new()
	camera.position = camera_position
	camera.zoom = Vector2(zoom, zoom)
	camera.enabled = true
	world.add_child(camera)

	for frame in 6:
		await get_tree().process_frame

	var output_path := "user://sky-map-%s.png" % label
	var error := viewport.get_texture().get_image().save_png(output_path)
	viewport.queue_free()
	if error != OK:
		push_error("Could not save sky preview (%s): %s" % [label, error_string(error)])
		return false
	print("PREVIEW %s: %s" % [label, ProjectSettings.globalize_path(output_path)])
	return true
