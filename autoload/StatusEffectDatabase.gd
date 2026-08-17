extends Node

# 상태 효과(버프/디버프) 데이터 레지스트리 (autoload).
# 시작 시 EFFECTS_DIR의 .tres(StatusEffectData)를 모두 로드해
# effect_id -> StatusEffectData 로 조회를 제공한다.
#
# CharacterDatabase와 동일한 패턴이다. 상태 효과 정의를 다른 곳에서
# 별도 딕셔너리로 재정의하지 않고, 항상 이 레지스트리로 조회한다.

const EFFECTS_DIR := "res://data/status_effects"

# effect_id(StringName) -> StatusEffectData
var _effects: Dictionary = {}

func _ready() -> void:
	name = "StatusEffectDatabase"
	_load_all()

# 디렉터리의 모든 .tres를 로드한다.
func _load_all() -> void:
	_effects.clear()

	var dir := DirAccess.open(EFFECTS_DIR)
	if dir == null:
		# 디렉터리가 아직 없거나 비어 있을 수 있다(효과 .tres 저작은 후속 단계).
		# 이 경우는 정상 상태로 보고 조용히 넘어간다.
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(EFFECTS_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

# 내보내기(export) 시 .tres가 .remap이 될 수 있어 두 확장자를 허용한다.
func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")

func _load_one(path: String) -> void:
	# .remap 경로면 실제 리소스 경로로 되돌린다.
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is StatusEffectData):
		push_warning("StatusEffectDatabase: StatusEffectData가 아닙니다(건너뜀): " + load_path)
		return

	var data: StatusEffectData = res
	var problems := data.validate()
	if not problems.is_empty():
		push_warning("StatusEffectDatabase: 유효하지 않은 효과(" + load_path + "): " + ", ".join(problems))
		return

	if _effects.has(data.effect_id):
		push_warning("StatusEffectDatabase: 중복 effect_id(건너뜀): " + String(data.effect_id))
		return

	_effects[data.effect_id] = data

# id로 효과를 조회한다. 없으면 경고 후 null.
func get_effect(id: StringName) -> StatusEffectData:
	if not _effects.has(id):
		push_warning("StatusEffectDatabase: 알 수 없는 effect_id: " + String(id))
		return null
	return _effects[id]

func has_effect(id: StringName) -> bool:
	return _effects.has(id)

func get_all_ids() -> Array:
	return _effects.keys()

func get_count() -> int:
	return _effects.size()

# 특정 종류(Kind)의 효과 id만 추린다. UI 표시나 디버그에 쓴다.
func get_ids_by_kind(kind: StatusEffectData.Kind) -> Array:
	var result: Array = []
	for id in _effects:
		var data: StatusEffectData = _effects[id]
		if data.kind == kind:
			result.append(id)
	return result
