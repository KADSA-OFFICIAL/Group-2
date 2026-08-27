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


# ===== 챕터별 조회 (Chapter queries) — #408 =====
#
# 전체 규모는 3챕터 x 3스테이지다. 챕터/컨셉 대응의 출처는 StageData 이므로
# 여기서 그 대응을 다시 쓰지 않는다 — 정렬과 묶기만 한다.

# (chapter, number) 순으로 정렬된 전체 id 목록.
# 챕터에 속하지 않는 스테이지(테스트 등)는 맨 끝에 온다.
#
# get_all_ids() 는 Dictionary 키 순서를 그대로 돌려주므로 파일 순회 순서에 달려 있다.
# 목록 화면은 이쪽을 쓴다.
func get_ordered_ids() -> Array:
	var ids: Array = _stages.keys()
	ids.sort_custom(func(a, b):
		var ka: int = _stages[a].get_sort_key()
		var kb: int = _stages[b].get_sort_key()
		if ka == kb:
			# 같은 자리에 두 스테이지가 저작되면(실수) 순서가 실행마다 흔들리지 않게 id 로 가른다.
			return String(a) < String(b)
		return ka < kb)
	return ids


# 특정 챕터에 속한 id 목록. number 순으로 정렬된다.
func get_ids_by_chapter(chapter: int) -> Array:
	var result: Array = []
	for id in get_ordered_ids():
		if _stages[id].chapter == chapter:
			result.append(id)
	return result


# 스테이지가 하나라도 저작된 챕터 번호 목록(오름차순).
# 저작 전인 챕터는 나오지 않는다 — 목록 화면이 빈 챕터 머리를 띄우지 않도록.
# StageData.NO_CHAPTER 는 챕터가 아니므로 포함되지 않는다.
func get_authored_chapters() -> Array:
	var seen := {}
	for id in _stages:
		var chapter: int = _stages[id].chapter
		if chapter != StageData.NO_CHAPTER:
			seen[chapter] = true
	var chapters: Array = seen.keys()
	chapters.sort()
	return chapters


# 어느 챕터에도 속하지 않는 id 목록(테스트·연습 스테이지).
func get_chapterless_ids() -> Array:
	var result: Array = []
	for id in get_ordered_ids():
		if _stages[id].chapter == StageData.NO_CHAPTER:
			result.append(id)
	return result
