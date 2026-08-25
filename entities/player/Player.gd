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
# 용어(#257): 직접 조작하는 캐릭터가 **플레이어**, 그 외 파티 캐릭터가 **아군 AI** 다.
# 어느 쪽인지는 PartySystem 이 정한다. party_index 가 조작 중일 때만 입력을 받고,
# 아니면 아래 "아군 AI" 절의 상태 기계가 그 노드를 굴린다.

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
		# 아군 AI 의 전투 진입 신호. 플레이어가 적을 때리면 여기로 들어온다(#257).
		EventBus.player_attacked.connect(_on_player_attacked)
		# 플레이어가 맞은 것도 전투 신호다. 출처가 필요 없어 기존 damage_taken 을 그대로 쓴다(#257).
		EventBus.damage_taken.connect(_on_damage_taken)
		# 스텟을 사본으로 떼어 놓으면 정의 쪽 장착 변경이 더 이상 자동으로 닿지 않는다.
		# (전에는 정의의 PlayerStats를 그대로 써서 우연히 반영되고 있었다.)
		# 그래서 자기 캐릭터의 착탈만 골라 장비 채널을 다시 밀어 넣는다.
		EventBus.equipment_equipped.connect(func(character_id, _eid, _slot): _sync_equipment_bonuses(character_id))
		EventBus.equipment_unequipped.connect(func(character_id, _slot): _sync_equipment_bonuses(character_id))
	_refresh_control_visual()

	# 머리 위 체력 바. 아군이라 테두리는 기본 윤곽선 색이다(#249).
	# _apply_data() 뒤에 붙인다 — 바가 보이는 스프라이트에서 높이를 계산하기 때문이다.
	_attach_health_bar(false)


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
	# 조작 주체가 바뀌었다. 이전 조작자의 자취를 새 아군 AI 가 이어 밟으면 대열이 엉뚱한 곳에 잡힌다(#257).
	_trail.clear()
	_trail_clock = 0.0
	if is_controlled():
		_exit_combat()


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

# 플레이어를 시각적으로 구분한다. 밝기로만 표시한다.
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
	_tick_skill_cooldowns(delta)

	_process_control(delta)

	# 조종 중이 아니어도(velocity가 계속 0) 호출한다. 그래야 정지 포즈로 고정된다.
	_update_walk_animation()


# 입력 처리 한 틱. velocity를 정하고 필요하면 실제로 이동시킨다.
# 외형 갱신과 분리해 둔 이유: 아래 조기 반환이 애니메이션 갱신까지 건너뛰면
# 조종을 넘긴 멤버가 멈춘 뒤에도 걷는 모션이 남기 때문이다.
func _process_control(delta: float) -> void:
	if is_controlled():
		_process_input(delta)
		# 아군 AI 가 딜레이를 두고 밟을 자취를 남긴다(#257).
		_record_trail(delta)
	else:
		_process_ally_ai(delta)


# 사람이 잡고 있을 때. 이동·평타·대시·스킬이 모두 입력에서 나온다.
func _process_input(_delta: float) -> void:
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

# ===== 아군 AI (Ally AI) =====
#
# 직접 조작하는 캐릭터가 **플레이어**, 그 외 파티 캐릭터가 **아군 AI** 다(#257).
#
# 아군 AI 는 두 상태를 오간다.
#   비전투 — 플레이어 뒤 양옆으로 독수리 전형(V자)을 이루고, 플레이어의 자취를 딜레이만큼
#            늦게 밟으며 따라 걷는다. **공격하지 않는다.**
#   전투   — 타겟 하나를 잡고 **그 적만** 평타로 때린다.
#
# 스킬과 대시는 **어느 상태에서도** 쓰지 않는다(docs §4 [확정]: 사람이 잡아야 발동).
#
# 왜 아군 AI 가 평타를 쳐야 하는가: 설계가 그 위에 세워져 있다. 표식 충전은 §8.1 에서
# **파티 전체의 평타**로 이뤄지고 원거리 스택도 평타 기반이다. 아군 AI 가 가만히 있으면
# 시너지 1단계가 플레이어 1명분만 돈다.

