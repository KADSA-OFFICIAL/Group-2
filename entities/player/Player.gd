extends CharacterBody2D
class_name Player

# 파티 멤버 캐릭터 노드.
#
# 데이터 출처:
#   - 캐릭터 정의/외형: CharacterData (CharacterDatabase에서 옴)
#   - 스텟/피해 계산: PlayerStats (공격력, 방어 적용)
#   - 이동/공격 수치: CombatConfig.tuning
#   여기서 수치를 새로 만들지 않는다.
#
# 조종 여부는 PartySystem이 정한다. party_index가 조종 중일 때만 입력을 받는다.
# 조종하지 않는 멤버는 이 단계에서 정지한다(AI는 후속 이슈).

# 캐릭터 정의. 설정되면 스텟과 외형을 여기서 가져온다.
# 비어 있으면 아래 stats를 쓰므로 기존 씬도 그대로 동작한다(하위 호환).
@export var data: CharacterData = null

# 스텟 바탕: PlayerStats가 HP/공격력/방어력의 단일 출처다.
# 씬에서 .tres로 교체 주입할 수 있도록 export 한다.
@export var stats: PlayerStats = PlayerStats.new()

# 이 노드가 파티에서 몇 번째 멤버인가. PartySystem이 이 인덱스로 조종 여부를 판단한다.
# -1이면 파티 소속이 아니며, 조종되지 않는다.
@export var party_index: int = -1

var hp: int = 0
var max_hp: int = 0
var is_alive: bool = true

# 평타 쿨다운 잔여 시간(초).
var _attack_cooldown_left: float = 0.0

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape = get_node_or_null("CollisionShape2D")


# 유효한 스텟 출처를 반환한다. data가 있으면 그 정의의 스텟이 우선한다.
func get_stats() -> PlayerStats:
	if data != null:
		return data.get_stats()
	if stats == null:
		stats = PlayerStats.new()
	return stats


func _ready() -> void:
	add_to_group("party_member")
	# 기존 코드/HUD가 "player" 그룹으로 플레이어를 찾으므로 유지한다.
	add_to_group("player")

	_apply_data()

	max_hp = get_stats().get_max_hp()
	hp = max_hp

	if EventBus:
		EventBus.party_control_changed.connect(_on_control_changed)
	_refresh_control_visual()


# CharacterData가 설정된 경우에만 정의의 외형을 반영한다.
# 노드 name은 건드리지 않는다(씬 트리 식별자와 display_name은 별개).
func _apply_data() -> void:
	if data == null:
		return
	if sprite == null:
		sprite = get_node_or_null("Sprite2D")
	if sprite is Sprite2D:
		if data.sprite_texture != null:
			sprite.texture = data.sprite_texture
		sprite.self_modulate = data.tint
		sprite.scale = data.sprite_scale


# ===== 조종 상태 (Control) =====

# 이 멤버를 지금 사람이 조종 중인가.
func is_controlled() -> bool:
	if party_index < 0:
		return false
	return PartySystem.is_controlled(party_index)

func _on_control_changed(_index: int) -> void:
	_refresh_control_visual()

# 조종 중인 멤버를 시각적으로 구분한다.
# 도형 플레이스홀더 단계이므로 밝기로만 표시한다(아트는 추후).
func _refresh_control_visual() -> void:
	if sprite == null:
		return
	sprite.modulate = Color.WHITE if is_controlled() else Color(0.55, 0.55, 0.55, 1.0)


# ===== 이동 / 공격 (Movement / Attack) =====

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left -= delta

	# 조종 중인 멤버만 입력을 받는다.
	# 나머지는 이 단계에서 정지한다(AI는 후속 이슈).
	if not is_controlled():
		velocity = Vector2.ZERO
		return

	_handle_movement()
	move_and_slide()

	if Input.is_action_pressed("attack"):
		try_attack()


func _handle_movement() -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * get_move_speed()

# 실제 이동 속도 = 기본 속도(CombatConfig) x 이속 배수(PlayerStats 버프 채널).
# 원거리 스택 같은 효과가 이속 배수를 올리면 여기 자동 반영된다.
func get_move_speed() -> float:
	return CombatConfig.tuning.base_move_speed * get_stats().get_move_speed_multiplier()

# 실제 평타 쿨다운 = 기본 쿨다운(CombatConfig) / 공속 배수(PlayerStats 버프 채널).
func get_attack_cooldown() -> float:
	var mult := get_stats().get_attack_speed_multiplier()
	if mult <= 0.0:
		return CombatConfig.tuning.base_attack_cooldown
	return CombatConfig.tuning.base_attack_cooldown / mult

func can_attack() -> bool:
	return is_alive and _attack_cooldown_left <= 0.0

# 사거리 안의 적에게 평타를 넣는다. 쿨다운 중이면 아무것도 하지 않는다.
# 피해량은 PlayerStats.get_physical_attack(), 방어 적용은 대상의 apply_defense()가 한다.
func try_attack() -> bool:
	if not can_attack():
		return false

	var target := _find_attack_target()
	if target == null:
		return false

	_attack_cooldown_left = get_attack_cooldown()
	target.take_damage(get_stats().get_physical_attack(), self)
	return true

# 사거리 안에서 가장 가까운 살아있는 적을 찾는다.
# 적 목록은 GameManager가 단일 출처다.
func _find_attack_target() -> Node:
	var nearest := GameManager.get_nearest_enemy(global_position)
	if nearest == null:
		return null
	if not nearest.is_alive:
		return null
	if global_position.distance_to(nearest.global_position) > get_attack_range():
		return null
	return nearest

# 평타 사거리. 씬의 AttackArea2D 위치를 기준으로 삼는다.
# (역할별 사거리 차등은 후속 과제.)
func get_attack_range() -> float:
	var area := get_node_or_null("AttackArea2D")
	if area is Node2D:
		return maxf(area.position.length(), 1.0) * 2.0
	return 60.0


# ===== 피해 / 사망 (Damage / Death) =====

func take_damage(amount: int, _source = null) -> void:
	if not is_alive:
		return

	# 방어력 적용. 피해 공식은 PlayerStats.apply_defense()가 단일 출처다.
	var dealt = get_stats().apply_defense(amount)
	hp -= dealt
	hp = max(hp, 0)

	if EventBus:
		EventBus.damage_taken.emit(self, dealt, global_position)

	if hp <= 0:
		die()

func heal(amount: int) -> void:
	if not is_alive:
		return

	hp += amount
	hp = min(hp, max_hp)

	if EventBus:
		EventBus.healing_applied.emit(self, amount)

func die() -> void:
	is_alive = false
	if EventBus:
		EventBus.player_died.emit()
	queue_free()

func get_health_percent() -> float:
	if max_hp == 0:
		return 0.0
	return float(hp) / float(max_hp)
