extends Node

# 장비 데이터 레지스트리 (autoload).
# 시작 시 EQUIPMENT_DIR의 .tres(EquipmentData)를 모두 로드해
# equipment_id -> EquipmentData 로 조회를 제공한다.
# CharacterDatabase와 동일한 패턴을 따른다.

const EQUIPMENT_DIR := "res://data/equipment"

# equipment_id(StringName) -> EquipmentData
var _equipment: Dictionary = {}

func _ready() -> void:
	name = "EquipmentDatabase"
	_load_all()

# 디렉터리의 모든 .tres를 로드한다.
func _load_all() -> void:
	_equipment.clear()

	var dir := DirAccess.open(EQUIPMENT_DIR)
	if dir == null:
		# 아직 장비 아이템이 저작되지 않았을 수 있다(정상). 경고만 남긴다.
		push_warning("EquipmentDatabase: 디렉터리를 열 수 없습니다: " + EQUIPMENT_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(EQUIPMENT_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

# 내보내기(export) 시 .tres가 .remap이 될 수 있어 두 확장자를 허용한다.
func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")

func _load_one(path: String) -> void:
	# .remap 경로면 실제 리소스 경로로 되돌린다.
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is EquipmentData):
		push_warning("EquipmentDatabase: EquipmentData가 아닙니다(건너뜀): " + load_path)
		return

	var data: EquipmentData = res
	var problems := data.validate()
	if not problems.is_empty():
		push_warning("EquipmentDatabase: 유효하지 않은 장비(" + load_path + "): " + ", ".join(problems))
		return

	if _equipment.has(data.equipment_id):
		push_warning("EquipmentDatabase: 중복 equipment_id(건너뜀): " + String(data.equipment_id))
		return

	_equipment[data.equipment_id] = data

# id로 장비를 조회한다. 없으면 경고 후 null.
func get_equipment(id: StringName) -> EquipmentData:
	if not _equipment.has(id):
		push_warning("EquipmentDatabase: 알 수 없는 equipment_id: " + String(id))
		return null
	return _equipment[id]

func has_equipment(id: StringName) -> bool:
	return _equipment.has(id)

func get_all_ids() -> Array:
	return _equipment.keys()

func get_count() -> int:
	return _equipment.size()

# 특정 슬롯의 장비 id 목록을 반환한다.
func get_ids_by_slot(slot: EquipmentData.Slot) -> Array:
	var result: Array = []
	for id in _equipment:
		if _equipment[id].slot == slot:
			result.append(id)
	return result
