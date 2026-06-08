extends EnemyBase

var attack_cooldown: float = 0.0
var attack_timer: float = 0.0

func _ready():
	super._ready()
	name = "TrainingGoblin"

func _physics_process(delta):
	attack_cooldown = max(0, attack_cooldown - delta)
	super._physics_process(delta)
	update_animation()

func attack(delta):
	super.attack(delta)
	
	if target and attack_cooldown <= 0:
		var distance_to_target = global_position.distance_to(target.global_position)
		var attack_range = config.get("attack_range", 25)
		
		if distance_to_target <= attack_range:
			var damage = config.get("attack_damage", 8)
			CombatSystem.apply_damage(target, damage, {"source": self})
			attack_cooldown = config.get("attack_cooldown", 1.5)
			EventBus.attack_performed.emit(self, global_position)
		else:
			# Move closer if out of range
			var direction = (target.global_position - global_position).normalized()
			velocity = direction * config.get("base_speed", 100)
	else:
		velocity = Vector2.ZERO

func update_animation():
	if sprite and velocity.x != 0:
		if velocity.x < 0:
			sprite.flip_h = true
		elif velocity.x > 0:
			sprite.flip_h = false
