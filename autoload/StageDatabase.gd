extends Node

# 스테이지 데이터 레지스트리 (autoload).
# 시작 시 STAGE_DIR의 .tres(StageData)를 모두 로드해
# stage_id -> StageData 로 조회를 제공한다.
# EnemyDatabase / EquipmentDatabase 와 동일한 패턴을 따른다.

const STAGE_DIR := "res://data/stages"

# stage_id(StringName) -> StageData
var _stages: Dictionary = {}

func _ready() -> void:
	name = "StageDatabase"
	_load_all()

# 디렉터리의 모든 .tres를 로드한다.
func _load_all() -> void:
	_stages.clear()

	var dir := DirAccess.open(STAGE_DIR)
	if dir == null:
		# 아직 스테이지가 저작되지 않았을 수 있다(정상). 경고만 남긴다.
		push_warning("StageDatabase: 디렉터리를 열 수 없습니다: " + STAGE_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(STAGE_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

# 내보내기(export) 시 .tres가 .remap이 될 수 있어 두 확장자를 허용한다.
func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")

func _load_one(path: String) -> void:
	# .remap 경로면 실제 리소스 경로로 되돌린다.
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is StageData):
		push_warning("StageDatabase: StageData가 아닙니다(건너뜀): " + load_path)
		return

	var data: StageData = res
	var problems := data.validate()
	if not problems.is_empty():
		push_warning("StageDatabase: 유효하지 않은 스테이지(" + load_path + "): " + ", ".join(problems))
		return

	if _stages.has(data.stage_id):
		push_warning("StageDatabase: 중복 stage_id(건너뜀): " + String(data.stage_id))
		return

	_stages[data.stage_id] = data

# id로 스테이지를 조회한다. 없으면 경고 후 null.
func get_stage(id: StringName) -> StageData:
	if not _stages.has(id):
		push_warning("StageDatabase: 알 수 없는 stage_id: " + String(id))
		return null
	return _stages[id]

func has_stage(id: StringName) -> bool:
	return _stages.has(id)

func get_all_ids() -> Array:
	return _stages.keys()

func get_count() -> int:
	return _stages.size()

# 특정 타입의 스테이지 id 목록을 반환한다.
# (EquipmentDatabase.get_ids_by_slot() 과 같은 규약.)
func get_ids_by_type(type: StageData.Type) -> Array:
	var result: Array = []
	for id in _stages:
		if _stages[id].type == type:
			result.append(id)
	return result

# 특정 승리 조건 프리미티브를 요구하는 스테이지 id 목록.
# 판정은 StageData 가 한다. 여기서 타입->조건 대응을 다시 쓰지 않는다.
func get_ids_requiring(objective: StageData.Objective) -> Array:
	var result: Array = []
	for id in _stages:
		if _stages[id].requires(objective):
			result.append(id)
	return result
