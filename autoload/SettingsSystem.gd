extends Node

# 게임 설정의 단일 출처 (autoload).
#
# 책임: 플레이어가 고른 설정 값을 보유하고, 실제 시스템에 적용한다.
#
# 여기 있는 값은 **게임 밸런스가 아니라 실제 시스템 값**이다.
# 창 모드는 DisplayServer, 볼륨은 AudioServer 가 실제로 적용받는다.
# 그래서 임의 수치를 만들 여지가 없다(기획 대기 항목이 아니다).
#
# 단일 출처 원칙:
#   - 화면(설정 화면)은 이 시스템에서 읽고 이 시스템에 시킨다.
#     DisplayServer / AudioServer 를 화면이 직접 만지지 않는다.
#   - 저장은 SaveSystem 제공자로 등록한다. 화면이 파일을 쓰지 않는다.

# 저장 스키마에서 설정이 들어가는 키.
const SAVE_KEY := "settings"

# 볼륨을 다루는 오디오 버스 이름. Godot 기본 버스다.
const MASTER_BUS := "Master"

# 볼륨 0 은 무음이다. 데시벨로는 -inf 라서 따로 다뤄야 한다.
const SILENT_DB := -80.0

# 설정이 바뀔 때. 화면은 이 신호로만 갱신한다.
signal settings_changed()

# 전체화면인가. false 면 창 모드.
var fullscreen: bool = false

# 마스터 볼륨 (0.0 ~ 1.0). 데시벨 변환은 이 시스템이 감춘다.
var master_volume: float = 1.0


func _ready() -> void:
	name = "SettingsSystem"
	# 저장 스키마의 설정 부분은 이 시스템이 소유한다(SaveSystem 은 내부를 모른다).
	SaveSystem.register_provider(SAVE_KEY, self)
	# 복원된 값(또는 기본값)을 실제 시스템에 반영한다.
	# register_provider 안에서 from_save_dict 가 이미 불렸을 수 있으므로 여기서 한 번 적용한다.
	apply_all()


# ===== 변경 (Mutation) =====

func set_fullscreen(value: bool) -> void:
	if value == fullscreen:
		return
	fullscreen = value
	_apply_window_mode()
	settings_changed.emit()


# 0.0 ~ 1.0 밖의 값은 잘라 넣는다.
func set_master_volume(value: float) -> void:
	var clamped := clampf(value, 0.0, 1.0)
	if is_equal_approx(clamped, master_volume):
		return
	master_volume = clamped
	_apply_volume()
	settings_changed.emit()


# ===== 적용 (Apply) =====
# 실제 시스템에 밀어 넣는 곳. 화면은 이 함수를 부르지 않는다(set_* 가 대신 부른다).

func apply_all() -> void:
	_apply_window_mode()
	_apply_volume()


func _apply_window_mode() -> void:
	# 헤드리스에서는 창이 없다. 그때 호출해도 안전하다(Godot 이 무시한다).
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _apply_volume() -> void:
	var bus := AudioServer.get_bus_index(MASTER_BUS)
	if bus < 0:
		push_warning("SettingsSystem: 오디오 버스를 찾을 수 없습니다: " + MASTER_BUS)
		return
	# 0 은 데시벨로 표현할 수 없으므로 음소거로 따로 처리한다.
	if master_volume <= 0.0:
		AudioServer.set_bus_mute(bus, true)
		AudioServer.set_bus_volume_db(bus, SILENT_DB)
		return
	AudioServer.set_bus_mute(bus, false)
	AudioServer.set_bus_volume_db(bus, linear_to_db(master_volume))


# ===== 저장/복원 (Save / Load) =====
# SaveSystem 은 이 두 함수만 호출한다.

func to_save_dict() -> Dictionary:
	return {
		"fullscreen": fullscreen,
		"master_volume": master_volume,
	}


func from_save_dict(data: Dictionary) -> void:
	# 없는 키는 현재 값을 유지한다(구 세이브 호환).
	fullscreen = bool(data.get("fullscreen", fullscreen))
	master_volume = clampf(float(data.get("master_volume", master_volume)), 0.0, 1.0)
	# 복원 직후 실제 시스템에 반영한다. _ready() 보다 먼저 불릴 수 있어 여기서도 적용한다.
	apply_all()
	settings_changed.emit()
