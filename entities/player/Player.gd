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
	# 캐스트와 체인 창은 조종 여부와 무관하게 돈다. 조종을 넘겨도 걸린 것은 계속 흐른다(#263).
	_tick_cast(delta)
	_tick_chain_window(delta)
	# 평타 변형 창도 같다(#328) — 조종을 넘겨도 7초는 7초다. 아군 AI 가 된 하랑도
	# 그 동안 광역 평타를 낸다(효과는 StatusEffectSystem 이 따로 돌린다).
	_tick_attack_override_window(delta)

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

	_process_combat_input()


# 평타·스킬 입력(#264). 이동과 나눠 둔 이유: 위쪽은 대시 중에 입력을 무시하는 구간이 있는데,
# 공격은 그 구간에도 계속 받아야 한다(대시하며 쏘는 것이 이 게임의 회피 조작이다).
#
# 차단(기절 등)은 여기서 보지 않는다. can_attack() 과 try_use_skill() 이 이미 CONTROL 효과를
# 확인하므로, 여기서 한 번 더 보면 차단 규칙의 출처가 두 곳이 된다.
func _process_combat_input() -> void:
	# **누르고 있으면** 쿨다운이 도는 대로 반복해 나간다. 연타를 강요하지 않는다 —
	# 평타는 쿨다운이 리듬을 정하는 행동이라, 입력이 그 리듬보다 빨라도 얻는 것이 없다.
	if Input.is_action_pressed("attack"):
		try_attack()

	# 스킬은 **누른 순간** 1회다. 홀드로 반복하면 쿨타임이 도는 즉시 저절로 나가,
	# "언제 쓸까"라는 판단이 사라진다.
	if Input.is_action_just_pressed("skill_q"):
		try_use_skill(SkillData.InputSlot.Q)
	if Input.is_action_just_pressed("skill_e"):
		try_use_skill(SkillData.InputSlot.E)

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


# 이 몸이 향해 움직인 방향. 멈춰 있으면 마지막으로 움직인 방향을 쓴다.
#
# **조준이 아니다.** 사람이 어디를 가리키는지는 get_aim_direction() 이 답한다(#264).
# 이쪽은 아군 AI 와 대열 자취도 함께 쓰는 값이라, 커서를 섞으면 그쪽까지 끌려간다.
func _facing_direction() -> Vector2:
	if velocity.length() > 0.01:
		return velocity.normalized()
	if _last_move_direction != Vector2.ZERO:
		return _last_move_direction.normalized()
	return Vector2.DOWN


# ===== 조준 (Aim) =====
#
# 발사 방향의 출처다(#264). **조종 중인 캐릭터만** 마우스로 조준한다.
#
# 왜 _facing_direction() 을 대체하지 않고 위에 얹는가:
#   _facing_direction() 은 "이 몸이 어디를 향해 움직였는가"이고 아군 AI 와 적도 같은 뜻으로 쓴다.
#   조준은 "사람이 어디를 가리키고 있는가"라 마우스가 있는 한 명에게만 있다. 둘은 다른 질문이고,
#   하나로 합치면 아군 AI 의 방향이 조종 중인 사람의 커서에 끌려간다.

## 마우스가 캐릭터와 이보다 가까우면 방향을 만들 수 없다고 본다(px).
## 0 과 정확히 비교하면 커서가 몸에 겹칠 때 정규화가 0 벡터를 뱉는다.
const AIM_DEADZONE := 1.0


# 이 캐릭터가 지금 쏘는 방향(단위 벡터).
#
# 조종 중이면 커서 쪽, 아니면 지금까지와 같은 진행 방향이다.
# get_global_mouse_position() 이 카메라 변환을 이미 반영하므로 여기서 다시 계산하지 않는다.
func get_aim_direction() -> Vector2:
	if is_controlled():
		var to_cursor := get_global_mouse_position() - global_position
		if to_cursor.length() > AIM_DEADZONE:
			return to_cursor.normalized()
	return _facing_direction()


# 지금 마우스로 조준하고 있는가. 외형·검증이 읽는다.
func is_aiming() -> bool:
	return is_controlled()


# ===== 워크 애니메이션 (Walk animation) =====

# 지금 향한 방향의 애니메이션을 재생한다. 멈춰 있으면 정지 포즈로 고정한다.
# 시트가 없는 캐릭터는 _anim_sprite가 null이라 아무 일도 하지 않는다.
#
# 방향의 출처가 둘이다(#264):
#   조종 중  -> **조준 방향**. 서서 커서만 돌려도 몸이 따라 돈다. 어디를 쏘는지가 보여야 한다.
#   아군 AI  -> 진행 방향. 마우스가 없으므로 지금까지와 같다.
#
# 4방향 시트라 스트레이프(옆걸음) 모션이 없다. 커서를 등지고 걸으면 게걸음처럼 보이는데,
# 조준과 몸이 어긋나는 쪽이 더 읽기 어려워서 이쪽을 택했다.
#
# 애니메이션 이름과 멈춤 임계값의 출처는 WalkAnimation이다(적과 같은 규약을 쓴다).
func _update_walk_animation() -> void:
	if _anim_sprite == null:
		return

	var walking := WalkAnimation.is_walking(velocity)

	# 어느 애니메이션을 향할 것인가. 아군 AI 가 멈춰 있으면 지금 것을 그대로 둔다
	# — 멈출 때마다 정면으로 홱 돌아보면 어색하기 때문이다(기존 동작).
	var anim := _anim_sprite.animation
	if is_aiming():
		anim = WalkAnimation.animation_for(get_aim_direction())
	elif walking:
		anim = WalkAnimation.animation_for(velocity)

	if not walking:
		# 멈추면 재생을 세우고 정지 포즈(0번 프레임)로 고정한다.
		# 방향은 위에서 정해진 값을 쓰므로, 조종 중이면 서 있어도 커서를 계속 따라본다.
		if _anim_sprite.animation != anim:
			_anim_sprite.animation = anim
		if _anim_sprite.is_playing():
			_anim_sprite.stop()
		_anim_sprite.frame = 0
		return

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
## 직선 범위 스킬이 지나간 자리를 잠깐 그리는 표시. 판정은 하지 않는다(#263).
const BEAM_EFFECT_SCENE := preload("res://entities/combat/BeamEffect.tscn")


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


# 투사체 스킬을 쏜다. **커서로 조준한 방향**으로 나간다(#264).
# 조종 중이 아니면 진행 방향으로 되돌아가지만, 아군 AI 는 스킬을 쓰지 않으므로 실제로는 커서다.
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
		get_aim_direction(),
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

	# 체력 조건(#328). 몰린 순간에만 쓸 수 있는 역전기가 있다(하랑 E).
	#
	# 쿨타임 **뒤**, 게이지 소모 **앞**에 둔다: 조건에 걸린 것은 "아무 일도 일어나지 않은 것"이라
	# 자원을 가져가면 안 된다(쿨타임 검사와 같은 처리). 조건을 쿨타임보다 먼저 보든 나중에 보든
	# 결과는 같지만, 자원을 만지기 전에 모든 게이트를 지나는 순서가 읽기 쉽다.
	if not skill.meets_hp_condition(hp, max_hp):
		return false

	# 게이지는 **발동이 확정된 뒤** 소모한다. 쿨타임에 막혀 아무 일도 없었는데 자원만
	# 사라지면 안 된다. 소모하기 전의 비율이 그대로 이번 시전의 세기가 된다(#259).
	var gauge_ratio := _consume_skill_gauge(skill)

	# 쿨타임은 **누른 시점**부터 돈다. 캐스트가 끝난 뒤부터 돌면 캐스트를 공속으로 당길수록
	# 다음 시전까지의 총 대기가 길어져, 강화가 손해가 되는 역전이 생긴다.
	if skill.cooldown > 0.0:
		_skill_cooldowns[skill.skill_id] = skill.cooldown
	if EventBus:
		EventBus.skill_used.emit(self, skill.skill_id)

	# 시전 시간이 있으면 지금 나가지 않는다. 캐스트가 끝나야 효과가 터진다(#263).
	if skill.cast_time > 0.0:
		_begin_cast(skill, gauge_ratio)
		return true

	_fire_skill_effects(skill, gauge_ratio)
	return true


