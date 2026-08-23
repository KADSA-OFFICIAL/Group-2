extends Node

# 파티 구성의 단일 출처 (autoload).
#
# 책임: 로스터에서 뽑은 파티 멤버 목록과 "지금 조종 중인 멤버"를 보유한다.
#
# 단일 출처 원칙:
#   - 캐릭터 정의는 CharacterDatabase에서 가져온다. 여기서 캐릭터를 재정의하지 않는다.
#   - 시너지 계산은 SynergySystem이 한다. 여기서 역할 카운트를 다시 세지 않는다.
#   - 이 시스템은 "누가 파티에 있고 누구를 조종 중인가"만 안다.
#
# 참고: docs/combat-screen-design.md §1, §4

# [확정] 파티는 3명이다 (docs §1).
const PARTY_SIZE: int = 3

# 조종 중인 멤버가 없음을 뜻하는 인덱스.
const NO_CONTROL: int = -1

# 파티 멤버 씬 노드가 등록되는 그룹 이름. **이 상수가 그룹 이름의 단일 출처다.**
# Player가 이 그룹에 자신을 등록하고, 파티 멤버 노드를 찾아야 하는 쪽(적 AI 등)은
# 문자열을 다시 적지 않고 이 상수로 조회한다.
# 양쪽에 문자열을 따로 두면 한쪽만 바뀔 때 런타임 에러 없이 조용히 깨진다.
#
# 편성의 출처가 이 시스템이므로 그룹 이름도 여기에 둔다.
# (PartySystem은 CharacterData 편성만 알고 씬 노드는 소유하지 않지만,
#  "파티 멤버를 어떻게 식별하는가"는 파티 도메인의 지식이다.)
const MEMBER_GROUP := &"party_member"

# 파티 멤버 (CharacterData). 최대 PARTY_SIZE명.
var _members: Array[CharacterData] = []

# 현재 조종 중인 멤버의 인덱스. 파티가 비면 NO_CONTROL.
var _controlled_index: int = NO_CONTROL


# 저장 스키마에서 편성이 들어가는 키.
const SAVE_KEY := "party"


func _ready() -> void:
	name = "PartySystem"
	# 저장 스키마의 편성 부분은 이 시스템이 소유한다(SaveSystem은 내부를 모른다).
	SaveSystem.register_provider(SAVE_KEY, self)
	# 조종 중인 멤버가 죽으면 조종을 넘겨야 한다(#245).
	# 이 시스템이 듣는 이유: "누구를 조종 중인가"의 소유자가 여기이기 때문이다.
	EventBus.player_died.connect(_on_member_died)


# ===== 편성 (Composition) =====

# character_id 목록으로 파티를 구성한다.
# 성공하면 첫 번째 멤버를 조종 대상으로 잡는다.
#
# 거부 조건: 인원 초과, 중복 id, 알 수 없는 id.
# 하나라도 문제가 있으면 **아무것도 바꾸지 않고** false를 반환한다(부분 반영 방지).
func set_party(character_ids: Array) -> bool:
	if character_ids.size() > PARTY_SIZE:
		push_warning("PartySystem: 파티 인원 초과(%d명, 최대 %d명)" % [character_ids.size(), PARTY_SIZE])
		return false

	var seen := {}
	var resolved: Array[CharacterData] = []

	for id in character_ids:
		var key := StringName(id)
		if seen.has(key):
			push_warning("PartySystem: 중복 캐릭터: " + String(key))
			return false
		seen[key] = true

		if not CharacterDatabase.has_character(key):
			push_warning("PartySystem: 알 수 없는 character_id: " + String(key))
			return false

		var data := CharacterDatabase.get_character(key)
		if data == null:
			return false

		# 스토리 인물·보스는 정의는 있어도 편성되지 않는다 (#216).
		# 여기서 막으면 SynergySystem 이 그 역할을 세는 일 자체가 없어진다
		# — 시너지 쪽에 예외 분기를 두면 규칙이 두 곳으로 갈린다.
		if not data.playable:
			push_warning("PartySystem: 편성할 수 없는 캐릭터: " + String(key))
			return false

		resolved.append(data)

	_members = resolved
	_controlled_index = NO_CONTROL if _members.is_empty() else 0

	EventBus.party_changed.emit(get_members())
	EventBus.party_control_changed.emit(_controlled_index)
	return true

