extends Node

# 스토리 진행도의 단일 출처 (autoload).
#
# 책임: 어느 챕터를 읽었는지 기억한다.
#
# 왜 StoryDatabase 와 나누는가:
#   StoryDatabase 는 **저작 데이터**(챕터 대본)를 소유한다. 플레이어마다 달라지지 않는다.
#   읽음 여부는 **플레이어 상태**다. 저장 대상이고 플레이어마다 다르다.
#   둘을 한 곳에 두면 레지스트리가 세이브에 묶여 버린다.
#   (EquipmentDatabase 와 EquipmentSystem 을 나눈 것과 같은 이유다.)
#
# 단일 출처 원칙:
#   챕터 목록·존재 여부 -> StoryDatabase
#   읽음 여부           -> 여기
#   화면은 여기서 읽기만 하고 자기 목록을 따로 들지 않는다.

# 저장 스키마에서 스토리 진행도가 들어가는 키.
const SAVE_KEY := "story_progress"

# 읽음 상태가 바뀔 때. 화면은 이 신호로만 갱신한다.
signal progress_changed()

# 읽은 chapter_id 집합. Dictionary 를 집합처럼 쓴다(GDScript 에 Set 이 없다).
var _read: Dictionary = {}


func _ready() -> void:
	name = "StoryProgress"
	# 저장 스키마의 진행도 부분은 이 시스템이 소유한다(SaveSystem 은 내부를 모른다).
	SaveSystem.register_provider(SAVE_KEY, self)


# ===== 조회 (Query) =====

func is_read(chapter_id: StringName) -> bool:
	return _read.has(chapter_id)


func get_read_count() -> int:
	return _read.size()


# 아직 읽지 않은 챕터 수. 저작된 챕터가 기준이므로 StoryDatabase 에 묻는다.
# (읽음 기록에 남아 있어도 챕터가 사라졌으면 세지 않는다.)
func get_unread_count() -> int:
	var n := 0
	for id in StoryDatabase.get_all_ids():
		if not is_read(id):
			n += 1
	return n


func has_unread() -> bool:
	return get_unread_count() > 0


# 다음에 읽을 챕터. 저작 순서(number)로 처음 만나는 미열람 챕터다. 없으면 빈 값.
func get_next_unread_id() -> StringName:
	for id in StoryDatabase.get_all_ids():
		if not is_read(id):
			return id
	return &""


# ===== 변경 (Mutation) =====

# 챕터를 읽음으로 표시한다. 이미 읽었으면 아무것도 하지 않는다(신호도 쏘지 않는다).
func mark_read(chapter_id: StringName) -> bool:
	if String(chapter_id).is_empty():
		return false
	if _read.has(chapter_id):
		return false
	# 존재하지 않는 챕터를 읽음으로 기록하지 않는다(세이브에 쓰레기가 쌓인다).
	if not StoryDatabase.has_chapter(chapter_id):
		push_warning("StoryProgress: 알 수 없는 chapter_id: " + String(chapter_id))
		return false

	_read[chapter_id] = true
	progress_changed.emit()
	return true


# 진행도를 초기화한다(디버그·다회차용).
func reset() -> void:
	if _read.is_empty():
		return
	_read.clear()
	progress_changed.emit()


# ===== 저장/복원 (Save / Load) =====
# SaveSystem 은 이 두 함수만 호출한다.

func to_save_dict() -> Dictionary:
	var ids: Array[String] = []
	for id in _read:
		ids.append(String(id))
	return {"read": ids}


func from_save_dict(data: Dictionary) -> void:
	_read.clear()
	for raw in data.get("read", []):
		_read[StringName(raw)] = true
	progress_changed.emit()
