extends Node
class_name Damageable

var hp: int = 100
var max_hp: int = 100
var is_alive: bool = true

func _ready():
	hp = max_hp

func take_damage(amount: int, _source = null):
	if not is_alive:
		return
	
	hp -= amount
	hp = max(hp, 0)
	
	if EventBus:
		var pos = Vector2.ZERO
		if owner and owner.has_method("get_global_position"):
			pos = owner.global_position
		EventBus.damage_taken.emit(self, amount, pos)
	
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
		if is_in_group("player"):
			EventBus.player_died.emit()
		else:
			EventBus.enemy_died.emit(self)
	queue_free()

func get_health_percent() -> float:
	if max_hp == 0:
		return 0.0
	return float(hp) / float(max_hp)
