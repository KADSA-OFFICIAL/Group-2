## res://screens/characters/characters.gd
## 캐릭터 관리 화면. 로스터 그리드 + 우측 상세/강화/돌파 패널.
## 모든 UI 는 _ready() 에서 코드로 빌드.

extends Control

# ── 내부 상태 ──
var _selected_index: int = -1
var _detail_panel: PanelContainer
var _detail_vbox: VBoxContainer
var _title_label: Label
var _gold_label: Label
var _gems_label: Label
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
# HP/ATK 계산 (HTML 공식 그대로)
# ─────────────────────────────────────────────
func _calc_hp(ch: Dictionary) -> int:
	var base_hp: int
	match ch.get("role", ""):
		"공격": base_hp = 160
		"방어": base_hp = 310
		_:      base_hp = 210  # 지원
	var lv: int = ch.get("lv", 1)
	var r:  int = ch.get("r",  1)
	return roundi(base_hp * (1.0 + lv / 130.0) * (1.0 + r * 0.08))


func _calc_atk(ch: Dictionary) -> int:
	var base_atk: int
	match ch.get("role", ""):
		"공격": base_atk = 13
		"방어": base_atk = 30
		_:      base_atk = 17  # 지원
	var lv: int = ch.get("lv", 1)
	var r:  int = ch.get("r",  1)
	return roundi(base_atk * (1.0 + lv / 130.0) * (1.0 + r * 0.08))


func _lv_cost(ch: Dictionary) -> int:
	return 600 * ch.get("lv", 1)


func _promo_cost(ch: Dictionary) -> int:
	return 15 * ch.get("r", 1)


func _pw_gain_per_lv(ch: Dictionary) -> int:
	return 160 + ch.get("r", 1) * 30


# ─────────────────────────────────────────────
# UI 빌드
# ─────────────────────────────────────────────
func _build_ui() -> void:
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

	# 제목
	_title_label = Label.new()
	_title_label.text = _make_title()
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(_title_label)

	# 골드 표시
	var gold_pill := PanelContainer.new()
	gold_pill.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))
	hbox.add_child(gold_pill)
	_gold_label = Label.new()
	_gold_label.text = "🪙 %s" % _comma(GameData.gold)
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	gold_pill.add_child(_gold_label)

	# 보석 표시
	var gem_pill := PanelContainer.new()
	gem_pill.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))
	hbox.add_child(gem_pill)
	_gems_label = Label.new()
	_gems_label.text = "💎 %s" % _comma(GameData.gems)
	_gems_label.add_theme_font_size_override("font_size", 14)
	_gems_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	gem_pill.add_child(_gems_label)

	# 통화 변경 구독
	GameData.currency_changed.connect(func(_k, _a):
		_gold_label.text = "🪙 %s" % _comma(GameData.gold)
		_gems_label.text = "💎 %s" % _comma(GameData.gems)
	)


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
	margin.size_flags_stretch_ratio = 0.58
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
	card.custom_minimum_size = Vector2(100, 130)

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

	# 역할 배지 (오른쪽 정렬)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 0)
	vbox.add_child(badge_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_row.add_child(spacer)
	var role_badge := Label.new()
	role_badge.text = GameData.role_icon(ch.get("role", ""))
	role_badge.add_theme_font_size_override("font_size", 12)
	badge_row.add_child(role_badge)

	# 초상화 (색깔 원 대신 역할 이모지 크게)
	var portrait_lbl := Label.new()
	portrait_lbl.text = GameData.role_icon(ch.get("role", ""))
	portrait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_lbl.add_theme_font_size_override("font_size", 36)
	vbox.add_child(portrait_lbl)

	# 이름
	var name_lbl := Label.new()
	name_lbl.text = ch.get("n", "?")
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	# 별 등급
	var star_lbl := Label.new()
	star_lbl.text = GameData.star_label(r)
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	star_lbl.add_theme_font_size_override("font_size", 12)
	match r:
		3: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
		2: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
		_: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_LINE)
	vbox.add_child(star_lbl)

	# Lv
	var lv_lbl := Label.new()
	lv_lbl.text = "Lv.%d" % ch.get("lv", 1)
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_font_size_override("font_size", 11)
	lv_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	vbox.add_child(lv_lbl)

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
	margin.size_flags_stretch_ratio = 0.42
	parent.add_child(margin)

	_detail_panel = PanelContainer.new()
	_detail_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 22))
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(_detail_panel)

	_detail_vbox = VBoxContainer.new()
	_detail_vbox.add_theme_constant_override("separation", 8)
	_detail_panel.add_child(_detail_vbox)

	_show_detail_empty()


func _show_detail_empty() -> void:
	_clear_detail()
	var lbl := Label.new()
	lbl.text = "캐릭터를 선택하세요"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	_detail_vbox.add_child(lbl)


