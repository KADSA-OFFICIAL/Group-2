extends Node

# 스토리 전용 화자 레지스트리 (autoload).
# 시작 시 CAST_DIR 의 .tres(StoryCastData)를 모두 로드해 cast_id -> StoryCastData 조회를 제공한다.
#
# 구조는 CharacterDatabase / EnemyDatabase 와 같다. 화자 해석의 세 번째 출처이고,
# **해석 순서에서 맨 뒤**다 (StoryLineData.get_character() 주석 참고).
#
# 왜 autoload 선언이 StoryDatabase 보다 앞에 있어야 하는가:
#   StoryDatabase 는 _ready() 에서 대본을 로드하며 StoryChapterData.validate() 를 부르고,
#   그것이 줄마다 StoryLineData.validate() -> get_character() 를 탄다. 이 시점에 cast 가
#   아직 없으면 cast 화자가 전부 "알 수 없는 character_id" 로 잡힌다.
#   EnemyDatabase 가 StoryDatabase 보다 앞에 선언되어 있는 것과 같은 이유다.

const CAST_DIR := "res://data/story/cast"

# cast_id(StringName) -> StoryCastData
var _cast: Dictionary = {}

func _ready() -> void:
	name = "StoryCastDatabase"
	_load_all()

# 디렉터리의 모든 .tres를 로드한다.
func _load_all() -> void:
	_cast.clear()

	var dir := DirAccess.open(CAST_DIR)
	if dir == null:
		push_warning("StoryCastDatabase: 디렉터리를 열 수 없습니다: " + CAST_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(CAST_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

# 내보내기(export) 시 .tres가 .remap이 될 수 있어 두 확장자를 허용한다.
func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")

func _load_one(path: String) -> void:
	# .remap 경로면 실제 리소스 경로로 되돌린다.
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is StoryCastData):
		push_warning("StoryCastDatabase: StoryCastData가 아닙니다(건너뜀): " + load_path)
		return

	var data: StoryCastData = res
	var problems := data.validate()
	if not problems.is_empty():
		push_warning("StoryCastDatabase: 유효하지 않은 화자(" + load_path + "): " + ", ".join(problems))
		return

	if _cast.has(data.cast_id):
		push_warning("StoryCastDatabase: 중복 cast_id(건너뜀): " + String(data.cast_id))
		return

	_cast[data.cast_id] = data

# id로 화자를 조회한다. 없으면 경고 후 null.
func get_cast(id: StringName) -> StoryCastData:
	if not _cast.has(id):
		push_warning("StoryCastDatabase: 알 수 없는 cast_id: " + String(id))
		return null
	return _cast[id]

func has_cast(id: StringName) -> bool:
	return _cast.has(id)

func get_all_ids() -> Array:
	return _cast.keys()

func get_count() -> int:
	return _cast.size()
