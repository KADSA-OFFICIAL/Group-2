extends Node

# #485: Validate authored PNGs AND actual TurnBattle TextureRects, not just paths.
# godot --headless --path . res://tests/combat/VerifyBattleSprites.tscn
# For rendered evidence, omit --headless and append -- --capture <directory>.
var failures: Array[String] = []
var checks := 0
var seen: Dictionary = {}

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _ready() -> void:
	await get_tree().process_frame
	var manifest: Array = JSON.parse_string(FileAccess.get_file_as_string("res://art/battle-sprites/manifest.json"))
	expect(manifest.size() == 12, "Expected 12 authored sprites")
	for entry in manifest: verify_asset(entry)
	verify_restyled_portraits()
	await verify_scene([&"harang", &"mina", &"seola", &"taehee"],
		[&"mammoth_beastfolk", &"velociraptor_beastfolk", &"velociraptor_beastfolk_2", &"seoa"], "battle-party-a.png")
	await verify_scene([&"arin", &"gangji", &"harang", &"mina"],
		[&"mammoth_boss", &"pterosaur_queen"], "battle-party-b.png")
	expect(seen.size() == 12, "All 12 units must be observed with textures in TurnBattle")
	for failure in failures: push_error(failure)
	print("%s: battle sprite verification %d checks, %d unique units, %d failures" %
		["PASS" if failures.is_empty() else "FAIL", checks, seen.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func verify_asset(entry: Dictionary) -> void:
	var data: Resource = load(entry.data)
	expect(data != null, entry.id+": data loads")
	if data == null: return
	var texture: Texture2D = data.get("battle_sprite")
	expect(texture != null, entry.id+": battle_sprite assigned")
	if texture == null: return
	expect(texture.resource_path == entry.output, entry.id+": correct texture assigned")
	expect(FileAccess.file_exists(entry.output+".import"), entry.id+": import sidecar exists")
	var img := Image.load_from_file(ProjectSettings.globalize_path(entry.output))
	expect(img.get_size() == Vector2i(entry.width,entry.height), entry.id+": exact dimensions")
	var bounds := img.get_used_rect()
	expect(bounds.end.y == img.get_height(), entry.id+": sole on bottom edge")
	expect(bounds.position.y >= ceili(img.get_height()*0.05), entry.id+": top clearance")
	expect(bounds.position.x >= ceili(img.get_width()*0.05) and bounds.end.x <= floori(img.get_width()*0.95), entry.id+": side clearance")
	var colors: Dictionary = {}
	var has_transparent := false
	var accent_count := 0
	var accent_color := Color(entry.element_color)
	var skin_count := 0
	var chroma_count := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x,y)
			if c.a == 0:
				has_transparent = true
				continue
			var rgb := c.to_html(false)
			colors[rgb] = true
			if c.a > 0.9:
				if Vector3(c.r-accent_color.r,c.g-accent_color.g,c.b-accent_color.b).length() < 0.22: accent_count += 1
				# Warm pale skin remains separate from mint/blue hair and gray clothes.
				if c.r > 0.85 and c.g > 0.65 and c.b > 0.60 and c.r-c.g > 0.018 and c.r-c.b > 0.025: skin_count += 1
				if minf(c.r,c.b)-c.g > 0.24: chroma_count += 1
	expect(has_transparent and img.get_pixel(0,0).a == 0, entry.id+": real transparent background")
	expect(colors.size() > 16, entry.id+": source colors retained without four-color quantization")
	expect(skin_count > 50, entry.id+": pale warm skin survives export")
	expect(chroma_count == 0, entry.id+": no production magenta remains")
	expect(accent_count > 2, entry.id+": elemental ornament survives export")
	var element := int(data.get("element")) if entry.side == "ally" else int(data.get("turn_element"))
	expect(accent_color.to_html(false) == TurnCombat.element_color(element).to_html(false), entry.id+": accent matches current game element")

func verify_restyled_portraits() -> void:
	for id in ["arin","gangji"]:
		var data: Resource = load("res://data/characters/"+id+".tres")
		var portrait: Texture2D = data.get("portrait")
		expect(portrait != null, id+": shared portrait assigned")
		if portrait == null: continue
		expect(portrait.resource_path == "res://assets/sprites/characters/portraits/"+id+".png", id+": revised portrait used by existing screens")
		var img := Image.load_from_file(ProjectSettings.globalize_path(portrait.resource_path))
		var bounds := img.get_used_rect()
		expect(img.get_size() == Vector2i(941,1691) and img.get_pixel(0,0).a == 0, id+": normalized transparent portrait")
		expect(absf(float(bounds.size.y)/img.get_height()-0.92) < 0.002, id+": 92 percent figure height")
		var head := PortraitSystem.get_head_rect(portrait)
		expect(head.size.y > 0.14 and head.end.y < 0.25, id+": authored face crop available to HUD and formation")

func verify_scene(party: Array[StringName], enemies: Array[StringName], filename: String) -> void:
	var scene := load("res://stage/turn/TurnBattle.tscn") as PackedScene
	var node := scene.instantiate()
	node.set("use_stage",false)
	node.set("party_ids",party)
	node.set("enemy_ids",enemies)
	node.set("battle_seed",480)
	# Hold presentation at the initial battle state without leaving a suspended
	# pause coroutine behind when this verification scene is freed.
	node.set("_playing",true)
	add_child(node)
	node.call("_sync_shapes")
	(node.get("hud") as TurnBattleHUD).refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var battle: TurnBattleManager = node.get("battle")
	expect(battle.units.size() == party.size()+enemies.size(), "Requested encounter size")
	var shapes: Dictionary = node.get("_shapes")
	for unit in battle.units:
		var shape: Node2D = shapes.get(unit.unit_id)
		expect(shape != null, "Unit has a stage node")
		if shape == null: continue
		var picture := shape.get_child(0)
		expect(picture is TextureRect or picture is AnimatedSprite2D, "Stage uses authored art")
		var data: Resource = unit.character if unit.is_ally() else unit.enemy
		var id: StringName = data.get("character_id") if unit.is_ally() else data.get("enemy_id")
		seen[id] = true
		# 표시 칸의 정본은 TurnBattle 이다. 여기에 숫자를 박아 두면 칸을 키울 때
		# (#492 가 1.8배로 키웠다) 아트는 멀쩡한데 이 검증만 빨간불이 켜진다.
		var expected: Vector2 = node.get("ALLY_BODY") if unit.is_ally() else node.get("ENEMY_BODY")
		if picture is AnimatedSprite2D:
			expect(picture.sprite_frames == data.get("battle_frames"), String(id)+": stage uses authored frames")
			var cell := BattleAnimation.cell_size(picture.sprite_frames)
			expected = cell * minf(expected.x/cell.x, expected.y/cell.y)
			expect((cell * picture.scale).is_equal_approx(expected) and (picture.offset * picture.scale).is_equal_approx(-expected*Vector2(0.5,1)), String(id)+": animated display size and feet anchor")
		elif picture is TextureRect:
			expect(picture.texture == data.get("battle_sprite"), String(id)+": stage uses authored resource")
			expect(picture.size == expected and picture.position == -expected*Vector2(0.5,1), String(id)+": original display size and feet anchor")
	var args := OS.get_cmdline_user_args()
	if args.size() == 2 and args[0] == "--capture":
		expect(DisplayServer.get_name() != "headless", "Capture requires rendering")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute(args[1])
			var result := get_viewport().get_texture().get_image().save_png(args[1]+"/"+filename)
			expect(result == OK, "Saved rendered battle evidence")
			for motion in BattleAnimation.ALL:
				for shape in shapes.values():
					var sprite := (shape as Node2D).get_child(0) as AnimatedSprite2D
					if sprite != null and sprite.sprite_frames.has_animation(motion):
						sprite.pause()
						sprite.animation = motion
						sprite.frame = mini(2, sprite.sprite_frames.get_frame_count(motion)-1) if motion != BattleAnimation.DEATH else sprite.sprite_frames.get_frame_count(motion)-1
				await RenderingServer.frame_post_draw
				var path := args[1]+"/"+filename.get_basename()+"-"+String(motion)+".png"
				expect(get_viewport().get_texture().get_image().save_png(path) == OK, "Saved rendered animation pose")
	node.queue_free()
	await get_tree().process_frame
