extends Node

# 적 데이터 레지스트리 (autoload).
# 시작 시 ENEMIES_DIR의 .tres(EnemyData)를 모두 로드해
# enemy_id -> EnemyData 로 조회를 제공한다.
#
# CharacterDatabase와 동일한 패턴이지만 **별도 레지스트리**다.
# 로스터(9명) 조회인 CharacterDatabase.get_all_ids()/get_count()가
# 적 데이터로 오염되지 않도록 디렉터리와 레지스트리를 분리한다.

const ENEMIES_DIR := "res://data/enemies"

# enemy_id(StringName) -> EnemyData
var _enemies: Dictionary = {}

func _ready() -> void:
	name = "EnemyDatabase"
	_load_all()

# 디렉터리의 모든 .tres를 로드한다.
func _load_all() -> void:
	_enemies.clear()

	var dir := DirAccess.open(ENEMIES_DIR)
	if dir == null:
		# 디렉터리가 아직 없거나 비어 있을 수 있다(적 .tres 저작은 후속 단계).
		# 이 경우는 정상 상태로 보고 조용히 넘어간다.
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and _is_resource_file(file_name):
			_load_one(ENEMIES_DIR.path_join(file_name))
		file_name = dir.get_next()
	dir.list_dir_end()

# 내보내기(export) 시 .tres가 .remap이 될 수 있어 두 확장자를 허용한다.
func _is_resource_file(file_name: String) -> bool:
	return file_name.ends_with(".tres") or file_name.ends_with(".tres.remap")

func _load_one(path: String) -> void:
	# .remap 경로면 실제 리소스 경로로 되돌린다.
	var load_path := path.trim_suffix(".remap")
	var res := load(load_path)
	if not (res is EnemyData):
		push_warning("EnemyDatabase: EnemyData가 아닙니다(건너뜀): " + load_path)
		return

	var data: EnemyData = res
	var problems := data.validate()
	if not problems.is_empty():
		push_warning("EnemyDatabase: 유효하지 않은 적(" + load_path + "): " + ", ".join(problems))
		return

	if _enemies.has(data.enemy_id):
		push_warning("EnemyDatabase: 중복 enemy_id(건너뜀): " + String(data.enemy_id))
		return

	_enemies[data.enemy_id] = data

# id로 적을 조회한다. 없으면 경고 후 null.
func get_enemy(id: StringName) -> EnemyData:
	if not _enemies.has(id):
		push_warning("EnemyDatabase: 알 수 없는 enemy_id: " + String(id))
		return null
	return _enemies[id]

func has_enemy(id: StringName) -> bool:
	return _enemies.has(id)

func get_all_ids() -> Array:
	return _enemies.keys()

func get_count() -> int:
	return _enemies.size()