# ===== 시전 시간 (Cast) =====
#
# 누른 뒤 실제로 나가기까지 기다리는 스킬이 있다(태희 E, #263).
# 실제 대기 시간은 **공속 배수로 나뉜다** — 평타를 쳐서 쌓은 것(원거리 스택)이 그대로
# 캐스트를 당긴다. 캐스트 중에는 평타가 나가지 않으므로, 그 짧아진 시간이 곧 안전이다.
#
# 캐스트가 걸린 뒤 죽거나 기절하면 캐스트는 취소된다. 쿨타임과 게이지는 돌려주지 않는다
# — 둘 다 "누른 것"의 비용이고, 이미 눌렀기 때문이다.

## 캐스트가 끝나기까지 남은 시간(초). 0 이면 캐스트 중이 아니다.
var _cast_time_left: float = 0.0
## 지금 캐스트 중인 스킬.
var _cast_skill: SkillData = null
## 누른 시점의 게이지 비율. 캐스트가 끝났을 때의 세기다(게이지는 누를 때 이미 소모됐다).
var _cast_gauge_ratio: float = 0.0


func _begin_cast(skill: SkillData, gauge_ratio: float) -> void:
	_cast_skill = skill
	_cast_gauge_ratio = gauge_ratio
	_cast_time_left = skill.get_cast_time(get_stats().get_attack_speed_multiplier())


# 지금 스킬을 시전 중인가.
func is_casting() -> bool:
	return _cast_time_left > 0.0


# 남은 시전 시간(초).
func get_cast_time_left() -> float:
	return maxf(_cast_time_left, 0.0)


func _tick_cast(delta: float) -> void:
	if _cast_time_left <= 0.0:
		return

	# 기절 등 CONTROL 효과가 스킬을 막으면 캐스트가 끊긴다(평타·이동과 같은 규약).
	if not is_alive or StatusEffectSystem.blocks_skill(self):
		_cancel_cast()
		return

	_cast_time_left -= delta
	if _cast_time_left > 0.0:
		return

	var skill := _cast_skill
	var ratio := _cast_gauge_ratio
	_cancel_cast()
	if skill != null:
		_fire_skill_effects(skill, ratio)


func _cancel_cast() -> void:
	_cast_time_left = 0.0
	_cast_skill = null
	_cast_gauge_ratio = 0.0


# 스킬이 실제로 하는 일. 즉발 스킬은 누른 즉시, 캐스트 스킬은 캐스트가 끝났을 때 여기로 온다.
#
# 한 스킬이 여러 채널을 가질 수 있으므로 else 로 묶지 않는다(미나 E 는 보호막만, 미나 Q 는
# 투사체만, 태희 Q 는 체인 창만 연다).
func _fire_skill_effects(skill: SkillData, gauge_ratio: float) -> void:
	if skill.is_projectile():
		_cast_projectile_skill(skill, gauge_ratio)
	if skill.grants_shield():
		_cast_shield_skill(skill, gauge_ratio)
	if skill.is_beam():
		_cast_beam_skill(skill)
	if skill.chains_basic_attacks():
		_open_chain_window(skill)
	if skill.is_wave():
		_cast_wave_skill(skill)
	if skill.party_effect_id != &"":
		_cast_party_effect(skill)
	if skill.is_instant_aoe():
		_cast_instant_aoe(skill)
	if skill.self_effect_id != &"":
		_cast_self_effect(skill)
	if skill.overrides_basic_attack():
		_open_attack_override_window(skill)
	if skill.creates_aura():
		_cast_aura_zone(skill)
	if skill.ally_effect_id != &"":
		_cast_ally_effect(skill)
	if skill.is_cone():
		_cast_cone_skill(skill)


# ===== 부채꼴 (Cone) =====

## 부채꼴이 지나간 자리를 잠깐 그리는 표시. 판정은 시전 순간에 이미 끝난다.
const CONE_EFFECT_SCENE := preload("res://entities/combat/ConeEffect.tscn")

## 부채꼴에 맞은 적의 넉백 경로를 잔상과 먼지로 보여 준다(#348).
const KNOCKBACK_EFFECT_SCENE := preload("res://entities/combat/KnockbackEffect.tscn")

## 낙뢰가 떨어진 자리를 잠깐 그리는 표시. 마찬가지로 판정하지 않는다.
const STRIKE_EFFECT_SCENE := preload("res://entities/combat/StrikeEffect.tscn")

## 아린 E의 시전·활성·종료 연출. 상태 효과 수치는 데이터에서 받아 온다(#348).
const OVERLOAD_EFFECT_SCENE := preload("res://entities/combat/OverloadEffect.tscn")
const BURST_EFFECT_SHEET: Texture2D = preload("res://assets/sprites/effects/burst.png")
const BURST_FRAME_COUNT: int = 4
const BURST_FPS: float = 12.0


# 조준 방향으로 부채꼴 판정을 낸다(#336).
#
# 빔(_cast_beam_skill)과 같은 자리·같은 방향 출처를 쓰지만 판정 모양이 다르다:
# 빔은 축에서의 **수직 거리**로 자르고, 부채꼴은 축과의 **각도**로 자른다.
# 그래서 부채꼴은 멀수록 넓어진다 — 붙어 있는 적 무리를 한 번에 치우는 데 맞는 모양이다.
#
# 관통이다 — 앞의 적이 뒤의 적을 막아 주지 않는다.
func _cast_cone_skill(skill: SkillData) -> void:
	var forward := get_aim_direction()
	if forward == Vector2.ZERO:
		forward = _facing_direction()
	forward = forward.normalized()

	var half_angle := skill.get_cone_half_angle()
	var damage := skill.get_effective_power(get_stats().get_goddess_skill_boost())
	var origin := global_position

	_spawn_cone_effect(origin, forward, skill)

	for enemy in GameManager.get_all_enemies().duplicate():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive:
			continue

		# 타입을 명시한다: enemy 가 타입 없는 Variant 라 := 로는 추론이 되지 않는다.
		var offset: Vector2 = enemy.global_position - origin
		if offset.length() > skill.cone_length:
			continue
		# 정확히 겹쳐 있으면 각도를 잴 수 없다. 붙어 있는 것이므로 맞는 것으로 본다.
		if offset != Vector2.ZERO and absf(forward.angle_to(offset)) > half_angle:
			continue

		if damage > 0:
			enemy.take_damage(damage, self)
		# 죽었으면 밀 대상도, 걸 효과도 없다.
		if not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		if skill.knockback_distance > 0.0 and enemy.has_method("apply_knockback"):
			_spawn_knockback_effect(enemy, origin, skill.knockback_distance)
			enemy.apply_knockback(origin, skill.knockback_distance)
		if skill.apply_effect_id != &"":
			StatusEffectSystem.apply(enemy, skill.apply_effect_id, self)

	# 노린 대상이 하나로 없다. 아군 AI 는 이 신호에서 최근접 적을 스스로 고른다(#257).
	if is_controlled() and EventBus:
		EventBus.player_attacked.emit(self, null)


func _spawn_cone_effect(origin: Vector2, forward: Vector2, skill: SkillData) -> void:
	var host := get_parent()
	if host == null:
		return
	var fx = CONE_EFFECT_SCENE.instantiate()
	host.add_child(fx)
	fx.global_position = origin
	fx.setup(forward, skill.cone_length, skill.get_cone_half_angle(),
		data.tint if data != null else Color.WHITE)


func _spawn_knockback_effect(target: Node2D, origin: Vector2, distance: float) -> void:
	var host := get_parent()
	if host == null:
		return
	var fx = KNOCKBACK_EFFECT_SCENE.instantiate()
	host.add_child(fx)
	fx.global_position = target.global_position
	fx.setup(target, origin, distance, data.tint if data != null else Color.WHITE)


# ===== 지대 (Aura zone) =====

## 머무는 원형 지대. Shockwave 와 달리 퍼지지 않고 그 자리에 남는다(#334).
const AURA_ZONE_SCENE := preload("res://entities/combat/AuraZone.tscn")