## 지금 전투 상태인가. **아군 AI 마다 따로** 관리한다 — 플레이어에게서 멀어진 쪽만 대열로 돌아간다.
var _ai_in_combat: bool = false
## 고정된 타겟. 비전투로 돌아가거나 이 적이 죽을 때까지 바뀌지 않는다(타겟 고정).
## 예외는 아래 _tick_target_stuck() 의 안전장치 하나뿐이다.
var _ai_target: Node = null
## 플레이어가 마지막으로 때린 적. 내 타겟이 죽었을 때 넘겨받을 후보다. 광역 공격이면 null.
var _ai_player_target: Node = null
## 마지막 전투 신호(플레이어의 공격·피격 또는 나의 피격) 이후 지난 시간(초).
## ally_ai_combat_timeout 을 넘기면 전투를 푼다.
var _ai_idle_time: float = 0.0
## 고정 타겟에 가까워지지 못한 채 흐른 시간(초). 벽 뒤나 도망치는 적을 붙잡고 있는 상태다.
var _ai_target_stuck_time: float = 0.0
## 직전에 잰 타겟까지의 거리. 이보다 줄어들면 "다가가는 중"으로 본다.
var _ai_last_target_distance: float = INF

## 타겟에 이만큼(px) 가까워져야 진전으로 친다. 0 으로 두면 미세한 흔들림도 진전으로 읽힌다.
const AI_STUCK_PROGRESS_EPSILON := 4.0


func _process_ally_ai(delta: float) -> void:
	_update_ai_state(delta)

	if StatusEffectSystem.blocks_movement(self):
		velocity = Vector2.ZERO
	else:
		velocity = _ai_velocity(delta)
	move_and_slide()

	# 비전투에서는 때리지 않는다. 대열을 지키며 걷기만 한다.
	# 전투 중이라도 사거리 밖이면 try_attack() 이 대상을 못 찾아 스스로 아무 일도 하지 않는다.
	# 쿨다운·기절 판정도 그 안에 있으므로 여기서 다시 검사하지 않는다.
	if _ai_in_combat:
		try_attack()


# ----- 상태 전환 (State transitions) -----
#
# 비전투 -> 전투: 플레이어가 적을 공격했을 때, 플레이어가 맞았을 때, 내가 맞았을 때.
# 전투 -> 비전투: 그 신호들이 ally_ai_combat_timeout 초 동안 없거나,
#                 플레이어와의 거리가 ally_ai_leash_range 를 넘었을 때.
func _update_ai_state(delta: float) -> void:
	if not _ai_in_combat:
		return

	var tuning := CombatConfig.tuning

	_ai_idle_time += delta
	if _ai_idle_time >= tuning.ally_ai_combat_timeout:
		_exit_combat()
		return

	# 거리 판정은 아군 AI 개별이다. 플레이어가 혼자 앞서 가면 뒤처진 쪽부터 대열로 복귀한다.
	var player := _player_node()
	if player != null and global_position.distance_to(player.global_position) > tuning.ally_ai_leash_range:
		_exit_combat()
		return

	# 타겟은 **죽었을 때만** 갈아탄다. 플레이어가 다른 적으로 옮겨 가도 따라가지 않는다.
	if not _is_valid_enemy(_ai_target):
		_set_ai_target(_ai_player_target if _is_valid_enemy(_ai_player_target) else _nearest_enemy_to_self())
		if _ai_target == null:
			_exit_combat()
		return

	_tick_target_stuck(delta)


