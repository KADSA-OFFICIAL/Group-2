## res://screens/formation/formation.gd
## 편성 화면 — 최대 5인 팀을 구성하고 출격한다.
## HTML showFormation() 대응.

extends Control

const BATTLE_SCENE := preload("res://screens/battle/Battle.tscn")

# ── 상태 ──
var _selected_slot: int = -1          # 현재 활성 슬롯 인덱스 (0-4), -1 = 미선택
var _team: Array[String] = ["", "", "", "", ""]  # 슬롯별 char id ("" = 비어있음)

# ── 노드 참조 (동적 생성 후 보관) ──
var _slot_buttons: Array[Button] = []
var _team_power_label: Label
var _stamina_label: Label
var _roster_grid: GridContainer
var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	# 전투 컨텍스트에서 기존 팀 읽기
	var existing: Array = GameData.battle.get("team", [])
	for i in mini(existing.size(), 5):
		_team[i] = str(existing[i])

	_build_ui()


func _build_ui() -> void:
	# ── 최상위 VBox ──
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_top_bar())
	root.add_child(_build_stage_info())
	root.add_child(_build_slots_section())
	root.add_child(_build_roster_section())
	root.add_child(_build_bottom_bar())

	# ── 토스트 ──
	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.custom_minimum_size = Vector2(400, 48)
	_toast_label.position -= Vector2(200, 24)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_stylebox_override("normal", ThemeFactory.glass_panel(true, 24))
	_toast_label.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	_toast_label.visible = false
	add_child(_toast_label)


# ── 상단 바 ──────────────────────────────────────────────
func _build_top_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var back_btn := Button.new()
	back_btn.text = "← 뒤로"
	back_btn.pressed.connect(func(): ScreenManager.pop())
	hbox.add_child(back_btn)

	var title := Label.new()
	title.text = "편성 — %s" % GameData.battle.get("code", "?")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ThemeFactory.C_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(title)

	# 오른쪽 패딩 균형용 빈 공간
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(spacer)

	return bar


# ── 스테이지 정보 ─────────────────────────────────────────
func _build_stage_info() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var reco: int = GameData.battle.get("reco", 0)
	var my_pw: int = GameData.combat_power

	var reco_lbl := Label.new()
	reco_lbl.text = "권장 전투력: %s" % _comma(reco)
	reco_lbl.add_theme_font_size_override("font_size", 15)
	reco_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM if my_pw >= reco else ThemeFactory.C_BAD)
	hbox.add_child(reco_lbl)

	var sep := Label.new()
	sep.text = "|"
	sep.add_theme_color_override("font_color", ThemeFactory.C_LINE)
	hbox.add_child(sep)

	var my_lbl := Label.new()
	my_lbl.text = "내 전투력: %s" % _comma(my_pw)
	my_lbl.add_theme_font_size_override("font_size", 15)
	my_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOOD if my_pw >= reco else ThemeFactory.C_BAD)
	hbox.add_child(my_lbl)

	return panel


# ── 팀 슬롯 ──────────────────────────────────────────────
func _build_slots_section() -> Control:
	var wrap := VBoxContainer.new()
	wrap.add_theme_constant_override("separation", 6)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 4)
	wrap.add_child(margin)

	var slot_row := HBoxContainer.new()
	slot_row.add_theme_constant_override("separation", 8)
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(slot_row)

	_slot_buttons.clear()
	for i in 5:
		var btn := _make_slot_button(i)
		slot_row.add_child(btn)
		_slot_buttons.append(btn)

	var pw_margin := MarginContainer.new()
	pw_margin.add_theme_constant_override("margin_left", 12)
	pw_margin.add_theme_constant_override("margin_right", 12)
	pw_margin.add_theme_constant_override("margin_top", 0)
	pw_margin.add_theme_constant_override("margin_bottom", 4)
	wrap.add_child(pw_margin)

	_team_power_label = Label.new()
	_team_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_team_power_label.add_theme_font_size_override("font_size", 15)
	_team_power_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	pw_margin.add_child(_team_power_label)
	_refresh_team_power()

	return wrap


