## res://screens/missions/missions.gd
## 미션 화면 — 일일 / 주간 / 도전 탭. 모든 UI 는 _ready() 에서 코드로 생성한다.

extends Control

# ── 미션 정의 ──────────────────────────────────────────────────────────────
const DAILY_MISSIONS = [
	{id="d1", ic="⚔️", nm="스테이지 1회 클리어",  goal=1,  rw={k="gems", a=50}},
	{id="d2", ic="🗺️", nm="스테이지 3회 클리어",  goal=3,  rw={k="gold", a=50000}},
	{id="d3", ic="✨",  nm="모집 1회",             goal=1,  rw={k="gems", a=30}},
	{id="d4", ic="📈",  nm="캐릭터 레벨업 1회",    goal=1,  rw={k="gold", a=30000}},
	{id="d5", ic="🎁",  nm="일일 미션 4개 완료",   goal=4,  rw={k="gems", a=100}},
]

const WEEKLY_MISSIONS = [
	{id="w1", ic="⚔️", nm="스테이지 10회 클리어",  goal=10, rw={k="gems", a=300}},
	{id="w2", ic="✨",  nm="모집 10회",             goal=10, rw={k="gems", a=200}},
	{id="w3", ic="📈",  nm="캐릭터 레벨업 20회",    goal=20, rw={k="gold", a=200000}},
]

const ACHIEVE_MISSIONS = [
	{id="a1", ic="🏴",  nm="33-9 클리어",           goal=1,  rw={k="gems", a=100}},
	{id="a2", ic="👑",  nm="챕터 보스 격파 (33-10)", goal=1,  rw={k="gems", a=300}},
	{id="a3", ic="👥",  nm="캐릭터 15명 보유",       goal=15, rw={k="gems", a=150}},
	{id="a4", ic="🌟",  nm="★4 캐릭터 보유",         goal=1,  rw={k="gems", a=200}},
]

# ── 런타임 상태 ───────────────────────────────────────────────────────────
var _current_tab: int = 0          # 0=일일, 1=주간, 2=도전
var _tab_buttons: Array[Button] = []
var _list_root: VBoxContainer

var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_build_ui()
	_switch_tab(0)


# ── UI 빌드 ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	# 상단바
	var topbar := _make_topbar()
	root.add_child(topbar)

	# 탭 버튼
	var tab_row := HBoxContainer.new()
	tab_row.add_theme_constant_override("separation", 8)
	var margin_tabs := MarginContainer.new()
	margin_tabs.add_theme_constant_override("margin_left", 16)
	margin_tabs.add_theme_constant_override("margin_right", 16)
	margin_tabs.add_theme_constant_override("margin_top", 8)
	margin_tabs.add_theme_constant_override("margin_bottom", 4)
	margin_tabs.add_child(tab_row)
	root.add_child(margin_tabs)

	var tab_labels := ["일일", "주간", "도전"]
	for i in tab_labels.size():
		var btn := Button.new()
		btn.text = tab_labels[i]
		btn.custom_minimum_size = Vector2(80, 36)
		btn.pressed.connect(_switch_tab.bind(i))
		tab_row.add_child(btn)
		_tab_buttons.append(btn)

	# 스크롤 영역
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 16)
	scroll_margin.add_theme_constant_override("margin_right", 16)
	scroll_margin.add_theme_constant_override("margin_top", 8)
	scroll_margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(scroll_margin)

	_list_root = VBoxContainer.new()
	_list_root.add_theme_constant_override("separation", 10)
	_list_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_child(_list_root)

	# 토스트
	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -240.0
	_toast_label.offset_top = -24.0
	_toast_label.offset_right = 240.0
	_toast_label.offset_bottom = 24.0
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 15)
	_toast_label.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	_toast_label.visible = false
	add_child(_toast_label)


func _make_topbar() -> MarginContainer:
	var mc := MarginContainer.new()
	mc.add_theme_constant_override("margin_left", 12)
	mc.add_theme_constant_override("margin_right", 12)
	mc.add_theme_constant_override("margin_top", 10)
	mc.add_theme_constant_override("margin_bottom", 10)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	mc.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "← 뒤로"
	back_btn.pressed.connect(func(): ScreenManager.pop())
	hbox.add_child(back_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var title := Label.new()
	title.text = "미션"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ThemeFactory.C_INK)
	hbox.add_child(title)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer2)

	return mc


# ── 탭 전환 ──────────────────────────────────────────────────────────────
func _switch_tab(idx: int) -> void:
	_current_tab = idx
	for i in _tab_buttons.size():
		var btn := _tab_buttons[i]
		if i == idx:
			btn.add_theme_stylebox_override("normal",  ThemeFactory.accent_box(14))
			btn.add_theme_stylebox_override("hover",   ThemeFactory.accent_box(14))
			btn.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(14))
			btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
		else:
			btn.remove_theme_stylebox_override("normal")
			btn.remove_theme_stylebox_override("hover")
			btn.remove_theme_stylebox_override("pressed")
			btn.remove_theme_color_override("font_color")
	_rebuild_list()