# 지대를 놓는다. 시전자 자리에 고정되며, 안에 있는 아군에게만 효과가 걸린다.
#
# 부모를 이 캐릭터가 아니라 **전장**으로 두는 이유는 Shockwave·Projectile 과 같다:
# 시전자가 죽거나 조종이 넘어가도 지대는 그 자리에 남아야 하고, 방을 버릴 때 함께 정리되어야 한다.
# (지대 자신이 _exit_tree 에서 걸어 둔 효과를 푼다.)
func _cast_aura_zone(skill: SkillData) -> void:
	var host := get_parent()
	if host == null:
		return

	var zone = AURA_ZONE_SCENE.instantiate()
	host.add_child(zone)
	zone.global_position = global_position
	var color: Color = data.tint if data != null else Color.WHITE
	zone.setup(skill.aura_radius, skill.aura_duration, skill.aura_effect_id, self, color)


# ===== 아군 1명 효과 부여 (Single-ally effect) =====

# 체력 비율이 가장 낮은 아군 하나에게 효과를 건다(#334).
#
# 대상 선정은 _lowest_health_ally() 하나가 갖는다 — 설아 3타 회복(ally_heal)이 쓰는 것과
# 같은 규칙이라 여기서 다시 만들지 않는다. 시전자 자신도 후보다.
func _cast_ally_effect(skill: SkillData) -> void:
	var target := _lowest_health_ally()
	if target == null:
		return
	StatusEffectSystem.apply(target, skill.ally_effect_id, self)


# ===== 즉발 광역 (Instant AoE) =====

# 시전한 자리에서 원형으로 즉시 때린다(#328). 피해와 상태 효과 둘 다 선택이다 —
# 피해가 0 이고 효과만 거는 스킬도 정상이다(하랑 Q 의 광역 도발).
#
# 파동(_cast_wave_skill)과 달리 판정이 지금 끝난다. 그래서 달려서 피할 수 없다.
func _cast_instant_aoe(skill: SkillData) -> void:
	var damage := skill.get_effective_power(get_stats().get_goddess_skill_boost())
	var hit_any := false

	for enemy in GameManager.get_all_enemies():
		if enemy == null or not enemy.is_alive:
			continue
		if global_position.distance_to(enemy.global_position) > skill.instant_aoe_radius:
			continue

		hit_any = true
		if damage > 0:
			enemy.take_damage(damage, self)
			# 피해로 죽었으면 효과를 걸지 않는다(EnemyBase.try_attack 과 같은 규약).
			if not is_instance_valid(enemy) or not enemy.is_alive:
				continue
		if skill.apply_effect_id != &"":
			StatusEffectSystem.apply(enemy, skill.apply_effect_id, self)

	# 노린 대상이 하나로 없다. 아군 AI 는 이 신호에서 최근접 적을 스스로 고른다(#257).
	if hit_any and is_controlled() and EventBus:
		EventBus.player_attacked.emit(self, null)


# ===== 자기 효과 부여 (Self effect) =====

# 시전자 자신에게만 상태 효과를 건다(#328).
#
# _cast_party_effect 와 나눠 둔 이유는 SkillData.self_effect_id 주석에 있다 —
# 이쪽은 자기만 이득을 보고 자기만 대가를 치른다.
#
# source 를 자기 자신으로 넘긴다: 이 효과의 출처는 자기 시전이고, 지속 피해가
# 되돌아올 때 "누가 넣은 피해인가"가 자기여야 한다. 자기 반사(_reflect_damage)와
# 아군 AI 반격(_on_damaged_by)은 둘 다 source == self 를 이미 걸러 낸다.
func _cast_self_effect(skill: SkillData) -> void:
	if not StatusEffectSystem.apply(self, skill.self_effect_id, self):
		return
	if skill.skill_id == &"arin_overload":
		_spawn_overload_effect(skill.self_effect_id)


func _spawn_overload_effect(effect_id: StringName) -> void:
	if get_node_or_null("OverloadEffect") != null:
		return
	var effect_data := StatusEffectDatabase.get_effect(effect_id)
	if effect_data == null:
		return
	var fx = OVERLOAD_EFFECT_SCENE.instantiate()
	fx.setup(effect_data.duration, data.tint if data != null else Color.WHITE)
	add_child(fx)


# ===== 파동 (Shockwave) =====

## 퍼지는 원형 파동. 판정이 시간에 따라 커진다(#276). BeamEffect 와 달리 **연출이 아니라 판정**이다.
const SHOCKWAVE_SCENE := preload("res://entities/combat/Shockwave.tscn")

## 처형 표식(#331). 처형이 성사된 자리에 한 장 놓는다.
const EXECUTE_MARK_SCENE := preload("res://entities/combat/ExecuteMark.tscn")


# 파동을 놓는다. 시전자 자리에서 바깥으로 퍼지며 적에게 피해를, 아군에게 회복을 준다.
#
# 조준 방향을 쓰지 않는다 — 원은 방향이 없다. 이 스킬이 조준을 요구하지 않는 것이 의도다.
func _cast_wave_skill(skill: SkillData) -> void:
	var host := get_parent()
	if host == null:
		return

	var boost := get_stats().get_goddess_skill_boost()
	var wave := SHOCKWAVE_SCENE.instantiate()
	host.add_child(wave)
	wave.global_position = global_position
	wave.setup(
		skill.wave_radius,
		skill.wave_speed,
		skill.get_effective_power(boost),
		skill.get_effective_ally_heal(boost),
		self,
		data.tint if data != null else Color.WHITE
	)

	# 파동에는 노린 대상이 하나로 없다. 아군 AI 는 최근접 적을 스스로 고른다(#257).
	if is_controlled() and EventBus:
		EventBus.player_attacked.emit(self, null)


# ===== 파티 전체 효과 (Party-wide effect) =====

# 파티 전원(자기 자신 포함, 아군 AI 포함)에게 상태 효과를 건다(#276).
#
# 아군 AI 도 받는 이유: 이 효과가 바꾸는 것은 "그 캐릭터가 무엇을 할 수 있는가"이고,
# 아군 AI 도 평타는 친다. 조종 중인 한 명만 받으면 파티 버프가 아니라 자기 버프가 된다.
# 시전만 사람이 한다(docs §4 — 아군 AI 는 스킬을 쓰지 않는다).
func _cast_party_effect(skill: SkillData) -> void:
	if skill.party_effect_id == &"":
		return
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if not is_instance_valid(node) or not node.is_alive:
			continue
		StatusEffectSystem.apply(node, skill.party_effect_id, self)


# ===== 아군 회복 (Ally heal) =====

# 체력 **비율**이 가장 낮은 아군을 회복시킨다(#276).
#
# 비율 기준인 이유는 미나 보호막(#259)과 같다 — 절대량으로 재면 최대 체력이 작은 멤버가
# 만피여도 뽑힌다(1000 만피 < 1200 중 1100). 위태로운 쪽을 살리는 것이 의도다.
func _heal_lowest_ally(skill: SkillData) -> void:
	var target := _lowest_health_ally()
	if target == null:
		return
	var amount := skill.get_effective_ally_heal(get_stats().get_goddess_skill_boost())
	if amount > 0:
		# 버퍼 3단계는 **들어간 만큼만** 센다(#369). 만피 아군에게 넘친 몫은 제공된 것이 아니다.
		_credit_support_provided(target.heal(amount))


# 파티에서 체력 비율이 가장 낮은 멤버. **자기 자신도 후보다.**
#
# _lowest_health_party_member() 와 나눠 둔 이유: 그쪽은 미나 보호막이 쓰는데, 그 스킬은
# 시전자에게 이미 따로 보호막을 걸어 놓고 "그 외에 한 명 더"를 찾는다. 여기는 "가장 위태로운
# 한 명"이라 자기가 그 한 명이면 자기여야 한다. 같은 함수로 묶으면 둘 중 하나가 조용히 틀린다.
func _lowest_health_ally() -> Node:
	var best: Node = null
	var best_percent := INF
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if not is_instance_valid(node) or not node.is_alive:
			continue
		var percent: float = node.get_health_percent()
		if percent < best_percent:
			best_percent = percent
			best = node
	return best