func _make_slot_button(index: int) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 80)
	btn.add_theme_stylebox_override("normal", ThemeFactory.glass_panel(false, 16))
	btn.add_theme_stylebox_override("hover", ThemeFactory.glass_panel(true, 16))
	btn.add_theme_stylebox_override("pressed", ThemeFactory.glass_panel(true, 16))
	btn.pressed.connect(_on_slot_pressed.bind(index))
	_update_slot_button(btn, index)
	return btn


func _update_slot_button(btn: Button, index: int) -> void:
	var char_id: String = _team[index]
	if char_id == "":
		btn.text = "[ + ]"
		btn.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
		# 활성 슬롯 강조
		if _selected_slot == index:
			btn.add_theme_stylebox_override("normal", ThemeFactory.accent_box(16))
		else:
			btn.add_theme_stylebox_override("normal", ThemeFactory.glass_panel(false, 16))
	else:
		var ch := _find_char(char_id)
		if ch.is_empty():
			btn.text = "[ + ]"
			return
		var icon := GameData.role_icon(ch.get("role", ""))
		btn.text = "%s\n%s\n%s" % [icon, ch.get("n", "?"), _comma(int(ch.get("pw", 0)))]
		btn.add_theme_color_override("font_color", ThemeFactory.C_INK)
		if _selected_slot == index:
			btn.add_theme_stylebox_override("normal", ThemeFactory.accent_box(16))
		else:
			btn.add_theme_stylebox_override("normal", ThemeFactory.glass_panel(true, 16))


func _on_slot_pressed(index: int) -> void:
	if _team[index] != "":
		# 이미 배치된 캐릭터 → 해제
		_team[index] = ""
		_selected_slot = index
	else:
		# 빈 슬롯 → 선택 활성화
		_selected_slot = index
	_refresh_all_slots()
	_refresh_roster()
	_refresh_team_power()


func _refresh_all_slots() -> void:
	for i in 5:
		_update_slot_button(_slot_buttons[i], i)


func _refresh_team_power() -> void:
	var total := 0
	for cid in _team:
		if cid != "":
			var ch := _find_char(cid)
			total += int(ch.get("pw", 0))
	_team_power_label.text = "팀 전투력: %s" % _comma(total)


# ── 로스터 그리드 ─────────────────────────────────────────
func _build_roster_section() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	scroll.add_child(margin)

	_roster_grid = GridContainer.new()
	_roster_grid.columns = 4
	_roster_grid.add_theme_constant_override("h_separation", 8)
	_roster_grid.add_theme_constant_override("v_separation", 8)
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(_roster_grid)

	_refresh_roster()
	return scroll


func _refresh_roster() -> void:
	for c in _roster_grid.get_children():
		c.queue_free()

	for ch in GameData.roster:
		var card := _make_char_card(ch)
		_roster_grid.add_child(card)