func _show_detail_char(idx: int) -> void:
	_clear_detail()
	var ch: Dictionary = GameData.roster[idx]
	var r: int = ch.get("r", 1)
	var lv: int = ch.get("lv", 1)

	# ── 상단 스크롤 가능 영역 ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	# 초상화 영역 (좌: 큰 초상화 | 우: 이름/별/역할)
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 12)
	inner.add_child(portrait_row)

	# 큰 초상화 컨테이너
	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(80, 90)
	var port_sb := ThemeFactory.glass_panel(false, 16)
	portrait_panel.add_theme_stylebox_override("panel", port_sb)
	portrait_row.add_child(portrait_panel)

	var portrait_lbl := Label.new()
	portrait_lbl.text = GameData.role_icon(ch.get("role", ""))
	portrait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_lbl.add_theme_font_size_override("font_size", 44)
	portrait_panel.add_child(portrait_lbl)

	# 이름/별/역할/조각 세로 블록
	var name_vbox := VBoxContainer.new()
	name_vbox.add_theme_constant_override("separation", 4)
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_row.add_child(name_vbox)

	var name_lbl := Label.new()
	name_lbl.text = ch.get("n", "?")
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_vbox.add_child(name_lbl)

	var star_lbl := Label.new()
	star_lbl.text = GameData.star_label(r)
	star_lbl.add_theme_font_size_override("font_size", 16)
	match r:
		3: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
		2: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
		_: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_LINE)
	name_vbox.add_child(star_lbl)

	# 역할 배지
	var role_hbox := HBoxContainer.new()
	role_hbox.add_theme_constant_override("separation", 4)
	name_vbox.add_child(role_hbox)
	var role_chip := PanelContainer.new()
	var role_sb := ThemeFactory.pill(ThemeFactory.C_BG2, 12)
	role_chip.add_theme_stylebox_override("panel", role_sb)
	role_hbox.add_child(role_chip)
	var role_lbl := Label.new()
	role_lbl.text = "%s %s" % [GameData.role_icon(ch.get("role", "")), ch.get("role", "?")]
	role_lbl.add_theme_font_size_override("font_size", 13)
	role_chip.add_child(role_lbl)

	# 조각 수
	var shard_lbl := Label.new()
	shard_lbl.text = "🧩 조각: %d개" % ch.get("shards", 0)
	shard_lbl.add_theme_font_size_override("font_size", 13)
	shard_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	name_vbox.add_child(shard_lbl)

	# ── 스탯 박스 ──
	var stat_panel := PanelContainer.new()
	var stat_sb := ThemeFactory.glass_panel(false, 14)
	stat_sb.content_margin_top = 10
	stat_sb.content_margin_bottom = 10
	stat_panel.add_theme_stylebox_override("panel", stat_sb)
	inner.add_child(stat_panel)

	var stat_vbox := VBoxContainer.new()
	stat_vbox.add_theme_constant_override("separation", 5)
	stat_panel.add_child(stat_vbox)

	_add_stat_row(stat_vbox, "레벨", "Lv.%d" % lv, ThemeFactory.C_INK)
	_add_stat_row(stat_vbox, "전투력", _comma(ch.get("pw", 0)), ThemeFactory.C_AMBER)
	_add_stat_row(stat_vbox, "HP", _comma(_calc_hp(ch)), ThemeFactory.C_GOOD)
	_add_stat_row(stat_vbox, "ATK", _comma(_calc_atk(ch)), ThemeFactory.C_PINK)
	_add_stat_row(stat_vbox, "무기", ch.get("weapon", "?"), ThemeFactory.C_INK_DIM)

	# ── 강화 버튼 영역 ──
	var btn_sep := HSeparator.new()
	inner.add_child(btn_sep)

	# 강화 (Lv.N) 버튼
	var cost1 := _lv_cost(ch)
	var gain1 := _pw_gain_per_lv(ch)
	var upgrade_btn := Button.new()
	upgrade_btn.text = "강화 (Lv.%d)  🪙 %s  +전투력 %d" % [lv, _comma(cost1), gain1]
	upgrade_btn.custom_minimum_size = Vector2(0, 44)
	upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade_btn.add_theme_font_size_override("font_size", 14)
	var up_sb := ThemeFactory.accent_box(14)
	upgrade_btn.add_theme_stylebox_override("normal", up_sb)
	if GameData.gold < cost1:
		upgrade_btn.disabled = true
	else:
		upgrade_btn.pressed.connect(_on_upgrade.bind(idx))
	inner.add_child(upgrade_btn)

	# 강화 (×10) 버튼
	var cost10 := _calc_10lv_cost(ch)
	var upgrade10_btn := Button.new()
	upgrade10_btn.text = "강화 (×10)  🪙 %s" % _comma(cost10)
	upgrade10_btn.custom_minimum_size = Vector2(0, 44)
	upgrade10_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrade10_btn.add_theme_font_size_override("font_size", 14)
	var up10_sb := ThemeFactory.glass_panel(false, 14)
	up10_sb.border_color = ThemeFactory.C_CYAN
	up10_sb.set_border_width_all(2)
	upgrade10_btn.add_theme_stylebox_override("normal", up10_sb)
	if GameData.gold < cost10:
		upgrade10_btn.disabled = true
	else:
		upgrade10_btn.pressed.connect(_on_upgrade_10.bind(idx))
	inner.add_child(upgrade10_btn)

	# 승급 버튼
	var promo_cost := _promo_cost(ch)
	var promote_btn := Button.new()
	var promo_sb := ThemeFactory.glass_panel(false, 14)
	if r >= 5:
		promote_btn.text = "최대 등급"
		promote_btn.disabled = true
		promo_sb.border_color = ThemeFactory.C_LINE
	else:
		promote_btn.text = "승급  🧩 %d 조각" % promo_cost
		promo_sb.border_color = ThemeFactory.C_GOLD
		promo_sb.set_border_width_all(2)
		if ch.get("shards", 0) < promo_cost:
			promote_btn.disabled = true
		else:
			promote_btn.pressed.connect(_on_promote.bind(idx))
	promote_btn.custom_minimum_size = Vector2(0, 44)
	promote_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	promote_btn.add_theme_font_size_override("font_size", 14)
	promote_btn.add_theme_stylebox_override("normal", promo_sb)
	inner.add_child(promote_btn)


