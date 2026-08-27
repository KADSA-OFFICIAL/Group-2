extends Node2D
class_name DamageNumberSpawner

# 한 광역 타격의 동시 숫자와 연속 타격 여유를 함께 잡은 크기다(#297).
# 32개를 넘기면 가장 오래된 표시를 재사용해 전장 노드 수가 공격 횟수만큼 늘지 않게 한다.
const POOL_SIZE: int = 32
const ENEMY_GROUP: StringName = &"enemy"
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://entities/combat/DamageNumber.tscn")
const HEAL_EFFECT_SHEET: Texture2D = preload("res://assets/sprites/effects/heal.png")
const HEAL_FRAME_COUNT: int = 4
const HEAL_FPS: float = 12.0
# 시트의 발밑 타원(y=80)이 캐릭터 충돌 도형 아래쪽에 오도록 중심을 올린다.
const HEAL_EFFECT_OFFSET := Vector2(0.0, -12.0)

var _pool: Array[DamageNumber] = []
var _next_spawn_order: int = 0


func _ready() -> void:
	_build_pool()
	# Player의 기존 연결은 아군 AI 교전용이다. 시각 리스너는 따로 붙여 책임을 섞지 않는다(#297).
	if not EventBus.damage_taken.is_connected(_on_damage_taken):
		EventBus.damage_taken.connect(_on_damage_taken)
	if not EventBus.healing_applied.is_connected(_on_healing_applied):
		EventBus.healing_applied.connect(_on_healing_applied)


func _exit_tree() -> void:
	if EventBus.damage_taken.is_connected(_on_damage_taken):
		EventBus.damage_taken.disconnect(_on_damage_taken)
	if EventBus.healing_applied.is_connected(_on_healing_applied):
		EventBus.healing_applied.disconnect(_on_healing_applied)


func _build_pool() -> void:
	for index: int in range(POOL_SIZE):
		var number: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
		if number == null:
			push_error("DamageNumberSpawner: DamageNumber 씬을 만들 수 없습니다.")
			return
		number.name = "DamageNumber%d" % index
		add_child(number)
		_pool.append(number)


func _on_damage_taken(target: Variant, damage: int, position: Vector2) -> void:
	var target_node: Node = target as Node
	if target_node == null or not is_instance_valid(target_node):
		return

	var color: Color
	if target_node.is_in_group(ENEMY_GROUP):
		color = UITheme.HOSTILE
	elif target_node.is_in_group(PartySystem.MEMBER_GROUP):
		color = UITheme.CREAM
	else:
		return

	var number: DamageNumber = _acquire_number()
	if number == null:
		return
	_next_spawn_order += 1
	number.play(damage, position, color, _next_spawn_order)


func _on_healing_applied(target: Variant, amount: int) -> void:
	var target_node: Node2D = target as Node2D
	if target_node == null or not is_instance_valid(target_node) or amount <= 0:
		return
	if not target_node.is_in_group(PartySystem.MEMBER_GROUP):
		return

	var number: DamageNumber = _acquire_number()
	if number != null:
		_next_spawn_order += 1
		number.play(amount, target_node.global_position, UITheme.POSITIVE, _next_spawn_order)

	var effect := SpriteSheetEffect.new()
	effect.name = "HealEffect"
	target_node.add_child(effect)
	effect.position = HEAL_EFFECT_OFFSET
	effect.setup(HEAL_EFFECT_SHEET, HEAL_FRAME_COUNT, HEAL_FPS)


func _acquire_number() -> DamageNumber:
	for number: DamageNumber in _pool:
		if not number.is_active():
			return number

	var oldest: DamageNumber = _pool[0] if not _pool.is_empty() else null
	for number: DamageNumber in _pool:
		if oldest == null or number.get_spawn_order() < oldest.get_spawn_order():
			oldest = number
	return oldest
