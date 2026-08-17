extends Node

# 캐릭터 데이터 레지스트리 (autoload).
# 시작 시 CHARACTERS_DIR의 .tres(CharacterData)를 모두 로드해
# character_id -> CharacterData 로 조회를 제공한다.

const CHARACTERS_DIR := "res://data/characters"

# character_id(StringName) -> CharacterData
var _characters: Dictionary = {}

func _ready() -> void:
	name = "CharacterDatabase"
	_load_all()

# 디렉터리의 모든 .tres를 로드한다.
func _load_all() -> void:
	_characters.clear()

	var dir := DirAccess.open(CHARACTERS_DIR)
	if dir == null:
		push_warning("CharacterDatabase: 디렉터리를 열 수 없습니다: " + CHARACTERS_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(CHARACTERS_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

# 내보내기(export) 시 .tres가 .remap이 될 수 있어 두 확장자를 허용한다.
func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")

func _load_one(path: String) -> void:
	# .remap 경로면 실제 리소스 경로로 되돌린다.
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is CharacterData):
		push_warning("CharacterDatabase: CharacterData가 아닙니다(건너뜀): " + load_path)
		return

	var data: CharacterData = res
	var problems := data.validate()
	if not problems.is_empty():
		push_warning("CharacterDatabase: 유효하지 않은 캐릭터(" + load_path + "): " + ", ".join(problems))
		return

	if _characters.has(data.character_id):
		push_warning("CharacterDatabase: 중복 character_id(건너뜀): " + String(data.character_id))
		return

	_characters[data.character_id] = data

# id로 캐릭터를 조회한다. 없으면 경고 후 null.
func get_character(id: StringName) -> CharacterData:
	if not _characters.has(id):
		push_warning("CharacterDatabase: 알 수 없는 character_id: " + String(id))
		return null
	return _characters[id]

func has_character(id: StringName) -> bool:
	return _characters.has(id)

func get_all_ids() -> Array:
	return _characters.keys()

func get_count() -> int:
	return _characters.size()