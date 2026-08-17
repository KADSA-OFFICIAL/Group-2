extends Control

# 설정 화면 (메타 UI).
#
# 책임: 설정 값을 보여주고 바꾼다. **적용과 저장은 하지 않는다.**
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   설정 값        -> SettingsSystem
#   실제 적용       -> SettingsSystem (DisplayServer/AudioServer 를 여기서 만지지 않는다)
#   저장           -> SaveSystem (SettingsSystem 이 제공자로 등록되어 있다)
#   색·조각        -> UITheme / HUDKit
#
# 화면은 set_* 를 부르고 결과만 다시 그린다.

var _rows: VBoxContainer

# 이 화면이 스스로 일으킨 변경 때문에 다시 그리는 것을 막는다.
#
# SettingsSystem.set_master_volume() 은 settings_changed 를 쏘고, 그 신호가 _refresh()
# 에 연결돼 있다. 그래서 슬라이더를 끄는 동안 슬라이더 노드 자체가 매 프레임 지워졌다
# 다시 만들어져 드래그가 끊겼다. 바깥에서 온 변경만 다시 그린다.
var _applying_own_change: bool = false


func _ready() -> void:
	_build()
	_refresh()
	# 다른 경로로 설정이 바뀌어도 표시가 따라오게 한다.
	SettingsSystem.settings_changed.connect(_refresh)


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

	root.add_child(HUDKit.make_header("설정", "settings", "icon_settings"))

	# 설정은 항목이 두 개뿐이라 화면 폭을 다 쓰면 라벨과 조작부가 너무 멀어진다.
	# 가운데로 폭을 제한한다.
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(center)

	var left_pad := Control.new()
	left_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(left_pad)

	var panel := HUDKit.make_panel("환경 설정", "preferences")
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)

	var right_pad := Control.new()
	right_pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(right_pad)

	_rows = HUDKit.body_of(panel)
	_rows.add_theme_constant_override("separation", 10)

	var tail := Control.new()
	tail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(tail)

	HUDKit.play_enter([panel])


# ===== 갱신 =====

func _refresh() -> void:
	if _applying_own_change:
		return
	if not is_instance_valid(_rows):
		return
	_clear(_rows)
	_rows.add_child(_build_fullscreen_row())
	_rows.add_child(HUDKit.rule())
	_rows.add_child(_build_volume_row())


# 창 모드: 두 값뿐이므로 토글 버튼 하나로 둔다.
func _build_fullscreen_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 56)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)
	box.add_child(HUDKit.label("화면 모드", 15, HUDKit.text_1(), 600))
	box.add_child(HUDKit.caption("display mode"))

	# 켜진 상태만 CTA(액센트 채움)로 둔다. 지금 어느 쪽인지가 버튼 모양으로 드러난다.
	var on := SettingsSystem.fullscreen
	var button := HUDKit.make_cta("전체화면", "on") if on else HUDKit.make_ghost("창 모드", 150)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(func(): SettingsSystem.set_fullscreen(not SettingsSystem.fullscreen))
	row.add_child(button)
	return row


# 마스터 볼륨: 0~100 을 슬라이더로. 값 변환(데시벨)은 SettingsSystem 이 감춘다.
func _build_volume_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.custom_minimum_size = Vector2(0, 56)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.custom_minimum_size = Vector2(130, 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)
	box.add_child(HUDKit.label("소리 크기", 15, HUDKit.text_1(), 600))
	box.add_child(HUDKit.caption("volume"))

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = SettingsSystem.master_volume
	slider.custom_minimum_size = Vector2(0, 32)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	HUDKit.style_slider(slider)

	# 슬라이더를 끌 때마다 _refresh() 로 다시 만들면 드래그가 끊긴다.
	# 그래서 여기서는 값만 넘기고, 옆 숫자 라벨만 직접 갱신한다.
	var value_label := HUDKit.value(_percent(SettingsSystem.master_volume), 20)
	value_label.custom_minimum_size = Vector2(64, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slider.value_changed.connect(func(v: float):
		_applying_own_change = true
		SettingsSystem.set_master_volume(v)
		_applying_own_change = false
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
