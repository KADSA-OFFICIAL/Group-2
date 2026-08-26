extends Node

# 배경음악 재생 시스템 (autoload).
#
# **한 번에 한 곡만** 재생한다. 배경음악은 겹쳐 나오면 안 되는 종류의 소리라,
# 여러 트랙을 동시에 다루는 구조를 만들지 않았다(필요해지면 그때 근거가 생긴다).
#
# 왜 autoload 인가:
#   이 게임의 로비는 별도 씬이 아니라 ScreenManager 가 게임플레이 위에 얹는 오버레이다.
#   화면은 열리고 닫히고 자유롭게 갈리지만 음악은 그 사이에 끊기면 안 된다.
#   씬 트리 어딘가에 AudioStreamPlayer 를 두면 그 노드가 해제될 때 음악도 끊긴다.
#
# **이 시스템은 어떤 곡이 어느 화면의 것인지 모른다.** "트랙 하나를 재생한다"만 안다.
# "로비는 이 곡"이라는 결정은 부르는 쪽(screens/main/main_screen_launcher.gd)이 갖는다 —
# ScreenManager 가 MainScreen 을 알지 않는 것과 같은 규약이다. 인프라가 화면에 의존하면
# 화면이 늘어날 때마다 인프라를 고쳐야 한다.
#
# 볼륨은 여기서 다루지 않는다. Master 버스로 재생하므로 SettingsSystem.master_volume 이
# 그대로 적용된다(SettingsSystem._apply_volume 이 AudioServer 에 반영한다).
# 수치의 출처를 둘로 만들지 않기 위해 이 시스템은 자기 볼륨을 0dB 로 고정해 둔다.

# ===== 페이드 (Fade) =====
#
# 화면 전환(ScreenManager.FADE_IN 0.08초)보다 길다. 음악이 그 속도로 튀어나오면
# 소리가 뭉개져 들리고, 출격할 때 뚝 끊기면 전환이 거칠다.

## 곡이 시작될 때 무음에서 제 음량까지 올라오는 시간(초).
const FADE_IN := 0.6

## 곡이 멈출 때 제 음량에서 무음까지 내려가는 시간(초).
const FADE_OUT := 0.5

## 무음으로 취급하는 데시벨. linear_to_db(0) 이 -inf 라 트윈에 쓸 수 없어 하한을 둔다.
const SILENT_DB := -60.0

## 제 음량(데시벨). 0 = 원본 그대로. 이 값을 낮춰 BGM 을 줄이지 않는다 —
## 볼륨의 출처는 SettingsSystem 하나다.
const FULL_DB := 0.0


# 실제로 소리를 내는 노드. 이 시스템이 소유한다.
var _player: AudioStreamPlayer = null

# 지금 재생 중이거나 재생하려는 스트림. 같은 곡 재요청을 걸러 내는 기준이다.
var _current: AudioStream = null

# 페이드 트윈. 이 시스템이 소유한다 — 새 요청이 오면 이전 페이드를 끊어야 하는데,
# 트윈을 노드에 걸어 두면 어느 트윈이 살아 있는지 추적할 곳이 없다.
var _tween: Tween = null


func _ready() -> void:
	name = "MusicSystem"
	# 메타 화면이 열리면 게임플레이가 멈춘다(ScreenManager._apply_pause).
	# 음악은 그때도 계속 나와야 하므로 일시정지의 영향을 받지 않게 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"
	_player.bus = &"Master"
	_player.volume_db = SILENT_DB
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)


# ===== 재생 (Play) =====

# 곡을 재생한다. **이미 그 곡이 재생 중이면 아무 일도 하지 않는다.**
#
# 그 무시가 이 시스템의 핵심이다: 로비 -> 편성 -> 로비로 오갈 때마다 부르는 쪽이
# play() 를 다시 부르게 되는데, 매번 처음부터 다시 시작하면 음악이 화면 전환에
# 끌려다닌다. "같은 곡이면 그대로 둔다"가 곧 "화면을 옮겨도 끊기지 않는다"다.
#
# fade_in 을 0 으로 주면 즉시 제 음량으로 시작한다.
func play(stream: AudioStream, fade_in: float = FADE_IN) -> void:
	if stream == null:
		push_warning("MusicSystem.play: stream이 null입니다.")
		return

	# 같은 곡이고 실제로 나오는 중이면 건드리지 않는다.
	# 페이드 아웃이 돌던 중이었다면 아래로 내려가 다시 올라온다(중간에 마음이 바뀐 경우).
	if _current == stream and _player.playing and not _is_fading_out():
		return

	_kill_tween()

	if _current != stream or not _player.playing:
		_current = stream
		_player.stream = stream
		_player.play()

	if fade_in <= 0.0:
		_player.volume_db = FULL_DB
		return

	# 이미 어느 정도 올라와 있으면 거기서부터 올린다(처음부터 다시 페이드하지 않는다).
	_player.volume_db = minf(_player.volume_db, FULL_DB)
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", FULL_DB, fade_in)


# 재생을 멈춘다. 페이드 아웃이 끝나면 실제로 정지한다.
#
# fade_out 을 0 으로 주면 그 자리에서 끊는다.
func stop(fade_out: float = FADE_OUT) -> void:
	if not _player.playing:
		_current = null
		return

	_kill_tween()

	if fade_out <= 0.0:
		_finish_stop()
		return

	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", SILENT_DB, fade_out)
	_tween.tween_callback(_finish_stop)


# 페이드 아웃이 끝난 뒤 실제로 멈춘다.
func _finish_stop() -> void:
	_player.stop()
	_player.volume_db = SILENT_DB
	_current = null


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


# 페이드 아웃이 도는 중인가. 같은 곡을 다시 요청했을 때 "그대로 두기"와
# "다시 올리기"를 가르는 기준이다.
func _is_fading_out() -> bool:
	return _tween != null and _tween.is_valid() and _player.volume_db < FULL_DB


# ===== 조회 (Accessors) =====

# 지금 소리가 나고 있는가.
func is_playing() -> bool:
	return _player != null and _player.playing


# 지금 재생 중인 스트림. 없으면 null.
func get_current_stream() -> AudioStream:
	return _current


# 이 스트림이 지금 재생 중인가.
func is_playing_stream(stream: AudioStream) -> bool:
	return _current == stream and is_playing()


# 재생 위치(초). 같은 곡 재요청이 위치를 지켰는지 확인하는 데 쓴다.
func get_playback_position() -> float:
	return _player.get_playback_position() if _player != null and _player.playing else 0.0
