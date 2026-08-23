extends Node

# 캐릭터 초상의 단일 출처 (autoload).
#
# 책임 둘:
#   1. 쓸 수 있는 초상 목록을 안다(폴더를 훑어 만든다).
#   2. 캐릭터마다 **어느 초상을 쓸지**를 들고 저장한다.
#
# 왜 CharacterData 에 박지 않는가:
#   어느 그림이 어느 캐릭터인지가 아직 정해지지 않았다. .tres 에 박아 두면 바꿀 때마다
#   데이터를 고쳐야 하고, 화면에서 보면서 고를 수 없다.
#   그래서 저작 기본값(CharacterData.portrait)은 그대로 두고, **선택**만 여기서 덮는다.
#   배정이 확정되면 선택을 .tres 로 옮기고 이 시스템은 목록 제공만 남기면 된다.
#
# 단일 출처 원칙:
#   캐릭터 정의   -> CharacterData / CharacterDatabase
#   초상 기본값   -> CharacterData.portrait
#   초상 선택     -> 여기 (화면은 여기에 묻는다)
#
# 참고: autoload/StoryProgress.gd(같은 저장 규약), ui/HUDKit.gd

const SAVE_KEY := "portraits"

# 초상 파일이 있는 곳. 여기 넣으면 목록에 자동으로 뜬다.
const PORTRAIT_DIR := "res://assets/sprites/characters/portraits"

# 초상별 얼굴 위치·크기 저작본. 없으면 화면이 자동 추정으로 떨어진다.
const META_PATH := "res://data/portraits/portrait_meta.tres"

# "초상 없음"을 고를 때 쓰는 값. 빈 문자열은 "선택 안 함"(저작 기본값 사용)과 구분해야 한다.
const NONE_ID := &"__none__"

# 선택이 바뀌었다. 화면은 이 신호로만 갱신한다.
signal portrait_changed(character_id: StringName)

# portrait_id(StringName) -> 리소스 경로(String). id 는 파일 이름(확장자 제외)이다.
var _catalog: Dictionary = {}

# character_id(String) -> portrait_id(String). 저장 스키마의 키가 문자열이라 String 으로 둔다.
var _selection: Dictionary = {}

# 얼굴 위치 저작본. 로드 실패해도 목록·선택은 그대로 동작해야 하므로 null 을 허용한다.
var _meta: PortraitMeta = null


func _ready() -> void:
	name = "PortraitSystem"
	_scan()
	_meta = load(META_PATH) as PortraitMeta if ResourceLoader.exists(META_PATH) else null
	SaveSystem.register_provider(SAVE_KEY, self)


# 폴더를 훑어 목록을 만든다. 임포트된 텍스처만 담는다.
func _scan() -> void:
	_catalog.clear()

	var dir := DirAccess.open(PORTRAIT_DIR)
	if dir == null:
		# 아직 아트가 없을 수 있다(정상). 목록이 비면 화면은 "없음"만 보여 준다.
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			# 내보내기 시 .import 가 붙거나 확장자가 바뀔 수 있어 원본 경로만 본다.
			var clean := file_name.trim_suffix(".import").trim_suffix(".remap")
			if clean.get_extension().to_lower() in ["png", "jpg", "jpeg", "webp", "svg"]:
				var path: String = PORTRAIT_DIR.path_join(clean)
				if ResourceLoader.exists(path):
					_catalog[StringName(clean.get_basename())] = path
		file_name = dir.get_next()
	dir.list_dir_end()


# ===== 목록 (Catalog) =====

# 쓸 수 있는 초상 id 목록. 이름순이라 화면마다 순서가 달라지지 않는다.
#
# String 으로 바꿔 정렬한다: StringName 끼리의 비교는 사전순이 아니라 내부 포인터 기준이라
# 그대로 sort() 하면 실행할 때마다 순서가 달라진다(실제로 뒤섞여 나왔다).
func get_all_ids() -> Array:
	var names: Array = []
	for id in _catalog:
		names.append(String(id))
	names.sort()

	var ids: Array = []
	for name in names:
		ids.append(StringName(name))
	return ids


func has_portrait(portrait_id: StringName) -> bool:
	return _catalog.has(portrait_id)


# id 로 텍스처를 얻는다. 없으면 null.
func get_texture(portrait_id: StringName) -> Texture2D:
	if not _catalog.has(portrait_id):
		return null
	return load(_catalog[portrait_id]) as Texture2D


# ===== 얼굴 위치 (Head metrics) =====

# 이 초상의 머리 범위(캔버스 대비 비율). 저작되지 않았으면 빈 Rect2.
#
# 텍스처로 묻는 이유: 화면 조각(HUDKit)은 초상 id 가 아니라 텍스처를 들고 있다.
# 경로로 되짚어 id 를 찾는다 — 목록이 다섯 줄 규모라 비용이 문제되지 않는다.
func get_head_rect(portrait: Texture2D) -> Rect2:
	if portrait == null or _meta == null:
		return Rect2()

	var path := portrait.resource_path
	if path.is_empty():
		return Rect2()
	return _meta.get_head_rect(StringName(path.get_file().get_basename()))


# ===== 선택 (Selection) =====

# 이 캐릭터가 고른 초상 id. 고른 적 없으면 빈 값(저작 기본값을 쓴다는 뜻).
func get_selected_id(character_id: StringName) -> StringName:
	return StringName(str(_selection.get(String(character_id), "")))


# 화면에 실제로 그릴 초상.
#   선택이 "없음"이면 null (플레이스홀더로 떨어진다)
#   선택이 있으면 그 텍스처
#   선택이 없으면 저작 기본값(CharacterData.portrait)
func get_portrait(character: CharacterData) -> Texture2D:
	if character == null:
		return null

	var selected := get_selected_id(character.character_id)
	if selected == NONE_ID:
		return null
	if not String(selected).is_empty():
		var texture := get_texture(selected)
		if texture != null:
			return texture

	return character.portrait


# 이 캐릭터의 초상을 고른다. NONE_ID 를 주면 "초상 없음"이다.
# 알 수 없는 id 는 무시한다 — 고른 것과 다른 그림이 뜨는 것보다 그대로 두는 편이 낫다.
func select(character_id: StringName, portrait_id: StringName) -> bool:
	if String(character_id).is_empty():
		return false
	if portrait_id != NONE_ID and not has_portrait(portrait_id):
		push_warning("PortraitSystem: 알 수 없는 portrait_id(무시): " + String(portrait_id))
		return false

	_selection[String(character_id)] = String(portrait_id)
	SaveSystem.request_save()
	portrait_changed.emit(character_id)
	return true


# 선택을 지운다(저작 기본값으로 돌아간다).
func clear_selection(character_id: StringName) -> void:
	if not _selection.has(String(character_id)):
		return
	_selection.erase(String(character_id))
	SaveSystem.request_save()
	portrait_changed.emit(character_id)


# ===== 저장 (Save) =====

func to_save_dict() -> Dictionary:
	return { "selection": _selection.duplicate() }


func from_save_dict(data: Dictionary) -> void:
	_selection.clear()
	var saved = data.get("selection", {})
	if typeof(saved) != TYPE_DICTIONARY:
		return

	for key in saved:
		var value := str(saved[key])
		# 파일이 사라진 초상은 버린다(없는 그림을 계속 들고 있으면 조용히 빈 화면이 된다).
		if value == String(NONE_ID) or has_portrait(StringName(value)):
			_selection[str(key)] = value
	portrait_changed.emit(&"")
