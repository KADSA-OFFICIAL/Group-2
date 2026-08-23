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

# 지금까지 나간 평타 횟수. **적중이 아니라 발생** 기준이다.
# SkillData.every_n_attacks 패시브가 이 값을 본다(주기 판정이라 리셋하지 않는다).
var _attack_swing_count: int = 0

# ===== 대시 (Dash) =====
# 로스터 전원 공용 회피 조작(#235). 수치는 CombatTuning 이 소유한다.
#
# 충전은 **다 쓴 뒤 한꺼번에** 돌아온다(한 발씩 개별 재충전이 아니다).
# "두 번 쓰면 쿨타임이 돌아야 다시 쓸 수 있다"가 확정 스펙이라 그대로 옮겼다.

## 남은 대시 횟수. 0 이 되면 _dash_cooldown_left 가 돌고, 끝나면 전부 복구된다.
var _dash_charges: int = -1        # -1 = 아직 초기화 안 됨(_ready 에서 채운다)
## 대시가 남은 시간(초). 0 보다 크면 지금 대시 중이다.
var _dash_time_left: float = 0.0
## 대시 진행 방향(정규화). 대시 중에는 입력을 무시하고 이 방향으로 나간다.
var _dash_direction: Vector2 = Vector2.DOWN
## 충전 재보급까지 남은 시간(초).
var _dash_cooldown_left: float = 0.0
## 마지막으로 실제 움직인 방향. 방향 입력 없이 대시했을 때 쓴다.
var _last_move_direction: Vector2 = Vector2.DOWN

@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var collision_shape = get_node_or_null("CollisionShape2D")

# 워크 애니메이션을 그리는 노드. 씬에 AnimatedSprite2D가 있고 data.walk_frames가
# 채워져 있을 때만 잡힌다. null이면 이 스크립트는 외형을 Sprite2D로만 다루므로
# 시트가 없는 캐릭터는 지금까지와 똑같이 도형 플레이스홀더로 남는다.
var _anim_sprite: AnimatedSprite2D = null


# 이 노드가 소유하는 런타임 스텟. 정의(CharacterData)의 스텟 사본이다.
#
# 왜 사본인가: .tres는 경로 기준으로 캐시되므로 CharacterDatabase가 돌려주는 정의는
# 로스터 전체가 공유하는 **하나의 인스턴스**다. StatusEffectData가 PlayerStats의 버프
# 채널을 대상으로 삼기 때문에, 공유된 채로 두면 한 노드에 건 버프/디버프가 같은 정의를
# 쓰는 쪽 전부에 걸리고, 스테이지를 다시 열어도 이전 판의 버프 잔재가 남는다.
# 정의(.tres)는 읽기 전용 데이터로 남기고, 전투 중 변하는 값은 노드가 소유한다.
var _runtime_stats: PlayerStats = null

# 유효한 스텟 출처를 반환한다. data가 있으면 그 정의의 스텟이 사본의 바탕이 된다.
func get_stats() -> PlayerStats:
	if _runtime_stats == null:
		_runtime_stats = _make_runtime_stats()
	return _runtime_stats

# 정의(또는 씬에 주입된 stats)에서 이 노드만의 스텟 사본을 만든다.
# 처음 get_stats()가 불릴 때 한 번만 만들어지므로, 씬이 export로 주입한 값이 반영된 뒤다.
# duplicate(true): 이후 PlayerStats에 하위 리소스가 추가되어도 같이 복제되게 한다.
func _make_runtime_stats() -> PlayerStats:
	var source: PlayerStats = data.get_stats() if data != null else stats
	if source == null:
		return PlayerStats.new()
	return source.duplicate(true)


