extends Control

# 전투 결과 화면 (메타 UI).
#
# 책임: 승패와 스테이지 이름을 보여 주고, 다시 시도할지 메인으로 갈지 고르게 한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   승패·스테이지  -> 띄우는 쪽(stage_result_launcher)이 set_outcome() 으로 넘긴다
#   스테이지 이름   -> StageData.display_name (여기서 문자열을 만들지 않는다)
#   재진입         -> StageSystem.request_stage()
#   색·조각        -> UITheme / HUDKit
#
# 참고: docs/combat-screen-design.md §5, screens/result/stage_result_launcher.gd

const MAIN_SCREEN_PATH := "res://screens/main/MainScreen.tscn"

var _victory: bool = true
var _stage_id: StringName = &""

var _title: Label
var _subtitle: Label


func _ready() -> void:
	_build()
	_refresh()


# 띄우는 쪽이 push 직후에 부른다. _ready 보다 늦게 올 수 있으므로 다시 그린다.
func set_outcome(victory: bool, stage_id: StringName) -> void:
	_victory = victory
	_stage_id = stage_id
	_refresh()


# ===== 화면 구성 =====

func _build() -> void:
	# 전장 위에 얹힌다. 배경을 꽉 채우지 않고 결과 판만 띄운다 —
	# 방금 무슨 일이 있었는지(쓰러진 파티, 남은 적)가 보여야 한다.
	var dim := ColorRect.new()
	dim.color = Color(UITheme.BG.r, UITheme.BG.g, UITheme.BG.b, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -230.0
	panel.offset_right = 230.0
	panel.offset_top = -120.0
	panel.offset_bottom = 120.0
	panel.add_theme_stylebox_override("panel", HUDKit.panel(20))
	add_child(panel)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	_title = HUDKit.label("", 30, HUDKit.text_1(), 700)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)

	_subtitle = HUDKit.label("", 14, HUDKit.text_3())
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)

	box.add_child(HUDKit.rule())

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var retry := HUDKit.make_ghost("다시 시도", 130)
	retry.pressed.connect(_on_retry_pressed)
	actions.add_child(retry)

	var home := HUDKit.make_cta("메인으로", "home")
	home.pressed.connect(_on_home_pressed)
	actions.add_child(home)


func _refresh() -> void:
	if not is_instance_valid(_title):
		return

	_title.text = "승리" if _victory else "패배"
	# 승패는 색으로도 읽혀야 한다. 글자만이면 두 결과가 같은 화면으로 보인다.
	_title.add_theme_color_override("font_color",
		UITheme.POSITIVE if _victory else UITheme.NEGATIVE)

	var stage := StageDatabase.get_stage(_stage_id) if StageDatabase.has_stage(_stage_id) else null
	var stage_name: String = stage.display_name if stage != null else String(_stage_id)
	_subtitle.text = "%s · %s" % [stage_name, "소탕 완료" if _victory else "파티 전멸"]


# ===== 조작 =====

# 같은 스테이지를 처음 상태로 다시 연다.
func _on_retry_pressed() -> void:
	StageSystem.request_stage(_stage_id)
	ScreenManager.close_all()


func _on_home_pressed() -> void:
	ScreenManager.replace(load(MAIN_SCREEN_PATH))
