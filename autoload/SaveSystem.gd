extends Node

# 저장/불러오기 (autoload). 저장 스키마의 단일 출처.
#
# 설계: SaveSystem은 다른 시스템의 내부를 알지 않는다.
#   - 각 시스템이 자기 상태를 직렬화하는 to_save_dict() / from_save_dict(Dictionary)를 갖고,
#     자신의 _ready()에서 register_provider(키, self)로 등록한다.
#   - SaveSystem은 "저장 키 -> 제공자" 목록과 파일 입출력만 담당한다.
#   - 따라서 새 시스템을 저장 대상에 넣을 때 이 파일을 고치지 않아도 된다.
#
# 현재 제공자: CurrencySystem("currencies"), PartySystem("party"), EquipmentSystem("equipment").

const SAVE_PATH = "user://game_save.json"

# 저장 키(String) -> 제공자 노드
var _providers: Dictionary = {}

# 복원 중 플래그. 복원이 쏘는 시그널(party_changed 등)이 다시 저장을 유발하지 않게 막는다.
var _loading: bool = false

# 저장할 변경이 밀려 있는지. 한 프레임에 여러 변경이 와도 파일은 한 번만 쓴다.
var _save_pending: bool = false

# 마지막으로 읽은 세이브 원본. 제공자가 없는 키(stage, playtime 등)를 다시 쓸 때 보존하려고 들고 있다.
# (이걸 안 하면 자동 저장이 남의 키를 기본값으로 덮어쓴다.)
var _loaded_data: Dictionary = {}

# 세이브 파일을 이미 읽었는지. 첫 제공자가 등록될 때 한 번만 읽는다.
var _file_read: bool = false

func _ready():
	name = "SaveSystem"

	# 불러오기는 제공자가 등록되는 시점에 각자 일어난다(register_provider 참고).
	# 여기서 한꺼번에 하지 않는다.

	# 자동 저장 시점: 편성 확정 / 장비 제작 / 장비 착탈.
	# (재화는 이 시점들과 종료 시에 함께 기록된다. 전투 중 재화 변동마다 파일을 쓰지는 않는다.)
	#
	# 스테이지 클리어는 여기서 듣지 않는다: 같은 신호를 StageProgress 도 듣고 기록하는데,
	# 이 노드가 먼저 등록되어 먼저 실행되므로 여기서 저장하면 기록 이전 상태가 쓰인다.
	# 그래서 그쪽이 기록을 끝낸 뒤 직접 request_save() 를 부른다.
	EventBus.party_changed.connect(func(_members): request_save())
	EventBus.equipment_crafted.connect(func(_id): request_save())
	EventBus.equipment_equipped.connect(func(_cid, _eid, _slot): request_save())
	EventBus.equipment_unequipped.connect(func(_cid, _slot): request_save())

# 앱 종료 시 남은 변경을 반드시 파일에 쓴다.
# NOTIFICATION_WM_CLOSE_REQUEST: 창을 닫을 때. NOTIFICATION_EXIT_TREE: get_tree().quit() 등.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_EXIT_TREE:
		if not _loading and not _providers.is_empty():
			save_all()

# ===== 제공자 등록 (Providers) =====

# 시스템이 자기 상태를 저장 대상에 등록한다. 각 시스템의 _ready()에서 호출한다.
func register_provider(key: String, provider: Object) -> void:
	if key.is_empty() or provider == null:
		push_warning("SaveSystem: 잘못된 제공자 등록입니다.")
		return
	if not (provider.has_method("to_save_dict") and provider.has_method("from_save_dict")):
		push_warning("SaveSystem: to_save_dict/from_save_dict가 없는 제공자입니다: " + key)
		return
	if _providers.has(key) and _providers[key] != provider:
		push_warning("SaveSystem: 저장 키가 중복되었습니다(무시): " + key)
		return
	_providers[key] = provider

	# 등록하는 즉시 그 시스템의 저장된 상태를 복원한다.
	#
	# 왜 등록 시점인가: 예전에는 모든 autoload 가 준비된 뒤(call_deferred) 한꺼번에
	# 복원했다. 그런데 그 시점은 **초기 씬(main.tscn)의 _ready 보다 뒤**다.
	# 그래서 Stage1_1.spawn_party() 가 복원 전의 빈 파티를 보고 기본 편성을 스폰한 다음
	# 복원이 일어나, 월드의 캐릭터와 PartySystem 의 편성이 어긋났다.
	# 등록은 각 시스템의 _ready() 안에서 일어나므로 초기 씬보다 확실히 앞이다.
	#
	# 전제: 제공자는 자기 복원에 필요한 시스템보다 **뒤에** 등록되어야 한다.
	# project.godot 의 autoload 순서가 그 순서다
	# (PartySystem 은 CharacterDatabase 뒤, EquipmentSystem 은 EquipmentDatabase 뒤).
	_ensure_file_read()
	_restore_one(key, provider)

