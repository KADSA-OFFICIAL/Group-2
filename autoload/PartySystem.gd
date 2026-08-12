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


func _ready() -> void:
	name = "PartySystem"


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
func switch_to(index: int) -> bool:
	if index < 0 or index >= _members.size():
		push_warning("PartySystem: 잘못된 전환 인덱스: " + str(index))
		return false
	if index == _controlled_index:
		return true

	_controlled_index = index
	EventBus.party_control_changed.emit(_controlled_index)
	return true

# 다음 멤버로 순환 전환한다.
func switch_next() -> bool:
	if _members.is_empty():
		return false
	return switch_to((_controlled_index + 1) % _members.size())


func _unhandled_input(event: InputEvent) -> void:
	# 1/2/3 키로 파티 멤버 전환 (docs §6 전환 UI).
	for i in range(PARTY_SIZE):
		if event.is_action_pressed("switch_member_%d" % (i + 1)):
			switch_to(i)
			get_viewport().set_input_as_handled()
			return
