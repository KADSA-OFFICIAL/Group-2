extends CharacterBody2D

var config: Dictionary = {}
var hp: int = 30
var max_hp: int = 30
var is_alive: bool = true

var detection_range: float = 300
var patrol_range: float = 200
var state: String = "idle"  # idle, patrol, chase, attack
var target: Node = null
var start_position: Vector2

var sprite: Sprite2D
var animation_player: AnimationPlayer
var attack_area: Area2D
var detection_area: Area2D

func _ready():
	start_position = global_position
	GameManager.register_enemy(self)
	load_config()
	
	# Find child nodes safely
	sprite = get_node_or_null("Sprite2D")
	animation_player = get_node_or_null("AnimationPlayer")
	attack_area = get_node_or_null("AttackArea2D")
	detection_area = get_node_or_null("DetectionArea2D")
	
	if attack_area:
		attack_area.area_entered.connect(_on_attack_area_entered)
	
	if detection_area:
		detection_area.area_entered.connect(_on_detection_area_entered)
		detection_area.area_exited.connect(_on_detection_area_exited)
	
	EventBus.player_died.connect(_on_player_died)

func _exit_tree():
	GameManager.unregister_enemy(self)

func load_config():
	var config_file = FileAccess.open("res://config/enemy_config.json", FileAccess.READ)
	if config_file:
		var json = JSON.new()
		json.parse(config_file.get_as_text())
		var all_configs = json.data
		if all_configs.has("training_goblin"):
			config = all_configs["training_goblin"]
	
	detection_range = config.get("detection_range", 300)
	patrol_range = config.get("patrol_range", 200)
	max_hp = config.get("max_hp", 30)
	hp = max_hp

func _physics_process(delta):
	if not is_alive:
		return
	
	update_state()
	execute_state(delta)
	move_and_slide()

func update_state():
	var player = get_tree().get_first_node_in_group("player")
	
	if player and is_instance_valid(player):
		var distance = global_position.distance_to(player.global_position)
		
		if distance <= detection_range:
			target = player
			change_state("chase")
			EventBus.enemy_spotted.emit(self, player)
		else:
			target = null
			if state == "chase":
				change_state("patrol")
				EventBus.enemy_lost_target.emit(self)
	else:
		if state != "idle":
			change_state("patrol")

func execute_state(delta):
	match state:
		"idle":
			velocity = Vector2.ZERO
		"patrol":
			patrol()
		"chase":
			if target:
				chase(delta)
		"attack":
			if target:
				attack(delta)

func patrol():
	# Simple patrol behavior
	var distance_from_start = global_position.distance_to(start_position)
	if distance_from_start > patrol_range:
		velocity = (start_position - global_position).normalized() * config.get("base_speed", 100)
	else:
		velocity = Vector2.ZERO

func chase(_delta):
	var distance_to_target = global_position.distance_to(target.global_position)
	var attack_range = config.get("attack_range", 25)
	
	if distance_to_target <= attack_range:
		change_state("attack")
	else:
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * config.get("base_speed", 100)

func attack(_delta):
	velocity = Vector2.ZERO
	# Attack implementation would go here

func change_state(new_state: String):
	if state != new_state:
		state = new_state
		EventBus.ai_state_changed.emit(self, new_state)

func take_damage(amount: int):
	if not is_alive:
		return
	
	hp -= amount
	hp = max(hp, 0)
	
	EventBus.damage_taken.emit(self, amount, global_position)
	
	if hp <= 0:
		die()

func die():
	is_alive = false
	EventBus.enemy_died.emit(self)
	queue_free()

func _on_attack_area_entered(body):
	if body.is_in_group("player"):
		var damage = config.get("attack_damage", 8)
		CombatSystem.apply_damage(body, damage, {"source": self})

func _on_detection_area_entered(area):
	if area.is_in_group("player") or (area.get_parent() and area.get_parent().is_in_group("player")):
		target = area if area.is_in_group("player") else area.get_parent()
		change_state("chase")

func _on_detection_area_exited(area):
	if area == target:
		target = null

func _on_player_died():
	change_state("idle")

