extends Node

# 길라잡이의 단일 출처 (autoload).
#
# 책임: "지금 플레이어가 다음에 할 일" 하나를 판정한다.
#
# 왜 여기서 판정하는가:
#   화면이 각자 "다음 할 일"을 추측하면 화면마다 안내가 어긋난다.
#   판정 규칙을 한 곳에 두고, 화면은 결과만 읽어 표시한다.
#
# 데이터를 만들지 않는다 (중요):
#   퀘스트 시스템이 아직 없다. 그래서 퀘스트 목록·보상 같은 **없는 데이터를 만들지 않고**,
#   이미 존재하는 시스템의 실제 상태에서만 다음 할 일을 끌어낸다.
#     파티 구성   -> PartySystem
#     장비 보유   -> EquipmentSystem
#     장비 정의   -> EquipmentDatabase
#     착용 상태   -> CharacterData.get_equipped()
#   퀘스트 시스템이 생기면 이 파일의 _evaluate() 를 그 시스템 조회로 바꾸면 된다.
#   화면은 고치지 않아도 된다.
#
# 판정 순서는 [임시값] 이다. 무엇을 먼저 안내할지는 기획의 몫이므로
# 팀이 _evaluate() 의 순서만 바꾸면 된다 (CombatConfig 의 표기 방식을 따른다).

# 다음에 할 일의 종류. 화면은 이 값으로 어느 화면을 열지 정한다.
# (여기서 화면 씬을 알지 않는다. 인프라가 화면에 의존하면 안 된다.)
enum Step {
	PARTY_INCOMPLETE,   # 파티가 덜 찼다 -> 편성
	NO_EQUIPMENT,       # 만들 수 있는 장비가 있는데 보유가 없다 -> 제조
	EQUIPMENT_IDLE,     # 보유한 장비가 있는데 아무도 안 찼다 -> 장비
	READY,              # 남은 안내가 없다 -> 출격
}

# 판정 결과가 바뀔 때. 화면은 이 신호로만 갱신한다.
signal step_changed(step: Step)

# 마지막으로 알린 단계. 같은 단계를 반복해서 쏘지 않으려고 들고 있다.
var _last_step: int = -1


func _ready() -> void:
	name = "GuideSystem"
	# 판정에 쓰이는 상태가 바뀌면 다시 판정한다.
	EventBus.party_changed.connect(func(_members): _notify())
	EventBus.equipment_crafted.connect(func(_id): _notify())
	EventBus.equipment_equipped.connect(func(_cid, _eid, _slot): _notify())
	EventBus.equipment_unequipped.connect(func(_cid, _slot): _notify())


# ===== 조회 (Query) =====

# 지금 다음에 할 일.
func get_step() -> Step:
	return _evaluate()


# 화면에 그대로 띄울 안내 문구.
# 문구를 화면에 두지 않는 이유: 같은 안내가 여러 화면에 생기면 표현이 갈린다.
func get_text() -> String:
	match _evaluate():
		Step.PARTY_INCOMPLETE:
			var short: int = PartySystem.PARTY_SIZE - PartySystem.get_size()
			return "편성에서 %d명을 더 골라 파티를 채우세요" % short
		Step.NO_EQUIPMENT:
			return "제조에서 첫 장비를 만들어 보세요"
		Step.EQUIPMENT_IDLE:
			return "만든 장비를 캐릭터에게 착용시키세요"
		_:
			return "준비가 끝났습니다. 출격하세요"


# ===== 판정 (Evaluation) =====

# 순서가 곧 우선순위다. [임시값] — 무엇을 먼저 안내할지는 기획이 정한다.
func _evaluate() -> Step:
	# 1) 파티가 덜 찼으면 그것부터. 파티 없이는 나머지가 의미가 없다.
	if PartySystem.get_size() < PartySystem.PARTY_SIZE:
		return Step.PARTY_INCOMPLETE

	# 2) 보유한 장비가 하나도 없고, 만들 수 있는 장비가 저작되어 있으면 제조로 보낸다.
	#    (장비가 저작되지 않은 단계에서는 이 안내를 띄우지 않는다.)
	if EquipmentSystem.get_owned_ids().is_empty():
		if EquipmentDatabase.get_count() > 0:
			return Step.NO_EQUIPMENT
		return Step.READY

	# 3) 보유는 있는데 파티원 중 아무도 착용하지 않았으면 장비 화면으로 보낸다.
	if not _anyone_equipped():
		return Step.EQUIPMENT_IDLE

	return Step.READY


# 파티원 중 한 명이라도 장비를 차고 있는가.
# 착용 상태의 출처는 CharacterData 다. 여기서 따로 기록하지 않는다.
func _anyone_equipped() -> bool:
	for member in PartySystem.get_members():
		if member == null:
			continue
		for slot in EquipmentData.Slot.values():
			if member.get_equipped(slot) != null:
				return true
	return false


# 판정이 달라졌을 때만 알린다.
func _notify() -> void:
	var step := _evaluate()
	if step == _last_step:
		return
	_last_step = step
	step_changed.emit(step)
