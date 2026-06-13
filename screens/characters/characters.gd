## res://screens/characters/characters.gd
## 캐릭터 관리 화면. 로스터 그리드 + 우측 상세/강화/돌파 패널.
## 모든 UI 는 _ready() 에서 코드로 빌드.

extends Control

# ── 내부 상태 ──
var _selected_index: int = -1
var _detail_panel: PanelContainer
var _detail_vbox: VBoxContainer
var _title_label: Label
var _toast_label: Label
var _toast_timer: SceneTreeTimer
var _card_nodes: Array[PanelContainer] = []


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_build_ui()
	_toast_label.visible = false


# ─────────────────────────────────────────────
# UI 빌드
# ─────────────────────────────────────────────
func _build_ui() -> void:
	# 루트 VBox: 상단바 + 콘텐츠
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	_build_top_bar(root_vbox)
	_build_content(root_vbox)
	_build_toast()


func _build_top_bar(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.custom_minimum_size = Vector2(0, 64)
	parent.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# 뒤로 버튼
	var back := Button.new()
	back.text = "← 메인"
	back.pressed.connect(func(): ScreenManager.pop())
	hbox.add_child(back)

	# 제목 (나중에 갱신)
	_title_label = Label.new()
	_title_label.text = _make_title()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(_title_label)


func _make_title() -> String:
	return "캐릭터 — %d명 보유 · 총 전투력 %s" % [
		GameData.roster.size(),
		_comma(GameData.total_power())
	]


func _build_content(parent: Container) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)

	_build_roster_panel(hbox)
	_build_detail_panel(hbox)


# ── 왼쪽: 스크롤 가능한 그리드 ──
func _build_roster_panel(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 0.6
	parent.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	_card_nodes.clear()
	for i in GameData.roster.size():
		var card := _make_char_card(GameData.roster[i], i)
		grid.add_child(card)
		_card_nodes.append(card)


func _make_char_card(ch: Dictionary, idx: int) -> PanelContainer:
	var r: int = ch.get("r", 1)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 120)

	var sb := ThemeFactory.glass_panel(false, 14)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	match r:
		3: sb.border_color = ThemeFactory.C_PINK; sb.set_border_width_all(3)
		2: sb.border_color = ThemeFactory.C_CYAN; sb.set_border_width_all(2)
		_: sb.border_color = ThemeFactory.C_LINE; sb.set_border_width_all(1)
	card.add_theme_stylebox_override("panel", sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	card.add_child(vbox)

	# 역할 아이콘 + 이름
	var name_lbl := Label.new()
	name_lbl.text = "%s %s" % [GameData.role_icon(ch.get("role", "")), ch.get("n", "?")]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	# Lv
	var lv_lbl := Label.new()
	lv_lbl.text = "Lv.%d" % ch.get("lv", 1)
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_font_size_override("font_size", 12)
	lv_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM if true else ThemeFactory.C_INK)
	vbox.add_child(lv_lbl)

	# 전투력
	var pw_lbl := Label.new()
	pw_lbl.text = _comma(ch.get("pw", 0))
	pw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pw_lbl.add_theme_font_size_override("font_size", 12)
	pw_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	vbox.add_child(pw_lbl)

	# 별 등급
	var star_lbl := Label.new()
	star_lbl.text = GameData.star_label(r)
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", 13)
	match r:
		3: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
		2: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
		_: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_LINE)
	vbox.add_child(star_lbl)

	# 클릭 감지용 Button (투명 오버레이)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.text = ""
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_on_card_pressed.bind(idx))
	card.add_child(btn)

	return card


# ── 오른쪽: 상세 패널 ──
func _build_detail_panel(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 0.4
	parent.add_child(margin)

	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 22))
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_detail_panel)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.add_theme_constant_override("separation", 10)
	_detail_panel.add_child(_detail_vbox)

	_show_detail_empty()


func _show_detail_empty() -> void:
	_clear_detail()
	var lbl := Label.new()
	lbl.text = "캐릭터를 선택하세요"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM if true else ThemeFactory.C_INK)
	_detail_vbox.add_child(lbl)


func _show_detail_char(idx: int) -> void:
	_clear_detail()
	var ch: Dictionary = GameData.roster[idx]
	var r: int = ch.get("r", 1)

	# 역할 이모지 (큰)
	var icon_lbl := Label.new()
	icon_lbl.text = GameData.role_icon(ch.get("role", ""))
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 70)
	_detail_vbox.add_child(icon_lbl)

	# 이름
	var name_lbl := Label.new()
	name_lbl.text = ch.get("n", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	_detail_vbox.add_child(name_lbl)

	# 별 등급
	var star_lbl := Label.new()
	star_lbl.text = GameData.star_label(r)
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", 18)
	match r:
		3: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
		2: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
		_: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_LINE)
	_detail_vbox.add_child(star_lbl)

	# 구분선
	var sep := HSeparator.new()
	_detail_vbox.add_child(sep)

	# Lv / 역할 / 무기 행
	_add_info_row("레벨", "Lv.%d" % ch.get("lv", 1))
	_add_info_row("역할", ch.get("role", "?"))
	_add_info_row("무기", ch.get("weapon", "?"))
	_add_info_row("조각", "%d / 30" % ch.get("shards", 0))

	# 전투력
	var pw_lbl := Label.new()
	pw_lbl.text = "전투력: %s" % _comma(ch.get("pw", 0))
	pw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pw_lbl.add_theme_font_size_override("font_size", 16)
	pw_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	_detail_vbox.add_child(pw_lbl)

	var sep2 := HSeparator.new()
	_detail_vbox.add_child(sep2)

	# 강화 버튼
	var lv_cost := ch.get("lv", 1) * 500
	var upgrade_btn := Button.new()
	upgrade_btn.text = "강화하기 (🪙 %s)" % _comma(lv_cost)
	upgrade_btn.add_theme_stylebox_override("normal", ThemeFactory.accent_box(14))
	upgrade_btn.pressed.connect(_on_upgrade.bind(idx))
	_detail_vbox.add_child(upgrade_btn)

	# 돌파 버튼
	var promote_btn := Button.new()
	promote_btn.text = "돌파 (🧩 30 조각)"
	if r >= 3:
		promote_btn.disabled = true
		promote_btn.text = "돌파 (최대 등급)"
	else:
		promote_btn.pressed.connect(_on_promote.bind(idx))
	var promote_sb := ThemeFactory.glass_panel(false, 14)
	promote_sb.border_color = ThemeFactory.C_GOLD
	promote_btn.add_theme_stylebox_override("normal", promote_sb)
	_detail_vbox.add_child(promote_btn)


