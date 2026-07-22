## res://screens/characters/characters.gd
## 캐릭터 관리 화면. 로스터 그리드 + 우측 상세 패널.
## 데이터 출처(단일 원천)는 CharacterDatabase(캐릭터 정의) + CharacterData/PlayerStats(스탯)이다.
## 레벨/랭크/조각 등 성장·가챠 진행 필드는 아직 기초 시스템에 없으므로 표시하지 않는다.
## (성장 필드는 CharacterData 후속 이슈에서 추가 예정 — 그때 이 화면도 확장한다.)

extends Control

# ── 내부 상태 ──
var _ids: Array = []                       # CharacterDatabase.get_all_ids()
var _selected_id: StringName = &""
var _detail_panel: PanelContainer
var _detail_vbox: VBoxContainer
var _title_label: Label
var _gold_label: Label
var _gems_label: Label
var _toast_label: Label
var _toast_timer: SceneTreeTimer
var _card_nodes: Dictionary = {}           # id(String) -> PanelContainer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_ids = CharacterDatabase.get_all_ids()
	_build_ui()
	_toast_label.visible = false


# 역할 아이콘 (CharacterData.Role 기준)
func _role_icon(role: int) -> String:
	match role:
		CharacterData.Role.MELEE_DEALER:  return "⚔"
		CharacterData.Role.RANGED_DEALER: return "🏹"
		CharacterData.Role.BUFFER:        return "💫"
	return "?"


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

	# 통화 변경 구독 (재화는 CurrencySystem 단일 원천 → GameData 프록시)
	GameData.currency_changed.connect(func(_k, _a):
		_gold_label.text = "🪙 %s" % _comma(GameData.gold)
		_gems_label.text = "💎 %s" % _comma(GameData.gems)
	)


func _make_title() -> String:
	return "캐릭터 — %d명 보유 (CharacterDatabase)" % CharacterDatabase.get_count()


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
	if _ids.is_empty():
		var empty := Label.new()
		empty.text = "등록된 캐릭터가 없습니다.\n(data/characters/*.tres 추가 시 표시됩니다)"
		empty.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
		grid.add_child(empty)
		return

	for id in _ids:
		var card := _make_char_card(id)
		grid.add_child(card)
		_card_nodes[String(id)] = card


func _make_char_card(id: StringName) -> PanelContainer:
	var cd: CharacterData = CharacterDatabase.get_character(id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(100, 120)

	var sb := ThemeFactory.glass_panel(false, 14)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_color = ThemeFactory.C_LINE
	sb.set_border_width_all(1)
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
	role_badge.text = _role_icon(cd.role) if cd else "?"
	role_badge.add_theme_font_size_override("font_size", 12)
	badge_row.add_child(role_badge)

	# 초상화 (역할 이모지 크게)
	var portrait_lbl := Label.new()
	portrait_lbl.text = _role_icon(cd.role) if cd else "?"
	portrait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_lbl.add_theme_font_size_override("font_size", 36)
	vbox.add_child(portrait_lbl)

	# 이름
	var name_lbl := Label.new()
	name_lbl.text = cd.display_name if cd else String(id)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)

	# 역할 이름
	var role_lbl := Label.new()
	role_lbl.text = cd.get_role_name() if cd else "-"
	role_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	vbox.add_child(role_lbl)

	# 클릭 감지용 Button (투명 오버레이)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.text = ""
	btn.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.pressed.connect(_on_card_pressed.bind(id))
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


func _show_detail_char(id: StringName) -> void:
	_clear_detail()
	var cd: CharacterData = CharacterDatabase.get_character(id)
	if cd == null:
		_show_detail_empty()
		return
	var ps: PlayerStats = cd.get_stats()

	# ── 상단 스크롤 가능 영역 ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_vbox.add_child(scroll)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	# 초상화 영역 (좌: 큰 초상화 | 우: 이름/역할)
	var portrait_row := HBoxContainer.new()
	portrait_row.add_theme_constant_override("separation", 12)
	inner.add_child(portrait_row)

	var portrait_panel := PanelContainer.new()
	portrait_panel.custom_minimum_size = Vector2(80, 90)
	portrait_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))
	portrait_row.add_child(portrait_panel)

	var portrait_lbl := Label.new()
	portrait_lbl.text = _role_icon(cd.role)
	portrait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_lbl.add_theme_font_size_override("font_size", 44)
	portrait_panel.add_child(portrait_lbl)

	var name_vbox := VBoxContainer.new()
	name_vbox.add_theme_constant_override("separation", 4)
	name_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	portrait_row.add_child(name_vbox)

	var name_lbl := Label.new()
	name_lbl.text = cd.display_name
	name_lbl.add_theme_font_size_override("font_size", 20)
	name_vbox.add_child(name_lbl)

	# 역할 배지
	var role_hbox := HBoxContainer.new()
	role_hbox.add_theme_constant_override("separation", 4)
	name_vbox.add_child(role_hbox)
	var role_chip := PanelContainer.new()
	role_chip.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 12))
	role_hbox.add_child(role_chip)
	var role_lbl := Label.new()
	role_lbl.text = "%s %s" % [_role_icon(cd.role), cd.get_role_name()]
	role_lbl.add_theme_font_size_override("font_size", 13)
	role_chip.add_child(role_lbl)

	# ── 스탯 박스 (PlayerStats 파생값) ──
	var stat_panel := PanelContainer.new()
	var stat_sb := ThemeFactory.glass_panel(false, 14)
	stat_sb.content_margin_top = 10
	stat_sb.content_margin_bottom = 10
	stat_panel.add_theme_stylebox_override("panel", stat_sb)
	inner.add_child(stat_panel)

	var stat_vbox := VBoxContainer.new()
	stat_vbox.add_theme_constant_override("separation", 5)
	stat_panel.add_child(stat_vbox)

	_add_stat_row(stat_vbox, "HP", _comma(ps.get_max_hp()), ThemeFactory.C_GOOD)
	_add_stat_row(stat_vbox, "물리 공격", _comma(ps.get_physical_attack()), ThemeFactory.C_PINK)
	_add_stat_row(stat_vbox, "물리 방어", _comma(ps.get_physical_defense()), ThemeFactory.C_CYAN)
	_add_stat_row(stat_vbox, "마법 방어", _comma(ps.get_magic_defense()), ThemeFactory.C_CYAN)
	_add_stat_row(stat_vbox, "신앙", _comma(ps.faith), ThemeFactory.C_AMBER)

	# ── 설명 ──
	if cd.description != "":
		var desc_sep := HSeparator.new()
		inner.add_child(desc_sep)
		var desc := Label.new()
		desc.text = cd.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
		inner.add_child(desc)


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
func _on_card_pressed(id: StringName) -> void:
	_selected_id = id
	_refresh_card_highlights()
	_show_detail_char(id)


func _refresh_card_highlights() -> void:
	for key in _card_nodes:
		var card: PanelContainer = _card_nodes[key]
		var selected: bool = (key == String(_selected_id))
		var sb := ThemeFactory.glass_panel(selected, 14)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		if selected:
			sb.border_color = ThemeFactory.C_AMBER
			sb.set_border_width_all(4)
		else:
			sb.border_color = ThemeFactory.C_LINE
			sb.set_border_width_all(1)
		card.add_theme_stylebox_override("panel", sb)


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