func _ready() -> void:
	# 그룹 이름의 단일 출처는 PartySystem.MEMBER_GROUP이다(문자열을 여기 다시 적지 않는다).
	add_to_group(PartySystem.MEMBER_GROUP)
	# 기존 코드/HUD가 "player" 그룹으로 플레이어를 찾으므로 유지한다.
	add_to_group("player")

	_apply_data()

	max_hp = get_stats().get_max_hp()
	hp = max_hp

	if EventBus:
		EventBus.party_control_changed.connect(_on_control_changed)
		# 스텟을 사본으로 떼어 놓으면 정의 쪽 장착 변경이 더 이상 자동으로 닿지 않는다.
		# (전에는 정의의 PlayerStats를 그대로 써서 우연히 반영되고 있었다.)
		# 그래서 자기 캐릭터의 착탈만 골라 장비 채널을 다시 밀어 넣는다.
		EventBus.equipment_equipped.connect(func(character_id, _eid, _slot): _sync_equipment_bonuses(character_id))
		EventBus.equipment_unequipped.connect(func(character_id, _slot): _sync_equipment_bonuses(character_id))
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

	# 워크 시트가 있으면 AnimatedSprite2D가 외형을 맡고 도형 플레이스홀더는 숨는다.
	# 둘 중 하나만 보이게 해서 실제 아트 위에 도형이 겹쳐 보이지 않게 한다.
	#
	# tint를 입히지 않는 이유: tint는 흰색 도형을 칠하려고 둔 값이라
	# 색이 있는 실제 아트에 곱하면 색이 죽는다(CharacterData.tint 주석 참고).
	var anim := get_node_or_null("AnimatedSprite2D")
	if anim is AnimatedSprite2D and data.walk_frames != null:
		_anim_sprite = anim
		_anim_sprite.sprite_frames = data.walk_frames
		_anim_sprite.scale = data.walk_sprite_scale
		_anim_sprite.offset = data.walk_sprite_offset
		# 첫 프레임은 정면 정지 포즈로 둔다. animation을 지정하지 않으면 기본값 &"default"를
		# 찾다가 없어서 경고가 난다.
		_anim_sprite.animation = WalkAnimation.ANIMATIONS[WalkAnimation.DOWN]
		_anim_sprite.frame = 0
		_anim_sprite.visible = true
		if sprite is Sprite2D:
			sprite.visible = false


# ===== 조종 상태 (Control) =====

# 이 멤버를 지금 사람이 조종 중인가.
func is_controlled() -> bool:
	if party_index < 0:
		return false
	return PartySystem.is_controlled(party_index)

func _on_control_changed(_index: int) -> void:
	_refresh_control_visual()


# ===== 장비 (Equipment) =====

# 장비 보너스를 정의에서 다시 읽어 이 노드의 스텟 사본에 반영한다.
# 보너스 합산의 출처는 CharacterData.get_equipment_bonuses()다(여기서 다시 세지 않는다).
# 다른 캐릭터의 착탈이면 아무것도 하지 않는다.
func _sync_equipment_bonuses(character_id: StringName) -> void:
	if data == null or character_id != data.character_id:
		return
	var bonuses := data.get_equipment_bonuses()
	get_stats().set_equipment_bonuses(
		bonuses["physical_attack"], bonuses["magic_attack"],
		bonuses["physical_defense"], bonuses["magic_defense"], bonuses["hp"]
	)

# 조종 중인 멤버를 시각적으로 구분한다. 밝기로만 표시한다.
#
# 지금 화면에 보이는 노드에 걸어야 한다. 워크 시트를 쓰는 캐릭터는 Sprite2D가
# 숨어 있으므로 거기에 modulate를 걸면 조종 표시가 아무 효과도 내지 않는다.
# self_modulate가 아니라 modulate인 이유: self_modulate는 _apply_data()가 tint용으로
# 쓰고 있어서, 같은 채널에 조종 밝기를 겹쳐 쓰면 서로를 지운다.
func _refresh_control_visual() -> void:
	var target: CanvasItem = _anim_sprite if _anim_sprite != null else sprite
	if target == null:
		return
	target.modulate = Color.WHITE if is_controlled() else Color(0.55, 0.55, 0.55, 1.0)


# ===== 이동 / 공격 (Movement / Attack) =====

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left -= delta

	_decay_stack(delta)

	_tick_dash(delta)
	_tick_skill_shield(delta)

	_process_control(delta)

	# 조종 중이 아니어도(velocity가 계속 0) 호출한다. 그래야 정지 포즈로 고정된다.
	_update_walk_animation()


