extends Control

# 설정 화면 (메타 UI).
#
# 책임: 설정 값을 보여주고 바꾼다. **적용과 저장은 하지 않는다.**
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   설정 값        -> SettingsSystem
#   실제 적용       -> SettingsSystem (DisplayServer/AudioServer 를 여기서 만지지 않는다)
#   저장           -> SaveSystem (SettingsSystem 이 제공자로 등록되어 있다)
#   색             -> UITheme
#
# 화면은 set_* 를 부르고 결과만 다시 그린다.

const BACK_ICON := "icon_back"
const SETTINGS_ICON := "icon_settings"

var _rows: VBoxContainer


func _ready() -> void:
	_build()
	_refresh()
	# 다른 경로로 설정이 바뀌어도 표시가 따라오게 한다.
	SettingsSystem.settings_changed.connect(_refresh)


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

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(panel)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 12)
	panel.add_child(_rows)

	var tail := Control.new()
	tail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tail)


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

	var icon := _icon(SETTINGS_ICON, 24)
	if icon != null:
		row.add_child(icon)

	var title := Label.new()
	title.text = "설정"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	return row


# ===== 갱신 =====

func _refresh() -> void:
	if not is_instance_valid(_rows):
		return
	_clear(_rows)
	_rows.add_child(_build_fullscreen_row())
	_rows.add_child(HSeparator.new())
	_rows.add_child(_build_volume_row())


# 창 모드: 두 값뿐이므로 토글 버튼 하나로 둔다.
func _build_fullscreen_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := _text("화면 모드", 15, UITheme.INK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var button := Button.new()
	button.text = "전체화면" if SettingsSystem.fullscreen else "창 모드"
	button.custom_minimum_size = Vector2(140, 40)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_stylebox_override("normal", UITheme.accent_box() if SettingsSystem.fullscreen else UITheme.panel_box_deep())
	button.add_theme_stylebox_override("hover", UITheme.accent_box() if SettingsSystem.fullscreen else UITheme.panel_box_deep())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	button.pressed.connect(func(): SettingsSystem.set_fullscreen(not SettingsSystem.fullscreen))
	row.add_child(button)
	return row


# 마스터 볼륨: 0~100 을 슬라이더로. 값 변환(데시벨)은 SettingsSystem 이 감춘다.
func _build_volume_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var label := _text("소리 크기", 15, UITheme.INK)
	label.custom_minimum_size = Vector2(120, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = SettingsSystem.master_volume
	slider.custom_minimum_size = Vector2(0, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 슬라이더를 끌 때마다 _refresh() 로 다시 만들면 드래그가 끊긴다.
	# 그래서 여기서는 값만 넘기고, 옆 숫자 라벨만 직접 갱신한다.
	var value_label := _text(_percent(SettingsSystem.master_volume), 15, UITheme.INK)
	value_label.custom_minimum_size = Vector2(56, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(v: float):
		SettingsSystem.set_master_volume(v)
		if is_instance_valid(value_label):
			value_label.text = _percent(v)
	)
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _percent(value: float) -> String:
	return "%d%%" % int(round(value * 100.0))


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
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
