extends Node
# #491: Full delivery contract for the twelve authored battle units.
var checks := 0
var failures: Array[String] = []
func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
func _ready() -> void:
	var units: Array = JSON.parse_string(FileAccess.get_file_as_string("res://art/battle-sprites/manifest.json"))
	for unit in units:
		var data: Resource = load(unit.data)
		var frames: SpriteFrames = data.get("battle_frames")
		var original := Image.load_from_file(ProjectSettings.globalize_path(unit.output))
		expect(frames != null, unit.id+": frames connected")
		if frames == null: continue
		for anim in BattleAnimation.ALL:
			expect(frames.has_animation(anim), unit.id+": "+anim)
			if not frames.has_animation(anim): continue
			expect(frames.get_frame_count(anim) == BattleAnimation.FRAME_COUNT[anim], unit.id+": exact count "+anim)
			expect(frames.get_animation_speed(anim) == BattleAnimation.FPS[anim], unit.id+": exact fps "+anim)
			var hashes: Dictionary = {}
			for n in frames.get_frame_count(anim):
				var texture := frames.get_frame_texture(anim,n)
				var img := Image.load_from_file(ProjectSettings.globalize_path(texture.resource_path))
				expect(img.get_size() == Vector2i(unit.width,unit.height), texture.resource_path+": canvas")
				expect(img.get_used_rect().end.y == img.get_height(), texture.resource_path+": baseline")
				expect(img.get_pixel(0,0).a == 0, texture.resource_path+": alpha")
				if anim == BattleAnimation.IDLE:
					expect(absi(img.get_used_rect().size.y-original.get_used_rect().size.y) <= 6, texture.resource_path+": idle stays at original scale")
				if anim == BattleAnimation.DEATH and n == 3:
					expect(img.get_used_rect().size.y < original.get_used_rect().size.y*0.8, texture.resource_path+": fallen pose is lower, not enlarged")
				var colors: Dictionary = {}
				var chroma := 0
				for y in img.get_height():
					for x in img.get_width():
						var color := img.get_pixel(x,y)
						if color.a > 0.9:
							colors[color.to_html(false)] = true
							# Test the production key, not violet ornaments. Lanczos
							# creates small RGB overshoots around legitimate purples.
							if minf(color.r,color.b)-color.g > 0.5: chroma += 1
				expect(chroma == 0 and colors.size() > 16, texture.resource_path+": keyed background removed and illustration colors retained")
				hashes[img.get_data().hex_encode().sha256_text()] = true
				if anim == &"idle" and n == 0:
					expect(FileAccess.get_sha256(texture.resource_path) == FileAccess.get_sha256(unit.output), unit.id+": untouched idle_0")
			expect(hashes.size() == frames.get_frame_count(anim), unit.id+": distinct frames "+anim)
	await verify_playback()
	for failure in failures: push_error(failure)
	print("%s: authored animation verification %d checks, %d failures" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
func verify_playback() -> void:
	var node := (load("res://stage/turn/TurnBattle.tscn") as PackedScene).instantiate()
	node.set("use_stage",false)
	node.set("party_ids",Array([&"harang",&"mina",&"arin",&"gangji"],TYPE_STRING_NAME,"",null))
	node.set("enemy_ids",Array([&"seoa"],TYPE_STRING_NAME,"",null))
	node.set("_playing",true)
	add_child(node)
	await get_tree().process_frame
	var battle: TurnBattleManager = node.get("battle")
	var unit: TurnUnit = battle.units[0]
	var sprite: AnimatedSprite2D = node.call("_anim_of",unit)
	expect(sprite != null,"Actual battle uses AnimatedSprite2D")
	if sprite != null:
		for speed in [1.0,3.0]:
			battle.presentation.speed = speed
			await node.call("_play_unit_anim",unit,BattleAnimation.ATTACK)
			expect(sprite.animation == BattleAnimation.IDLE,"Attack returns to idle")
			await node.call("_play_unit_anim",unit,BattleAnimation.HIT)
			expect(sprite.animation == BattleAnimation.IDLE,"Hit returns to idle")
		await node.call("_play_unit_anim",unit,BattleAnimation.DEATH,true)
		expect(sprite.animation == BattleAnimation.DEATH and sprite.frame == 3 and not sprite.is_playing(),"Death holds final frame")
		battle.presentation.speed = 1.0
		sprite.play(BattleAnimation.IDLE)
		node.call("_play_death", {"unit":unit})
		await get_tree().create_timer(0.4).timeout
		var shape: Node2D = sprite.get_parent()
		expect(shape.visible and shape.modulate.a > 0.99 and sprite.frame == 3,"Final death pose is visible before fade begins")
		await get_tree().create_timer(0.6).timeout
		expect(not shape.visible,"Death presentation completes its fade")
	node.queue_free()
	await get_tree().process_frame
