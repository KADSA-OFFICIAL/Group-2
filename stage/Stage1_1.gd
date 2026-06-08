extends Node2D
class_name Stage

var stage_name: String = "Stage1_1"
var current_room: Node = null

func _ready():
	name = stage_name
	EventBus.stage_started.emit(stage_name)
	load_room()

func load_room():
	# Load the first room
	if current_room:
		current_room.queue_free()
	
	# Get or create room
	current_room = get_node_or_null("Room1")
	if not current_room:
		current_room = Node2D.new()
		current_room.name = "Room1"
		add_child(current_room)
	
	# Clear existing children in room
	for child in current_room.get_children():
		child.queue_free()
	
	# Spawn player
	spawn_player()
	
	# Spawn enemies
	spawn_enemies()

func spawn_player():
	var player_scene = load("res://entities/player/Player.tscn")
	if player_scene:
		var player = player_scene.instantiate()
		current_room.add_child(player)
		player.global_position = Vector2(100, 100)
	else:
		# Fallback: create player manually
		var player = CharacterBody2D.new()
		player.name = "Player"
		player.add_to_group("player")
		current_room.add_child(player)
		player.global_position = Vector2(100, 100)

func spawn_enemies():
	var goblin_scene = load("res://entities/enemies/TrainingGoblin.tscn")
	if goblin_scene:
		for i in range(2):
			var goblin = goblin_scene.instantiate()
			current_room.add_child(goblin)
			goblin.global_position = Vector2(400 + i * 100, 200)

func complete_stage():
	EventBus.stage_completed.emit(stage_name)

