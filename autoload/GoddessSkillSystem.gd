extends Node

# 여신의 스킬의 단일 출처 (autoload).
#
# 책임 넷:
#   1. data/goddess_skills 의 정의(.tres)를 로드해 skill_id 로 조회한다.
#   2. **무엇을 들고 나갈지**(선택)를 들고 저장한다.
#   3. **스테이지당 1회** 제약을 판정한다.
#   4. 시전한다 — 시간 정지 상태를 소유하고, 부활을 실행한다.
#
# 하지 않는 것:
#   - 그리지 않는다. 편성 화면과 HUD 가 이 시스템을 읽어 그린다.
#   - 강화 배수를 새로 계산하지 않는다. PlayerStats.get_goddess_skill_boost() 가 출처다.
#   - 죽음 처리를 바꾸지 않는다. 죽은 파티원은 **PartySystem 의 멤버 중 살아 있는 노드가
#     없는 멤버**로 판정한다(Player.die() 가 노드를 queue_free 하므로 노드는 남지 않는다).
#
# 시간 정지를 어떻게 구현하는가:
#   얼릴 노드의 process_mode 를 PROCESS_MODE_DISABLED 로 바꾼다.
#   Engine.time_scale 은 파티까지 함께 멈추므로 쓸 수 없고, 노드마다 "정지 중인가"를
#   묻게 만들면 적·투사체·상태효과 세 곳에 같은 분기가 생긴다.
#   상태 효과는 StatusEffectSystem 이 can_process() 로 걸러 준다 — 멈춘 노드면 상태도 멈춘다.
#
# 참고: entities/goddess/GoddessSkillData.gd, docs/combat-screen-design.md §8

const SKILLS_DIR := "res://data/goddess_skills"

# 저장 키. 무엇을 골랐는지만 저장한다(스테이지당 사용 여부는 전투 상태이므로 저장하지 않는다).
const SAVE_KEY := "goddess_skill"

# 발동 입력 (project.godot [input] 에 정의, R 키).
const CAST_ACTION := "goddess_skill"

# 시간 가속(#366)이 스텟 기여를 등록할 때 쓰는 출처 키. 원거리 스택과 다른 키라 서로 합산된다.
const HASTE_SOURCE := &"goddess_haste"

# 부활한 파티원을 살아 있는 파티원에게서 얼마나 떨어뜨려 세울지(px).
const REVIVE_OFFSET := Vector2(-48.0, 0.0)

# 선택이 바뀌었다. 편성 화면·HUD 는 이 신호로 갱신한다.
signal selection_changed(skill_id: StringName)

# 사용 가능 여부가 바뀌었다(스테이지 진입으로 초기화 / 사용으로 소진).
signal availability_changed(available: bool)

# skill_id(StringName) -> GoddessSkillData
var _skills: Dictionary = {}

# 들고 나갈 스킬. 비어 있으면 아무것도 고르지 않은 상태다.
var _selected_id: StringName = &""

# 이번 스테이지에서 아직 쓸 수 있는가.
var _available: bool = true

# ----- 시간 정지 상태 -----
var _time_stop_left: float = 0.0
# 얼린 노드 -> 원래 process_mode. 되돌릴 때 그대로 복원한다
# (전부 INHERIT 으로 되돌리면 원래 다른 값이던 노드가 조용히 달라진다).
var _frozen: Dictionary = {}

# ----- 시간 가속 상태 (#366) -----
var _haste_skill: GoddessSkillData = null
var _haste_boost: float = 1.0
var _haste_total: float = 0.0
var _haste_left: float = 0.0
# 한 번이라도 기여를 걸었던 노드. 종료 시 여기 전부에서 지운다.
var _haste_touched: Dictionary = {}


func _ready() -> void:
	name = "GoddessSkillSystem"

	# 시간 정지 중에도 이 노드는 돌아야 한다 — 얼린 것을 되돌릴 주체가 자기 자신이다.
	# (트리 정지(메타 화면·튜토리얼) 중에는 잔여 시간이 흐르지 않아야 하므로
	#  PROCESS_MODE_ALWAYS 가 아니라 기본값을 쓰고, 입력만 따로 막는다.)
	_load_all()
	SaveSystem.register_provider(SAVE_KEY, self)

	EventBus.stage_started.connect(_on_stage_started)


# ===== 로드 (Load) =====

