extends Node

func _ready() -> void:
	var count := 0
	var failed := false
	for file in DirAccess.get_files_at("res://data/equipment"):
		if not file.ends_with(".tres"):
			continue
		var equipment := load("res://data/equipment/" + file) as EquipmentData
		var id := file.get_basename()
		var expected := "res://assets/sprites/ui/icons/icon_equip_%s.png" % id
		if equipment == null or equipment.icon == null or equipment.icon.resource_path != expected:
			failed = true
			push_error("Equipment icon is disconnected: " + id)
			continue
		var image := equipment.icon.get_image()
		var bounds := image.get_used_rect()
		if image.get_size() != Vector2i(512, 512) or bounds.position.x < 64 or bounds.position.y < 64 or bounds.end.x > 448 or bounds.end.y > 448:
			failed = true
			push_error("Equipment icon dimensions: " + id)
		count += 1
	failed = failed or count != 17
	print("EQUIPMENT_ICONS ", "FAIL" if failed else "PASS", " count=", count)
	get_tree().quit(1 if failed else 0)
