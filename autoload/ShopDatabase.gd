extends Node

# 상점 판매 목록 레지스트리 (autoload).
# 시작 시 SHOP_DIR의 .tres(ShopEntryData)를 모두 로드해
# entry_id -> ShopEntryData 로 조회를 제공한다.
# EquipmentDatabase / StageDatabase 와 동일한 패턴을 따른다.

const SHOP_DIR := "res://data/shop"

# entry_id(StringName) -> ShopEntryData
var _entries: Dictionary = {}

func _ready() -> void:
	name = "ShopDatabase"
	_load_all()

func _load_all() -> void:
	_entries.clear()

	var dir := DirAccess.open(SHOP_DIR)
	if dir == null:
		# 아직 판매 항목이 저작되지 않았을 수 있다(정상). 경고만 남긴다.
		push_warning("ShopDatabase: 디렉터리를 열 수 없습니다: " + SHOP_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(SHOP_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

# 내보내기(export) 시 .tres가 .remap이 될 수 있어 두 확장자를 허용한다.
func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")

func _load_one(path: String) -> void:
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is ShopEntryData):
		push_warning("ShopDatabase: ShopEntryData가 아닙니다(건너뜀): " + load_path)
		return

	var data: ShopEntryData = res
	var problems := data.validate()
	if not problems.is_empty():
		push_warning("ShopDatabase: 유효하지 않은 판매 항목(" + load_path + "): " + ", ".join(problems))
		return

	# 파는 장비가 실제로 존재해야 한다. 없으면 화면에 빈 칸이 생긴다.
	if not EquipmentDatabase.has_equipment(data.equipment_id):
		push_warning("ShopDatabase: 알 수 없는 equipment_id(건너뜀): " + String(data.equipment_id))
		return

	if _entries.has(data.entry_id):
		push_warning("ShopDatabase: 중복 entry_id(건너뜀): " + String(data.entry_id))
		return

	_entries[data.entry_id] = data

# id로 판매 항목을 조회한다. 없으면 경고 후 null.
func get_entry(id: StringName) -> ShopEntryData:
	if not _entries.has(id):
		push_warning("ShopDatabase: 알 수 없는 entry_id: " + String(id))
		return null
	return _entries[id]

func has_entry(id: StringName) -> bool:
	return _entries.has(id)

func get_all_ids() -> Array:
	return _entries.keys()

func get_count() -> int:
	return _entries.size()