# 입력 처리 한 틱. velocity를 정하고 필요하면 실제로 이동시킨다.
# 외형 갱신과 분리해 둔 이유: 아래 조기 반환이 애니메이션 갱신까지 건너뛰면
# 조종을 넘긴 멤버가 멈춘 뒤에도 걷는 모션이 남기 때문이다.
func _process_control(_delta: float) -> void:
	# 조종 중인 멤버만 입력을 받는다.
	# 나머지는 이 단계에서 정지한다(AI는 후속 이슈).
	if not is_controlled():
		velocity = Vector2.ZERO
		return

	# 기절 등 CONTROL 효과가 이동을 막으면 움직이지 않는다.
	if StatusEffectSystem.blocks_movement(self):
		velocity = Vector2.ZERO
		# 기절 등으로 이동이 막히면 진행 중인 대시도 끊는다.
		_dash_time_left = 0.0
	else:
		if Input.is_action_just_pressed("dash"):
			try_dash()
		if _dash_time_left > 0.0:
			# 대시 중에는 이동 입력을 무시한다. 방향은 시작할 때 정해졌다.
			velocity = _dash_direction * get_dash_speed()
		else:
			_handle_movement()
	move_and_slide()

	if Input.is_action_pressed("attack"):
		try_attack()

	# 고유 스킬은 사람이 직접 눌러야 발동한다(docs §4 [확정]: AI 는 스킬을 쓰지 않는다).
	if Input.is_action_just_pressed("skill_q"):
		try_use_skill(SkillData.InputSlot.Q)
	if Input.is_action_just_pressed("skill_e"):
		try_use_skill(SkillData.InputSlot.E)


# ===== 워크 애니메이션 (Walk animation) =====

# 지금 속도에 맞는 방향 애니메이션을 재생한다. 멈춰 있으면 정지 포즈로 고정한다.
# 시트가 없는 캐릭터는 _anim_sprite가 null이라 아무 일도 하지 않는다.
#
# 방향 판정과 멈춤 임계값의 출처는 WalkAnimation이다(적과 같은 규약을 쓴다).
func _update_walk_animation() -> void:
	if _anim_sprite == null:
		return

	if not WalkAnimation.is_walking(velocity):
		# 멈추면 재생을 세우고 정지 포즈(0번 프레임)로 고정한다.
		# animation은 그대로 두어 마지막으로 향했던 방향을 유지한다
		# — 멈출 때마다 정면으로 홱 돌아보면 어색하기 때문이다.
		if _anim_sprite.is_playing():
			_anim_sprite.stop()
			_anim_sprite.frame = 0
		return

	var anim := WalkAnimation.animation_for(velocity)
	if _anim_sprite.animation != anim or not _anim_sprite.is_playing():
		_anim_sprite.play(anim)


func _handle_movement() -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# 방향 입력이 없는 대시를 위해 마지막 이동 방향을 기억한다.
	if direction != Vector2.ZERO:
		_last_move_direction = direction.normalized()
	velocity = direction * get_move_speed()


# ===== 고유 스킬 (Unique skill) =====

# 키 슬롯(Q·E)에 걸린 고유 스킬을 발동한다. 슬롯이 비어 있으면 아무 일도 하지 않는다.
#
# 이 스킬의 조작은 **누르기 두 번**이다:
#   1회 — 자기와 가장 위험한 파티원에게 보호막을 두른다.
#   2회 — 살아 있는 보호막을 그 즉시 전부 터뜨린다(보호막을 포기하고 타이밍을 얻는다).
# 누르지 않아도 보호막이 깨지거나 지속시간이 끝나면 알아서 터진다.
#
# 슬롯 해석의 단일 출처는 CharacterData.get_skill_for_slot() 이다.
func try_use_skill(slot: SkillData.InputSlot) -> bool:
	if not is_alive or data == null:
		return false
	# 기절 등 CONTROL 효과가 스킬을 막으면 쓸 수 없다(평타·이동과 같은 규약).
	if StatusEffectSystem.blocks_skill(self):
		return false

	var skill := data.get_skill_for_slot(slot)
	if skill == null:
		return false

	# 같은 슬롯을 한 번 더 누르면 **살아 있는 보호막이 그 즉시 전부 터진다.**
	# 보호막을 포기하는 대신 폭발 타이밍을 얻는 것이 이 스킬의 조작이다.
	if _detonate_shields_from(skill) > 0:
		if EventBus:
			EventBus.skill_used.emit(self, skill.skill_id)
		return true

	if skill.shield_percent > 0.0:
		_cast_shield_skill(skill)
	if EventBus:
		EventBus.skill_used.emit(self, skill.skill_id)
	return true


# ===== 스킬 보호막 (Skill shield) =====

# 시전: 자기 자신과 **파티에서 가장 체력이 낮은 파티원**에게 보호막을 두른다.
#
# "가장 체력이 낮은"은 **비율** 기준이다. 절대량으로 재면 최대 체력이 작은 멤버가
# 만피여도 뽑히는데(1000 만피 < 1200 중 1100), 위험한 쪽을 지키는 스킬의 의도와 어긋난다.
func _cast_shield_skill(skill: SkillData) -> void:
	_apply_skill_shield(skill, self)
	var ally := _lowest_health_ally()
	if ally != null:
		ally._apply_skill_shield(skill, self)


