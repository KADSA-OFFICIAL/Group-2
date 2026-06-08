extends CharacterBody2D
class_name Player

var hp: int = 100
var max_hp: int = 100
var is_alive: bool = true
var player_config: Dictionary = {}

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	name = "Player"
	add_to_group("player")
	load_config()
	hp = player_config.get("max_hp", 100)
	max_hp = player_config.get("max_hp", 100)

func load_config():
	var config_file = FileAccess.open("res://config/player_config.json", FileAccess.READ)
	if config_file:
		var json = JSON.new()
		json.parse(config_file.get_as_text())
		player_config = json.data

func _physics_process(_delta):
	if not is_alive:
		return

func take_damage(amount: int, _source = null):
	if not is_alive:
		return
	
	hp -= amount
	hp = max(hp, 0)
	
	if EventBus:
		EventBus.damage_taken.emit(self, amount, global_position)
	
	if hp <= 0:
		die()

func heal(amount: int):
	if not is_alive:
		return
	
	hp += amount
	hp = min(hp, max_hp)
	
	if EventBus:
		EventBus.healing_applied.emit(self, amount)

func die():
	is_alive = false
	if EventBus:
		EventBus.player_died.emit()
	queue_free()

func get_health_percent() -> float:
	if max_hp == 0:
		return 0.0
	return float(hp) / float(max_hp)

func get_player_config() -> Dictionary:
	return player_config


