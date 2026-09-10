extends Node

# 게임 설정의 단일 출처 (autoload).
#
# 책임: 플레이어가 고른 설정 값을 보유하고, 실제 시스템에 적용한다.
#
# 여기 있는 값은 **게임 밸런스가 아니라 실제 시스템 값**이다.
# 창 모드와 창 크기는 DisplayServer, 볼륨은 AudioServer 가 실제로 적용받는다.
# 그래서 임의 수치를 만들 여지가 없다(기획 대기 항목이 아니다).
#
# 해상도 프리셋 목록(WINDOW_SIZES)도 이 시스템이 소유한다. 설정 화면은 이 목록을
# 읽어 버튼을 만들 뿐, 자기 목록을 따로 두지 않는다.
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

# 창 모드에서 고를 수 있는 창 크기. **해상도 목록의 유일한 출처다.**
#
# project.godot 의 기본 뷰포트가 1280x720 이고 stretch 가 canvas_items + expand 라,
# 같은 16:9 로만 둔다. 비율이 달라지면 UI 여백을 따로 검증해야 한다(이슈 #483 non-goal).
const WINDOW_SIZES: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]

# 프리셋이 지금 모니터에 들어가는지 볼 때 남겨두는 여백(픽셀).
# 창 테두리와 메뉴 막대가 사용 가능 영역을 조금 더 먹기 때문에 딱 맞는 크기는 거른다.
const SCREEN_MARGIN := Vector2i(0, 64)

# 설정이 바뀔 때. 화면은 이 신호로만 갱신한다.
signal settings_changed()

# 전체화면인가. false 면 창 모드.
var fullscreen: bool = false

# 창 모드일 때 쓸 창 크기. 반드시 WINDOW_SIZES 안의 값이다.
# 전체화면 동안에도 이 값을 들고 있다가, 창 모드로 돌아올 때 이 크기로 되돌린다.
var window_size: Vector2i = WINDOW_SIZES[0]

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


# 프리셋 목록에 없거나 지금 모니터에 안 들어가는 크기는 무시한다.
# 전체화면 중에 골라도 값은 기억해 두고, 창 모드로 돌아올 때 적용한다.
func set_window_size(value: Vector2i) -> void:
	if not is_window_size_available(value):
		return
	if value == window_size:
		return
	window_size = value
	_apply_window_mode()
	settings_changed.emit()


# 프리셋 목록에 있고, 지금 모니터의 사용 가능 영역 안에 들어가는가.
# 모니터 밖으로 나가는 창은 만들지 않는다.
func is_window_size_available(value: Vector2i) -> bool:
	if not WINDOW_SIZES.has(value):
		return false
	var usable := _usable_screen_size()
	# 헤드리스처럼 화면 크기를 알 수 없으면 막지 않는다.
	if usable.x <= 0 or usable.y <= 0:
		return true
	return value.x + SCREEN_MARGIN.x <= usable.x and value.y + SCREEN_MARGIN.y <= usable.y


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
	#
	# 에디터에서 실행하면 Godot 4.4+ 가 게임 창을 Game 탭에 임베드할 수 있고
	# (Editor Settings > Run > Window Placement > Game Embed Mode), 그때는 아래
	# 호출이 조용히 무시된다. 창 설정이 안 먹는 것처럼 보이면 그 임베드를 먼저 끈다.
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_window_size()


# 창 모드에서만 의미가 있다. 크기를 바꾼 뒤 화면 중앙에 다시 놓는다.
# 크기만 바꾸면 창이 모니터 밖으로 걸치는 일이 생긴다.
func _apply_window_size() -> void:
	if DisplayServer.window_get_size() != window_size:
		DisplayServer.window_set_size(window_size)
	var usable := _usable_screen_size()
	if usable.x <= 0 or usable.y <= 0:
		return
	var origin := DisplayServer.screen_get_usable_rect().position
	DisplayServer.window_set_position(origin + (usable - window_size) / 2)


# 창을 놓을 수 있는 영역의 크기. 헤드리스에서는 (0, 0) 이 나올 수 있다.
func _usable_screen_size() -> Vector2i:
	if DisplayServer.get_name() == "headless":
		return Vector2i.ZERO
	return DisplayServer.screen_get_usable_rect().size


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
		# JSON 은 Vector2i 를 모른다. [폭, 높이] 로 풀어서 저장한다.
		"window_size": [window_size.x, window_size.y],
		"master_volume": master_volume,
	}


func from_save_dict(data: Dictionary) -> void:
	# 없는 키는 현재 값을 유지한다(구 세이브 호환).
	fullscreen = bool(data.get("fullscreen", fullscreen))
	window_size = _parse_window_size(data.get("window_size", null))
	master_volume = clampf(float(data.get("master_volume", master_volume)), 0.0, 1.0)
	# 복원 직후 실제 시스템에 반영한다. _ready() 보다 먼저 불릴 수 있어 여기서도 적용한다.
	apply_all()
	settings_changed.emit()


# 저장된 [폭, 높이] 를 프리셋으로 되돌린다.
# 목록에 없는 값(구 버전 프리셋, 손댄 세이브)은 지금 값을 유지한다.
func _parse_window_size(raw: Variant) -> Vector2i:
	if not (raw is Array) or (raw as Array).size() != 2:
		return window_size
	var parsed := Vector2i(int((raw as Array)[0]), int((raw as Array)[1]))
	if not WINDOW_SIZES.has(parsed):
		return window_size
	return parsed
