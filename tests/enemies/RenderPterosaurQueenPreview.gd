extends Node

const DATA := preload("res://data/enemies/pterosaur_queen.tres")
const NORMAL_FRAMES := preload("res://assets/sprites/vfx/pterosaur_queen_projectile_frames.tres")
const CHARGED_FRAMES := preload("res://assets/sprites/vfx/pterosaur_queen_projectile_charged_frames.tres")


func _ready() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(viewport)

	var backdrop := ColorRect.new()
	backdrop.size = viewport.size
	backdrop.color = Color("17131f")
	viewport.add_child(backdrop)

	var title := _label("PTEROSAUR QUEEN", 34, Color("fff3d5"))
	title.position = Vector2(54, 36)
	viewport.add_child(title)
	var subtitle := _label("4-DIRECTION WALK / NORMAL + CHARGED PROJECTILES", 18, Color("a77ad8"))
	subtitle.position = Vector2(57, 84)
	viewport.add_child(subtitle)

	var animations: Array[StringName] = [&"walk_down", &"walk_left", &"walk_up", &"walk_right"]
	var names := ["DOWN", "LEFT", "UP", "RIGHT"]
	for i in 4:
		var panel := ColorRect.new()
		panel.position = Vector2(48 + i * 300, 132)
		panel.size = Vector2(276, 420)
		panel.color = Color("211a2c") if i % 2 == 0 else Color("261e31")
		viewport.add_child(panel)

		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = DATA.walk_frames
		sprite.animation = animations[i]
		sprite.scale = DATA.walk_sprite_scale
		sprite.offset = DATA.walk_sprite_offset
		sprite.position = Vector2(186 + i * 300, 390)
		sprite.play()
		viewport.add_child(sprite)

		var direction_label := _label(names[i], 19, Color("d7d4d7"))
		direction_label.position = Vector2(60 + i * 300, 150)
		viewport.add_child(direction_label)

	var line := ColorRect.new()
	line.position = Vector2(48, 579)
	line.size = Vector2(1180, 2)
	line.color = Color("65468f")
	viewport.add_child(line)

	_make_projectile(viewport, NORMAL_FRAMES, Vector2(97, 642), "NORMAL  8x8", Color("e2c5f4"))
	_make_projectile(viewport, CHARGED_FRAMES, Vector2(455, 642), "CHARGED  12x12 / STUN", Color("ffd27a"))
	var note := _label("96x96 cells  /  8 fps  /  nearest 2x", 18, Color("9b929b"))
	note.position = Vector2(845, 626)
	viewport.add_child(note)

	for frame in 8:
		await get_tree().process_frame
	var output_path := "user://pterosaur-queen-pixel-art-preview.png"
	var error := viewport.get_texture().get_image().save_png(output_path)
	if error != OK:
		push_error("Could not save Pterosaur Queen preview: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("PREVIEW: %s" % ProjectSettings.globalize_path(output_path))
	get_tree().quit(0)


func _make_projectile(viewport: SubViewport, frames: SpriteFrames, position: Vector2,
		caption: String, caption_color: Color) -> void:
	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = &"spin"
	sprite.scale = Vector2(4, 4)
	sprite.position = position
	sprite.play()
	viewport.add_child(sprite)
	var label := _label(caption, 18, caption_color)
	label.position = position + Vector2(46, -14)
	viewport.add_child(label)


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