# 타겟 고정의 안전장치.
#
# 경로 탐색이 없어서 아군 AI 는 타겟을 향해 직선으로 미는 것밖에 못 한다. 그래서 벽 뒤에
# 있거나 도망치는 적을 물고 있으면, 타겟이 죽지도 않고 사거리에 들어오지도 않아 락이 영영
# 풀리지 않는다. 그 사이 자기를 때리는 다른 적은 무시한다.
#
# 그래서 "가까워지지 못한 채 ally_ai_target_stuck_time 초"를 실패로 보고 락을 푼다.
# 갈아탈 다른 적이 없으면 같은 적으로 다시 시도한다 — 놓아 봐야 갈 곳이 없다.
func _tick_target_stuck(delta: float) -> void:
	var distance := global_position.distance_to(_ai_target.global_position)

	# 사거리 안에 들어와 때리고 있으면 막힌 게 아니다.
	if distance <= get_attack_range():
		_ai_target_stuck_time = 0.0
		_ai_last_target_distance = distance
		return

	if distance < _ai_last_target_distance - AI_STUCK_PROGRESS_EPSILON:
		_ai_target_stuck_time = 0.0
		_ai_last_target_distance = distance
		return

	_ai_target_stuck_time += delta
	if _ai_target_stuck_time < CombatConfig.tuning.ally_ai_target_stuck_time:
		return

	var alternative := _nearest_enemy_to_self(_ai_target)
	if alternative != null:
		_set_ai_target(alternative)
	else:
		_ai_target_stuck_time = 0.0
		_ai_last_target_distance = INF


# 타겟을 갈아끼운다. 막힘 추적도 함께 초기화해야 새 타겟이 곧바로 막힌 것으로 읽히지 않는다.
func _set_ai_target(target) -> void:
	_ai_target = target
	_ai_target_stuck_time = 0.0
	_ai_last_target_distance = INF


# 전투에 들어간다. **이미 전투 중이면 타겟을 바꾸지 않는다** — 그것이 타겟 고정 규칙이다.
# 다만 전투 신호가 새로 왔으므로 이탈 타이머는 매번 되감는다.
func _enter_combat(target) -> void:
	_ai_idle_time = 0.0
	if _ai_in_combat:
		return
	_ai_in_combat = true
	# 노린 적이 없으면(광역 공격, 플레이어 피격) 나에게 가장 가까운 적을 잡는다.
	_set_ai_target(target if _is_valid_enemy(target) else _nearest_enemy_to_self())


func _exit_combat() -> void:
	_ai_in_combat = false
	_ai_player_target = null
	_ai_idle_time = 0.0
	_set_ai_target(null)


# 전투 **진입**을 허용할 거리인가.
#
# 이탈 거리와 같은 값을 쓰면 경계에 선 아군 AI 가 신호를 받아 진입했다가 다음 틱에 거리
# 때문에 이탈하기를 반복한다. 진입 문턱을 더 좁게 잡아 그 떨림을 없앤다(히스테리시스).
func _can_engage_from_player() -> bool:
	var player := _player_node()
	if player == null:
		return true
	var tuning := CombatConfig.tuning
	var limit: float = tuning.ally_ai_leash_range * tuning.ally_ai_engage_leash_ratio
	return global_position.distance_to(player.global_position) <= limit


# 플레이어가 적을 공격했다. 아군 AI 는 이것을 전투 신호로 삼는다.
# target 이 null 이면 광역 공격이라 "플레이어가 노린 적"이 하나로 정해지지 않는다.
func _on_player_attacked(attacker, target) -> void:
	if attacker == self or not is_alive or is_controlled():
		return
	if not _can_engage_from_player():
		return
	_ai_player_target = target if _is_valid_enemy(target) else null
	_enter_combat(_ai_player_target)


# 누군가 피해를 입었다. **플레이어가 맞은 것**이면 그것도 전투 신호다.
#
# 왜 필요한가: 전투 이탈 조건이 "플레이어가 3초간 공격하지 않음" 하나뿐이면, 플레이어가
# 적 패턴을 피하거나 자리를 잡느라 3초를 넘기는 순간 아군 AI 가 교전 한복판에서 등을 돌리고
# 대열로 걸어간다. 맞고 있다는 것은 싸움이 끝나지 않았다는 뜻이다.
#
# damage_taken 은 출처(때린 적)를 싣지 않으므로 타겟은 각자 최근접 적으로 고른다.
func _on_damage_taken(target, _damage: int, _position: Vector2) -> void:
	if target == self or not is_alive or is_controlled():
		return
	if not (target is Node) or not target.has_method("is_controlled") or not target.is_controlled():
		return
	if not _can_engage_from_player():
		return
	_enter_combat(null)


