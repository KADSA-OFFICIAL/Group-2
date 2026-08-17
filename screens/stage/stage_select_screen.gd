extends Control

# 스테이지 선택 화면 (메타 UI).
#
# 책임: 저작된 스테이지를 나열하고, 고른 스테이지로 출격한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   스테이지 목록/정의 -> StageDatabase / StageData
#   승리 조건          -> StageData.get_objectives_display_name()
#                        (타입->조건 대응을 화면에서 다시 쓰지 않는다)
#   색·조각            -> UITheme / HUDKit
#
# 아직 저작된 스테이지가 없다 (data/stages 가 비어 있다).
# 그래서 목록이 비었을 때를 정상 상태로 다루고, 지금까지처럼 바로 출격할 수 있는
# 길을 남겨 둔다. 스테이지가 저작되면 목록이 자동으로 채워진다.
#
# 참고: docs/combat-screen-design.md §5, data/stages/README.md

var _list_holder: VBoxContainer


func _ready() -> void:
	_build()
	_refresh()


# ===== 화면 구성 =====

func _build() -> void:
	add_child(HUDKit.make_backdrop())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(HUDKit.make_header("출격", "sortie", "icon_battle"))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list_holder = VBoxContainer.new()
	_list_holder.add_theme_constant_override("separation", 10)
	_list_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_holder)


# ===== 목록 =====

func _refresh() -> void:
	if not is_instance_valid(_list_holder):
		return
	_clear(_list_holder)

	var ids := StageDatabase.get_all_ids()
	if ids.is_empty():
		_list_holder.add_child(_empty_notice())
		return

	for id in ids:
		_list_holder.add_child(_make_stage_card(id))


# 저작된 스테이지가 없을 때. 오류가 아니라 정상 상태다.
# 지금까지 출격 버튼이 하던 일(화면 닫고 게임플레이 진입)을 여기서 이어 준다.
func _empty_notice() -> Control:
	var panel := HUDKit.empty_notice(
		"저작된 스테이지가 없습니다.",
		"data/stages 에 StageData(.tres)를 저작하면 여기 나타납니다.")

	var box := panel.get_meta("body") as VBoxContainer

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(actions)

	var button := HUDKit.make_cta("현재 스테이지로 출격", "launch")
	button.pressed.connect(_on_launch_pressed)
	actions.add_child(button)
	return panel


func _make_stage_card(id: StringName) -> Control:
	var stage := StageDatabase.get_stage(id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HUDKit.card())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	if stage == null:
		info.add_child(HUDKit.label(String(id), 16, HUDKit.text_1(), 700))
		return card

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	title_row.add_child(HUDKit.label(stage.display_name, 17, HUDKit.text_1(), 700))
	# 타입 이름과 승리 조건 문구의 출처는 StageData 다.
	title_row.add_child(HUDKit.tag_chip(stage.get_type_name(), UITheme.SKY))

	info.add_child(HUDKit.label("승리 조건: %s" % stage.get_objectives_display_name(), 13, HUDKit.text_2()))

	if not stage.description.is_empty():
		var desc := HUDKit.label(stage.description, 12, HUDKit.text_3())
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)

	var button := HUDKit.make_cta("출격", "go")
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(_on_launch_pressed)
	row.add_child(button)
	return card


# ===== 조작 =====

# 출격 = 메타 화면을 모두 닫아 게임플레이를 드러낸다.
#
# 고른 스테이지를 실제로 불러오지는 않는다(아직 못 한다):
# 승리 조건 판정(소탕 완료 / 점령 게이지)이 구현되지 않았고, 스테이지 로딩도
# Stage1_1 하나로 하드코딩되어 있다. 그 둘이 생기면 여기서 id 를 넘기면 된다.
func _on_launch_pressed() -> void:
	ScreenManager.close_all()


# ===== 공용 조각 =====

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