# 자기를 뺀 파티원 중 체력 비율이 가장 낮은 쪽. 없으면 null.
func _lowest_health_ally() -> Node:
	var best: Node = null
	var best_percent := INF
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if node == self or not is_instance_valid(node) or not node.is_alive:
			continue
		var percent: float = node.get_health_percent()
		if percent < best_percent:
			best_percent = percent
			best = node
	return best


# 이 노드에 스킬 보호막을 씌운다. 한도(shield_max_percent)에 걸려 실제로 못 받은 만큼은
# 스킬 몫으로 세지 않는다 — 없는 보호막이 깨지기를 기다리면 폭발이 나지 않는다.
func _apply_skill_shield(skill: SkillData, caster: Node) -> void:
	var amount := int(round(max_hp * skill.shield_percent))
	if amount <= 0:
		return

	var before := _shield
	_gain_shield(amount)
	var gained := _shield - before
	if gained <= 0:
		return

	_skill_shield = gained
	_skill_shield_time_left = skill.shield_duration
	_skill_shield_skill = skill
	_skill_shield_caster = caster


# 지속시간 한 틱. 시간이 다 되면 그 자리에서 터진다.
func _tick_skill_shield(delta: float) -> void:
	if _skill_shield_time_left <= 0.0:
		return
	_skill_shield_time_left -= delta
	if _skill_shield_time_left <= 0.0:
		_skill_shield_time_left = 0.0
		_detonate_skill_shield()


# 이 시전자가 준 보호막을 파티 전체에서 찾아 즉시 터뜨린다. 터진 개수를 반환한다.
#
# 자기 것만 보지 않는 이유: 자기 보호막이 먼저 깨져 이미 터졌더라도 파티원 쪽은
# 아직 살아 있을 수 있다. 그때 한 번 더 누른 것은 "남은 것을 터뜨려라"다.
func _detonate_shields_from(skill: SkillData) -> int:
	var count := 0
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if not is_instance_valid(node):
			continue
		if node._skill_shield_caster != self or node._skill_shield_skill != skill:
			continue
		if node._skill_shield <= 0:
			continue
		node._detonate_skill_shield()
		count += 1
	return count


# 이 노드에 걸린 스킬 보호막을 터뜨린다. 폭발은 **이 노드 자리**에서 난다
# — 보호막이 2개면 폭발도 2번, 각자의 자리다.
#
# 남은 보호막은 사라진다. 깨져서 터질 때는 이미 0이라 뺄 것이 없고,
# 만료·즉시 폭발로 터질 때는 남은 보호막을 대가로 지불하는 셈이다.
func _detonate_skill_shield() -> void:
	var skill := _skill_shield_skill
	var caster := _skill_shield_caster
	var remaining := _skill_shield

	_shield = maxi(_shield - remaining, 0)
	_skill_shield = 0
	_skill_shield_time_left = 0.0
	_skill_shield_skill = null
	_skill_shield_caster = null

	if skill == null or skill.aoe_radius <= 0.0:
		return

	# 위력은 **시전자**의 신앙심으로 스케일한다. 보호막을 두른 사람이 아니라 건 사람의 힘이다.
	var boost := 1.0
	if caster != null and is_instance_valid(caster):
		boost = caster.get_stats().get_goddess_skill_boost()
	var power := skill.get_effective_power(boost)
	if power <= 0:
		return

	var origin := global_position
	for enemy in GameManager.get_all_enemies():
		if enemy == null or not enemy.is_alive:
			continue
		if origin.distance_to(enemy.global_position) > skill.aoe_radius:
			continue
		enemy.take_damage(power, caster)

	if EventBus:
		EventBus.skill_shield_burst.emit(self, skill.skill_id, origin, power)


func get_skill_shield() -> int:
	return _skill_shield


func get_skill_shield_time_left() -> float:
	return _skill_shield_time_left
	return true


# ===== 대시 (Dash) =====

# 대시 타이머 한 틱. 충전은 쿨타임이 끝나는 순간 전부 돌아온다.
func _tick_dash(delta: float) -> void:
	if _dash_charges < 0:
		_dash_charges = CombatConfig.tuning.dash_charges

	if _dash_time_left > 0.0:
		_dash_time_left = maxf(_dash_time_left - delta, 0.0)

	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left -= delta
		if _dash_cooldown_left <= 0.0:
			_dash_cooldown_left = 0.0
			_dash_charges = CombatConfig.tuning.dash_charges


