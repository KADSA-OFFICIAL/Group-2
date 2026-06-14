## res://screens/settings/settings.gd
## 설정 화면. 오디오 / 그래픽 / 계정 세 섹션.

extends Control

var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var root_margin := MarginContainer.new()
	root_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_margin.add_theme_constant_override("margin_left", 16)
	root_margin.add_theme_constant_override("margin_right", 16)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(root_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	root_margin.add_child(vbox)

	# ── 상단바 ──
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = "← 뒤로"
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(func(): ScreenManager.pop())
	top_bar.add_child(back_btn)

	var title_label := Label.new()
	title_label.text = "설정"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title_label)

	# ── 오디오 섹션 ──
	vbox.add_child(_section_header("오디오"))
	var audio_panel := PanelContainer.new()
	audio_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
	vbox.add_child(audio_panel)

	var audio_vbox := VBoxContainer.new()
	audio_vbox.add_theme_constant_override("separation", 10)
	audio_panel.add_child(audio_vbox)

	# BGM 토글
	audio_vbox.add_child(_make_toggle_row("BGM", GameData.settings.bgm,
		func(val: bool): GameData.settings.bgm = val))

	# BGM 볼륨
	audio_vbox.add_child(_make_slider_row("BGM 볼륨", GameData.settings.bgm_vol,
		func(val: float): GameData.settings.bgm_vol = val))

	# SFX 토글
	audio_vbox.add_child(_make_toggle_row("효과음", GameData.settings.sfx,
		func(val: bool): GameData.settings.sfx = val))

	# SFX 볼륨
	audio_vbox.add_child(_make_slider_row("효과음 볼륨", GameData.settings.sfx_vol,
		func(val: float): GameData.settings.sfx_vol = val))

	# ── 그래픽 섹션 ──
	vbox.add_child(_section_header("그래픽"))
	var gfx_panel := PanelContainer.new()
	gfx_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
	vbox.add_child(gfx_panel)

	var gfx_vbox := VBoxContainer.new()
	gfx_vbox.add_theme_constant_override("separation", 10)
	gfx_panel.add_child(gfx_vbox)

	# 화면 흔들림
	gfx_vbox.add_child(_make_toggle_row("화면 흔들림", GameData.settings.shake,
		func(val: bool): GameData.settings.shake = val))

	# 데미지 표시
	gfx_vbox.add_child(_make_toggle_row("데미지 표시", GameData.settings.dmg,
		func(val: bool): GameData.settings.dmg = val))

	# 품질 선택
	gfx_vbox.add_child(_make_quality_row())

	# ── 계정 섹션 ──
	vbox.add_child(_section_header("계정"))
	var acct_panel := PanelContainer.new()
	acct_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
	vbox.add_child(acct_panel)

	var acct_vbox := VBoxContainer.new()
	acct_vbox.add_theme_constant_override("separation", 10)
	acct_panel.add_child(acct_vbox)

	var acct_name := Label.new()
	acct_name.text = "계정: %s" % GameData.player_name
	acct_name.add_theme_font_size_override("font_size", 15)
	acct_vbox.add_child(acct_name)

	var logout_btn := Button.new()
	logout_btn.text = "로그아웃"
	logout_btn.add_theme_font_size_override("font_size", 15)
	logout_btn.pressed.connect(func(): _toast("로그아웃 기능은 아직 구현 중이야"))
	acct_vbox.add_child(logout_btn)

	var reset_btn := Button.new()
	reset_btn.text = "데이터 초기화"
	reset_btn.add_theme_font_size_override("font_size", 15)
	reset_btn.add_theme_color_override("font_color", ThemeFactory.C_BAD)
	reset_btn.pressed.connect(_on_reset_data)
	acct_vbox.add_child(reset_btn)

	# ── 버전 ──
	var version_label := Label.new()
	version_label.text = "버전 0.1.0 (프로토타입)"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 13)
	version_label.add_theme_color_override("font_color", ThemeFactory.C_LINE)
	vbox.add_child(version_label)

	# ── 토스트 ──
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -240
	_toast_label.offset_right = 240
	_toast_label.offset_top = -28
	_toast_label.offset_bottom = 28
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.visible = false
	add_child(_toast_label)


func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	return lbl


func _make_toggle_row(label_text: String, initial: bool, on_changed: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var toggle := CheckButton.new()
	toggle.button_pressed = initial
	toggle.toggled.connect(on_changed)
	row.add_child(toggle)

	return row


func _make_slider_row(label_text: String, initial: float, on_changed: Callable) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	col.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = initial
	slider.custom_minimum_size = Vector2(0, 28)
	slider.value_changed.connect(on_changed)
	col.add_child(slider)

	return col


func _make_quality_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = "품질"
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var btn_hbox := HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 6)
	row.add_child(btn_hbox)

	var quality_options := ["하", "중", "상"]
	var current_quality: String = GameData.settings.quality

	for opt in quality_options:
		var btn := Button.new()
		btn.text = opt
		btn.add_theme_font_size_override("font_size", 14)
		btn.custom_minimum_size = Vector2(44, 0)
		if opt == current_quality:
			btn.add_theme_stylebox_override("normal", ThemeFactory.accent_box(10))
		btn.pressed.connect(_on_quality_select.bind(opt, btn_hbox, quality_options))
		btn_hbox.add_child(btn)

	return row


func _on_quality_select(opt: String, btn_hbox: HBoxContainer, options: Array) -> void:
	GameData.settings.quality = opt
	var children := btn_hbox.get_children()
	for i in children.size():
		var b := children[i] as Button
		if b == null:
			continue
		if options[i] == opt:
			b.add_theme_stylebox_override("normal", ThemeFactory.accent_box(10))
		else:
			b.remove_theme_stylebox_override("normal")


func _on_reset_data() -> void:
	GameData.reset_save()
	_toast("데이터 초기화 — 게임을 재시작하면 처음부터 시작해")


func _toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false
