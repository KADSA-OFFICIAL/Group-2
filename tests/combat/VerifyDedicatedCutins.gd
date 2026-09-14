extends Node
var failed := false
func check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
func _ready() -> void:
	var field = load("res://stage/turn/TurnBattle.tscn").instantiate()
	field.use_stage = false
	add_child(field)
	await get_tree().process_frame
	for id in ["harang", "mina", "seola", "taehee", "arin"]:
		var unit := TurnUnit.new()
		unit.character = load("res://data/characters/%s.tres" % id)
		unit.display_name = unit.character.display_name
		var skill: SkillData = load("res://data/skills/turn/%s_turn_ult.tres" % id)
		check(field._setup_cutin(unit, skill, Color(0.6, 0.8, 1.0)), "Cutin setup: " + id)
		if id == "arin":
			check(not field._wide_cutin, "Existing portrait fallback must remain")
			continue
		var texture: Texture2D = field._cutin_art.texture
		check(field._wide_cutin and not texture is AtlasTexture, "Dedicated canvas must retain transparent space")
		check(texture.get_size() == Vector2(2400, 1350), "2400x1350 required")
		var bounds := texture.get_image().get_used_rect()
		check(bounds.size.x >= 1080 and bounds.end.x <= 1320, "Left 45-55 percent only")
		check(field._cutin_name.position.x >= get_viewport().get_visible_rect().size.x * 0.59, "Type on right")
		field._fade_hud(0.0, 0.01)
		field._cutin.visible = true
		field._cutin.modulate.a = 1.0
		if DisplayServer.get_name() != "headless":
			await get_tree().create_timer(0.05).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://docs/art-review/missing-art/%s-cutin.png" % id)
	field.queue_free()
	await get_tree().process_frame
	MusicSystem.stop()
	print("DEDICATED_CUTINS ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