# 대시 속도. 이속 배수를 타지 않는다 — 회피 거리는 예측 가능해야 한다(CombatTuning 주석).
func get_dash_speed() -> float:
	var tuning := CombatConfig.tuning
	return tuning.base_move_speed * tuning.dash_speed_multiplier


func can_dash() -> bool:
	if not is_alive:
		return false
	if _dash_charges <= 0:
		return false
	# 대시 중에 다시 대시할 수는 없다. 대시가 끝난 직후의 두 번째 대시는 된다.
	if _dash_time_left > 0.0:
		return false
	return not StatusEffectSystem.blocks_movement(self)


# 대시를 시작한다. 방향을 주지 않으면 지금 이동 입력 방향, 그것도 없으면
# 마지막으로 움직인 방향으로 나간다.
#
# direction 인자를 둔 이유: 입력 없이도 호출해 검증할 수 있어야 한다.
func try_dash(direction: Vector2 = Vector2.ZERO) -> bool:
	if _dash_charges < 0:
		_dash_charges = CombatConfig.tuning.dash_charges
	if not can_dash():
		return false

	var dir := direction
	if dir == Vector2.ZERO:
		dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir == Vector2.ZERO:
		dir = _last_move_direction

	_dash_direction = dir.normalized()
	_dash_time_left = CombatConfig.tuning.dash_duration
	_dash_charges -= 1
	if _dash_charges <= 0:
		_dash_cooldown_left = CombatConfig.tuning.dash_cooldown
	return true


func is_dashing() -> bool:
	return _dash_time_left > 0.0


func get_dash_charges() -> int:
	return maxi(_dash_charges, 0)


func get_dash_cooldown_left() -> float:
	return _dash_cooldown_left


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
	# 기절 등 CONTROL 효과가 평타를 막으면 공격할 수 없다.
	return is_alive and _attack_cooldown_left <= 0.0 and not StatusEffectSystem.blocks_attack(self)

# 사거리 안의 적에게 평타를 넣는다. 쿨다운 중이면 아무것도 하지 않는다.
# 피해량은 PlayerStats.get_physical_attack(), 방어 적용은 대상의 apply_defense()가 한다.
#
# 평타는 역할 메커니즘(§8.1 시너지 1단계)이 걸리는 지점이기도 하다.
# 순서: 처형 판정 -> 피해 -> 표식 부여 -> 표식 충전 -> 스택 축적
func try_attack() -> bool:
	if not can_attack():
		return false

	var target := _find_attack_target()
	if target == null:
		return false

	_attack_cooldown_left = get_attack_cooldown()

	# 평타 발생을 먼저 센다. 처형으로 끝나거나 적을 죽인 평타도 "나간 평타"다.
	_attack_swing_count += 1
	_apply_attack_passives()

	# 패시브 광역 피해가 대상을 먼저 죽일 수 있다.
	if not is_instance_valid(target) or not target.is_alive:
		_gain_stack()
		return true

	# 버퍼: 조건이 맞으면 피해 대신 처형한다.
	if _try_execute(target):
		_gain_stack()
		return true

	var dealt: int = target.take_damage(get_stats().get_physical_attack(), self)

	# 원거리 3단계: 실제로 준 피해에 비례해 회복한다(죽인 타격도 포함이다).
	_apply_lifesteal(dealt)

	# 대상이 이 평타로 죽었으면 이후 처리를 하지 않는다.
	if not is_instance_valid(target) or not target.is_alive:
		_gain_stack()
		return true

	# 탱커: 표식을 부여한다(이미 있으면 StatusEffectData의 중첩 규칙대로).
	if _is_role_active(CharacterData.Role.TANK):
		StatusEffectSystem.apply(target, MARK_EFFECT, self)

	# 표식 충전은 **파티 전체**의 평타로 이뤄진다(탱커 본인만이 아니다).
	_charge_mark(target)

	# 원거리: 스택을 쌓는다.
	_gain_stack()
	return true


# ===== 평타 패시브 (Basic-attack passives) =====
#
# 캐릭터 고유 스킬(SkillData) 중 every_n_attacks 가 설정된 것은 평타 주기로 발동한다.
# 역할 메커니즘(아래)과 달리 **파티 구성과 무관하다** — 시너지가 아니라 캐릭터 개성이라
# 혼자 있어도 작동한다(docs §3 티어2).
#
# 데이터가 없으면 아무 일도 하지 않으므로, 패시브를 저작하지 않은 캐릭터의 평타는 이전과 같다.
func _apply_attack_passives() -> void:
	if data == null:
		return
	for skill in data.skills:
		if skill == null or skill.every_n_attacks <= 0:
			continue
		if _attack_swing_count % skill.every_n_attacks != 0:
			continue
		_fire_attack_passive(skill)