func _calc_10lv_cost(ch: Dictionary) -> int:
	var total := 0
	var lv: int = ch.get("lv", 1)
	for i in 10:
		total += 600 * (lv + i)
	return total


func _add_stat_row(parent: Container, label_text: String, value_text: String, value_color: Color) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	parent.add_child(hbox)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	hbox.add_child(lbl)

	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 14)
	val.add_theme_color_override("font_color", value_color)
	hbox.add_child(val)


func _clear_detail() -> void:
	for child in _detail_vbox.get_children():
		child.queue_free()


# ── 토스트 ──
func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -220.0
	_toast_label.offset_top = -28.0
	_toast_label.offset_right = 220.0
	_toast_label.offset_bottom = 28.0
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.visible = false
	var toast_sb := ThemeFactory.glass_panel(true, 20)
	toast_sb.bg_color = Color(0.08, 0.05, 0.18, 0.92)
	_toast_label.add_theme_stylebox_override("normal", toast_sb)
	_toast_label.add_theme_font_size_override("font_size", 15)
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
	var cost := _lv_cost(ch)
	if GameData.gold < cost:
		_toast("🪙 골드 부족 (%s 필요)" % _comma(cost))
		return
	GameData.add_currency("gold", -cost)
	var gain := _pw_gain_per_lv(ch)
	ch["lv"] = ch.get("lv", 1) + 1
	ch["pw"] = ch.get("pw", 0) + gain
	GameData.stats["levelups"] = GameData.stats.get("levelups", 0) + 1
	_title_label.text = _make_title()
	_show_detail_char(idx)
	_refresh_card_at(idx)
	_toast("✅ %s 강화 완료 → Lv.%d" % [ch.get("n", "?"), ch.get("lv", 1)])


func _on_upgrade_10(idx: int) -> void:
	var ch: Dictionary = GameData.roster[idx]
	var total_cost := _calc_10lv_cost(ch)
	if GameData.gold < total_cost:
		_toast("🪙 골드 부족 (%s 필요)" % _comma(total_cost))
		return
	GameData.add_currency("gold", -total_cost)
	var total_gain := 0
	var r: int = ch.get("r", 1)
	for i in 10:
		total_gain += 160 + r * 30
	ch["lv"] = ch.get("lv", 1) + 10
	ch["pw"] = ch.get("pw", 0) + total_gain
	GameData.stats["levelups"] = GameData.stats.get("levelups", 0) + 10
	_title_label.text = _make_title()
	_show_detail_char(idx)
	_refresh_card_at(idx)
	_toast("✅ %s ×10 강화 완료 → Lv.%d" % [ch.get("n", "?"), ch.get("lv", 1)])


func _on_promote(idx: int) -> void:
	var ch: Dictionary = GameData.roster[idx]
	var cost := _promo_cost(ch)
	if ch.get("shards", 0) < cost:
		_toast("🧩 조각 부족 (%d / %d)" % [ch.get("shards", 0), cost])
		return
	if ch.get("r", 1) >= 5:
		_toast("이미 최고 등급입니다")
		return
	ch["shards"] = ch.get("shards", 0) - cost
	ch["r"] = ch.get("r", 1) + 1
	ch["pw"] = ch.get("pw", 0) + 1500
	GameData.stats["promos"] = GameData.stats.get("promos", 0) + 1
	_title_label.text = _make_title()
	_show_detail_char(idx)
	_refresh_card_at(idx)
	_toast("🌟 %s 승급 → %s" % [ch.get("n", "?"), GameData.star_label(ch.get("r", 1))])


func _refresh_card_at(idx: int) -> void:
	if idx < 0 or idx >= _card_nodes.size():
		return
	# 카드를 완전히 재빌드
	var old_card := _card_nodes[idx]
	var grid := old_card.get_parent()
	var position_in_grid := old_card.get_index()
	old_card.queue_free()
	var new_card := _make_char_card(GameData.roster[idx], idx)
	grid.add_child(new_card)
	grid.move_child(new_card, position_in_grid)
	_card_nodes[idx] = new_card
	_refresh_card_highlights()


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