# ===== 평타 체인 창 (Chain window) =====
#
# 일정 시간 동안 평타 투사체가 다음 적으로 튕긴다(태희 Q, #263).
# 즉발 피해가 아니라 **평타를 강화하는 창**이라, 창 안에 평타를 몇 번 넣느냐가 곧 값어치다.

## 체인 창이 남은 시간(초). 0 이면 평타는 단일 대상 그대로다.
var _chain_time_left: float = 0.0
## 창을 연 스킬. 튕김 횟수·사거리·감쇠의 출처다.
var _chain_skill: SkillData = null


func _open_chain_window(skill: SkillData) -> void:
	_chain_skill = skill
	# 겹쳐 쓰면 남은 시간이 **갱신**된다(누적이 아니다). 누적이면 쿨타임이 짧아졌을 때
	# 창이 영원히 닫히지 않는 구간이 생긴다.
	_chain_time_left = skill.chain_duration


func _tick_chain_window(delta: float) -> void:
	if _chain_time_left <= 0.0:
		return
	_chain_time_left -= delta
	if _chain_time_left <= 0.0:
		_chain_time_left = 0.0
		_chain_skill = null


# 지금 평타가 튕기는가. HUD/검증이 읽는다.
func is_chain_window_open() -> bool:
	return _chain_time_left > 0.0


# 체인 창이 남은 시간(초).
func get_chain_time_left() -> float:
	return maxf(_chain_time_left, 0.0)


# ===== 평타 변형 창 (Attack override window) =====
#
# 일정 시간 동안 평타 **자체가** 다른 평타가 된다(하랑 E, #328).
# 체인 창과 나란히 두었지만 성질이 다르다 — 체인은 평타에 얹고, 이쪽은 평타를 갈아치운다.
# 자세한 구분은 SkillData.attack_override_duration 주석에 있다.

## 변형 창이 남은 시간(초). 0 이면 평타는 원래대로다.
var _attack_override_time_left: float = 0.0
## 창을 연 스킬. 반경과 피해 공식의 출처다.
var _attack_override_skill: SkillData = null


func _open_attack_override_window(skill: SkillData) -> void:
	_attack_override_skill = skill
	# 겹쳐 쓰면 남은 시간이 **갱신**된다(체인 창과 같은 규약).
	_attack_override_time_left = skill.attack_override_duration


func _tick_attack_override_window(delta: float) -> void:
	if _attack_override_time_left <= 0.0:
		return
	_attack_override_time_left -= delta
	if _attack_override_time_left <= 0.0:
		_attack_override_time_left = 0.0
		_attack_override_skill = null


# 지금 평타가 바뀌어 있는가. HUD/검증이 읽는다.
func is_attack_override_open() -> bool:
	return _attack_override_time_left > 0.0 and _attack_override_skill != null


# 변형 창이 남은 시간(초).
func get_attack_override_time_left() -> float:
	return maxf(_attack_override_time_left, 0.0)


# 바뀐 평타 한 번. 반경 안 적 **전원**을 평타 규칙(_resolve_attack_hit)에 통과시킨다.
#
# 적마다 피해를 따로 계산한다 — 최대 체력 비례이므로 큰 적이 더 많이 아프다.
# 비율이 저작되지 않았으면(0) 공격력 그대로다. 광역화만 하고 피해 공식은 그대로 두는
# 창도 있을 수 있기 때문이다.
#
# 처형·피흡·표식이 전원에게 각각 적용된다: 이 창의 계약이 "평타가 광역이 된다"이고,
# 광역이 된 평타는 맞은 적 하나하나에게 평타를 넣은 것이다.
#
# 반환: 한 명이라도 때렸으면 true.
func _resolve_override_attack(skill: SkillData) -> bool:
	var base := get_stats().get_physical_attack()
	var hit_any := false

	# 순회 중 적이 죽어(queue_free) 목록이 흔들릴 수 있으므로 사본을 돈다.
	for enemy in GameManager.get_all_enemies().duplicate():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		if global_position.distance_to(enemy.global_position) > skill.attack_override_aoe_radius:
			continue

		var damage := skill.get_attack_override_damage(enemy.max_hp)
		if damage <= 0:
			damage = base
		_resolve_attack_hit(enemy, damage)
		hit_any = true

	if hit_any and skill.attack_override_aoe_radius > 0.0:
		_spawn_burst(global_position, skill.attack_override_aoe_radius)

	return hit_any


# ===== 직선 범위 스킬 (Beam) =====

# **커서로 조준한 방향**으로 뻗는 직사각형 안의 적 **전체**를 관통해 때린다(태희 E, #263 · 조준 #264).
#
# 피해는 대상마다 다르다 — SkillData.get_damage_against() 가 그 적의 **현재 체력**을 보고
# 정한다. 방어 적용은 대상의 take_damage() 가 하므로 여기서 피해 공식을 다시 쓰지 않는다.
#
# 평타가 아니므로 처형·피흡·표식은 걸리지 않는다. 그 셋은 평타의 규칙이다(_resolve_attack_hit).
func _cast_beam_skill(skill: SkillData) -> void:
	var origin := global_position
	var forward := get_aim_direction()
	var side_axis := Vector2(-forward.y, forward.x)
	var half_width: float = skill.beam_width * 0.5
	var boost := get_stats().get_goddess_skill_boost()

	for enemy in GameManager.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		var relative: Vector2 = enemy.global_position - origin
		var along: float = relative.dot(forward)
		# 등 뒤와 사거리 밖은 제외한다.
		if along < 0.0 or along > skill.beam_length:
			continue
		if absf(relative.dot(side_axis)) > half_width:
			continue
		enemy.take_damage(skill.get_damage_against(enemy.hp, boost), self)

	_spawn_beam_effect(origin, forward, skill)

	# 빔에는 노린 대상이 하나로 없다. 아군 AI 는 최근접 적을 스스로 고른다(#257).
	if is_controlled() and EventBus:
		EventBus.player_attacked.emit(self, null)


# 빔이 지나간 자리를 잠깐 그린다. 아트가 없어 도형이다(투사체·적 플레이스홀더와 같은 규약).
func _spawn_beam_effect(origin: Vector2, forward: Vector2, skill: SkillData) -> void:
	var host := get_parent()
	if host == null:
		return
	var effect := BEAM_EFFECT_SCENE.instantiate()
	host.add_child(effect)
	effect.global_position = origin
	effect.setup(forward, skill.beam_length, skill.beam_width, data.tint if data != null else Color.WHITE)


# ===== 평타 쿨감 (Cooldown reduction on attack) =====

# 평타 1회가 스킬 쿨타임을 줄인다(태희 E, #263).
#
# 대상은 cooldown_reduction_per_attack 을 선언한 스킬뿐이다. 선언하지 않은 스킬은
# 지금까지처럼 시간으로만 줄어든다.
func _reduce_skill_cooldowns_on_attack() -> void:
	if data == null or _skill_cooldowns.is_empty():
		return
	for skill in data.skills:
		if skill == null or skill.cooldown_reduction_per_attack <= 0.0:
			continue
		if not _skill_cooldowns.has(skill.skill_id):
			continue
		var left: float = float(_skill_cooldowns[skill.skill_id]) - skill.cooldown_reduction_per_attack
		if left <= 0.0:
			_skill_cooldowns.erase(skill.skill_id)
		else:
			_skill_cooldowns[skill.skill_id] = left


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


# 이 노드에 스킬 보호막을 씌운다.
#
# 실제로 들어간 만큼만 스킬 몫으로 센다. 총량 한도는 없어졌지만(#261) 이 계산은 남겨 둔다 —
# 없는 보호막이 깨지기를 기다리면 폭발이 나지 않으므로, "실제로 걸린 양"이 계약이다.
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

	# 버퍼 3단계(#369). 이 함수는 **받는 쪽** 노드 위에서 도므로 공은 caster 에게 간다 —
	# 보호막을 얻은 사람이 아니라 건 사람이 제공자다. 자기 자신에게 걸 때는 caster 가 self 라
	# 같은 경로로 처리된다.
	if caster != null and is_instance_valid(caster) and caster.has_method("_credit_support_provided"):
		caster._credit_support_provided(gained)


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
	_spawn_burst(origin, skill.aoe_radius)
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


