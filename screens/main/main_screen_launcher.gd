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

# 메뉴를 여닫는 입력 액션 (project.godot [input] 에 정의).
const MENU_ACTION := &"open_menu"


func _ready() -> void:
	# 메타 화면이 떠 있으면 게임플레이가 멈추므로, 이 노드는 계속 입력을 받아야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS

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
