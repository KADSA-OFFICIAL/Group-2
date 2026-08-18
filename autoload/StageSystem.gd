extends Node

# 현재 스테이지 (autoload).
#
# 책임: **어느 스테이지를 플레이 중인지** 한 곳에서 안다.
#   - 스테이지 정의(배치·승리 조건)의 출처는 StageDatabase / StageData 다. 여기서 재정의하지 않는다.
#   - 화면 전환은 ScreenManager 가 한다. 여기서 화면을 열거나 닫지 않는다.
#
# 왜 필요한가: 출격 화면은 고른 스테이지 id 를 알고, 전장(Stage 노드)은 배치를 알아야 하는데
# 둘은 서로를 참조하지 않는다(화면은 자기를 pop 할 뿐 다음 화면을 모른다).
# 그 사이에 id 하나를 둘 자리가 없어서, 출격 버튼이 "떠 있는 전장을 드러내기"만 하고 있었다.
#
# 참고: autoload/StageDatabase.gd, stage/Stage1_1.gd, screens/stage/stage_select_screen.gd

# 스테이지가 요청됐다. 전장 노드가 받아 그 배치로 다시 만든다.
signal stage_requested(stage_id: StringName)

# 저작된 스테이지가 없을 때 쓰는 기본 id.
# 있으면 이것을, 없으면 로드된 첫 스테이지를 현재 스테이지로 잡는다.
const DEFAULT_STAGE_ID := &"stage_1_1"

var _current_id: StringName = &""


func _ready() -> void:
	name = "StageSystem"
	_current_id = _resolve_initial_id()


# 시작 시 현재 스테이지. 기본 id 가 저작되어 있으면 그것을 쓰고,
# 없으면 저작된 것 중 첫 번째를 쓴다(하나도 없으면 빈 값).
func _resolve_initial_id() -> StringName:
	if StageDatabase.has_stage(DEFAULT_STAGE_ID):
		return DEFAULT_STAGE_ID

	var ids := StageDatabase.get_all_ids()
	if ids.is_empty():
		return &""
	return ids[0]


func get_current_id() -> StringName:
	return _current_id


# 현재 스테이지 정의. 저작된 스테이지가 없으면 null 이다.
# 받는 쪽은 null 을 확인하고 대체 동작을 준비한다(전장은 적 없이 파티만 놓는다).
func get_current_stage() -> StageData:
	if String(_current_id).is_empty():
		return null
	return StageDatabase.get_stage(_current_id)


# 이 스테이지로 간다. 전장 노드가 signal 을 받아 다시 만든다.
# 알 수 없는 id 면 현재 스테이지를 바꾸지 않는다 — 고른 것과 다른 전장을 여는 것보다
# 있던 전장을 그대로 두는 편이 낫다.
func request_stage(stage_id: StringName) -> void:
	if not StageDatabase.has_stage(stage_id):
		push_warning("StageSystem: 알 수 없는 stage_id(무시): " + String(stage_id))
		return

	_current_id = stage_id
	stage_requested.emit(stage_id)