# 회복하고, 실제로 회복한 양에 비례해 주변 적에게 광역 피해를 준다.
#
# 기준이 "최대 체력"이 아니라 "잃은 체력"이라 체력이 가득 차 있으면 회복이 0이고,
# 광역 피해도 회복량에 비례하므로 함께 0이 된다. 몰릴수록 세지는 것이 의도다.
func _fire_attack_passive(skill: SkillData) -> void:
	var healed := 0
	if skill.heal_missing_hp_percent > 0.0:
		var missing: int = max_hp - hp
		healed = int(round(missing * skill.heal_missing_hp_percent))
		if healed > 0:
			heal(healed)

	if healed <= 0 or skill.heal_to_aoe_damage_percent <= 0.0 or skill.aoe_radius <= 0.0:
		return

	var amount := int(round(healed * skill.heal_to_aoe_damage_percent))
	if amount <= 0:
		return

	for enemy in GameManager.get_all_enemies():
		if enemy == null or not enemy.is_alive:
			continue
		if global_position.distance_to(enemy.global_position) > skill.aoe_radius:
			continue
		enemy.take_damage(amount, self)


# ===== 역할 메커니즘 (Role Mechanics) =====
# 메커니즘은 시너지 1단계가 곧 역할 정체성이라는 설계(docs §2)를 따른다.
# 그래서 "이 캐릭터가 그 역할을 가졌는가" + "파티에서 그 역할 시너지가 켜졌는가"를 함께 본다.

const MARK_EFFECT := &"mark"
const STACK_BONUS_KEY := &"ranged_stack"

# 원거리 스택. 정수 단위로 서서히 감소하므로 float로 들고 표시할 때 내림한다.
var _stack: float = 0.0

# 보호막. 피해를 체력보다 먼저 흡수한다(원거리 3단계의 초과 피흡분에서만 쌓인다).
#
# 왜 별도 자원인가: 초과 회복분을 체력으로 되돌리면 "가득 찬 뒤"라는 조건이 무의미해진다.
# docs §6 이 보호막을 HUD 미표시로 둔 것은 자원이 없었기 때문이고, 생겼으므로 표시한다.
var _shield: int = 0

# ----- 스킬 보호막 (Skill shield) -----
# 고유 스킬이 준 보호막은 위 _shield 풀 안에 있지만, **그중 얼마가 이 스킬 몫인지**를
# 따로 센다. 원거리 3단계가 준 보호막과 구분해야 하기 때문이다 —
# 그쪽 보호막이 깎였다고 스킬 폭발이 나면 안 된다.
#
# 폭발 계기가 세 가지다: 깨짐(_skill_shield 가 0) / 만료(_skill_shield_time_left 가 0) /
# 시전자가 같은 슬롯을 한 번 더 누름(즉시).
var _skill_shield: int = 0
var _skill_shield_time_left: float = 0.0
var _skill_shield_skill: SkillData = null
var _skill_shield_caster: Node = null

# 이 멤버에게 해당 역할의 메커니즘이 활성인가.
# 배타 규칙(#73)이 get_active_tiers()에 이미 반영되어 있으므로,
# 다른 역할이 3단계를 발동하면 여기서도 자동으로 꺼진다.
func _is_role_active(role: CharacterData.Role) -> bool:
	if data == null or not data.has_role(role):
		return false
	return SynergySystem.is_tier1_active(PartySystem.get_members(), role)


# 이 멤버에게 해당 역할의 **3단계**가 활성인가.
# 3단계는 1단계 위에 추가로 누적된다(docs §8.1) — 1단계를 대체하지 않는다.
func _is_role_tier3(role: CharacterData.Role) -> bool:
	if data == null or not data.has_role(role):
		return false
	return SynergySystem.is_tier3_active(PartySystem.get_members(), role)


# --- 탱커: 표식 → 기절 + 추가 피해 ---