# 내가 적에게 맞았다. 비전투로 걷다 두들겨 맞고만 있지 않도록 때린 적을 잡고 반격한다.
# 이미 전투 중이면 타이머만 되감긴다 — 계속 맞는 동안에는 전투가 풀리지 않는다.
#
# 여기만 진입 문턱이 이탈 거리(리쉬)와 같다. 맞고 있다는 것은 내 자리에서 벌어지는 일이라,
# 플레이어와의 거리로 반격을 막을 이유가 없다.
func _on_damaged_by(source) -> void:
	if not is_alive or is_controlled():
		return
	if not _is_valid_enemy(source) or not GameManager.get_all_enemies().has(source):
		return
	_enter_combat(source)


func is_ai_in_combat() -> bool:
	return _ai_in_combat


func get_ai_target() -> Node:
	return _ai_target


# ----- 이동 (Movement) -----

func _ai_velocity(delta: float) -> Vector2:
	if _ai_in_combat:
		return _combat_velocity(delta)
	return _formation_velocity(delta)


# 목표 지점으로 향하는 속도. arrive 안이면 멈춘다.
# 한 틱에 목표를 지나칠 만큼 빠르면 속도를 잘라 준다 — 지나쳤다 되돌아오면 떤다.
func _seek(destination: Vector2, arrive_radius: float, delta: float, catchup: bool) -> Vector2:
	var to_destination: Vector2 = destination - global_position
	var distance := to_destination.length()
	if distance <= arrive_radius:
		return Vector2.ZERO

	var speed := get_move_speed()
	if catchup:
		speed *= _catchup_multiplier(distance - arrive_radius)
	if delta > 0.0:
		speed = minf(speed, distance / delta)
	return to_destination.normalized() * speed


# 벌어진 거리에 **비례**하는 따라잡기 배수.
#
# 계단식("이 거리를 넘으면 몇 배")으로 두면 경계에서 속도가 툭 튀고, 문턱 바로 아래에서는
# 영영 따라잡지 못한다(플레이어와 이동 속도가 같기 때문이다). 비례면 조금 벌어지면 조금,
# 많이 벌어지면 많이 빨라진다.
func _catchup_multiplier(gap: float) -> float:
	var tuning := CombatConfig.tuning
	if tuning.ally_ai_catchup_scale <= 0.0:
		return 1.0
	return clampf(1.0 + gap / tuning.ally_ai_catchup_scale, 1.0, tuning.ally_ai_catchup_max)


# 전투: 고정 타겟 옆자리로 붙는다.
func _combat_velocity(delta: float) -> Vector2:
	if not _is_valid_enemy(_ai_target):
		return Vector2.ZERO
	return _seek(_attack_stand_position(), CombatConfig.tuning.ally_ai_formation_arrive, delta, false)


# 타겟을 때릴 때 설 자리.
#
# 셋 다 타겟 중심으로 곧장 달려가면 같은 방향에서 한 점에 몰려 서로 밀치고, 뒤쪽 아군은
# 앞쪽에 막혀 사거리 밖에 멈춘다. 그래서 **플레이어-타겟 축에서 좌우로 벌려** 세운다.
# 축을 플레이어 기준으로 잡는 이유: 플레이어가 보는 쪽에서 함께 감싸야 포위 모양이 된다.
#
# 거리는 평타 사거리 x ally_ai_stop_range_ratio. 경계에 딱 맞추면 붙었다 떨어지며 떤다.
func _attack_stand_position() -> Vector2:
	var tuning := CombatConfig.tuning
	var target_position: Vector2 = _ai_target.global_position

	var player := _player_node()
	var axis: Vector2 = Vector2.ZERO
	if player != null:
		axis = target_position - player.global_position
	if axis == Vector2.ZERO:
		axis = target_position - global_position
	if axis == Vector2.ZERO:
		axis = Vector2.DOWN
	axis = axis.normalized()

	var slot := _formation_slot()
	var rank := float(slot / 2 + 1)
	var side_sign := -1.0 if slot % 2 == 0 else 1.0
	var angle := deg_to_rad(tuning.ally_ai_flank_angle) * rank * side_sign

	# -axis = 타겟에서 플레이어 쪽. 거기서 좌우로 벌린 지점에 선다.
	var stand_direction := (-axis).rotated(angle)
	return target_position + stand_direction * (get_attack_range() * tuning.ally_ai_stop_range_ratio)


