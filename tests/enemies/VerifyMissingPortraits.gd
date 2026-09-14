extends Node

func _ready() -> void:
	await get_tree().process_frame
	var failed := false
	DirAccess.make_dir_recursive_absolute("res://docs/art-review/missing-portraits")
	for id in ["mammoth_beastfolk", "mammoth_boss", "pterosaur_queen"]:
		var enemy := load("res://data/enemies/%s.tres" % id) as EnemyData
		if enemy == null or enemy.portrait == null:
			push_error("Missing portrait: " + id)
			failed = true
			continue
		var texture := enemy.portrait
		var ratio := float(texture.get_width()) / texture.get_height()
		var rect := PortraitSystem.get_head_rect(texture)
		if absf(ratio - 0.5566) > 0.001 or not rect.has_area():
			push_error("Invalid portrait metrics: " + id)
			failed = true
		var head := HUDKit.head_texture(texture)
		if not head is AtlasTexture or head.get_height() >= texture.get_height() / 2:
			push_error("Timeline must crop the face: " + id)
			failed = true
		else:
			head.get_image().save_png("res://docs/art-review/missing-portraits/%s-head.png" % id)
	print("MISSING_PORTRAITS ", "FAIL" if failed else "PASS")
	get_tree().quit(1 if failed else 0)