# 표식이 걸린 대상이면 게이지를 채운다. 임계치에서 터지면 추가 피해를 넣는다.
# 충전은 역할과 무관하게 파티 전체가 한다(표식은 파티 공동 자원).
func _charge_mark(target: Node) -> void:
	if not StatusEffectSystem.has_effect(target, MARK_EFFECT):
		return

	# 표식을 건 주체(탱커)를 폭발 피해 계산에 쓰려고 미리 붙잡는다.
	var marker := StatusEffectSystem.get_source(target, MARK_EFFECT)

	if not StatusEffectSystem.add_gauge(target, MARK_EFFECT):
		return

	# 터졌다: 기절은 StatusEffectSystem이 이미 걸었고, 여기서는 추가 피해만 넣는다.
	_apply_mark_burst_damage(target, marker)

	# 탱커 3단계: 기절시킨 대가로 표식을 건 탱커가 회복한다.
	# 때린 사람이 아니라 **표식 주체**가 받는다 — 표식은 탱커의 메커니즘이고,
	# 충전은 파티 전체가 하기 때문이다.
	if is_instance_valid(marker) and marker.has_method("_on_stunned_enemy"):
		marker._on_stunned_enemy()


func _apply_mark_burst_damage(target: Node, marker: Node) -> void:
	if not is_instance_valid(target) or not target.is_alive:
		return

	# 추가 피해 = 표식을 건 탱커의 물리 공격력 x 배수.
	# 표식 주체가 사라졌으면 때린 사람 기준으로 대체한다.
	var attacker: Node = marker if is_instance_valid(marker) and marker.has_method("get_stats") else self
	var power := int(round(attacker.get_stats().get_physical_attack() * CombatConfig.tuning.mark_burst_damage_multiplier))
	target.take_damage(power, self)


# --- 원거리: 평타 스택 ---

# 평타 적중 시 스택을 쌓는다.
func _gain_stack() -> void:
	if not _is_role_active(CharacterData.Role.RANGED_DEALER):
		return
	_stack = minf(_stack + CombatConfig.tuning.stack_gain_per_hit, float(CombatConfig.tuning.stack_max))
	_push_stack_bonus()

# 스택은 놓으면 서서히 감소한다(docs §4.1의 전투 리듬).
# 조종 중일 때보다 미조종(AI) 중일 때 더 빨리 빠진다.
func _decay_stack(delta: float) -> void:
	if _stack <= 0.0:
		return

	# 역할 시너지가 꺼졌으면 스택을 즉시 정리한다.
	if not _is_role_active(CharacterData.Role.RANGED_DEALER):
		_stack = 0.0
		_push_stack_bonus()
		return

	var rate := CombatConfig.tuning.stack_decay_per_sec_controlled if is_controlled() \
		else CombatConfig.tuning.stack_decay_per_sec_uncontrolled
	_stack = maxf(_stack - rate * delta, 0.0)
	_push_stack_bonus()

# 현재 스택 수(표시·판정용). 내림한 정수다.
func get_stack_count() -> int:
	return int(floor(_stack))

# 스택 보너스를 버프 채널에 반영한다.
# 직접 set_buff_bonuses()를 호출하지 않고 StatusEffectSystem을 거치는 이유:
# 그 채널은 최종값을 받으므로 기록자가 둘이면 서로 덮어쓴다(#105 참조).
func _push_stack_bonus() -> void:
	var count := get_stack_count()
	if count <= 0:
		StatusEffectSystem.clear_external_bonus(self, STACK_BONUS_KEY)
		return

	StatusEffectSystem.set_external_bonus(self, STACK_BONUS_KEY, {}, {
		"attack_speed": CombatConfig.tuning.stack_attack_speed_per_stack * count,
		"move_speed": CombatConfig.tuning.stack_move_speed_per_stack * count,
	})


# --- 탱커 3단계: 반사 / 기절 회복 ---

# 받은 피해의 일부를 공격자에게 되돌린다.
#
# 되돌린 피해로 또 반사가 일어나지는 않는다: 적(EnemyBase)에는 반사가 없고,
# 파티원끼리는 서로 때리지 않는다. 그래도 자기 자신에게는 넣지 않도록 막아 둔다.
func _reflect_damage(source, amount: int) -> void:
	if amount <= 0 or source == null or source == self:
		return
	if not _is_role_tier3(CharacterData.Role.TANK):
		return
	if not is_instance_valid(source) or not source.has_method("take_damage"):
		return

	var reflected := int(round(amount * CombatConfig.tuning.reflect_damage_percent))
	if reflected <= 0:
		return
	source.take_damage(reflected, self)


