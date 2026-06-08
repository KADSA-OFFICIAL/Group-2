extends Node
class_name PlayerController

var player: Node
var config: Dictionary = {}
var sprite: Sprite2D
var animation_player: AnimationPlayer
var attack_area: Area2D
var parry_area: Area2D

# Movement variables
var move_direction: Vector2 = Vector2.ZERO
var current_speed: float = 0.0
var is_dashing: bool = false
var dash_time_remaining: float = 0.0

# Attack variables
var attack_cooldown: float = 0.0
var is_attacking: bool = false

# Parry variables
var parry_cooldown: float = 0.0
var parry_active: bool = false

# Input buffer
var input_buffer: Array = []
var buffer_time: float = 0.1

func _ready():
	player = get_parent()
	load_config()
	setup_input_map()
	
	# Find child nodes safely
	sprite = player.get_node_or_null("Sprite2D")
	animation_player = player.get_node_or_null("AnimationPlayer")
	attack_area = player.get_node_or_null("AttackArea2D")
	parry_area = player.get_node_or_null("ParryArea2D")
	
	if attack_area:
		attack_area.area_entered.connect(_on_attack_area_entered)
	
	if parry_area:
		parry_area.area_entered.connect(_on_parry_area_entered)
	
	EventBus.parry_success.connect(_on_parry_success)
	EventBus.player_died.connect(_on_player_died)

func load_config():
	var config_file = FileAccess.open("res://config/player_config.json", FileAccess.READ)
	if config_file:
		var json = JSON.new()
		json.parse(config_file.get_as_text())
		config = json.data

func setup_input_map():
	if not InputMap.has_action("move_right"):
		InputMap.add_action("move_right")
	
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
	
	if not InputMap.has_action("move_up"):
		InputMap.add_action("move_up")
	
	if not InputMap.has_action("move_down"):
		InputMap.add_action("move_down")
	
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
	
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
	
	if not InputMap.has_action("parry"):
		InputMap.add_action("parry")

func _physics_process(delta):
	if not player or not player.is_alive:
		return
	
	update_cooldowns(delta)
	handle_input()
	apply_movement(delta)
	handle_attack(delta)
	handle_parry(delta)
	
	player.move_and_slide()
	update_animation()

func handle_input():
	move_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if Input.is_action_just_pressed("dash"):
		perform_dash()
	
	if Input.is_action_just_pressed("attack"):
		buffer_input("attack")
	
	if Input.is_action_just_pressed("parry"):
		buffer_input("parry")

func apply_movement(delta):
	if is_dashing:
		return
	
	if move_direction.length() > 0:
		current_speed = config.get("max_speed", 300)
		player.velocity = move_direction.normalized() * current_speed
	else:
		var friction = config.get("friction", 800)
		player.velocity = player.velocity.lerp(Vector2.ZERO, friction * delta)

func perform_dash():
	if is_dashing or GameManager.active_enemies.is_empty():
		return
	
	var _dash_cooldown = config.get("dash_cooldown", 1.0)
	if dash_time_remaining > 0:
		return
	
	is_dashing = true
	dash_time_remaining = config.get("dash_duration", 0.3)
	
	var nearest_enemy = GameManager.get_nearest_enemy(player.global_position)
	if nearest_enemy:
		var direction = (nearest_enemy.global_position - player.global_position).normalized()
		player.velocity = direction * config.get("dash_speed", 400)
	
	EventBus.dash_performed.emit(player.global_position)

func handle_attack(delta):
	attack_cooldown = max(0, attack_cooldown - delta)
	
	if input_buffer.has("attack") and attack_cooldown <= 0:
		input_buffer.erase("attack")
		
		var nearest_enemy = GameManager.get_nearest_enemy(player.global_position)
		if nearest_enemy:
			var damage = config.get("attack_damage", 15)
			var range_dist = config.get("attack_range", 30)
			
			if player.global_position.distance_to(nearest_enemy.global_position) <= range_dist:
				CombatSystem.apply_damage(nearest_enemy, damage, {"source": player})
				var knockback = config.get("knockback_force", 200)
				var direction = (nearest_enemy.global_position - player.global_position).normalized()
				CombatSystem.apply_knockback(nearest_enemy, knockback, direction)
				EventBus.attack_performed.emit(player, player.global_position)
		
		attack_cooldown = config.get("attack_cooldown", 0.5)
		is_attacking = true
	else:
		is_attacking = false

func handle_parry(delta):
	parry_cooldown = max(0, parry_cooldown - delta)
	
	if input_buffer.has("parry") and parry_cooldown <= 0:
		input_buffer.erase("parry")
		
		var parry_window = config.get("parry_window", 0.2)
		ParrySystem.open_parry_window(parry_window)
		
		parry_cooldown = config.get("parry_cooldown", 1.0)
		parry_active = true
	
	if parry_active and not ParrySystem.is_parry_active():
		parry_active = false

func update_cooldowns(delta):
	if is_dashing:
		dash_time_remaining -= delta
		if dash_time_remaining <= 0:
			is_dashing = false

func update_animation():
	if sprite and player.velocity.x != 0:
		if player.velocity.x < 0:
			sprite.flip_h = true
		elif player.velocity.x > 0:
			sprite.flip_h = false

func buffer_input(action: String):
	if not input_buffer.has(action):
		input_buffer.append(action)

func _on_attack_area_entered(body):
	if body is Damageable and body != player:
		var damage = config.get("attack_damage", 15)
		CombatSystem.apply_damage(body, damage, {"source": player})

func _on_parry_area_entered(_area):
	# Parry detection through Area2D
	pass

func _on_parry_success(_position):
	if parry_active:
		# Gain knockback effect or damage bonus
		pass

func _on_player_died():
	set_physics_process(false)