# 비전투: 독수리 전형의 내 자리로 간다.
func _formation_velocity(delta: float) -> Vector2:
	var player := _player_node()
	if player == null:
		return Vector2.ZERO
	return _seek(_formation_position(player), CombatConfig.tuning.ally_ai_formation_arrive, delta, true)


# 독수리 전형에서 내가 설 자리.
#
# 기준점은 플레이어의 **지금** 위치가 아니라 ally_ai_follow_delay 초 전의 위치다.
# 현재 위치를 바로 쫓으면 붙었다 떨어지는 추격이 되어 같이 걷는 느낌이 나지 않는다.
# 지나간 자취를 늦게 밟으면 플레이어가 방향을 틀 때 대열도 한 박자 뒤에 따라 돈다.
#
# 앞뒤 기준도 그때의 진행 방향이다. 뒤 = 진행 방향의 반대.
func _formation_position(player: Node2D) -> Vector2:
	var tuning := CombatConfig.tuning
	var sample: Dictionary = player.get_trail_sample(tuning.ally_ai_follow_delay)
	var origin: Vector2 = sample["pos"]
	var forward: Vector2 = sample["dir"]
	if forward == Vector2.ZERO:
		forward = Vector2.DOWN
	forward = forward.normalized()

	var slot := _formation_slot()
	# 0,1 은 첫 줄, 2,3 은 그 뒤 줄. 짝수는 왼쪽 홀수는 오른쪽이라 V 자가 된다.
	var rank := float(slot / 2 + 1)
	var side_sign := -1.0 if slot % 2 == 0 else 1.0
	var side: Vector2 = forward.orthogonal() * (tuning.ally_ai_formation_side * rank * side_sign)
	return origin - forward * (tuning.ally_ai_formation_back * rank) + side


# 대열에서 내 번호. 살아 있는 아군 AI 를 party_index 순으로 세어 정한다.
# 인덱스 순이라 조작 대상이 바뀌어도 좌우가 서로 맞바뀌며 흔들리지 않는다.
# 전투 진영(_attack_stand_position)도 같은 번호를 쓴다 — 대열에서 왼쪽이면 전투에서도 왼쪽이다.
func _formation_slot() -> int:
	var slot := 0
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if node == self or not is_instance_valid(node):
			continue
		if not node.is_alive or node.is_controlled():
			continue
		if party_index >= 0 and node.party_index >= 0 and node.party_index < party_index:
			slot += 1
	return slot


# ----- 대상 판정 (Targeting) -----

# 나에게 가장 가까운 적. 지도 반대편의 적까지 잡지 않도록 ally_ai_engage_range 로 자른다.
# exclude 는 후보에서 뺀다 — 막힌 타겟을 다시 고르지 않기 위해서다.
func _nearest_enemy_to_self(exclude = null) -> Node:
	var engage_range: float = CombatConfig.tuning.ally_ai_engage_range
	var best: Node = null
	var best_distance := INF
	for enemy in GameManager.get_all_enemies():
		if not _is_valid_enemy(enemy) or enemy == exclude:
			continue
		var distance := global_position.distance_to(enemy.global_position)
		if distance > engage_range or distance >= best_distance:
			continue
		best_distance = distance
		best = enemy
	return best