func _add_info_row(label_text: String, value_text: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_detail_vbox.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM if true else ThemeFactory.C_INK)
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	hbox.add_child(val)


func _clear_detail() -> void:
	for child in _detail_vbox.get_children():
		child.queue_free()


# ── 토스트 ──
func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -200.0
	_toast_label.offset_top = -24.0
	_toast_label.offset_right = 200.0
	_toast_label.offset_bottom = 24.0
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.visible = false
	var toast_sb := ThemeFactory.glass_panel(true, 20)
	toast_sb.bg_color = Color(0.08, 0.05, 0.18, 0.92)
	_toast_label.add_theme_stylebox_override("normal", toast_sb)
	_toast_label.add_theme_font_size_override("font_size", 16)
	add_child(_toast_label)


# ─────────────────────────────────────────────
# 이벤트 핸들러
# ─────────────────────────────────────────────
func _on_card_pressed(idx: int) -> void:
	_selected_index = idx
	_refresh_card_highlights()
	_show_detail_char(idx)


func _refresh_card_highlights() -> void:
	for i in _card_nodes.size():
		var card := _card_nodes[i]
		var ch: Dictionary = GameData.roster[i]
		var r: int = ch.get("r", 1)
		var sb := ThemeFactory.glass_panel(i == _selected_index, 14)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		match r:
			3: sb.border_color = ThemeFactory.C_PINK; sb.set_border_width_all(3 if i != _selected_index else 4)
			2: sb.border_color = ThemeFactory.C_CYAN; sb.set_border_width_all(2 if i != _selected_index else 4)
			_: sb.border_color = ThemeFactory.C_LINE; sb.set_border_width_all(1 if i != _selected_index else 4)
		if i == _selected_index:
			sb.border_color = ThemeFactory.C_AMBER
		card.add_theme_stylebox_override("panel", sb)


func _on_upgrade(idx: int) -> void:
	var ch: Dictionary = GameData.roster[idx]
	var cost := ch.get("lv", 1) * 500
	if GameData.gold < cost:
		_toast("🪙 골드 부족 (%s 필요)" % _comma(cost))
		return
	GameData.add_currency("gold", -cost)
	ch["lv"] = ch.get("lv", 1) + 3
	ch["pw"] = ch.get("pw", 0) + 300
	GameData.stats["levelups"] = GameData.stats.get("levelups", 0) + 1
	_title_label.text = _make_title()
	_show_detail_char(idx)
	_refresh_card_at(idx)
	_toast("✅ %s 강화 완료 → Lv.%d" % [ch.get("n", "?"), ch.get("lv", 1)])


func _on_promote(idx: int) -> void:
	var ch: Dictionary = GameData.roster[idx]
	if ch.get("shards", 0) < 30:
		_toast("🧩 조각 부족 (%d / 30)" % ch.get("shards", 0))
		return
	if ch.get("r", 1) >= 3:
		_toast("이미 최고 등급입니다")
		return
	ch["shards"] = ch.get("shards", 0) - 30
	ch["r"] = ch.get("r", 1) + 1
	var new_pw := int(ch.get("pw", 0) * 1.20)
	ch["pw"] = new_pw
	GameData.stats["promos"] = GameData.stats.get("promos", 0) + 1
	_title_label.text = _make_title()
	_show_detail_char(idx)
	_refresh_card_at(idx)
	_toast("🌟 %s 돌파 → %s" % [ch.get("n", "?"), GameData.star_label(ch.get("r", 1))])


func _refresh_card_at(idx: int) -> void:
	if idx < 0 or idx >= _card_nodes.size():
		return
	var card := _card_nodes[idx]
	var ch: Dictionary = GameData.roster[idx]
	var r: int = ch.get("r", 1)

	# 카드 내부 라벨 갱신 (VBoxContainer 의 자식들)
	var vbox: VBoxContainer = null
	for child in card.get_children():
		if child is VBoxContainer:
			vbox = child
			break
	if vbox == null:
		return
	var children := vbox.get_children()
	if children.size() >= 4:
		(children[0] as Label).text = "%s %s" % [GameData.role_icon(ch.get("role", "")), ch.get("n", "?")]
		(children[1] as Label).text = "Lv.%d" % ch.get("lv", 1)
		(children[2] as Label).text = _comma(ch.get("pw", 0))
		(children[3] as Label).text = GameData.star_label(r)


# ─────────────────────────────────────────────
# 유틸
# ─────────────────────────────────────────────
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
	_toast_label.text = "  %s  " % msg
	_toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false


# ThemeFactory 에 없는 상수를 로컬에서 참조하기 위한 프록시
var C_INK_DIM := ThemeFactory.C_INK_DIM
