extends Node

# 캐릭터 초상의 단일 출처 (autoload).
#
# 책임:
#   1. 쓸 수 있는 초상 목록을 안다(폴더를 훑어 만든다).
#   2. 캐릭터의 초상을 판(일반·검열)에 맞게 돌려준다. 화면은 여기에 묻는다.
#   3. 초상별 얼굴 위치를 안다.
#
# 예전에는 캐릭터마다 **어느 초상을 쓸지** 고르는 선택을 들고 저장했다(배정이 정해지기 전,
# 캐릭터 화면의 "초상 고르기"). 배정이 확정되어 #590 에서 걷어냈다 — 남아 있던 선택이
# 다른 인물의 그림을 붙이거나 초상을 비웠다. 이제 초상은 CharacterData.portrait 하나다.
#
# 단일 출처 원칙:
#   캐릭터 정의   -> CharacterData / CharacterDatabase
#   초상          -> CharacterData.portrait (검열판이면 GameEdition 이 바꾼다)
#
# 참고: autoload/StoryProgress.gd(같은 저장 규약), ui/HUDKit.gd

const SAVE_KEY := "portraits"

# 초상 파일이 있는 곳. 여기 넣으면 목록에 자동으로 뜬다.
const PORTRAIT_DIR := "res://assets/sprites/characters/portraits"

# 초상별 얼굴 위치·크기 저작본. 없으면 화면이 자동 추정으로 떨어진다.
const META_PATH := "res://data/portraits/portrait_meta.tres"

# portrait_id(StringName) -> 리소스 경로(String). id 는 파일 이름(확장자 제외)이다.
var _catalog: Dictionary = {}

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


# id 로 텍스처를 얻는다. 없으면 null. 검열판이면 검열판 그림(GameEdition, #586).
func get_texture(portrait_id: StringName) -> Texture2D:
	if not _catalog.has(portrait_id):
		return null
	return load(GameEdition.resolve(_catalog[portrait_id])) as Texture2D


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


# 화면에 실제로 그릴 초상. 검열판이면 같은 이름의 검열판 그림으로 바뀐다(GameEdition, #586).
func get_portrait(character: CharacterData) -> Texture2D:
	if character == null:
		return null
	return GameEdition.texture(character.portrait)


# ===== 저장 (Save) =====
#
# 저장할 것이 없다. 공급자로 남겨 두는 이유: 옛 세이브의 "portraits" 블록(초상 선택)을
# 읽어 들인 뒤 다음 저장 때 빈 값으로 덮어, 지운 선택이 파일에 계속 남지 않게 한다.

func to_save_dict() -> Dictionary:
	return {}


func from_save_dict(_data: Dictionary) -> void:
	pass
