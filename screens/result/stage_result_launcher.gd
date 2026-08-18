extends Node

# 결과 화면을 여는 진입 훅.
#
# main.tscn(실제 게임플레이)의 자식으로 붙는다. main_screen_launcher.gd 와 같은 규약이다:
#   ScreenManager는 "어떤 화면이 떠 있는가"만 알아야 하고, 전장(Stage)은 화면을 몰라야 한다.
#   그래서 "승패가 났다(EventBus) -> 결과 화면을 연다(ScreenManager)" 를 잇는 자리를 따로 둔다.
#
# 참고: stage/Stage1_1.gd(판정), screens/result/result_screen.gd

const RESULT_SCREEN := preload("res://screens/result/ResultScreen.tscn")


func _ready() -> void:
	EventBus.stage_completed.connect(_on_stage_completed)
	EventBus.stage_failed.connect(_on_stage_failed)


func _on_stage_completed(_stage_name) -> void:
	_open(true)


func _on_stage_failed(_stage_name) -> void:
	_open(false)


# 결과 화면을 연다.
#
# 이미 화면이 떠 있으면 열지 않는다. 메뉴를 보는 동안 전장이 멈추므로 그 사이에
# 승패가 날 일은 없지만, 결과 화면 위에 결과 화면이 또 쌓이는 것만은 막아야 한다.
func _open(victory: bool) -> void:
	if ScreenManager.has_screen():
		return

	var screen := ScreenManager.push(RESULT_SCREEN)
	if screen == null:
		return
	screen.call("set_outcome", victory, StageSystem.get_current_id())
