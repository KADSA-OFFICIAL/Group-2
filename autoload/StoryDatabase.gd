extends Node

# 스토리 챕터 레지스트리 (autoload).
# 시작 시 STORY_DIR의 .tres(StoryChapterData)를 모두 로드해
# chapter_id -> StoryChapterData 로 조회를 제공한다.
# StageDatabase / ShopDatabase 와 동일한 패턴을 따른다.

const STORY_DIR := "res://data/story"

# chapter_id(StringName) -> StoryChapterData
var _chapters: Dictionary = {}

# number 순으로 정렬된 chapter_id 목록. 목록 화면이 이 순서를 쓴다.
var _ordered_ids: Array = []

func _ready() -> void:
	name = "StoryDatabase"
	_load_all()

func _load_all() -> void:
	_chapters.clear()
	_ordered_ids.clear()

	var dir := DirAccess.open(STORY_DIR)
	if dir == null:
		# 아직 챕터가 저작되지 않았을 수 있다(정상). 경고만 남긴다.
		push_warning("StoryDatabase: 디렉터리를 열 수 없습니다: " + STORY_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(STORY_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

	_rebuild_order()

# 내보내기(export) 시 .tres가 .remap이 될 수 있어 두 확장자를 허용한다.
func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")

func _load_one(path: String) -> void:
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is StoryChapterData):
		push_warning("StoryDatabase: StoryChapterData가 아닙니다(건너뜀): " + load_path)
		return

	var data: StoryChapterData = res
	var problems := data.validate()
	if not problems.is_empty():
		push_warning("StoryDatabase: 유효하지 않은 챕터(" + load_path + "): " + ", ".join(problems))
		return

	if _chapters.has(data.chapter_id):
		push_warning("StoryDatabase: 중복 chapter_id(건너뜀): " + String(data.chapter_id))
		return

	_chapters[data.chapter_id] = data

# 표시 순서를 number 로 정한다. 디렉터리 순회 순서에 기대지 않는다.
func _rebuild_order() -> void:
	_ordered_ids = _chapters.keys()
	_ordered_ids.sort_custom(func(a, b): return _chapters[a].number < _chapters[b].number)

# id로 챕터를 조회한다. 없으면 경고 후 null.
func get_chapter(id: StringName) -> StoryChapterData:
	if not _chapters.has(id):
		push_warning("StoryDatabase: 알 수 없는 chapter_id: " + String(id))
		return null
	return _chapters[id]

func has_chapter(id: StringName) -> bool:
	return _chapters.has(id)

# number 순으로 정렬된 id 목록.
func get_all_ids() -> Array:
	return _ordered_ids.duplicate()

func get_count() -> int:
	return _chapters.size()