func _spawn_burst(origin: Vector2, radius: float) -> void:
	var host := get_parent()
	if host == null or radius <= 0.0:
		return
	var diameter: float = radius * 2.0
	SpriteSheetEffect.spawn_once(
		host, BURST_EFFECT_SHEET, origin, BURST_FRAME_COUNT,
		Vector2(diameter, diameter), BURST_FPS
	)


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

	# 실제로 대시가 나간 지점에서만 알린다(#345) — 충전이 없어 막힌 입력은 대시가 아니다.
	EventBus.player_dashed.emit(self)
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
	# 스킬 캐스트 중에도 평타는 나가지 않는다 — 시전 시간이 이 스킬의 대가다(#263).
	return is_alive and _attack_cooldown_left <= 0.0 and _cast_time_left <= 0.0 \
		and not StatusEffectSystem.blocks_attack(self)

# 평타를 낸다. 쿨다운 중이면 아무것도 하지 않는다.
# 피해량은 PlayerStats.get_physical_attack(), 방어 적용은 대상의 apply_defense()가 한다.
#
# 평타는 역할 메커니즘(§8.1 시너지 1단계)이 걸리는 지점이기도 하다.
# 순서: 처형 판정 -> 피해 -> 표식 부여 -> 표식 충전 -> 스택 축적
#
# 평타는 **근접 즉시타격**과 **원거리 투사체** 두 갈래다(#263). 어느 쪽인지는 캐릭터 정의가
# 정한다(CharacterData.basic_attack_projectile_speed). 갈라지는 것은 "언제·누구에게 닿는가"
# 뿐이고, 닿았을 때 무슨 일이 일어나는지는 _resolve_attack_hit() 한 곳이 갖는다.
#
# **조준 발사**(#264): 사람이 잡은 원거리 캐릭터는 사거리 안에 적이 없어도 커서 쪽으로 쏜다.
# 조준이 있다는 것은 빗나갈 수 있다는 뜻이고, 맞을 때만 나가면 조준이 장식이 된다.
# 근접과 아군 AI 는 지금까지대로 사거리 안에 적이 있어야 평타가 나간다.
func try_attack() -> bool:
	if not can_attack():
		return false

	var aimed := _uses_aimed_fire()
	var target := _find_attack_target()

	# 평타 변형 창(#328)이 열려 있으면 **변형된 평타의 반경**이 곧 사거리다.
	# 그 반경이 평타 사거리보다 넓을 수 있어서, 대상 판정을 따로 본다 —
	# 그러지 않으면 반경 안에 적이 있는데도 "사거리 안에 적이 없다"고 평타가 나가지 않는다.
	var override_skill: SkillData = _attack_override_skill if is_attack_override_open() else null
	if override_skill != null and not _has_enemy_within(override_skill.attack_override_aoe_radius):
		override_skill = null

	if target == null and not aimed and override_skill == null:
		return false

	_attack_cooldown_left = get_attack_cooldown()

	# 아군 AI 가 "플레이어가 지금 때리는 적"을 알아야 한다(#257).
	#
	# 조준 발사에서는 이 값이 **커서 아래 적이 아니라 플레이어에게 가장 가까운 적**이다.
	# 커서 쪽 적을 골라 보내지 않는 이유: 탄이 유도되지 않으므로 "노린 적"이 확정되지 않는데,
	# 추정으로 하나를 집으면 아군 화력이 플레이어가 실제로 맞히는 적과 어긋난다.
	# 가까운 적을 함께 치는 편이 조준의 자유와 충돌하지 않는다.
	# 사거리 안에 적이 없으면 null 이고, 아군 AI 는 그때 자기 최근접 적을 스스로 고른다.
	if is_controlled() and EventBus:
		EventBus.player_attacked.emit(self, target)

	# 평타 발생을 먼저 센다. 처형으로 끝나거나 적을 죽인 평타도 "나간 평타"다.
	# 빗나갈 수 있게 된 뒤에도 이 기준은 그대로다 — 패시브·쿨감의 계약이 "발생"이기 때문이다.
	_attack_swing_count += 1

	# 파티 전체의 평타가 게이지를 채운다(#259). 표식 충전과 같은 규약이다.
	_charge_party_skill_gauges()

	# 평타로 줄어드는 스킬 쿨타임(#263). 발생 기준이라 빗나간 탄도 쿨감을 준다.
	_reduce_skill_cooldowns_on_attack()

	# 이번 평타의 패시브 중 **날아가는 탄에 실려야** 하는 것을 먼저 떼어 낸다.
	# 나머지는 지금 이 자리에서 터진다.
	var impact_passive := _projectile_impact_passive()
	_apply_attack_passives(impact_passive)

	# 평타 변형 창(#328): 이번 평타는 원래 평타가 아니라 **광역 근접 평타**로 나간다.
	# 투사체 평타를 쓰는 캐릭터에게도 이 창이 열리면 근접 광역이 된다 — 창의 계약이
	# "평타를 갈아치운다"이므로, 원래 평타의 성질(탄이 날아간다)까지 대체된다.
	if override_skill != null:
		_resolve_override_attack(override_skill)
		_gain_stack()
		return true

	# 낙뢰 평타(#336): 날아가지 않고 **대상 자리에** 즉시 떨어진다. 그 원 안의 적이 전부 맞는다.
	if data != null and data.has_strike_basic_attack():
		# 패시브 광역이 대상을 먼저 죽였을 수 있다. 그때는 떨어뜨릴 자리가 없다.
		if is_instance_valid(target) and target.is_alive:
			_resolve_strike_attack(target)
		_gain_stack()
		return true

	# 원거리 평타: 탄을 쏘고 끝난다. 피해·처형·피흡·표식은 탄이 닿았을 때 걸린다.
	if data != null and data.has_projectile_basic_attack():
		_fire_basic_attack_projectile(target, impact_passive)
		_gain_stack()
		return true

	# 패시브 광역 피해가 대상을 먼저 죽일 수 있다.
	if not is_instance_valid(target) or not target.is_alive:
		_gain_stack()
		return true

	_resolve_attack_hit(target, get_stats().get_physical_attack())
	_gain_stack()
	return true


# 이번 평타가 **커서 조준**으로 나가는가(#264).
#
# 셋이 모두 맞아야 한다: 사람이 잡고 있고(마우스가 있다), 캐릭터가 투사체 평타를 쓰며,
# 그 탄이 날아가 맞을 수 있다. 근접은 조준해도 닿는 거리가 그대로라 대상 판정을 바꾸지 않는다
# — 근접에 각도 판정을 새로 넣지 않는 것이 확정 스펙이다(#264).
func _uses_aimed_fire() -> bool:
	return is_controlled() and data != null and data.has_projectile_basic_attack()