# 파티를 비운다.
func clear_party() -> void:
	_members = []
	_controlled_index = NO_CONTROL
	EventBus.party_changed.emit(get_members())
	EventBus.party_control_changed.emit(_controlled_index)

# 파티 멤버 사본을 반환한다. 외부에서 내부 배열을 변형하지 못하게 한다.
func get_members() -> Array[CharacterData]:
	return _members.duplicate()

func get_size() -> int:
	return _members.size()

func is_empty() -> bool:
	return _members.is_empty()

# 인덱스로 멤버를 얻는다. 범위 밖이면 null.
func get_member(index: int) -> CharacterData:
	if index < 0 or index >= _members.size():
		return null
	return _members[index]

# 해당 캐릭터가 파티에 있는지.
func has_character(character_id: StringName) -> bool:
	for m in _members:
		if m != null and m.character_id == character_id:
			return true
	return false


# ===== 전환 (Control Switching) =====

func get_controlled_index() -> int:
	return _controlled_index

# 현재 조종 중인 멤버. 없으면 null.
func get_controlled_member() -> CharacterData:
	return get_member(_controlled_index)

# 해당 인덱스가 조종 중인지. 캐릭터 노드가 자기 입력 처리 여부를 판단할 때 쓴다.
func is_controlled(index: int) -> bool:
	return index == _controlled_index and index != NO_CONTROL

# 조종 대상을 바꾼다. 범위 밖이면 무시하고 false.
# 이미 그 멤버를 조종 중이면 시그널을 다시 쏘지 않는다.
#
# 죽은 멤버로는 전환하지 않는다(#245) — 전환은 되지만 조작할 노드가 없어
# 조용히 조작 불가 상태가 된다.
func switch_to(index: int) -> bool:
	if index < 0 or index >= _members.size():
		push_warning("PartySystem: 잘못된 전환 인덱스: " + str(index))
		return false
	if not _is_member_alive(index):
		push_warning("PartySystem: 죽은 멤버로는 전환하지 않습니다: " + str(index))
		return false
	if index == _controlled_index:
		return true

	_controlled_index = index
	EventBus.party_control_changed.emit(_controlled_index)
	return true


# ===== 사망 처리 (Death) =====
#
# 이 시스템은 씬 노드를 **소유하지 않는다.** 다만 "파티 멤버를 어떻게 식별하는가"는
# 파티 도메인의 지식이라 MEMBER_GROUP 이 여기 있고, 그 상수로 조회만 한다.
# (노드를 들고 있으면 스테이지가 다시 만들 때마다 무효 참조가 생긴다.)

# 파티원이 죽었다. 조종 중이던 멤버였다면 살아 있는 멤버로 넘긴다.
#
# 전멸이면 NO_CONTROL 로 두고 알린다. 승패 판정은 여기서 하지 않는다 — 전장(Stage)의 몫이다.
func _on_member_died() -> void:
	if _controlled_index == NO_CONTROL:
		return
	# 죽은 것이 조종 중이 아닌 멤버였다면 조종은 그대로다.
	if _is_member_alive(_controlled_index):
		return

	var next := _first_alive_index()
	if next == NO_CONTROL:
		_controlled_index = NO_CONTROL
		EventBus.party_control_changed.emit(_controlled_index)
		return

	# switch_to 를 그대로 쓴다(신호 발생 규칙을 한 곳에 둔다).
	switch_to(next)


