extends Control

# 전투 결과 화면 (메타 UI).
#
# 책임: 승패와 스테이지 이름을 보여 주고, 다시 시도할지 메인으로 갈지 고르게 한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   승패·스테이지  -> 띄우는 쪽(stage_result_launcher)이 set_outcome() 으로 넘긴다
#   스테이지 이름   -> StageData.display_name (여기서 문자열을 만들지 않는다)
#   보상·클리어 여부 -> StageProgress (지급은 그쪽이 이미 했다. 여기는 결과를 읽어 보여만 준다)
#   재진입         -> StageSystem.request_stage()
#   색·조각        -> UITheme / HUDKit
#
# 참고: docs/combat-screen-design.md §5, screens/result/stage_result_launcher.gd

const MAIN_SCREEN_PATH := "res://screens/main/MainScreen.tscn"

var _victory: bool = true
var _stage_id: StringName = &""

var _title: Label
var _subtitle: Label
var _reward_row: HBoxContainer


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

	_reward_row = HBoxContainer.new()
	_reward_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_row.add_theme_constant_override("separation", 6)
	box.add_child(_reward_row)

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

	_refresh_rewards()


# 받은 보상. 지급은 StageProgress 가 이미 했고 여기서는 그 결과만 읽는다.
# 다른 판의 결과를 보여 주지 않도록 stage_id 와 승패를 대조한다.
func _refresh_rewards() -> void:
	if not is_instance_valid(_reward_row):
		return
	for child in _reward_row.get_children():
		_reward_row.remove_child(child)
		child.queue_free()

	var result := StageProgress.get_last_result()
	if result.get("stage_id", &"") != _stage_id or result.get("victory", false) != _victory:
		return

	if bool(result.get("first_clear", false)):
		_reward_row.add_child(HUDKit.tag_chip("첫 클리어", UITheme.ACCENT.darkened(0.4)))

	var rewards: Dictionary = result.get("rewards", {})
	for currency_type in rewards:
		_reward_row.add_child(HUDKit.currency_chip(
			str(currency_type), "+%s" % HUDKit.comma(int(rewards[currency_type]))))

	# 프로틴과 삼각근 Lv.업. 재화 칩과 달리 프로틴은 재화가 아니므로 태그 칩으로 둔다.
	var protein := int(result.get("protein", 0))
	if protein > 0:
		_reward_row.add_child(HUDKit.tag_chip(
			"프로틴 +%s" % HUDKit.comma(protein), UITheme.POSITIVE.darkened(0.4)))

	var level_before := int(result.get("deltoid_level_before", 0))
	var level_after := int(result.get("deltoid_level_after", 0))
	if level_after > level_before:
		_reward_row.add_child(HUDKit.tag_chip(
			"삼각근 Lv.%d → Lv.%d" % [level_before, level_after], UITheme.ACCENT.darkened(0.4)))

	_reward_row.visible = _reward_row.get_child_count() > 0


# ===== 조작 =====

# 같은 스테이지를 처음 상태로 다시 연다.
func _on_retry_pressed() -> void:
	StageSystem.request_stage(_stage_id)
	ScreenManager.close_all()


func _on_home_pressed() -> void:
	ScreenManager.replace(load(MAIN_SCREEN_PATH))
