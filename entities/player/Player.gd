extends CharacterBody2D
class_name Player

# 스텟 바탕: PlayerStats가 HP/공격력/방어력의 단일 출처다.
# 씬에서 .tres로 교체 주입할 수 있도록 export 한다.
@export var stats: PlayerStats = PlayerStats.new()

var hp: int = 0
var max_hp: int = 0
var is_alive: bool = true

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

func _ready():
	name = "Player"
	add_to_group("player")
	max_hp = stats.get_max_hp()
	hp = max_hp

func _physics_process(_delta):
	if not is_alive:
		return

func take_damage(amount: int, _source = null):
	if not is_alive:
		return

	# 방어력 적용: 최소 1의 피해는 들어간다 (바탕 규칙, 수치는 추후 튜닝).
	var dealt = max(amount - stats.get_physical_defense(), 1)
	hp -= dealt
	hp = max(hp, 0)

	if EventBus:
		EventBus.damage_taken.emit(self, dealt, global_position)

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