func _rebuild_list() -> void:
	for child in _list_root.get_children():
		child.queue_free()

	var missions: Array
	match _current_tab:
		0: missions = DAILY_MISSIONS
		1: missions = WEEKLY_MISSIONS
		2: missions = ACHIEVE_MISSIONS
		_: missions = []

	for m in missions:
		var prog := _get_progress(m)
		var row := _make_mission_row(m, prog)
		_list_root.add_child(row)


# ── 진행도 계산 ──────────────────────────────────────────────────────────
func _get_progress(m: Dictionary) -> int:
	match m.id:
		"d1": return GameData.stats.get("clears", 0)
		"d2": return GameData.stats.get("clears", 0)
		"d3": return GameData.stats.get("pulls", 0)
		"d4": return GameData.stats.get("levelups", 0)
		"d5": return _daily_claimed_count()
		"w1": return GameData.stats.get("clears", 0)
		"w2": return GameData.stats.get("pulls", 0)
		"w3": return GameData.stats.get("levelups", 0)
		"a1": return 1 if GameData.cleared >= 9 else 0
		"a2": return 1 if GameData.cleared >= 10 else 0
		"a3": return GameData.roster.size()
		"a4": return _has_star4()
	return 0


func _daily_claimed_count() -> int:
	var count := 0
	for id in ["d1", "d2", "d3", "d4"]:
		if GameData.mission_claims.get(id, false):
			count += 1
	return count


func _has_star4() -> int:
	for c in GameData.roster:
		if int(c.get("r", 0)) >= 4:
			return 1
	return 0


# ── 미션 행 빌드 ─────────────────────────────────────────────────────────
func _make_mission_row(m: Dictionary, prog: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	# 이름 + 보상 행
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vbox.add_child(top_row)

	var nm_label := Label.new()
	nm_label.text = m.nm
	nm_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm_label.add_theme_font_size_override("font_size", 15)
	top_row.add_child(nm_label)

	# 보상 칩
	var rw: Dictionary = m.rw
	var chip := _make_reward_chip(rw)
	top_row.add_child(chip)

	# 수령 버튼
	var claimed: bool = GameData.mission_claims.get(m.id, false)
	var goal: int = m.goal
	var done: bool = prog >= goal

	var claim_btn := Button.new()
	claim_btn.custom_minimum_size = Vector2(70, 32)
	if claimed:
		claim_btn.text = "완료"
		claim_btn.disabled = true
	elif done:
		claim_btn.text = "수령"
		claim_btn.disabled = false
		claim_btn.add_theme_stylebox_override("normal",  ThemeFactory.accent_box(12))
		claim_btn.add_theme_stylebox_override("hover",   ThemeFactory.accent_box(12))
		claim_btn.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(12))
		claim_btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
	else:
		claim_btn.text = "수령"
		claim_btn.disabled = true
	claim_btn.pressed.connect(_on_claim.bind(m))
	top_row.add_child(claim_btn)

	# 진행 바
	var clamped_prog := mini(prog, goal)
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = goal
	bar.value = clamped_prog
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(bar)

	# 진행 텍스트
	var prog_label := Label.new()
	prog_label.text = "%d / %d" % [clamped_prog, goal]
	prog_label.add_theme_font_size_override("font_size", 12)
	prog_label.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM if not done else ThemeFactory.C_GOOD)
	vbox.add_child(prog_label)

	if claimed:
		panel.modulate = Color(1, 1, 1, 0.45)

	return panel


func _make_reward_chip(rw: Dictionary) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))

	var lbl := Label.new()
	lbl.add_theme_font_size_override("font_size", 13)
	match rw.k:
		"gems":
			lbl.text = "💎×%d" % rw.a
			lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
		"gold":
			lbl.text = "🪙×%d" % _comma(rw.a)
			lbl.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
		"stamina":
			lbl.text = "⚡×%d" % rw.a
			lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		"faction_token":
			lbl.text = "🔮×%d" % rw.a
			lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
		_:
			lbl.text = "%s×%d" % [rw.k, rw.a]
	chip.add_child(lbl)
	return chip


# ── 수령 처리 ─────────────────────────────────────────────────────────────
func _on_claim(m: Dictionary) -> void:
	if GameData.mission_claims.get(m.id, false):
		return
	var prog := _get_progress(m)
	if prog < int(m.goal):
		return
	GameData.mission_claims[m.id] = true
	var rw: Dictionary = m.rw
	GameData.add_currency(rw.k, rw.a)
	var icon := _rw_icon(rw.k)
	_toast("%s %d 수령!" % [icon, rw.a])
	_rebuild_list()


func _rw_icon(kind: String) -> String:
	match kind:
		"gems":          return "💎"
		"gold":          return "🪙"
		"stamina":       return "⚡"
		"faction_token": return "🔮"
	return kind


# ── 유틸 ─────────────────────────────────────────────────────────────────
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