func has_provider(key: String) -> bool:
	return _providers.has(key)

# ===== 저장 (Save) =====

# 모든 제공자의 상태를 모아 저장 딕셔너리를 만든다.
# 기본값 -> 마지막으로 읽은 값 -> 제공자의 현재 상태 순으로 덮는다.
func collect_save_data() -> Dictionary:
	var data := get_default_save()
	for key in _loaded_data:
		data[key] = _loaded_data[key]
	for key in _providers:
		var provider = _providers[key]
		if is_instance_valid(provider):
			data[key] = provider.to_save_dict()
	return data

# 지금 상태를 파일에 쓴다.
func save_all() -> bool:
	_save_pending = false
	return save_game(collect_save_data())

# 자동 저장 요청. 같은 프레임에 여러 번 불려도 실제 쓰기는 한 번이다.
func request_save() -> void:
	if _loading or _save_pending:
		return
	_save_pending = true
	_flush_save.call_deferred()

func _flush_save() -> void:
	if _save_pending:
		save_all()

func save_game(data: Dictionary) -> bool:
	var json_string = JSON.stringify(data)
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)

	if file == null:
		print("Error opening save file: ", FileAccess.get_open_error())
		return false

	file.store_string(json_string)
	return true

# ===== 불러오기 (Load) =====

# 세이브 파일을 아직 읽지 않았으면 읽어 둔다. 파일 읽기는 실행당 한 번이면 된다.
func _ensure_file_read() -> void:
	if _file_read:
		return
	_file_read = true
	_loaded_data = _read_save_file()

# 제공자 하나를 복원한다.
# 세이브에 그 키가 없으면 아무것도 하지 않는다(해당 시스템은 자기 초기 상태를 유지한다).
func _restore_one(key: String, provider: Object) -> void:
	if not is_instance_valid(provider):
		return
	if not (_loaded_data.has(key) and _loaded_data[key] is Dictionary):
		return
	# 복원이 쏘는 시그널이 다시 저장을 유발하지 않게 막는다.
	_loading = true
	provider.from_save_dict(_loaded_data[key])
	_loading = false

# 파일을 다시 읽어 등록된 모든 제공자에 복원시키고, 읽은 원본 딕셔너리를 반환한다.
# 시작 시 복원은 register_provider() 가 하므로, 이 함수는 "다시 불러오기"용이다.
func load_game() -> Dictionary:
	_file_read = true
	_loaded_data = _read_save_file()

	for key in _providers:
		_restore_one(key, _providers[key])

	return _loaded_data.duplicate(true)

func _read_save_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return get_default_save()

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)

	if file == null:
		print("Error opening save file: ", FileAccess.get_open_error())
		return get_default_save()

	var json_string = file.get_as_text()
	var json = JSON.new()
	var error = json.parse(json_string)

	if error != OK:
		print("Error parsing JSON: ", error)
		return get_default_save()

	if not (json.data is Dictionary):
		print("Error: save file root is not a Dictionary")
		return get_default_save()

	return json.data as Dictionary

func get_default_save() -> Dictionary:
	# 재화 목록은 CurrencySystem(단일 출처)을 참조한다.
	return {
		"stage": "Stage1_1",
		"playtime": 0.0,
		"currencies": CurrencySystem.DEFAULT_CURRENCIES.duplicate()
	}

func clear_save() -> bool:
	if FileAccess.file_exists(SAVE_PATH):
		var error = DirAccess.remove_absolute(SAVE_PATH)
		if error != OK:
			print("Error deleting save file: ", error)
			return false
	return true
