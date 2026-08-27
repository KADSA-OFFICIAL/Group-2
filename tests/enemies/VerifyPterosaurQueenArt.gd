extends Node

# Headless contract test for the Pterosaur Queen art package (#384).
# Run with: godot --headless --path . res://tests/enemies/VerifyPterosaurQueenArt.tscn

const DATA_PATH := "res://data/enemies/pterosaur_queen.tres"
const QUEEN_SCENE := preload("res://entities/enemies/PterosaurQueen.tscn")
const WALK_SHEET_PATH := "res://assets/sprites/enemies/pterosaur_queen_walk.png"
const NORMAL_SHEET_PATH := "res://assets/sprites/vfx/pterosaur_queen_projectile.png"
const CHARGED_SHEET_PATH := "res://assets/sprites/vfx/pterosaur_queen_projectile_charged.png"
const REQUIRED_ANIMATIONS := [&"walk_down", &"walk_left", &"walk_up", &"walk_right"]
const ALLOWED_COLORS := {
	"f7f3eaff": true, "d8d3ccff": true, "9a9691ff": true, "6e6558ff": true,
	"8b6bb0ff": true, "5e4578ff": true, "3a2c4aff": true, "a78bc8ff": true,
	"d9b26aff": true, "a8823fff": true, "3b342bff": true, "2e2a24ff": true,
	"dccdafff": true, "b39a78ff": true,
}

var _failures: Array[String] = []


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_walk_sheet()
	_verify_projectile_sheet(NORMAL_SHEET_PATH, Vector2i(24, 8))
	_verify_projectile_sheet(CHARGED_SHEET_PATH, Vector2i(36, 12))

	var data := load(DATA_PATH) as EnemyData
	_check(data != null, "queen EnemyData should load")
	if data != null:
		_check(data.validate().is_empty(), "queen EnemyData should validate: %s" % [data.validate()])
		_check(data.walk_sprite_scale == Vector2(2, 2), "walk scale should be 2x")
		_check(data.walk_sprite_offset == Vector2(0, -30), "walk offset should be (0, -30)")
		_check(data.tint.is_equal_approx(Color("8b6bb0")), "dialogue tint should be #8B6BB0")
		_check(data.projectile_hit_radius == 16.0, "projectile hit radius should remain 16px")
		_check(data.charged_attack_threshold == 4, "charged attack threshold should remain 4")
		_check(is_equal_approx(data.charged_attack_damage_multiplier, 1.5), "charged multiplier should remain 1.5")
		_check(data.charged_attack_effect == &"stun", "charged projectile should retain stun")
		_verify_animations(data.walk_frames)

	var queen := QUEEN_SCENE.instantiate()
	add_child(queen)
	var visual := queen.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_check(visual != null and visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
		"queen sprite should use nearest filtering")
	_check(visual != null and visual.visible, "walk art should replace the placeholder")
	_check(not queen.get_node("Sprite2D").visible, "placeholder Sprite2D should be hidden")
	var shape := queen.get_node("CollisionShape2D").shape as CapsuleShape2D
	_check(shape != null and shape.radius == 14.0 and shape.height == 40.0,
		"boss collision capsule should remain 14x40")

	if data != null and data.projectile_scene != null:
		var normal := data.projectile_scene.instantiate() as PterosaurQueenProjectile
		add_child(normal)
		normal.setup(Vector2.RIGHT, 340.0, 10, queen, 320.0, 16.0)
		_check(normal.visual.sprite_frames.resource_path.ends_with("pterosaur_queen_projectile_frames.tres"),
			"normal attack should use the purple 8x8 sheet")
		_check(normal.visual.scale == Vector2(4, 4), "projectile art should render at 4x")
		_check(normal.visual.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"projectile art should use nearest filtering")

		var charged := data.projectile_scene.instantiate() as PterosaurQueenProjectile
		add_child(charged)
		charged.setup(Vector2.UP, 340.0, 15, queen, 320.0, 16.0, &"stun")
		_check(charged.visual.sprite_frames.resource_path.ends_with("pterosaur_queen_projectile_charged_frames.tres"),
			"charged attack should use the amber 12x12 sheet")
		_check(charged.hit_radius == 16.0, "charged art must not change the hit radius")

	if _failures.is_empty():
		print("PASS: Pterosaur Queen art, animation, projectile, and collision contract")
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		get_tree().quit(1)


func _verify_walk_sheet() -> void:
	var texture := load(WALK_SHEET_PATH) as Texture2D
	var image := texture.get_image() if texture != null else null
	_check(image != null and image.get_size() == Vector2i(288, 384), "walk sheet should be 288x384")
	if image == null:
		return
	var saw_transparency := false
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a < 0.5:
				saw_transparency = true
				continue
			_check(ALLOWED_COLORS.has(pixel.to_html()), "undocumented palette color %s at %d,%d" % [pixel.to_html(), x, y])
	_check(saw_transparency, "walk sheet should preserve transparent cell backgrounds")

	for row in 4:
		for frame in 3:
			var last_y := -1
			for local_y in 96:
				for local_x in 96:
					if image.get_pixel(frame * 96 + local_x, row * 96 + local_y).a >= 0.5:
						last_y = maxi(last_y, local_y)
			var expected := 88 if frame == 0 else 87
			_check(last_y == expected, "row %d frame %d baseline should be y=%d, got %d" % [row, frame, expected, last_y])


func _verify_animations(frames: SpriteFrames) -> void:
	_check(frames != null, "walk SpriteFrames should load")
	if frames == null:
		return
	for animation in REQUIRED_ANIMATIONS:
		_check(frames.has_animation(animation), "missing animation %s" % animation)
		if frames.has_animation(animation):
			_check(frames.get_frame_count(animation) == 3, "%s should have 3 frames" % animation)
			_check(is_equal_approx(frames.get_animation_speed(animation), 8.0), "%s should run at 8fps" % animation)


func _verify_projectile_sheet(path: String, expected_size: Vector2i) -> void:
	var texture := load(path) as Texture2D
	var image := texture.get_image() if texture != null else null
	_check(image != null and image.get_size() == expected_size, "%s should be %s" % [path, expected_size])
	if image == null:
		return
	var saw_transparency := false
	var saw_opaque := false
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			saw_transparency = saw_transparency or alpha < 0.1
			saw_opaque = saw_opaque or alpha > 0.9
	_check(saw_transparency and saw_opaque, "%s should contain transparent and opaque pixels" % path)


func _check(condition: bool, message: String) -> void:
	if not condition and not _failures.has(message):
		_failures.append(message)