# 평타가 대상에 **닿았을 때** 일어나는 일 전부. 근접 즉시타격과 원거리 탄이 함께 쓴다.
#
# 여기가 평타 규칙의 단일 출처다. 투사체 쪽이 이 순서를 흉내 내면 두 벌이 되어
# 한쪽만 고쳐지는 순간이 온다(Projectile.on_hit 주석과 같은 이유).
#
# 순서: 처형 -> 피해 -> 피흡 -> 표식 부여 -> 표식 충전.
func _resolve_attack_hit(target: Node, damage: int) -> void:
	if not is_instance_valid(target) or not target.is_alive:
		return

	# 버퍼: 조건이 맞으면 피해 대신 처형한다.
	if _try_execute(target):
		return

	# 버퍼 3단계: 제공한 힐/보호막에서 쌓아 둔 보류 피해를 이 평타에 얹는다(#369).
	#
	# 처형 뒤에 두는 이유: 처형은 피해를 넣는 것이 아니라 대상을 없애는 것이라 얹을 자리가
	# 없다. 거기서 소모하면 보류가 아무 일도 못 하고 사라진다 — 다음 평타를 위해 남긴다.
	damage += _consume_buffer_pending_damage()

	var dealt: int = target.take_damage(damage, self)

	# 원거리 3단계: 실제로 준 피해에 비례해 회복한다(죽인 타격도 포함이다).
	_apply_lifesteal(dealt)

	# 강지 평타 패시브(#334): 준 피해에 비례해 가장 위태로운 아군을 회복시킨다.
	# 피흡과 같은 자리·같은 기준(실제로 들어간 피해)이지만 회복하는 쪽이 자기가 아니라 아군이다.
	_apply_attack_ally_heal(dealt)

	# 대상이 이 평타로 죽었으면 이후 처리를 하지 않는다.
	if not is_instance_valid(target) or not target.is_alive:
		return

	# 탱커: 표식을 부여한다(이미 있으면 StatusEffectData의 중첩 규칙대로).
	if _is_role_active(CharacterData.Role.TANK):
		StatusEffectSystem.apply(target, MARK_EFFECT, self)

	# 표식 충전은 **파티 전체**의 평타로 이뤄진다(탱커 본인만이 아니다).
	_charge_mark(target)

	# 평타에 실린 상태 효과(#336). 평타 모양(근접/투사체/낙뢰)과 무관하게, **닿았으면** 걸린다.
	# 여기 두는 이유는 이 함수의 계약과 같다 — 평타가 닿았을 때 일어나는 일의 단일 출처다.
	if data != null and data.basic_attack_effect_id != &"":
		StatusEffectSystem.apply(target, data.basic_attack_effect_id, self)


# 평타 투사체를 쏜다.
#
# 방향은 두 갈래다(#264):
#   사람이 잡았으면 **커서 쪽**(get_aim_direction). 노린 적이 없어도 그 방향으로 나간다.
#   아군 AI 면 **잡은 타겟 쪽**. 마우스가 없으므로 조준할 것이 없다.
# 어느 쪽이든 유도하지 않는다 — 발사 뒤 적이 움직이면 빗나간다.
#
# impact_passive 가 있으면 그 탄은 착탄 지점에서 광역으로 터진다(태희 4타, #263).
# 광역 위력은 **시전자 물리 공격력 x attack_aoe_power_percent** 이며 반경 안 전원에게 들어간다.
func _fire_basic_attack_projectile(target: Node, impact_passive: SkillData = null) -> void:
	var host := get_parent()
	if host == null:
		return

	var direction := _basic_attack_direction(target)
	if direction == Vector2.ZERO:
		return

	var damage := get_stats().get_physical_attack()
	var radius := 0.0
	if impact_passive != null and impact_passive.aoe_radius > 0.0 and impact_passive.attack_aoe_power_percent > 0.0:
		radius = impact_passive.aoe_radius
		damage = int(round(float(damage) * impact_passive.attack_aoe_power_percent))

	var projectile = PROJECTILE_SCENE.instantiate()
	host.add_child(projectile)
	projectile.global_position = global_position
	projectile.setup(
		direction,
		data.basic_attack_projectile_speed,
		damage,
		self,
		data.basic_attack_projectile_range,
		PROJECTILE_HIT_RADIUS,
		&"",
		data.tint,
		true,
		radius
	)
	# 닿았을 때의 처리는 평타 규칙(위)이 갖는다. 탄은 "언제·누구에게"까지만 정한다.
	projectile.on_hit = _resolve_attack_hit

	# 체인 창(태희 Q)이 열려 있으면 이 탄은 맞은 뒤 다음 적으로 튕긴다.
	if _chain_time_left > 0.0 and _chain_skill != null:
		projectile.setup_chain(
			_chain_skill.chain_bounces,
			_chain_skill.chain_range,
			_chain_skill.chain_damage_percent
		)


# 평타 탄이 나갈 방향. 조준이 켜져 있으면 커서 쪽, 아니면 타겟 쪽이다.
# 둘 다 없으면 0 벡터를 돌려주고, 부르는 쪽이 발사를 접는다.
# 낙뢰 평타 한 번(#336). 대상 **자리**에 원을 떨어뜨리고 그 안의 적을 전부 때린다.
#
# 원의 중심이 시전자가 아니라 **대상**이다: 원거리에서 떨어뜨리는 것이므로 발밑에서 터지면
# 사거리의 의미가 없다(태희 4타 광역이 착탄 지점에서 터지는 것과 같은 이유).
#
# 반경 안 적 하나하나를 _resolve_attack_hit() 에 통과시킨다 — 그래서 처형·피흡·표식·
# 평타 상태 효과가 전원에게 각각 걸린다. 광역이 된 평타는 맞은 적 하나하나에게 평타를 넣은 것이다.
#
# 대상 자신도 그 원 안에 있으므로 따로 때리지 않는다(중복 타격 방지).
func _resolve_strike_attack(target: Node) -> void:
	var center: Vector2 = target.global_position
	var radius: float = data.basic_attack_strike_radius
	var damage := get_stats().get_physical_attack()

	_spawn_strike_effect(center, radius)

	# 순회 중 적이 죽어(queue_free) 목록이 흔들릴 수 있으므로 사본을 돈다.
	for enemy in GameManager.get_all_enemies().duplicate():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		if center.distance_to(enemy.global_position) > radius:
			continue
		_resolve_attack_hit(enemy, damage)


# 낙뢰가 떨어진 자리를 잠깐 보여 준다. **판정하지 않는다**(BeamEffect 와 같은 규약).
func _spawn_strike_effect(at_global: Vector2, radius: float) -> void:
	var host := get_parent()
	if host == null:
		return
	var fx = STRIKE_EFFECT_SCENE.instantiate()
	host.add_child(fx)
	fx.global_position = at_global
	fx.setup(radius, data.tint if data != null else Color.WHITE)


func _basic_attack_direction(target: Node) -> Vector2:
	if _uses_aimed_fire():
		return get_aim_direction()
	if is_instance_valid(target):
		return target.global_position - global_position
	return Vector2.ZERO


# 평타로 준 피해에 비례해 **가장 위태로운 아군**을 회복시킨다(강지, #334).
#
# 왜 _apply_attack_passives() 가 아니라 여기인가: 그쪽은 `every_n_attacks` 주기 패시브이고
# 기준이 평타 **발생**이다. 이 채널의 계약은 "**실제로 들어간 피해**의 비율"이라 닿아야만
# 나가고, 그 값을 아는 자리는 여기다(원거리 3단계 피흡이 같은 이유로 같은 자리에 있다).
#
# 여러 스킬이 이 채널을 가지면 각각 따로 회복시킨다. 합산하지 않는 이유: 스킬마다 대상을
# 다시 고르는 것이 맞다 — 첫 회복으로 최저 체력이 바뀌면 다음 회복은 다른 사람에게 가야 한다.
func _apply_attack_ally_heal(damage_dealt: int) -> void:
	if damage_dealt <= 0 or data == null:
		return

	for skill in data.skills:
		if skill == null or not skill.heals_ally_on_attack():
			continue
		var amount := skill.get_ally_heal_from_damage(damage_dealt)
		if amount <= 0:
			continue
		var target := _lowest_health_ally()
		if target != null:
			# 강지 수혈도 힐 제공이다 — 버퍼 3단계가 켜져 있으면 여기서도 쌓인다(#369).
			_credit_support_provided(target.heal(amount))


# ===== 평타 패시브 (Basic-attack passives) =====
#
# 캐릭터 고유 스킬(SkillData) 중 every_n_attacks 가 설정된 것은 평타 주기로 발동한다.
# 역할 메커니즘(아래)과 달리 **파티 구성과 무관하다** — 시너지가 아니라 캐릭터 개성이라
# 혼자 있어도 작동한다(docs §3 티어2).
#
# 데이터가 없으면 아무 일도 하지 않으므로, 패시브를 저작하지 않은 캐릭터의 평타는 이전과 같다.
func _apply_attack_passives(skip: SkillData = null) -> void:
	if data == null:
		return
	for skill in data.skills:
		if skill == null or skill == skip or skill.every_n_attacks <= 0:
			continue
		if _attack_swing_count % skill.every_n_attacks != 0:
			continue
		_fire_attack_passive(skill)