func _load_all() -> void:
	_skills.clear()

	var dir := DirAccess.open(SKILLS_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(SKILLS_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()


func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")


func _load_one(path: String) -> void:
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is GoddessSkillData):
		push_warning("GoddessSkillSystem: GoddessSkillData가 아닙니다(건너뜀): " + load_path)
		return

	var skill: GoddessSkillData = res
	var problems := skill.validate()
	if not problems.is_empty():
		push_warning("GoddessSkillSystem: 유효하지 않은 스킬(" + load_path + "): " + ", ".join(problems))
		return

	if _skills.has(skill.skill_id):
		push_warning("GoddessSkillSystem: 중복 skill_id(건너뜀): " + String(skill.skill_id))
		return

	_skills[skill.skill_id] = skill


# ===== 조회 (Query) =====

# 고를 수 있는 스킬 id 목록. 이름순이라 화면마다 순서가 달라지지 않는다
# (StringName 끼리의 정렬은 사전순이 아니다 — PortraitSystem 과 같은 이유로 String 으로 정렬한다).
func get_all_ids() -> Array:
	var names: Array = []
	for id in _skills:
		names.append(String(id))
	names.sort()

	var ids: Array = []
	for n in names:
		ids.append(StringName(n))
	return ids


func get_skill(skill_id: StringName) -> GoddessSkillData:
	return _skills.get(skill_id, null)


func get_selected_id() -> StringName:
	return _selected_id


func get_selected() -> GoddessSkillData:
	return get_skill(_selected_id)


# 지금 쓸 수 있는가(고른 스킬이 있고 이번 스테이지에서 아직 안 썼다).
func is_available() -> bool:
	return _available and get_selected() != null


func is_time_stopped() -> bool:
	return _time_stop_left > 0.0


func get_time_stop_left() -> float:
	return maxf(_time_stop_left, 0.0)


# ----- 시간 가속 조회 (#366) -----

# 정의까지 함께 본다: 남은 시간만으로 판정하면 정의가 없는 상태에서 화면이 "가속 중 +0%"
# 라는 앞뒤 안 맞는 줄을 그린다. 두 값은 항상 함께 세워지고 함께 지워진다.
func is_hasted() -> bool:
	return _haste_left > 0.0 and _haste_skill != null


func get_haste_left() -> float:
	return maxf(_haste_left, 0.0)


# 곡선을 태운 지금의 최대치 대비 비율(0~1). 화면이 "얼마나 올랐나"를 보여 줄 때 쓴다.
func get_haste_ratio() -> float:
	if _haste_skill == null:
		return 0.0
	return _haste_skill.get_ramp_ratio(_haste_progress())


# 지금 걸려 있는 공격속도 증가율(0.5 = +50%).
func get_haste_attack_speed_percent() -> float:
	if _haste_skill == null:
		return 0.0
	return _haste_skill.get_haste_attack_speed(_haste_progress(), _haste_boost)


# 지금 걸려 있는 이동속도 증가율.
func get_haste_move_speed_percent() -> float:
	if _haste_skill == null:
		return 0.0
	return _haste_skill.get_haste_move_speed(_haste_progress(), _haste_boost)


# 여신 스킬 강화 배수. **파티 내 최고값**을 쓴다.
#
# 왜 최고값인가: 여신 스킬은 파티 공용인데 배수는 캐릭터 스텟(신앙심)과 장비(거울)에서
# 나온다. 조종 중인 캐릭터 기준으로 하면 시전 직전에 캐릭터를 바꿔 최적화하는 짓을
# 강요하게 되고, 평균으로 하면 거울 하나를 끼운 효과가 1/3 로 희석된다.
# 최고값이면 "거울을 한 명에게 끼우면 파티 전체가 이득"이 되어 투자 판단이 단순해진다.
func get_boost() -> float:
	var best := 1.0
	for member in PartySystem.get_members():
		if member == null:
			continue
		var boost: float = member.get_stats().get_goddess_skill_boost()
		if boost > best:
			best = boost
	return best


# ===== 선택 (Selection) =====

# 들고 나갈 스킬을 고른다. 빈 id 를 넘기면 선택을 해제한다.
func select(skill_id: StringName) -> bool:
	if not String(skill_id).is_empty() and not _skills.has(skill_id):
		push_warning("GoddessSkillSystem: 알 수 없는 skill_id: " + String(skill_id))
		return false

	if _selected_id == skill_id:
		return true

	_selected_id = skill_id
	SaveSystem.request_save()
	selection_changed.emit(_selected_id)
	return true


# ===== 스테이지 (Per-stage) =====

func _on_stage_started(_stage_name: String) -> void:
	# 진입할 때마다 1회로 돌아온다. 이 시스템의 유일한 제약이다.
	_available = true
	_end_time_stop()
	_end_haste()
	availability_changed.emit(is_available())


# ===== 시전 (Cast) =====

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(CAST_ACTION):
		return
	# 메타 화면이 떠 있으면 전투 입력이 아니다(화면 쪽이 먼저 먹지 못한 키만 여기 온다).
	if ScreenManager.has_screen():
		return
	get_viewport().set_input_as_handled()
	cast()


# 고른 스킬을 발동한다. 성공하면 사용 횟수를 소모한다.
#
# 실패(false)에는 두 종류가 있고 **둘 다 사용 횟수를 쓰지 않는다**:
#   - 고르지 않았거나 이미 썼다
#   - 조건이 맞지 않는다(부활할 파티원이 없다)
func cast() -> bool:
	if not is_available():
		return false

	var skill := get_selected()
	var boost := get_boost()
	var ok := false

	match skill.kind:
		GoddessSkillData.Kind.TIME_STOP:
			ok = _cast_time_stop(skill, boost)
		GoddessSkillData.Kind.REVIVE:
			ok = _cast_revive(skill, boost)
		GoddessSkillData.Kind.TIME_HASTE:
			ok = _cast_time_haste(skill, boost)

	if not ok:
		return false

	_available = false
	EventBus.goddess_skill_used.emit(skill.skill_id)
	availability_changed.emit(is_available())
	return true


# ----- 스킬 1: 시간 정지 -----

func _cast_time_stop(skill: GoddessSkillData, boost: float) -> bool:
	var duration := skill.get_effective_duration(boost)
	if duration <= 0.0:
		return false

	_freeze_all()
	_time_stop_left = duration
	EventBus.time_stop_changed.emit(true, _time_stop_left)
	return true


# 파티원을 **제외한** 전투 요소를 얼린다.
#
# 대상 둘:
#   적            — GameManager 가 활성 적의 단일 출처다.
#   적의 투사체    — 파티가 쏜 탄은 얼리지 않는다(파티의 시간은 흐른다).
#                    Projectile.source 로 가른다.
func _freeze_all() -> void:
	for enemy in GameManager.get_all_enemies():
		_freeze(enemy)

	for projectile in get_tree().get_nodes_in_group(&"projectile"):
		if _is_party_node(projectile.source if "source" in projectile else null):
			continue
		_freeze(projectile)


func _freeze(node: Node) -> void:
	if node == null or not is_instance_valid(node) or _frozen.has(node):
		return
	_frozen[node] = node.process_mode
	node.process_mode = Node.PROCESS_MODE_DISABLED


func _end_time_stop() -> void:
	_time_stop_left = 0.0

	for node in _frozen.keys():
		# 정지 중에 사라진 노드가 있을 수 있다(방을 새로 만들었을 때 등).
		if is_instance_valid(node):
			node.process_mode = _frozen[node]
	_frozen.clear()
	EventBus.time_stop_changed.emit(false, 0.0)


func _process(delta: float) -> void:
	if _time_stop_left > 0.0:
		_time_stop_left -= delta
		if _time_stop_left <= 0.0:
			_end_time_stop()

	if _haste_left > 0.0:
		_haste_left -= delta
		if _haste_left <= 0.0:
			_end_haste()
		else:
			_apply_haste()
			EventBus.goddess_haste_changed.emit(true, _haste_left, get_haste_ratio())


func _is_party_node(node) -> bool:
	if node == null or not is_instance_valid(node) or not (node is Node):
		return false
	return (node as Node).is_in_group(PartySystem.MEMBER_GROUP)


# ----- 스킬 3: 시간 가속 (#366) -----

func _cast_time_haste(skill: GoddessSkillData, boost: float) -> bool:
	var duration := skill.get_effective_duration(boost)
	if duration <= 0.0:
		return false

	_haste_skill = skill
	_haste_boost = boost
	_haste_total = duration
	_haste_left = duration
	_apply_haste()
	EventBus.goddess_haste_changed.emit(true, _haste_left, get_haste_ratio())
	return true


# 지금 진행도의 증가율을 **살아 있는 파티원 전원**에게 밀어 넣는다.
#
# 매 프레임 다시 넣는 이유 둘:
#   ① 증가율이 계속 변한다(램프).
#   ② 가속 중에 부활한 파티원(스킬 2)도 그 시점부터 함께 받아야 한다.
#
# StatusEffectSystem 의 외부 기여 채널을 쓴다 — 원거리 스택이 쓰는 것과 같은 통로라
# 상태 효과·장비 보너스와 자연스럽게 합산된다. PlayerStats.set_buff_bonuses() 를 직접
# 부르면 "최종값"을 받는 구조여서 다른 버프를 덮어쓴다.
func _apply_haste() -> void:
	if _haste_skill == null:
		return

	var progress := _haste_progress()
	var percent := {
		"attack_speed": _haste_skill.get_haste_attack_speed(progress, _haste_boost),
		"move_speed": _haste_skill.get_haste_move_speed(progress, _haste_boost),
	}

	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if not is_instance_valid(node) or not node.is_alive:
			continue
		# 종료 시 지울 대상을 기억한다 — 지금 죽은 파티원이 되살아나면 목록에서 빠져도
		# 이미 걸린 기여분이 남는다.
		_haste_touched[node] = true
		StatusEffectSystem.set_external_bonus(node, HASTE_SOURCE, {}, percent)


func _end_haste() -> void:
	_haste_left = 0.0
	_haste_total = 0.0
	_haste_skill = null
	_haste_boost = 1.0

	for node in _haste_touched.keys():
		if is_instance_valid(node):
			StatusEffectSystem.clear_external_bonus(node, HASTE_SOURCE)
	_haste_touched.clear()
	EventBus.goddess_haste_changed.emit(false, 0.0, 0.0)


# 0(시작) ~ 1(끝).
func _haste_progress() -> float:
	if _haste_total <= 0.0:
		return 0.0
	return clampf(1.0 - _haste_left / _haste_total, 0.0, 1.0)


# ----- 스킬 2: 부활 -----

func _cast_revive(skill: GoddessSkillData, boost: float) -> bool:
	var index := _first_dead_index()
	if index < 0:
		# 되살릴 파티원이 없다. 사용 횟수를 쓰지 않고 거부한다.
		return false

	var member: CharacterData = PartySystem.get_member(index)
	if member == null:
		return false

	var anchor := _living_member_node()
	if anchor == null:
		# 살아 있는 파티원이 아무도 없으면 이미 전멸이다(그 판은 끝났다).
		return false

	var scene := load("res://entities/player/Player.tscn")
	if scene == null:
		push_warning("GoddessSkillSystem: Player.tscn을 불러올 수 없습니다.")
		return false

	var node = scene.instantiate()
	node.data = member
	node.party_index = index
	anchor.get_parent().add_child(node)
	node.global_position = anchor.global_position + REVIVE_OFFSET

	# 체력은 _ready() 가 max_hp 를 계산한 뒤에 덮어써야 한다.
	var percent := skill.get_effective_revive_percent(boost)
	node.hp = maxi(int(round(float(node.max_hp) * percent)), 1)

	EventBus.healing_applied.emit(node, node.hp)
	return true


# 죽은 파티원 중 파티 순서상 가장 앞. 없으면 -1.
#
# 판정 근거: 편성에는 있는데 살아 있는 노드가 없는 멤버.
# Player.die() 가 노드를 queue_free 하므로 "죽은 노드"는 남지 않는다.
func _first_dead_index() -> int:
	var alive := {}
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if is_instance_valid(node) and node.is_alive and node.party_index >= 0:
			alive[node.party_index] = true

	var members := PartySystem.get_members()
	for i in range(members.size()):
		if members[i] != null and not alive.has(i):
			return i
	return -1


# 부활 위치의 기준이 될, 살아 있는 파티원 노드. 조종 중인 쪽을 우선한다.
func _living_member_node() -> Node:
	var fallback: Node = null
	for node in get_tree().get_nodes_in_group(PartySystem.MEMBER_GROUP):
		if not is_instance_valid(node) or not node.is_alive:
			continue
		if node.is_controlled():
			return node
		if fallback == null:
			fallback = node
	return fallback


# ===== 저장 (SaveSystem provider) =====

func to_save_dict() -> Dictionary:
	return {"selected": String(_selected_id)}


func from_save_dict(data: Dictionary) -> void:
	var raw := String(data.get("selected", ""))
	# 정의가 사라진 스킬이 세이브에 남아 있으면 선택을 비운다(정의의 출처는 이 시스템이다).
	_selected_id = StringName(raw) if _skills.has(StringName(raw)) else &""
	selection_changed.emit(_selected_id)
