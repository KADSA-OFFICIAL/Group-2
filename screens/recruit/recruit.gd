## res://screens/recruit/recruit.gd
## 모집(가챠) 화면. 픽업 배너 · 연속 보장(pity) · 1회/10회 뽑기 · 결과 오버레이.
## 모든 UI 는 _ready() 에서 코드로 빌드.

extends Control

# ── 연속 뽑기 카운터 (씬 수명 동안 유지) ──
var _pity_count: int = 0

# ── UI 참조 ──
var _pity_label: Label
var _pull_history_label: Label
var _results_overlay: Control
var _results_grid: GridContainer
var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_build_ui()
	_toast_label.visible = false
	_results_overlay.visible = false


# ─────────────────────────────────────────────
# UI 빌드
# ─────────────────────────────────────────────
func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 12)
	add_child(root_vbox)

	_build_top_bar(root_vbox)
	_build_banner(root_vbox)
	_build_pity_row(root_vbox)
	_build_pull_buttons(root_vbox)
	_build_history_chip(root_vbox)
	_build_results_overlay()
	_build_toast()


func _build_top_bar(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 0)
	parent.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var back := Button.new()
	back.text = "← 메인"
	back.pressed.connect(func(): ScreenManager.pop())
	hbox.add_child(back)

	var title := Label.new()
	title.text = "모집소"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(title)

	# 보석 표시
	var gem_pill := PanelContainer.new()
	gem_pill.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))
	hbox.add_child(gem_pill)
	var gem_lbl := Label.new()
	gem_lbl.name = "GemLabel"
	gem_lbl.text = "💎 %s" % _comma(GameData.gems)
	gem_lbl.add_theme_font_size_override("font_size", 15)
	gem_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	gem_pill.add_child(gem_lbl)
	GameData.currency_changed.connect(func(kind, _a):
		if kind == "gems":
			gem_lbl.text = "💎 %s" % _comma(GameData.gems)
	)