func _make_char_card(ch: Dictionary) -> Control:
	var char_id: String = ch.get("id", "")
	var r: int = ch.get("r", 1)
	var in_team: bool = _team.has(char_id)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 96)

	# 레어도에 따른 배경색
	var box := ThemeFactory.glass_panel(in_team, 14)
	if r == 3:
		box.bg_color = Color(ThemeFactory.C_PINK.r, ThemeFactory.C_PINK.g, ThemeFactory.C_PINK.b, 0.18)
		box.border_color = ThemeFactory.C_PINK
	elif r == 2:
		box.bg_color = Color(ThemeFactory.C_CYAN.r, ThemeFactory.C_CYAN.g, ThemeFactory.C_CYAN.b, 0.18)
		box.border_color = ThemeFactory.C_CYAN
	else:
		box.bg_color = ThemeFactory.C_BG2

	if in_team:
		box.border_color = ThemeFactory.C_GOLD
		box.set_border_width_all(3)

	panel.add_theme_stylebox_override("panel", box)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# 역할 아이콘 + 이름
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 4)
	vbox.add_child(header)

	var role_lbl := Label.new()
	role_lbl.text = GameData.role_icon(ch.get("role", ""))
	role_lbl.add_theme_font_size_override("font_size", 20)
	header.add_child(role_lbl)

	var name_lbl := Label.new()
	name_lbl.text = ch.get("n", "?")
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_lbl)

	# 레벨
	var lv_lbl := Label.new()
	lv_lbl.text = "Lv.%d" % int(ch.get("lv", 1))
	lv_lbl.add_theme_font_size_override("font_size", 13)
	lv_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	vbox.add_child(lv_lbl)

	# 전투력
	var pw_lbl := Label.new()
	pw_lbl.text = "%s" % _comma(int(ch.get("pw", 0)))
	pw_lbl.add_theme_font_size_override("font_size", 14)
	pw_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	vbox.add_child(pw_lbl)

	# 별
	var star_lbl := Label.new()
	star_lbl.text = GameData.star_label(r)
	star_lbl.add_theme_font_size_override("font_size", 13)
	star_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	vbox.add_child(star_lbl)

	# 클릭 처리용 Button (투명, 패널 위에 덮음)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.mouse_filter = Control.MOUSE_FILTER_PASS
	# StyleBox 를 완전 투명하게
	var invisible := StyleBoxFlat.new()
	invisible.bg_color = Color(0, 0, 0, 0)
	btn.add_theme_stylebox_override("normal", invisible)
	btn.add_theme_stylebox_override("hover", invisible)
	btn.add_theme_stylebox_override("pressed", invisible)
	btn.pressed.connect(_on_char_card_pressed.bind(char_id))
	panel.add_child(btn)

	return panel


func _on_char_card_pressed(char_id: String) -> void:
	if _team.has(char_id):
		# 이미 팀에 있으면 제거
		var idx := _team.find(char_id)
		_team[idx] = ""
	else:
		# 빈 슬롯에 배치
		if _selected_slot >= 0 and _team[_selected_slot] == "":
			_team[_selected_slot] = char_id
			# 다음 빈 슬롯으로 자동 이동
			_selected_slot = _next_empty_slot()
		else:
			# 슬롯 미선택이거나 선택된 슬롯이 꽉 찬 경우 → 첫 번째 빈 슬롯에 넣기
			var empty := _next_empty_slot()
			if empty >= 0:
				_team[empty] = char_id
				_selected_slot = _next_empty_slot()
			else:
				_toast("팀이 가득 찼어!")
				return

	_refresh_all_slots()
	_refresh_roster()
	_refresh_team_power()


func _next_empty_slot() -> int:
	for i in 5:
		if _team[i] == "":
			return i
	return -1


# ── 하단 바 ──────────────────────────────────────────────
func _build_bottom_bar() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	bar.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	_stamina_label = Label.new()
	_stamina_label.text = "⚡ 기력 %s" % GameData.stamina_text()
	_stamina_label.add_theme_font_size_override("font_size", 17)
	_stamina_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	hbox.add_child(_stamina_label)

	var deploy_btn := Button.new()
	deploy_btn.text = "▶ 출격"
	deploy_btn.custom_minimum_size = Vector2(160, 52)
	deploy_btn.add_theme_stylebox_override("normal", ThemeFactory.cta_box())
	deploy_btn.add_theme_stylebox_override("hover", ThemeFactory.cta_box())
	deploy_btn.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
	deploy_btn.add_theme_font_size_override("font_size", 20)
	deploy_btn.pressed.connect(_on_deploy)
	hbox.add_child(deploy_btn)

	return bar


func _on_deploy() -> void:
	# 팀에 최소 1명 있는지 확인
	var filled: Array[String] = []
	for cid in _team:
		if cid != "":
			filled.append(cid)

	if filled.is_empty():
		_toast("최소 1명 선택")
		return

	# GameData 에 팀 저장
	GameData.battle["team"] = filled
	var total := 0
	for cid in filled:
		var ch := _find_char(cid)
		total += int(ch.get("pw", 0))
	GameData.battle["team_power"] = total

	ScreenManager.push(BATTLE_SCENE)


# ── 유틸 ─────────────────────────────────────────────────
func _find_char(char_id: String) -> Dictionary:
	for ch in GameData.roster:
		if ch.get("id", "") == char_id:
			return ch
	return {}


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
