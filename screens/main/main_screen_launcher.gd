extends Node

# 게임 시작 시 메인화면을 띄우는 진입 훅.
#
# main.tscn(실제 게임플레이)의 자식으로 붙는다.
# 진입점(run/main_scene)은 그대로 main.tscn 이며, 이 노드는 그 위에
# 메타 화면을 "얹기만" 한다. 씬 트리를 교체하지 않는다.
#
# 화면을 여는 주체를 ScreenManager(인프라)가 아니라 여기에 둔 이유:
#   ScreenManager는 "어떤 화면이 떠 있는가"만 알아야 하고
#   특정 화면(MainScreen)을 알면 인프라가 화면에 의존하게 된다.

const MAIN_SCREEN := preload("res://screens/main/MainScreen.tscn")


func _ready() -> void:
	# 스테이지가 파티를 채운 뒤에 화면을 열어야 프리뷰에 멤버가 보인다.
	# (Stage1_1._ready() -> PartySystem.set_party())
	await get_tree().process_frame
	ScreenManager.push(MAIN_SCREEN)