# 그 인덱스의 멤버가 살아 있는가.
#
# 노드가 있으면 그 노드의 is_alive 가 답이다.
#
# 노드가 **없을 때**가 까다롭다. 두 경우가 겹친다:
#   전장 밖 (편성 화면·세이브 복원) — 파티 노드가 아예 없다. 여기서 false 를 주면
#     전환과 복원이 전부 막힌다.
#   죽어서 사라졌다 — queue_free 가 끝나면 그룹에서도 빠진다.
# 그래서 **다른 파티 노드가 하나라도 있는지**로 가른다. 하나라도 있으면 전장 안이고,
# 이 인덱스의 노드가 없다는 것은 죽어서 사라진 것이다.
func _is_member_alive(index: int) -> bool:
	var node := _member_node(index)
	if node != null:
		var alive = node.get("is_alive")
		return alive == null or bool(alive)
	return not _has_any_member_node()


# 전장에 파티 노드가 하나라도 있는가. "전장 안인가"의 판정에 쓴다.
func _has_any_member_node() -> bool:
	for node in get_tree().get_nodes_in_group(MEMBER_GROUP):
		if is_instance_valid(node):
			return true
	return false


# 살아 있는 첫 멤버의 인덱스. 없으면 NO_CONTROL.
func _first_alive_index() -> int:
	for i in range(_members.size()):
		if _is_member_alive(i) and _member_node(i) != null:
			return i
	return NO_CONTROL


# 그 party_index 를 가진 씬 노드. 없으면 null(전장 밖이거나 이미 사라졌다).
func _member_node(index: int) -> Node:
	for node in get_tree().get_nodes_in_group(MEMBER_GROUP):
		if not is_instance_valid(node):
			continue
		if int(node.get("party_index")) == index:
			return node
	return null

# 다음 멤버로 순환 전환한다. **죽은 멤버는 건너뛴다**(#245).
#
# 건너뛰지 않으면 switch_to 의 생존 검사에 걸려 순환이 죽은 멤버에서 멈춘다.
func switch_next() -> bool:
	if _members.is_empty():
		return false
	for step in range(1, _members.size() + 1):
		var index: int = (_controlled_index + step) % _members.size()
		if _is_member_alive(index):
			return switch_to(index)
	return false


# ===== 저장/복원 (Save / Load) =====
# SaveSystem은 이 두 함수만 호출한다.
# 캐릭터 정의는 저장하지 않고 character_id만 남긴다(정의의 출처는 CharacterDatabase다).

func to_save_dict() -> Dictionary:
	var ids: Array[String] = []
	for m in _members:
		if m != null:
			ids.append(String(m.character_id))
	return {
		"members": ids,
		"controlled": _controlled_index,
	}

func from_save_dict(data: Dictionary) -> void:
	var ids: Array = []
	for raw in data.get("members", []):
		var key := StringName(raw)
		# 로스터가 바뀌어 사라진 캐릭터, 편성 대상에서 빠진 캐릭터(#216)는 빼고
		# 나머지를 복원한다.
		# (set_party는 하나라도 문제가 있으면 전부 거부하므로 여기서 걸러 준다.)
		if not CharacterDatabase.has_character(key):
			push_warning("PartySystem: 세이브의 알 수 없는 character_id(건너뜀): " + String(key))
			continue

		var character := CharacterDatabase.get_character(key)
		if character != null and not character.playable:
			push_warning("PartySystem: 세이브의 편성 불가 캐릭터(건너뜀): " + String(key))
			continue

		ids.append(key)

	if not set_party(ids):
		return

	# 조종 대상 복원. 범위를 벗어나면 set_party가 잡아 둔 기본값(0번)을 유지한다.
	var controlled := int(data.get("controlled", 0))
	if controlled >= 0 and controlled < _members.size():
		switch_to(controlled)


func _unhandled_input(event: InputEvent) -> void:
	# 1/2/3 키로 파티 멤버 전환 (docs §6 전환 UI).
	for i in range(PARTY_SIZE):
		if event.is_action_pressed("switch_member_%d" % (i + 1)):
			switch_to(i)
			get_viewport().set_input_as_handled()
			return
