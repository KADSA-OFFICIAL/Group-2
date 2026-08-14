extends Control

# 스테이지 선택 화면 (메타 UI).
#
# 책임: 저작된 스테이지를 나열하고, 고른 스테이지로 출격한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   스테이지 목록/정의 -> StageDatabase / StageData
#   승리 조건          -> StageData.get_objectives_display_name()
#                        (타입->조건 대응을 화면에서 다시 쓰지 않는다)
#   색·치수            -> UITheme
#
# 아직 저작된 스테이지가 없다 (data/stages 가 비어 있다).
# 그래서 목록이 비었을 때를 정상 상태로 다루고, 지금까지처럼 바로 출격할 수 있는
# 길을 남겨 둔다. 스테이지가 저작되면 목록이 자동으로 채워진다.
#
# 참고: docs/combat-screen-design.md §5, data/stages/README.md

const BACK_ICON := "icon_back"
const BATTLE_ICON := "icon_battle"

var _list_holder: VBoxContainer


func _ready() -> void:
	_build()
	_refresh()


# ===== 화면 구성 =====

func _build() -> void:
	add_child(UITheme.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list_holder = VBoxContainer.new()
	_list_holder.add_theme_constant_override("separation", 10)
	_list_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_holder)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var back := Button.new()
	back.text = " 뒤로"
	back.icon = _texture(BACK_ICON)
	back.expand_icon = true
	back.custom_minimum_size = Vector2(0, 40)
	back.add_theme_stylebox_override("normal", UITheme.panel_box())
	back.add_theme_stylebox_override("hover", UITheme.panel_box())
	back.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	back.add_theme_color_override("font_color", UITheme.INK)
	back.pressed.connect(func(): ScreenManager.pop())
	row.add_child(back)

	var icon := _icon(BATTLE_ICON, 24)
	if icon != null:
		row.add_child(icon)

	var title := Label.new()
	title.text = "출격"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	return row


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
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	box.add_child(_text("저작된 스테이지가 없습니다.", 16, UITheme.INK))
	box.add_child(_text("data/stages 에 StageData(.tres)를 저작하면 여기 나타납니다.", 13, UITheme.INK_DIM))

	var button := Button.new()
	button.text = "현재 스테이지로 출격"
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_stylebox_override("normal", UITheme.accent_box())
	button.add_theme_stylebox_override("hover", UITheme.accent_box())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	button.pressed.connect(_on_launch_pressed)
	box.add_child(button)
	return panel


func _make_stage_card(id: StringName) -> Control:
	var stage := StageDatabase.get_stage(id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_box())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	if stage == null:
		info.add_child(_text(String(id), 16, UITheme.INK))
		return card

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	title_row.add_child(_text(stage.display_name, 16, UITheme.INK))
	# 타입 이름과 승리 조건 문구의 출처는 StageData 다.
	title_row.add_child(_text("(%s)" % stage.get_type_name(), 13, UITheme.INK_DIM))

	info.add_child(_text("승리 조건: %s" % stage.get_objectives_display_name(), 13, UITheme.INK_DIM))

	if not stage.description.is_empty():
		var desc := _text(stage.description, 12, UITheme.INK_DIM)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)

	var button := Button.new()
	button.text = "출격"
	button.custom_minimum_size = Vector2(96, 44)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_stylebox_override("normal", UITheme.accent_box())
	button.add_theme_stylebox_override("hover", UITheme.accent_box())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
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


func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _icon(icon_name: String, size: int) -> TextureRect:
	var texture := _texture(icon_name)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# 아이콘 **이름**("icon_back")을 받는다. 경로와 확장자 해석은 UITheme 이 한다.
func _texture(icon_name: String) -> Texture2D:
	var path := UITheme.icon_path(icon_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D