# 적을 기절시켰다. 표식을 부여한 탱커가 회복한다.
# 회복량은 그 탱커의 최대 체력 기준이다(적 체력과 무관하다).
func _on_stunned_enemy() -> void:
	if not _is_role_tier3(CharacterData.Role.TANK):
		return
	var amount := int(round(max_hp * CombatConfig.tuning.stun_heal_percent))
	if amount > 0:
		heal(amount)


# --- 원거리 3단계: 피흡 / 보호막 ---

# 평타로 실제로 준 피해에 비례해 회복한다.
# 체력이 가득 차 있으면 초과분의 일부가 보호막이 된다(한도까지).
func _apply_lifesteal(damage_dealt: int) -> void:
	if damage_dealt <= 0:
		return
	if not _is_role_tier3(CharacterData.Role.RANGED_DEALER):
		return

	var amount := int(round(damage_dealt * CombatConfig.tuning.lifesteal_percent))
	if amount <= 0:
		return

	var missing := max_hp - hp
	var healed := mini(amount, missing)
	if healed > 0:
		heal(healed)

	var overflow := amount - healed
	if overflow > 0:
		_gain_shield(int(round(overflow * CombatConfig.tuning.overheal_to_shield_percent)))


func _gain_shield(amount: int) -> void:
	if amount <= 0:
		return
	var limit := int(round(max_hp * CombatConfig.tuning.shield_max_percent))
	_shield = mini(_shield + amount, limit)


# 현재 보호막(표시·판정용).
func get_shield() -> int:
	return _shield


# --- 버퍼: 처형 ---

# 처형 조건을 만족하면 대상을 즉시 쓰러뜨린다.
# 조건 셋을 모두 만족해야 한다:
#   ① 이 멤버가 버퍼 역할이고 그 시너지가 켜져 있다 (버퍼가 **직접** 공격해야 한다)
#   ② 대상에 디버프가 걸려 있다
#   ③ 대상 체력이 execute_hp_percent 이하다
func _try_execute(target: Node) -> bool:
	if not _is_role_active(CharacterData.Role.BUFFER):
		return false
	if not StatusEffectSystem.has_any_debuff(target):
		return false
	if not can_execute(target):
		return false

	# 남은 체력을 확실히 넘기는 피해를 넣어 방어력에 막히지 않게 한다.
	target.take_damage(target.max_hp * 100, self)
	return true

# 대상이 처형 가능한 체력인가. HUD 표시에도 쓸 수 있도록 분리한다.
func can_execute(target) -> bool:
	if not is_instance_valid(target) or not target.is_alive:
		return false
	if target.max_hp <= 0:
		return false
	return float(target.hp) / float(target.max_hp) <= CombatConfig.tuning.execute_hp_percent

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

# 실제로 들어간 피해(방어·보호막 적용 후 체력에서 깎인 양)를 반환한다.
# 적 쪽(EnemyBase.take_damage)과 같은 규약이다.
func take_damage(amount: int, source = null) -> int:
	if not is_alive:
		return 0

	# 방어력 적용. 피해 공식은 PlayerStats.apply_defense()가 단일 출처다.
	var dealt: int = get_stats().apply_defense(amount)

	# 보호막이 먼저 받아 낸다. 남은 만큼만 체력이 깎인다.
	var absorbed: int = mini(_shield, dealt)
	_shield -= absorbed
	dealt -= absorbed

	# 스킬 보호막이 이 피해로 깎였는지 본다. 0이 되면 **깨짐**이고 폭발 계기다.
	# 원거리 3단계가 준 보호막만 깎인 경우에는 아무 일도 일어나지 않는다.
	var skill_shield_broke := false
	if _skill_shield > 0 and absorbed > 0:
		_skill_shield = maxi(_skill_shield - absorbed, 0)
		skill_shield_broke = _skill_shield <= 0

	hp -= dealt
	hp = max(hp, 0)

	if EventBus:
		# 흡수분도 "맞은 양"이다. 화면에 뜨는 숫자가 실제 타격과 어긋나면 안 된다.
		EventBus.damage_taken.emit(self, dealt + absorbed, global_position)

	# 탱커 3단계: 받은 피해에 비례해 공격자에게 되돌린다.
	# 흡수분까지 포함한 양이 기준이다 — 보호막을 둘렀다고 반사가 약해질 이유가 없다.
	_reflect_damage(source, dealt + absorbed)

	# 보호막이 깨져서 나는 폭발. die() 가 노드를 정리하기 전에 처리한다.
	if skill_shield_broke:
		_detonate_skill_shield()

	if hp <= 0:
		die()
	return dealt

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
