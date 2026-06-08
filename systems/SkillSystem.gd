extends Node

var player_skills: Dictionary = {}
var skill_configs: Dictionary = {}

func _ready():
	load_skill_configs()

func load_skill_configs():
	var skill_file = FileAccess.open("res://config/skill_config.json", FileAccess.READ)
	if skill_file:
		var json = JSON.new()
		json.parse(skill_file.get_as_text())
		skill_configs = json.data

func get_skill(skill_name: String) -> Dictionary:
	if skill_configs.has(skill_name):
		return skill_configs[skill_name]
	return {}

func is_skill_on_cooldown(player, skill_name: String) -> bool:
	if not player_skills.has(player):
		player_skills[player] = {}
	
	if not player_skills[player].has(skill_name):
		return false
	
	return player_skills[player][skill_name] > 0

func reduce_skill_cooldown(player, delta: float):
	if not player_skills.has(player):
		return
	
	for skill in player_skills[player]:
		player_skills[player][skill] -= delta
		if player_skills[player][skill] < 0:
			player_skills[player][skill] = 0

func set_skill_cooldown(player, skill_name: String, duration: float):
	if not player_skills.has(player):
		player_skills[player] = {}
	
	player_skills[player][skill_name] = duration

func trigger_skill(player, skill_name: String) -> bool:
	if is_skill_on_cooldown(player, skill_name):
		return false
	
	var skill = get_skill(skill_name)
	if skill.is_empty():
		return false
	
	set_skill_cooldown(player, skill_name, skill.get("cooldown", 0))
	return true
