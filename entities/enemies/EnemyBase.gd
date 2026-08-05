extends CharacterBody2D
class_name EnemyBase

# 적 정의 바탕: EnemyData가 적의 유일한 정의 출처다(EnemyDatabase로 조회).
# 설정되면 이 정의의 스텟/외형을 사용한다.
# 비어 있으면 아래 stats를 그대로 쓰므로 기존 씬은 그대로 동작한다(하위 호환).
@export var data: EnemyData = null

# 스텟 바탕: PlayerStats를 적의 HP/방어력 출처로 재사용한다.
# (faith/intelligence는 적에게 미사용, 기본값 유지)
# 씬에서 .tres로 교체 주입할 수 있도록 export 한다.
@export var stats: PlayerStats = PlayerStats.new()

var hp: int = 0
var max_hp: int = 0
var is_alive: bool = true

# 유효한 스텟 출처를 반환한다.
# data가 설정되어 있으면 그 정의의 스텟이 우선한다(적 정의가 단일 출처).
# 스텟 계산은 언제나 PlayerStats가 소유하므로 여기서 수치를 다시 만들지 않는다.
func get_stats() -> PlayerStats:
	if data != null:
		return data.get_stats()
	if stats == null:
		stats = PlayerStats.new()
	return stats

func _ready():
	GameManager.register_enemy(self)
	_apply_data()
	max_hp = get_stats().get_max_hp()
	hp = max_hp

# EnemyData가 설정된 경우에만 정의의 외형을 반영한다.
# data가 없으면 씬에 저작된 값을 건드리지 않는다.
#
# 노드 name은 건드리지 않는다: name은 씬 트리 식별자이고 display_name은 UI 표시용이다.
# (Godot이 name을 유일화하므로 둘을 섞으면 표시 이름이 깨진다.)
# 표시 이름이 필요한 UI는 data.display_name을 직접 읽는다.
func _apply_data() -> void:
	if data == null:
		return

	var sprite := get_node_or_null("Sprite2D")
	if sprite is Sprite2D:
		if data.sprite_texture != null:
			sprite.texture = data.sprite_texture
		sprite.self_modulate = data.tint
		sprite.scale = data.sprite_scale

func _exit_tree():
	GameManager.unregister_enemy(self)

func take_damage(amount: int, _source = null):
	if not is_alive:
		return

	# 방어력 적용: 최소 1의 피해는 들어간다 (바탕 규칙, 수치는 추후 튜닝).
	var dealt = max(amount - get_stats().get_physical_defense(), 1)
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