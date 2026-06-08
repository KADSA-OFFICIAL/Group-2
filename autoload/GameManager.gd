extends Node

static var active_enemies: Array = []

func _ready():
	name = "GameManager"
	# Load game data on startup
	var save_data = SaveSystem.load_game()
	print("Game loaded! Currencies: ", CurrencySystem.get_all_currencies())

static func register_enemy(enemy):
	if not active_enemies.has(enemy):
		active_enemies.append(enemy)

static func unregister_enemy(enemy):
	active_enemies.erase(enemy)

static func get_all_enemies() -> Array:
	return active_enemies.filter(func(e): return is_instance_valid(e))

static func get_nearest_enemy(position: Vector2) -> Node:
	var valid_enemies = get_all_enemies()
	if valid_enemies.is_empty():
		return null
	
	var nearest = valid_enemies[0]
	var min_distance = position.distance_to(nearest.global_position)
	
	for enemy in valid_enemies:
		var distance = position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = enemy
	
	return nearest

static func get_enemies_in_range(position: Vector2, range_distance: float) -> Array:
	var valid_enemies = get_all_enemies()
	var enemies_in_range = []
	
	for enemy in valid_enemies:
		if position.distance_to(enemy.global_position) <= range_distance:
			enemies_in_range.append(enemy)
	
	return enemies_in_range