# 이번 평타에서 발동할 패시브 중 **투사체 착탄 지점**에서 터져야 하는 것. 없으면 null.
#
# 원거리 캐릭터의 광역이 자기 발밑에서 나면 사거리의 의미가 없다. 그래서 이 패시브만
# 지금 터뜨리지 않고 떼어 두었다가 탄에 실어 보낸다.
# 근접 캐릭터에게는 실을 탄이 없으므로 항상 null 이다(그쪽은 발밑에서 그대로 터진다).
func _projectile_impact_passive() -> SkillData:
	if data == null or not data.has_projectile_basic_attack():
		return null
	for skill in data.skills:
		if skill == null or skill.every_n_attacks <= 0 or not skill.aoe_at_projectile_impact:
			continue
		if _attack_swing_count % skill.every_n_attacks != 0:
			continue
		return skill
	return null


# 평타 패시브 한 번. 두 채널이 있고, 한 스킬이 둘 다 가질 수도 있다.
#
#   ① 회복 + 회복량 비례 광역(미나) — 체력이 가득 차 있으면 회복이 0이고 광역도 0이다.
#      기준이 "최대 체력"이 아니라 "잃은 체력"이라 몰릴수록 세지는 역전 장치가 된다.
#   ② 공격력 비례 광역(태희) — 회복과 무관하게 항상 같은 비율로 나간다.
#
# ② 는 aoe_at_projectile_impact 가 켜져 있고 시전자가 투사체 평타를 쓰면 여기까지 오지
# 않는다. 그 경우는 탄이 착탄 지점에서 터뜨린다(_fire_basic_attack_projectile).
#
# 여기에 더해 아군 회복 채널(ally_heal, #276)도 이 훅에서 나간다 — 설아의 3타 회복이다.
# 광역과 달리 대상이 "가장 위태로운 아군" 하나라 반경과 무관하다.
func _fire_attack_passive(skill: SkillData) -> void:
	# 아군 회복(#276). 시전자 자신의 체력과 무관한 별개 채널이라 아래 회복보다 먼저 본다.
	if skill.heals_allies():
		_heal_lowest_ally(skill)

	var healed := 0
	if skill.heal_missing_hp_percent > 0.0:
		var missing: int = max_hp - hp
		healed = int(round(missing * skill.heal_missing_hp_percent))
		if healed > 0:
			# 자기에게 거는 힐도 이 멤버가 제공한 것이다(#369).
			# 아래 heal_to_aoe_damage_percent 와는 **별개 채널**이다(SkillData.gd:203) —
			# 그쪽은 캐릭터 개성이라 항상 돌고, 이쪽은 파티 구성으로 켜진다. 둘 다 켜지면 각각 나간다.
			healed = heal(healed)
			_credit_support_provided(healed)

	var amount := 0
	if healed > 0 and skill.heal_to_aoe_damage_percent > 0.0:
		amount += int(round(healed * skill.heal_to_aoe_damage_percent))
	if skill.attack_aoe_power_percent > 0.0:
		amount += int(round(get_stats().get_physical_attack() * skill.attack_aoe_power_percent))

	if amount <= 0 or skill.aoe_radius <= 0.0:
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

# ----- 버퍼 3단계: 보류 피해 (Buffer tier-3 pending damage) -----
# 이 멤버가 제공한 힐/보호막에서 나온, 아직 쓰지 않은 추가 피해(#369).
#
# 왜 즉시 넣지 않고 쌓아 두는가: 설계 §8.1 은 "힐/보호막을 제공할 때 그 양에 비례해
# 추가 피해"까지만 [확정]했고 **누구에게 언제 들어가는지는 정하지 않았다.**
# 즉시 광역으로 하면 반경 상수가 필요한데 설계에 근거가 없어 [임시값]이 하나 더 늘고,
# "가장 가까운 적"은 근거 없는 대상 선정 규칙이 된다.
#
# 다음 평타에 얹으면 새 수치 없이 대상이 자연히 정해지고, 버퍼 1단계 처형이 "버퍼가
# **직접** 공격해야 발동"하는 것과 계약이 같아진다 — 살리고, 그 값을 때려서 받는다.
# 대가: 힐 직후에 때리지 않으면 피해가 대기 상태로 남는다. 그것이 이 선택의 성질이다.
var _buffer_pending_damage: int = 0

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


# 이 캐릭터가 적에게 피해를 **실제로** 넣었을 때 불린다(EnemyBase.take_damage 가 부른다, #276).
#
# 평타·스킬·광역 패시브를 가리지 않는다. 피해가 나가는 자리는 여러 곳이지만 피해가 들어오는
# 곳은 한 곳이라, 그쪽에서 알리는 편이 새 피해 경로가 생겨도 자동으로 포함된다.
#
# 지금 여기 걸린 것은 **부여받은 흡혈**(EMPOWER)뿐이다. 원거리 3단계 피흡은 "평타로 준 피해"가
# 계약이라 여기 오지 않고 _resolve_attack_hit() 이 계속 갖는다 — 둘은 별개 채널이고, 둘 다
# 켜져 있으면 평타는 양쪽에서 회복한다.
func on_damage_dealt(dealt: int) -> void:
	if dealt <= 0 or not is_alive:
		return

	var percent := StatusEffectSystem.get_granted_lifesteal(self)
	if percent <= 0.0:
		return

	var amount := int(round(dealt * percent))
	if amount <= 0:
		return

	# 넘치는 분을 보호막으로 돌리지 않는다. 초과 회복 -> 보호막은 원거리 3단계가 가진 성질이고
	# (CombatTuning.overheal_to_shield_percent), 이 흡혈은 그 시너지와 무관한 별개 출처다.
	heal(amount)


func _gain_shield(amount: int) -> void:
	if amount <= 0:
		return
	# 총량 한도가 없다(#261). 예전에는 최대 체력 비례로 잘랐는데, 절대값으로 주는 보호막이
	# 받는 대상에 따라 조용히 잘려 스킬 밸런스가 남의 체력에 묶였다.
	_shield += amount


# 현재 보호막(표시·판정용).
func get_shield() -> int:
	return _shield


# --- 버퍼 3단계: 제공한 힐/보호막 -> 추가 피해 ---

# 이 멤버가 힐 또는 보호막을 **실제로 제공했을 때** 부른다(#369, docs §8.1).
#
# amount 는 요청한 양이 아니라 **들어간 양**이다. 만피에 넘친 힐과 0 으로 막힌 보호막은
# 제공된 것이 아니므로 세지 않는다 — 그러지 않으면 만피 파티를 계속 회복시키는 것만으로
# 피해가 쌓인다.
#
# 부르는 쪽이 **제공한 본인**이어야 한다. 보호막은 받는 쪽 노드에서 걸리므로
# (_apply_skill_shield 는 대상 위에서 돈다) 그쪽에서는 caster 에게 넘긴다.
func _credit_support_provided(amount: int) -> void:
	if amount <= 0:
		return
	# 배타 규칙(#73)은 is_tier3_active 에 이미 반영되어 있다 — 다른 역할이 3단계를
	# 발동한 파티에서는 여기서 자동으로 꺼진다.
	if not _is_role_tier3(CharacterData.Role.BUFFER):
		return

	var bonus := int(round(amount * CombatConfig.tuning.heal_to_damage_percent))
	if bonus <= 0:
		return
	_buffer_pending_damage += bonus


# 보류 피해를 꺼내 쓰고 0 으로 비운다. 평타가 **적중했을 때만** 부른다.
func _consume_buffer_pending_damage() -> int:
	var pending := _buffer_pending_damage
	_buffer_pending_damage = 0
	return pending


# 아직 쓰지 않은 보류 피해(표시·검증용).
func get_buffer_pending_damage() -> int:
	return _buffer_pending_damage


# --- 버퍼: 처형 ---

