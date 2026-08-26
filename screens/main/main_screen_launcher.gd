extends Node

# 메인화면을 여닫는 진입 훅.
#
# main.tscn(실제 게임플레이)의 자식으로 붙는다.
# 진입점(run/main_scene)은 그대로 main.tscn 이며, 이 노드는 그 위에
# 메타 화면을 "얹기만" 한다. 씬 트리를 교체하지 않는다.
#
# 화면을 여는 주체를 ScreenManager(인프라)가 아니라 여기에 둔 이유:
#   ScreenManager는 "어떤 화면이 떠 있는가"만 알아야 하고
#   특정 화면(MainScreen)을 알면 인프라가 화면에 의존하게 된다.

const MAIN_SCREEN := preload("res://screens/main/MainScreen.tscn")

# 로비에 흐르는 곡(#308).
#
# 왜 MusicSystem 이 아니라 여기서 정하는가: MusicSystem 은 "트랙 하나를 재생한다"만 아는
# 인프라다. 위와 같은 이유다 — 인프라가 특정 화면(과 그 화면의 곡)을 알면 화면이 늘어날
# 때마다 인프라를 고쳐야 한다. 이 노드는 이미 MainScreen 을 아는 자리라 곡도 여기가 안다.
const LOBBY_BGM := preload("res://assets/audio/bgm/lobby_theme.ogg")

# 메뉴를 여닫는 입력 액션 (project.godot [input] 에 정의).
const MENU_ACTION := &"open_menu"


func _ready() -> void:
	# 메타 화면이 떠 있으면 게임플레이가 멈추므로, 이 노드는 계속 입력을 받아야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 메타 화면이 열리고 닫히는 것에 맞춰 로비 음악을 켜고 끈다(#308).
	#
	# 이 신호는 스택이 **비었다 <-> 아니다** 가 바뀔 때만 나온다. 화면을 쌓고 무는
	# 동안에는 나오지 않으므로, 로비 -> 편성 -> 로비로 오가도 음악이 끊기지 않는다.
	# (그래도 play() 가 같은 곡을 걸러 내므로 중복 호출은 무해하다.)
	ScreenManager.screen_visibility_changed.connect(_on_screen_visibility_changed)

	# 스테이지가 파티를 채운 뒤에 화면을 열어야 프리뷰에 멤버가 보인다.
	# (Stage1_1._ready() -> PartySystem.set_party())
	await get_tree().process_frame
	open_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(MENU_ACTION):
		return
	get_viewport().set_input_as_handled()
	toggle_menu()


# 메뉴 키: 화면이 떠 있으면 맨 위를 닫고, 없으면 메인화면을 연다.
# 출격으로 화면을 닫은 뒤에도 이 키로 다시 돌아올 수 있다.
func toggle_menu() -> void:
	if ScreenManager.has_screen():
		ScreenManager.pop()
	else:
		open_menu()


# 메인화면을 연다. 이미 화면이 떠 있으면 중복해서 쌓지 않는다.
func open_menu() -> void:
	if ScreenManager.has_screen():
		return
	ScreenManager.push(MAIN_SCREEN)


# 메타 화면이 열렸는가에 따라 로비 음악을 켜고 끈다(#308).
#
# 이 게임의 로비는 별도 씬이 아니라 게임플레이 위에 얹히는 오버레이라, "로비에 있다" 는
# 곧 "메타 화면이 떠 있다" 다. 그래서 출격(close_all)하면 자동으로 꺼진다.
#
# 전투 BGM 은 아직 없다. 생기면 여기가 아니라 전투 쪽이 자기 곡을 요청하면 된다 —
# 이 노드는 로비만 안다.
func _on_screen_visibility_changed(has_screen: bool) -> void:
	if has_screen:
		MusicSystem.play(LOBBY_BGM)
	else:
		MusicSystem.stop()
