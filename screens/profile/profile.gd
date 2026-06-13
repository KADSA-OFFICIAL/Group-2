## res://screens/profile/profile.gd
## 프로필 화면. 플레이어 카드, 칭호 변경, 스탯 그리드.

extends Control

var _avatar_label: Label
var _name_label: Label
var _title_label: Label
var _level_label: Label
var _cp_label: Label
var _title_buttons_hbox: HBoxContainer
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
	title_label.text = "프로필"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title_label)

	# ── 플레이어 카드 ──
	var player_card := PanelContainer.new()
	player_card.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 22))
	vbox.add_child(player_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 8)
	player_card.add_child(card_vbox)

	_avatar_label = Label.new()
	_avatar_label.add_theme_font_size_override("font_size", 60)
	_avatar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(_avatar_label)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 28)
	_name_label.add_theme_color_override("font_color", ThemeFactory.C_INK)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(_name_label)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_vbox.add_child(_title_label)

	var badge_row := HBoxContainer.new()
	badge_row.alignment = BoxContainer.ALIGNMENT_CENTER
	badge_row.add_theme_constant_override("separation", 16)
	card_vbox.add_child(badge_row)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 16)
	_level_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	badge_row.add_child(_level_label)

	_cp_label = Label.new()
	_cp_label.add_theme_font_size_override("font_size", 16)
	_cp_label.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	badge_row.add_child(_cp_label)

	# ── 칭호 변경 섹션 ──
	var title_section_lbl := Label.new()
	title_section_lbl.text = "보유 칭호"
	title_section_lbl.add_theme_font_size_override("font_size", 18)
	title_section_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	vbox.add_child(title_section_lbl)

	var title_panel := PanelContainer.new()
	title_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
	vbox.add_child(title_panel)

	var title_margin := MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 4)
	title_margin.add_theme_constant_override("margin_right", 4)
	title_margin.add_theme_constant_override("margin_top", 8)
	title_margin.add_theme_constant_override("margin_bottom", 8)
	title_panel.add_child(title_margin)

	_title_buttons_hbox = HBoxContainer.new()
	_title_buttons_hbox.add_theme_constant_override("separation", 8)
	_title_buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_margin.add_child(_title_buttons_hbox)

	# ── 스탯 그리드 ──
	var stats_lbl := Label.new()
	stats_lbl.text = "전투 기록"
	stats_lbl.add_theme_font_size_override("font_size", 18)
	stats_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	vbox.add_child(stats_lbl)

	var stats_panel := PanelContainer.new()
	stats_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
	vbox.add_child(stats_panel)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 10)
	stats_panel.add_child(grid)

	var stats_data := [
		["총 클리어",   "%d" % (GameData.stats.clears + GameData.cleared)],
		["총 모집",     "%d" % GameData.stats.pulls],
		["총 강화",     "%d" % GameData.stats.levelups],
		["총 제조",     "%d" % GameData.stats.crafts],
		["돌파",        "%d" % GameData.stats.promos],
		["보유 캐릭터", "%d" % GameData.roster.size()],
		["총 전투력",   _comma(GameData.total_power())],
		["보유 보석",   "💎 " + _comma(GameData.gems)],
	]

	for pair in stats_data:
		var k_lbl := Label.new()
		k_lbl.text = pair[0]
		k_lbl.add_theme_font_size_override("font_size", 14)
		k_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		grid.add_child(k_lbl)

		var v_lbl := Label.new()
		v_lbl.text = pair[1]
		v_lbl.add_theme_font_size_override("font_size", 15)
		grid.add_child(v_lbl)

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

	_refresh_player_card()
	_build_title_buttons()


func _get_title_nm(id: String) -> String:
	for t in GameData.TITLES:
		if t.id == id:
			return t.nm
	return id


func _refresh_player_card() -> void:
	_avatar_label.text = GameData.avatar
	_name_label.text = GameData.player_name
	_title_label.text = _get_title_nm(GameData.title)
	_level_label.text = "Lv.%d" % GameData.level
	_cp_label.text = "⚔ %s" % _comma(GameData.combat_power)


func _build_title_buttons() -> void:
	for c in _title_buttons_hbox.get_children():
		c.queue_free()

	for t in GameData.TITLES:
		var btn := Button.new()
		var is_current := (t.id == GameData.title)
		btn.text = t.nm + (" (현재)" if is_current else "")
		btn.add_theme_font_size_override("font_size", 14)
		if is_current:
			btn.add_theme_stylebox_override("normal",  ThemeFactory.accent_box(12))
			btn.add_theme_stylebox_override("hover",   ThemeFactory.accent_box(12))
			btn.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(12))
			btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
		btn.pressed.connect(_on_select_title.bind(t.id, t.nm))
		_title_buttons_hbox.add_child(btn)


func _on_select_title(title_id: String, title_nm: String) -> void:
	GameData.title = title_id
	_refresh_player_card()
	_build_title_buttons()
	_toast("%s 칭호 적용!" % title_nm)


func _comma(v: int) -> String:
	var s := str(v)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i != 0:
			out = "," + out
	return out


func _toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false