func _build_banner(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	parent.add_child(margin)

	var banner := PanelContainer.new()
	banner.custom_minimum_size = Vector2(0, 140)
	# 핑크/분홍 계열 그라데이션 배경
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("4a1040")
	sb.set_corner_radius_all(20)
	sb.border_color = ThemeFactory.C_PINK
	sb.set_border_width_all(2)
	sb.shadow_color = Color(ThemeFactory.C_PINK.r, ThemeFactory.C_PINK.g, ThemeFactory.C_PINK.b, 0.35)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	banner.add_theme_stylebox_override("panel", sb)
	margin.add_child(banner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	banner.add_child(vbox)

	var pickup_lbl := Label.new()
	pickup_lbl.text = "★3 픽업 — 루멘"
	pickup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_lbl.add_theme_font_size_override("font_size", 26)
	pickup_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	vbox.add_child(pickup_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "새벽의 이정표"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 16)
	sub_lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
	vbox.add_child(sub_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "기간 한정 픽업 · 3성 등장 확률 3%"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	vbox.add_child(desc_lbl)


func _build_pity_row(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	parent.add_child(margin)

	var pity_panel := PanelContainer.new()
	var sb := ThemeFactory.glass_panel(false, 14)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pity_panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(pity_panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	pity_panel.add_child(hbox)

	var pity_icon := Label.new()
	pity_icon.text = "🔄"
	hbox.add_child(pity_icon)

	_pity_label = Label.new()
	_pity_label.text = _pity_text()
	_pity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(_pity_label)

	# 진행 바
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = 100
	bar.value = _pity_count
	bar.custom_minimum_size = Vector2(140, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.name = "PityBar"
	hbox.add_child(bar)
	_update_pity_bar(bar)


func _pity_text() -> String:
	return "연속 %d / 100 회  —  ★3 보장" % _pity_count


func _update_pity_bar(bar: ProgressBar) -> void:
	bar.value = _pity_count


func _build_pull_buttons(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	parent.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	# 1회 모집
	var btn1 := Button.new()
	btn1.text = "1회 모집  (💎 160)"
	btn1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn1.custom_minimum_size = Vector2(0, 56)
	btn1.add_theme_font_size_override("font_size", 17)
	var sb1 := ThemeFactory.glass_panel(true, 18)
	sb1.border_color = ThemeFactory.C_CYAN
	sb1.set_border_width_all(2)
	btn1.add_theme_stylebox_override("normal", sb1)
	btn1.add_theme_stylebox_override("hover", ThemeFactory.accent_box(18))
	btn1.pressed.connect(_on_pull_1)
	hbox.add_child(btn1)

	# 10회 모집
	var btn10 := Button.new()
	btn10.text = "10회 모집  (💎 1,600)"
	btn10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn10.custom_minimum_size = Vector2(0, 56)
	btn10.add_theme_font_size_override("font_size", 17)
	var sb10 := ThemeFactory.cta_box()
	btn10.add_theme_stylebox_override("normal", sb10)
	btn10.add_theme_stylebox_override("hover", sb10)
	btn10.add_theme_stylebox_override("pressed", sb10)
	btn10.pressed.connect(_on_pull_10)
	hbox.add_child(btn10)


func _build_history_chip(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	parent.add_child(margin)

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG1, 20))
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	margin.add_child(chip)

	_pull_history_label = Label.new()
	_pull_history_label.text = _history_text()
	_pull_history_label.add_theme_font_size_override("font_size", 14)
	_pull_history_label.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	chip.add_child(_pull_history_label)


func _history_text() -> String:
	return "총 %d회 모집" % GameData.stats.get("pulls", 0)


# ── 결과 오버레이 ──
func _build_results_overlay() -> void:
	_results_overlay = Control.new()
	_results_overlay.name = "ResultsOverlay"
	_results_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_results_overlay)

	# 어두운 배경
	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.75)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_overlay.add_child(dimmer)

	# 결과 패널
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(640, 400)
	panel.offset_left = -320
	panel.offset_top = -210
	panel.offset_right = 320
	panel.offset_bottom = 210
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var sb := ThemeFactory.glass_panel(true, 24)
	sb.bg_color = Color(0.10, 0.07, 0.22, 0.97)
	panel.add_theme_stylebox_override("panel", sb)
	_results_overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var result_title := Label.new()
	result_title.text = "모집 결과"
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_title.add_theme_font_size_override("font_size", 22)
	result_title.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	vbox.add_child(result_title)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 240)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_results_grid = GridContainer.new()
	_results_grid.columns = 5
	_results_grid.add_theme_constant_override("h_separation", 8)
	_results_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_results_grid)

	var confirm_btn := Button.new()
	confirm_btn.text = "확인"
	confirm_btn.custom_minimum_size = Vector2(160, 48)
	confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	confirm_btn.add_theme_stylebox_override("normal", ThemeFactory.accent_box(14))
	confirm_btn.pressed.connect(func(): _results_overlay.visible = false)
	vbox.add_child(confirm_btn)


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
	var sb := ThemeFactory.glass_panel(true, 20)
	sb.bg_color = Color(0.08, 0.05, 0.18, 0.92)
	_toast_label.add_theme_stylebox_override("normal", sb)
	_toast_label.add_theme_font_size_override("font_size", 16)
	add_child(_toast_label)


# ─────────────────────────────────────────────
# 뽑기 로직
# ─────────────────────────────────────────────
func _on_pull_1() -> void:
	if GameData.gems < 160:
		_toast("💎 부족 (160 필요)")
		return
	GameData.add_currency("gems", -160)
	var results := [_roll_single()]
	_pity_count += 1
	GameData.stats["pulls"] = GameData.stats.get("pulls", 0) + 1
	_apply_results(results)
	_show_results(results)


func _on_pull_10() -> void:
	if GameData.gems < 1600:
		_toast("💎 부족 (1,600 필요)")
		return
	GameData.add_currency("gems", -1600)
	var results: Array[Dictionary] = []
	var has_r2_plus := false
	for i in 10:
		var pulled := _roll_single()
		if pulled.get("r", 1) >= 2:
			has_r2_plus = true
		results.append(pulled)
	# 10회 보장: r>=2 없으면 마지막을 r=2 로 교체
	if not has_r2_plus:
		var r2_pool := GameData.pool.filter(func(c): return c.get("r", 1) >= 2)
		if r2_pool.size() > 0:
			results[9] = r2_pool[randi() % r2_pool.size()].duplicate()
	_pity_count += 10
	GameData.stats["pulls"] = GameData.stats.get("pulls", 0) + 10
	_apply_results(results)
	_show_results(results)


func _roll_single() -> Dictionary:
	var r: int
	if _pity_count >= 89:
		r = 3
	elif randf() < 0.03:
		r = 3
	elif randf() < 0.15:
		r = 2
	else:
		r = 1
	# pity 리셋은 3성 획득 시
	if r == 3:
		_pity_count = 0
	var candidates := GameData.pool.filter(func(c): return c.get("r", 1) == r)
	if candidates.is_empty():
		candidates = GameData.pool
	return candidates[randi() % candidates.size()].duplicate()


func _apply_results(results: Array) -> void:
	for ch in results:
		var char_id: String = ch.get("id", "")
		if GameData.owns_char(char_id):
			# 이미 보유 → 조각 +10
			var existing := GameData.get_char(char_id)
			existing["shards"] = existing.get("shards", 0) + 10
		else:
			# 새 캐릭터 추가
			var new_char := {
				"id": ch.get("id", ""),
				"n":  ch.get("n", "?"),
				"r":  ch.get("r", 1),
				"lv": 1,
				"pw": 500 + ch.get("r", 1) * 800,
				"role":   ch.get("role", "공격"),
				"weapon": ch.get("weapon", "bolt"),
				"c1": ch.get("c1", "#ffffff"),
				"c2": ch.get("c2", "#888888"),
				"shards": 0,
			}
			GameData.roster.append(new_char)
	GameData.roster_changed.emit()
	_pity_label.text = _pity_text()
	_pull_history_label.text = _history_text()
	# pity 바 갱신
	var bar := get_node_or_null("VBoxContainer/MarginContainer3/PanelContainer/HBoxContainer/PityBar") as ProgressBar
	if bar:
		_update_pity_bar(bar)


func _show_results(results: Array) -> void:
	for child in _results_grid.get_children():
		child.queue_free()

	for ch in results:
		var r: int = ch.get("r", 1)
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(100, 110)

		var sb := ThemeFactory.glass_panel(false, 14)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		match r:
			3: sb.border_color = ThemeFactory.C_PINK; sb.set_border_width_all(3)
			2: sb.border_color = ThemeFactory.C_CYAN; sb.set_border_width_all(2)
			_: sb.border_color = ThemeFactory.C_LINE
		card.add_theme_stylebox_override("panel", sb)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 3)
		card.add_child(vbox)

		var icon_lbl := Label.new()
		icon_lbl.text = GameData.role_icon(ch.get("role", ""))
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 32)
		vbox.add_child(icon_lbl)

		var name_lbl := Label.new()
		name_lbl.text = ch.get("n", "?")
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 13)
		vbox.add_child(name_lbl)

		var star_lbl := Label.new()
		star_lbl.text = GameData.star_label(r)
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.add_theme_font_size_override("font_size", 12)
		match r:
			3: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
			2: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
			_: star_lbl.add_theme_color_override("font_color", ThemeFactory.C_LINE)
		vbox.add_child(star_lbl)

		# 중복 여부
		if GameData.owns_char(ch.get("id", "")) and results.count(ch) <= 1:
			var dup_lbl := Label.new()
			dup_lbl.text = "+10🧩"
			dup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dup_lbl.add_theme_font_size_override("font_size", 11)
			dup_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
			vbox.add_child(dup_lbl)

		_results_grid.add_child(card)

	_results_overlay.visible = true


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


var C_INK_DIM := ThemeFactory.C_INK_DIM
