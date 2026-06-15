extends CharacterBody2D

# 스텟 바탕: PlayerStats를 적의 HP/방어력 출처로 재사용한다.
# (faith/intelligence는 적에게 미사용, 기본값 유지)
# 씬에서 .tres로 교체 주입할 수 있도록 export 한다.
@export var stats: PlayerStats = PlayerStats.new()

var hp: int = 0
var max_hp: int = 0
var is_alive: bool = true

func _ready():
	GameManager.register_enemy(self)
	max_hp = stats.get_max_hp()
	hp = max_hp

func _exit_tree():
	GameManager.unregister_enemy(self)

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

func die():
	is_alive = false
	if EventBus:
		EventBus.enemy_died.emit(self)
	queue_free()