# **파라미터에 타입을 붙이지 않는다**(#245). 들고 있던 적이 죽으면 queue_free 로 해제되는데,
# Node 로 타입을 박으면 해제된 객체가 들어올 때 대입 단계에서 죽는다.
func _is_valid_enemy(node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if not (node is Node):
		return false
	return "is_alive" in node and node.is_alive


# 지금 조작 중인 플레이어 노드. 그룹 이름의 출처는 PartySystem.MEMBER_GROUP 이다.
func _player_node() -> Node2D:
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if node == self or not is_instance_valid(node):
			continue
		if node is Node2D and node.is_controlled():
			return node as Node2D
	return null


# ===== 플레이어 자취 (Player trail) =====
#
# 아군 AI 가 "딜레이를 두고" 따라오려면 플레이어가 **지나간 자리**가 필요하다.
# 그래서 조작 중일 때만 자기 위치와 진행 방향을 짧게 기록하고, 아군 AI 가 그것을 늦게 읽는다.

## 자취를 들고 있는 시간(초). 추종 딜레이보다 넉넉해야 샘플이 모자라지 않는다.
const TRAIL_HISTORY_SECONDS := 2.0

## {"t": 시각, "pos": 위치, "dir": 진행 방향} 의 시간순 배열. 조작 중일 때만 쌓인다.
var _trail: Array[Dictionary] = []
## 자취 기록용 자체 시계(초).
var _trail_clock: float = 0.0


func _record_trail(delta: float) -> void:
	_trail_clock += delta
	_trail.append({"t": _trail_clock, "pos": global_position, "dir": _facing_direction()})
	var cutoff := _trail_clock - TRAIL_HISTORY_SECONDS
	while _trail.size() > 1 and float(_trail[0]["t"]) < cutoff:
		_trail.pop_front()


# delay 초 전의 내 위치와 진행 방향. 기록이 그만큼 없으면 가장 오래된 것을 준다.
func get_trail_sample(delay: float) -> Dictionary:
	if _trail.is_empty():
		return {"pos": global_position, "dir": _facing_direction()}

	var want: float = _trail_clock - maxf(delay, 0.0)
	if want <= float(_trail[0]["t"]):
		return {"pos": _trail[0]["pos"], "dir": _trail[0]["dir"]}

	for i in range(_trail.size() - 1, -1, -1):
		var sample: Dictionary = _trail[i]
		if float(sample["t"]) > want:
			continue
		if i + 1 >= _trail.size():
			return {"pos": sample["pos"], "dir": sample["dir"]}
		# 두 샘플 사이를 보간한다. 프레임 단위로 끊어 읽으면 대열이 덜컥거린다.
		var next_sample: Dictionary = _trail[i + 1]
		var span: float = float(next_sample["t"]) - float(sample["t"])
		var ratio: float = 0.0 if span <= 0.0 else (want - float(sample["t"])) / span
		return {
			"pos": (sample["pos"] as Vector2).lerp(next_sample["pos"], ratio),
			"dir": sample["dir"],
		}

	return {"pos": _trail[0]["pos"], "dir": _trail[0]["dir"]}


# 지금 바라보는 방향. 멈춰 있으면 마지막으로 움직인 방향을 쓴다.
func _facing_direction() -> Vector2:
	if velocity.length() > 0.01:
		return velocity.normalized()
	if _last_move_direction != Vector2.ZERO:
		return _last_move_direction.normalized()
	return Vector2.DOWN


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




# ===== 스킬 게이지 (Skill gauge) =====
#
# 캐릭터 개성 자원이다(#259). 지금은 미나만 갖는다.
#
# 정의(상한·충전량)는 CharacterData 가 소유하고, **지금 얼마나 찼는지**는 이 노드가 소유한다.
# 정의(.tres)는 로스터가 공유하는 읽기 전용 데이터라, 거기에 현재값을 두면 스테이지를 다시
# 열어도 이전 판의 게이지가 남는다(스텟 사본을 노드가 갖는 것과 같은 이유다).
#
# 충전은 **파티 전체의 평타**로 이뤄진다 — 아군 AI 가 친 평타도 센다. 표식 충전(docs §8.1)과
# 같은 규약이다. 시간으로는 줄지 않는다. 쓸 때만 사라진다.

## 지금 찬 게이지. 게이지가 없는 캐릭터는 계속 0 이다.
var _skill_gauge: int = 0

## 투사체 스킬이 쓰는 탄. 적 탄과 같은 씬을 쓴다(비행·명중 코드를 두 벌 두지 않는다).
const PROJECTILE_SCENE := preload("res://entities/combat/Projectile.tscn")
## 투사체 스킬의 명중 판정 반경(px). 방울이 적을 스치기만 해도 터지지 않을 만큼만 둔다.
const PROJECTILE_HIT_RADIUS := 14.0


func has_skill_gauge() -> bool:
	return data != null and data.has_skill_gauge()


func get_skill_gauge() -> int:
	return _skill_gauge


func get_skill_gauge_max() -> int:
	return data.skill_gauge_max if data != null else 0


# 0.0 ~ 1.0. 스킬 세기 스케일의 입력이다.
func get_skill_gauge_ratio() -> float:
	var maximum := get_skill_gauge_max()
	if maximum <= 0:
		return 0.0
	return clampf(float(_skill_gauge) / float(maximum), 0.0, 1.0)


# 게이지를 채운다. 상한을 넘지 않는다.
func add_skill_gauge(amount: int) -> void:
	if not has_skill_gauge() or amount <= 0:
		return
	_skill_gauge = mini(_skill_gauge + amount, get_skill_gauge_max())


# 평타 한 번이 파티의 게이지 보유자 전원을 채운다. 친 본인도 포함이다.
#
# 왜 파티 전체인가: "아군과 자신이 평타를 치면 찬다"가 스펙이다. 미나를 놓고 다른 캐릭터를
# 잡고 있어도 게이지가 도는 것이 이 자원의 성질이라, 친 사람 것만 채우면 안 된다.
func _charge_party_skill_gauges() -> void:
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if not is_instance_valid(node) or not node.is_alive:
			continue
		if not node.has_skill_gauge():
			continue
		node.add_skill_gauge(node.data.skill_gauge_gain_per_attack)


# 스킬이 게이지를 먹는다면 **전량** 소모한다. 소모하기 전의 비율을 돌려주는데,
# 그 값이 이번 시전의 세기가 된다.
func _consume_skill_gauge(skill: SkillData) -> float:
	var ratio := get_skill_gauge_ratio()
	if skill.consumes_gauge:
		_skill_gauge = 0
	return ratio


# 투사체 스킬을 쏜다. 조준 UI 가 없으므로 **지금 바라보는 방향**으로 나간다.
#
# 반경을 여기서 정해 실어 보낸다: 게이지는 쏜 사람의 자원이고, 날아가는 탄은 그 뒤의
# 게이지 변화를 알 필요가 없다(피해량을 발사한 쪽이 정해 보내는 것과 같은 규약).
func _cast_projectile_skill(skill: SkillData, gauge_ratio: float) -> void:
	var host := get_parent()
	if host == null:
		return

	var projectile = PROJECTILE_SCENE.instantiate()
	host.add_child(projectile)
	projectile.global_position = global_position
	projectile.setup(
		_facing_direction(),
		skill.projectile_speed,
		skill.get_effective_power(get_stats().get_goddess_skill_boost()),
		self,
		skill.projectile_range,
		PROJECTILE_HIT_RADIUS,
		skill.apply_effect_id,
		data.tint if data != null else Color.WHITE,
		true,
		skill.get_effective_radius(gauge_ratio)
	)

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
	#
	# **쿨타임 검사보다 먼저다.** 쿨타임이 막는 것은 보호막 생성이고,
	# 이미 두른 보호막을 터뜨리는 것은 생성이 아니다.
	if _detonate_shields_from(skill) > 0:
		if EventBus:
			EventBus.skill_used.emit(self, skill.skill_id)
		return true

	# 쿨타임 중에는 새로 만들지 못한다. 쿨타임은 **시전 시점**부터 돌았으므로
	# 일찍 터뜨렸다면 남은 시간을 기다려야 한다.
	if get_skill_cooldown_left(skill.skill_id) > 0.0:
		return false

	# 게이지는 **발동이 확정된 뒤** 소모한다. 쿨타임에 막혀 아무 일도 없었는데 자원만
	# 사라지면 안 된다. 소모하기 전의 비율이 그대로 이번 시전의 세기가 된다(#259).
	var gauge_ratio := _consume_skill_gauge(skill)

	if skill.is_projectile():
		_cast_projectile_skill(skill, gauge_ratio)
	if skill.grants_shield():
		_cast_shield_skill(skill, gauge_ratio)
	if skill.cooldown > 0.0:
		_skill_cooldowns[skill.skill_id] = skill.cooldown
	if EventBus:
		EventBus.skill_used.emit(self, skill.skill_id)
	return true


# 이 스킬의 남은 쿨타임(초). 0 이면 지금 쓸 수 있다.
func get_skill_cooldown_left(skill_id: StringName) -> float:
	return maxf(float(_skill_cooldowns.get(skill_id, 0.0)), 0.0)


# 스킬 쿨타임 한 틱. 스킬별로 따로 돈다 — Q 와 E 가 서로의 쿨타임을 공유하지 않는다.
func _tick_skill_cooldowns(delta: float) -> void:
	if _skill_cooldowns.is_empty():
		return
	for id in _skill_cooldowns.keys():
		var left: float = float(_skill_cooldowns[id]) - delta
		if left <= 0.0:
			_skill_cooldowns.erase(id)
		else:
			_skill_cooldowns[id] = left


# ===== 스킬 보호막 (Skill shield) =====

# 시전: 자기 자신과 **파티에서 가장 체력이 낮은 파티원**에게 보호막을 두른다.
#
# "가장 체력이 낮은"은 **비율** 기준이다. 절대량으로 재면 최대 체력이 작은 멤버가
# 만피여도 뽑히는데(1000 만피 < 1200 중 1100), 위험한 쪽을 지키는 스킬의 의도와 어긋난다.
func _cast_shield_skill(skill: SkillData, gauge_ratio: float = 0.0) -> void:
	_apply_skill_shield(skill, self, gauge_ratio)
	var ally := _lowest_health_party_member()
	if ally != null:
		ally._apply_skill_shield(skill, self, gauge_ratio)


# 자기를 뺀 파티원 중 체력 비율이 가장 낮은 쪽. 없으면 null.
func _lowest_health_party_member() -> Node:
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
func _apply_skill_shield(skill: SkillData, caster: Node, gauge_ratio: float = 0.0) -> void:
	var amount := skill.get_effective_shield(gauge_ratio)
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

	# 보호막 폭발도 광역 공격이다. 시전자가 플레이어일 때만 아군 AI 에게 알린다(#257).
	if caster != null and is_instance_valid(caster) and caster.is_controlled() and EventBus:
		EventBus.player_attacked.emit(caster, null)

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

	# 아군 AI 가 "플레이어가 지금 때리는 적"을 알아야 한다(#257).
	if is_controlled() and EventBus:
		EventBus.player_attacked.emit(self, target)

	# 평타 발생을 먼저 센다. 처형으로 끝나거나 적을 죽인 평타도 "나간 평타"다.
	_attack_swing_count += 1

	# 파티 전체의 평타가 게이지를 채운다(#259). 표식 충전과 같은 규약이다.
	_charge_party_skill_gauges()
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

	# 광역 패시브에는 노린 대상이 하나로 없다. 아군 AI 는 이 신호에서 최근접 적을 스스로 고른다(#257).
	if is_controlled() and EventBus:
		EventBus.player_attacked.emit(self, null)


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

# 스킬별 남은 쿨타임. skill_id(StringName) -> 남은 초.
# 항목이 없으면 쿨타임이 없다는 뜻이다(다 돌면 지운다).
#
# 슬롯이 아니라 skill_id 로 키를 잡는 이유: 쿨타임은 스킬의 성질이라
# 같은 스킬을 다른 슬롯으로 옮겨도 따라가야 한다.
var _skill_cooldowns: Dictionary = {}

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
	# 아군 AI 는 **고정 타겟만** 때린다(#257). 지나가다 사거리에 들어온 다른 적은 건드리지
	# 않는다 — 그래야 파티 화력이 플레이어가 잡은 적 하나에 모인다.
	if not is_controlled() and _ai_in_combat:
		if _is_valid_enemy(_ai_target) and global_position.distance_to(_ai_target.global_position) <= get_attack_range():
			return _ai_target
		return null

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

	# 비전투로 걷던 아군 AI 는 맞으면 반격한다(#257).
	_on_damaged_by(source)

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


# ===== 체력 바 (Health bar) =====

# 머리 위 체력 바를 붙인다. 씬이 아니라 코드로 붙이므로 새 캐릭터·새 적이 자동으로 얻는다.
# hostile 이면 테두리가 빨강이 된다(적/아군 구분, #249).
func _attach_health_bar(hostile: bool) -> void:
	var bar := HealthBar.new()
	bar.name = "HealthBar"
	bar.hostile = hostile
	add_child(bar)