# 처형 조건을 만족하면 대상을 즉시 쓰러뜨린다.
# 조건 셋을 모두 만족해야 한다:
#   ① 이 멤버가 버퍼 역할이고 그 시너지가 켜져 있다 (버퍼가 **직접** 공격해야 한다)
#   ② 대상에 디버프가 걸려 있다
#   ③ 대상 체력이 execute_hp_percent 이하다
func _try_execute(target: Node) -> bool:
	# 두 갈래로 열린다(#276):
	#   ① 버퍼 1단계 시너지 — 파티 구성으로 켜지고, 대상에게 **디버프가 있어야** 한다.
	#   ② 부여받은 처형(EMPOWER) — 설아 E 같은 스킬이 한시적으로 준다. 시너지도 디버프도 묻지 않는다.
	#
	# ② 가 디버프를 묻지 않는 이유: 디버프 조건은 시너지가 **상시** 갖는 힘에 붙은 대가다.
	# 쿨타임과 지속시간으로 이미 값을 치른 스킬에 같은 대가를 또 물리면, 파티에 디버프 출처가
	# 없을 때 스킬이 조용히 아무 일도 하지 않는다.
	#
	# 체력 임계치(can_execute)는 어느 쪽이든 지킨다 — 그것은 처형의 정의이지 조건이 아니다.
	var granted := StatusEffectSystem.grants_execute(self)
	if not granted:
		if not _is_role_active(CharacterData.Role.BUFFER):
			return false
		if not StatusEffectSystem.has_any_debuff(target):
			return false
	if not can_execute(target):
		return false

	# 처형이 성사됐다는 표식을 그 자리에 남긴다(#331).
	#
	# take_damage **전에** 놓는다 — 그 호출이 대상을 죽여 queue_free() 하므로 뒤에서는
	# global_position 을 믿고 읽을 수 없다.
	_spawn_execute_mark(target.global_position)

	# 표식과 같은 이유로 죽이기 **전에** 알린다(#345) — 듣는 쪽이 대상을 읽을 수 있어야 한다.
	EventBus.enemy_executed.emit(target, self)

	# 남은 체력을 확실히 넘기는 피해를 넣어 방어력에 막히지 않게 한다.
	target.take_damage(target.max_hp * 100, self)
	return true


# 처형 표식을 전장에 놓는다.
#
# 부모가 **대상이 아니라 전장**이어야 한다(vfx-guide §1.7). 대상은 이 직후 사라지므로
# 자식으로 붙이면 표식도 함께 사라져 아무것도 보이지 않는다.
func _spawn_execute_mark(at_global: Vector2) -> void:
	var host := get_parent()
	if host == null:
		return
	var mark := EXECUTE_MARK_SCENE.instantiate()
	host.add_child(mark)
	mark.setup(at_global, UITheme.HOSTILE)

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

# 사거리 제한이 풀렸을 때 쓰는 값(px, #336).
#
# 한 방(Stage1_1.load_room)의 크기를 훨씬 넘는 거리라 "제한 없음"과 구분되지 않는다.
# INF 가 아닌 유한값인 이유는 get_attack_range() 주석 참고.
const UNLIMITED_ATTACK_RANGE: float = 100000.0


# 이 반경 안에 살아 있는 적이 하나라도 있는가(#328).
#
# 평타 변형 창이 "이번 평타가 나갈 수 있는가"를 판단할 때 쓴다. 대상을 하나 고르지 않는 이유:
# 변형된 평타는 반경 안 전원을 때리므로 고를 대상이 없다. 있는지만 알면 된다.
func _has_enemy_within(radius: float) -> bool:
	if radius <= 0.0:
		return false
	for enemy in GameManager.get_all_enemies():
		if enemy == null or not is_instance_valid(enemy) or not enemy.is_alive:
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			return true
	return false


# 평타 사거리.
#
# 캐릭터 정의가 값을 갖고 있으면 그쪽이 우선이다(원거리 평타는 씬 노드보다 훨씬 멀리 닿는다).
# 없으면 지금까지처럼 씬의 AttackArea2D 위치를 기준으로 삼는다.
func get_attack_range() -> float:
	# 사거리 제한 해제(#336). 켜져 있으면 거리 판정이 사실상 사라진다 —
	# 살아 있는 적이 있으면 어디에 있든 평타가 나간다.
	#
	# INF 를 쓰지 않고 아주 큰 수를 쓰는 이유: 이 값이 distance 비교뿐 아니라 뺄셈·곱셈에
	# 들어갈 수 있는데(HUD 표시 등), INF 는 그 자리에서 NaN 을 만든다.
	if StatusEffectSystem.grants_unlimited_attack_range(self):
		return UNLIMITED_ATTACK_RANGE

	if data != null and data.basic_attack_range > 0.0:
		return data.basic_attack_range
	var area := get_node_or_null("AttackArea2D")
	if area is Node2D:
		return maxf(area.position.length(), 1.0) * 2.0
	return 60.0


# ===== 피해 / 사망 (Damage / Death) =====

# 실제로 들어간 피해(방어·보호막 적용 후 체력에서 깎인 양)를 반환한다.
# 적 쪽(EnemyBase.take_damage)과 같은 규약이다.
#
# ignore_defense: 방어력을 적용하지 않는다(#328). **보호막은 그대로 받아 낸다** — 무시하는
# 것은 방어력뿐이다. 지금 이 통로를 쓰는 것은 하랑 E 의 자기 피해뿐이며, 그 이유는
# StatusEffectData.tick_ignores_defense 주석에 있다(방어 공식이 작은 피해를 크게 깎아
# "체력을 태워 화력을 얻는다"는 거래가 방어력 스텟에 따라 흔들린다).
func take_damage(amount: int, source = null, ignore_defense: bool = false) -> int:
	if not is_alive:
		return 0

	# 무적(#334)은 **맨 앞에서** 막는다. 방어력·보호막을 거치기 전이므로 보호막이 깎이지 않고,
	# 지속 피해도 들어가지 않고, 반사도 일어나지 않는다.
	#
	# 여기서 damage_taken 배수와 섞지 않는 이유: 그 배수는 최소 피해를 지켜 1 은 계속
	# 들어간다(감소를 겹쳐도 무적이 되지 않게 하려는 의도). 무적은 별개 상태다.
	if StatusEffectSystem.grants_invulnerable(self):
		return 0

	# 방어력 적용. 피해 공식은 PlayerStats.apply_defense()가 단일 출처다.
	var dealt: int = amount if ignore_defense else get_stats().apply_defense(amount)

	# 받는 피해 감소(#334). 방어와 나눠 둔 통로라 방어를 무시하는 피해에도 걸린다.
	dealt = get_stats().apply_damage_taken(dealt)

	# 보호막이 먼저 받아 낸다. 남은 만큼만 체력이 깎인다.
	var absorbed: int = mini(_shield, dealt)
	_shield -= absorbed
	dealt -= absorbed

	# 남은 체력보다 큰 피해는 넘치는 만큼 버려진다(EnemyBase 와 같은 규약).
	# 자르지 않으면 아래 반사가 실제로 들어간 피해보다 크게 나간다.
	dealt = mini(dealt, hp)

	# 스킬 보호막이 이 피해로 깎였는지 본다. 0이 되면 **깨짐**이고 폭발 계기다.
	# 원거리 3단계가 준 보호막만 깎인 경우에는 아무 일도 일어나지 않는다.
	var skill_shield_broke := false
	if _skill_shield > 0 and absorbed > 0:
		_skill_shield = maxi(_skill_shield - absorbed, 0)
		skill_shield_broke = _skill_shield <= 0

	hp -= dealt

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

# 회복시키고 **실제로 들어간 양**을 돌려준다(take_damage 가 dealt 를 돌려주는 것과 같은 규약).
#
# 왜 반환값이 필요한가: 만피 근처에서는 요청한 양과 들어간 양이 다르다. 버퍼 3단계는
# "제공한 힐에 비례"라 넘친 몫까지 세면 만피인 파티를 계속 회복시키는 것만으로 피해가
# 쌓인다. 부르는 쪽이 무시해도 되므로 기존 호출부는 그대로 동작한다.
func heal(amount: int) -> int:
	if not is_alive or amount <= 0:
		return 0

	var before := hp
	hp += amount
	hp = min(hp, max_hp)
	var applied := hp - before

	if EventBus and applied > 0:
		# 숫자와 연출은 요청량이 아니라 실제로 오른 체력을 표시한다(#399).
		EventBus.healing_applied.emit(self, applied)

	return applied

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
