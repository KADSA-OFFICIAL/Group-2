## res://screens/recruit/recruit.gd
## 모집(가챠) 화면. 픽업 배너 · 10연 보장 · 1회/10회 뽑기 · 결과 오버레이.
## 모든 UI 는 _ready() 에서 코드로 빌드.

extends Control

const COST1  := 160
const COST10 := 1600
const PICKUP_ID := "lumen"

# ── UI 참조 ──
var _gem_label: Label
var _results_overlay: Control
var _results_grid: GridContainer
var _toast_label: Label
var _toast_timer: SceneTreeTimer

# 이미 소유 여부를 뽑기 전에 스냅샷 (NEW/DUP 판별용)
var _owned_before: Dictionary = {}


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
	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	_build_left_panel(root)
	_build_right_panel(root)
	_build_results_overlay()
	_build_toast()


# ── 왼쪽: 배너 (60cqw 비율) ──
func _build_left_panel(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 0.6
	parent.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# 상단: 뒤로 버튼 + 제목 + 보석
	var top_hbox := HBoxContainer.new()
	top_hbox.add_theme_constant_override("separation", 12)
	vbox.add_child(top_hbox)

	var back := Button.new()
	back.text = "← 메인"
	back.pressed.connect(func(): ScreenManager.pop())
	top_hbox.add_child(back)

	var title := Label.new()
	title.text = "모집소"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_hbox.add_child(title)

	var gem_pill := PanelContainer.new()
	gem_pill.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))
	top_hbox.add_child(gem_pill)
	_gem_label = Label.new()
	_gem_label.text = "💎 %s" % _comma(GameData.gems)
	_gem_label.add_theme_font_size_override("font_size", 15)
	_gem_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	gem_pill.add_child(_gem_label)
	GameData.currency_changed.connect(func(kind, _a):
		if kind == "gems":
			_gem_label.text = "💎 %s" % _comma(GameData.gems)
	)

	# 배너 패널
	var banner := PanelContainer.new()
	banner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("4a1040")
	sb.set_corner_radius_all(20)
	sb.border_color = ThemeFactory.C_PINK
	sb.set_border_width_all(2)
	sb.shadow_color = Color(ThemeFactory.C_PINK.r, ThemeFactory.C_PINK.g, ThemeFactory.C_PINK.b, 0.35)
	sb.shadow_size = 20
	sb.shadow_offset = Vector2(0, 4)
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 24
	sb.content_margin_bottom = 24
	banner.add_theme_stylebox_override("panel", sb)
	vbox.add_child(banner)

	var bvbox := VBoxContainer.new()
	bvbox.add_theme_constant_override("separation", 10)
	bvbox.alignment = BoxContainer.ALIGNMENT_CENTER
	banner.add_child(bvbox)

	var pickup_lbl := Label.new()
	pickup_lbl.text = "★3 픽업 — 루멘"
	pickup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_lbl.add_theme_font_size_override("font_size", 28)
	pickup_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	bvbox.add_child(pickup_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "새벽의 이정표"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 18)
	sub_lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK)
	bvbox.add_child(sub_lbl)

	# 픽업 캐릭터 초상화 원
	var portrait_container := CenterContainer.new()
	portrait_container.custom_minimum_size = Vector2(0, 100)
	bvbox.add_child(portrait_container)
	var portrait_circle := PanelContainer.new()
	portrait_circle.custom_minimum_size = Vector2(90, 90)
	var circ_sb := StyleBoxFlat.new()
	circ_sb.bg_color = Color("fff3b0").darkened(0.3)
	circ_sb.set_corner_radius_all(45)
	circ_sb.border_color = ThemeFactory.C_GOLD
	circ_sb.set_border_width_all(3)
	portrait_circle.add_theme_stylebox_override("panel", circ_sb)
	portrait_container.add_child(portrait_circle)
	var portrait_lbl := Label.new()
	portrait_lbl.text = "⚔"
	portrait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	portrait_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait_lbl.add_theme_font_size_override("font_size", 40)
	portrait_circle.add_child(portrait_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "기간 한정 픽업 · ★3 등장 확률 3%  |  ★2: 18%  |  ★1: 79%"
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	bvbox.add_child(desc_lbl)


# ── 오른쪽: 뽑기 버튼 패널 (33cqw 비율) ──
func _build_right_panel(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_stretch_ratio = 0.4
	parent.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)

	# 확률 안내 박스
	var info_panel := PanelContainer.new()
	var info_sb := ThemeFactory.glass_panel(false, 16)
	info_sb.content_margin_top = 14
	info_sb.content_margin_bottom = 14
	info_panel.add_theme_stylebox_override("panel", info_sb)
	vbox.add_child(info_panel)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 6)
	info_panel.add_child(info_vbox)

	var info_title := Label.new()
	info_title.text = "모집 확률"
	info_title.add_theme_font_size_override("font_size", 16)
	info_title.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	info_vbox.add_child(info_title)

	for rate_text in ["★3 (픽업 50%): 3%", "★2: 18%", "★1: 79%"]:
		var lbl := Label.new()
		lbl.text = rate_text
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
		info_vbox.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 1회 모집 버튼
	var btn1 := Button.new()
	btn1.text = "1회 모집\n💎 %d" % COST1
	btn1.custom_minimum_size = Vector2(0, 70)
	btn1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn1.add_theme_font_size_override("font_size", 17)
	var sb1 := ThemeFactory.glass_panel(true, 18)
	sb1.border_color = ThemeFactory.C_CYAN
	sb1.set_border_width_all(2)
	btn1.add_theme_stylebox_override("normal", sb1)
	btn1.add_theme_stylebox_override("hover", ThemeFactory.accent_box(18))
	btn1.pressed.connect(_on_pull_1)
	vbox.add_child(btn1)

	# 10회 모집 버튼
	var btn10 := Button.new()
	btn10.text = "10회 모집\n💎 %s" % _comma(COST10)
	btn10.custom_minimum_size = Vector2(0, 70)
	btn10.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn10.add_theme_font_size_override("font_size", 17)
	var sb10 := ThemeFactory.cta_box()
	btn10.add_theme_stylebox_override("normal", sb10)
	btn10.add_theme_stylebox_override("hover", sb10)
	btn10.add_theme_stylebox_override("pressed", sb10)
	btn10.pressed.connect(_on_pull_10)
	vbox.add_child(btn10)

	# 보장 텍스트
	var guar_lbl := Label.new()
	guar_lbl.text = "10연 ★2 이상 1장 보장"
	guar_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	guar_lbl.add_theme_font_size_override("font_size", 13)
	guar_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	vbox.add_child(guar_lbl)

	# 누적 뽑기 수
	var hist_chip := PanelContainer.new()
	hist_chip.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG1, 20))
	hist_chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(hist_chip)
	var hist_lbl := Label.new()
	hist_lbl.name = "HistLabel"
	hist_lbl.text = "총 %d회 모집" % GameData.stats.get("pulls", 0)
	hist_lbl.add_theme_font_size_override("font_size", 14)
	hist_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	hist_chip.add_child(hist_lbl)


# ── 결과 오버레이 ──
func _build_results_overlay() -> void:
	_results_overlay = Control.new()
	_results_overlay.name = "ResultsOverlay"
	_results_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_results_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_results_overlay)

	var dimmer := ColorRect.new()
	dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dimmer.color = Color(0, 0, 0, 0.78)
	dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_results_overlay.add_child(dimmer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(660, 420)
	panel.offset_left = -330
	panel.offset_top = -220
	panel.offset_right = 330
	panel.offset_bottom = 220
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
	scroll.custom_minimum_size = Vector2(0, 260)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	_results_grid = GridContainer.new()
	_results_grid.columns = 5
	_results_grid.add_theme_constant_override("h_separation", 8)
	_results_grid.add_theme_constant_override("v_separation", 8)
	_results_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	_toast_label.offset_left = -210.0
	_toast_label.offset_top = -28.0
	_toast_label.offset_right = 210.0
	_toast_label.offset_bottom = 28.0
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
	if GameData.gems < COST1:
		_toast("💎 부족 (%d 필요)" % COST1)
		return
	_snapshot_owned()
	GameData.add_currency("gems", -COST1)
	var results := [_roll_single()]
	GameData.stats["pulls"] = GameData.stats.get("pulls", 0) + 1
	_apply_results(results)
	_show_results(results)
	_update_history_label()


func _on_pull_10() -> void:
	if GameData.gems < COST10:
		_toast("💎 부족 (%s 필요)" % _comma(COST10))
		return
	_snapshot_owned()
	GameData.add_currency("gems", -COST10)
	var results: Array[Dictionary] = []
	var has_r2_plus := false
	for i in 10:
		var pulled := _roll_single()
		if pulled.get("r", 1) >= 2:
			has_r2_plus = true
		results.append(pulled)
	# 10연 보장: r>=2 없으면 마지막을 r=2 로 교체
	if not has_r2_plus:
		var r2_pool := GameData.pool.filter(func(c): return c.get("r", 1) >= 2)
		if r2_pool.size() > 0:
			results[9] = r2_pool[randi() % r2_pool.size()].duplicate()
	GameData.stats["pulls"] = GameData.stats.get("pulls", 0) + 10
	_apply_results(results)
	_show_results(results)
	_update_history_label()


func _roll_single() -> Dictionary:
	var rnd := randf()
	var r: int
	if rnd < 0.03:
		r = 3
	elif rnd < 0.21:  # 0.03 + 0.18
		r = 2
	else:
		r = 1

	# ★3 픽업 50% 확률
	if r == 3 and randf() < 0.5:
		var pickup := GameData.pool.filter(func(c): return c.get("id", "") == PICKUP_ID)
		if pickup.size() > 0:
			return pickup[0].duplicate()

	var candidates := GameData.pool.filter(func(c): return c.get("r", 1) == r)
	if candidates.is_empty():
		candidates = GameData.pool
	return candidates[randi() % candidates.size()].duplicate()


func _snapshot_owned() -> void:
	_owned_before.clear()
	for ch in GameData.roster:
		_owned_before[ch.get("id", "")] = true


func _apply_results(results: Array) -> void:
	for ch in results:
		var char_id: String = ch.get("id", "")
		if GameData.owns_char(char_id):
			var existing := GameData.get_char(char_id)
			existing["shards"] = existing.get("shards", 0) + 10
		else:
			var new_char := {
				"id":     ch.get("id", ""),
				"n":      ch.get("n", "?"),
				"r":      ch.get("r", 1),
				"lv":     1,
				"pw":     500 + ch.get("r", 1) * 800,
				"role":   ch.get("role", "공격"),
				"weapon": ch.get("weapon", "bolt"),
				"c1":     ch.get("c1", "#ffffff"),
				"c2":     ch.get("c2", "#888888"),
				"shards": 0,
			}
			GameData.roster.append(new_char)
	GameData.roster_changed.emit()


func _show_results(results: Array) -> void:
	for child in _results_grid.get_children():
		child.queue_free()

	for ch in results:
		var r: int = ch.get("r", 1)
		var char_id: String = ch.get("id", "")
		var is_new := not _owned_before.has(char_id)

		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(110, 125)

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

		# NEW / DUP 배지
		var badge_row := HBoxContainer.new()
		badge_row.add_theme_constant_override("separation", 0)
		vbox.add_child(badge_row)
		var badge_spacer := Control.new()
		badge_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		badge_row.add_child(badge_spacer)
		var badge_lbl := Label.new()
		if is_new:
			badge_lbl.text = "NEW"
			badge_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOOD)
		else:
			badge_lbl.text = "DUP"
			badge_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		badge_lbl.add_theme_font_size_override("font_size", 10)
		badge_row.add_child(badge_lbl)

		var icon_lbl := Label.new()
		icon_lbl.text = GameData.role_icon(ch.get("role", ""))
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 34)
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

		if not is_new:
			var dup_lbl := Label.new()
			dup_lbl.text = "+10🧩"
			dup_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			dup_lbl.add_theme_font_size_override("font_size", 11)
			dup_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
			vbox.add_child(dup_lbl)

		_results_grid.add_child(card)

	_results_overlay.visible = true


func _update_history_label() -> void:
	# 히스토리 라벨 갱신 (노드 트리 검색 대신 직접 탐색)
	var hist_lbl := _find_hist_label(self)
	if hist_lbl:
		hist_lbl.text = "총 %d회 모집" % GameData.stats.get("pulls", 0)


func _find_hist_label(node: Node) -> Label:
	if node is Label and node.name == "HistLabel":
		return node as Label
	for child in node.get_children():
		var result := _find_hist_label(child)
		if result:
			return result
	return null


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
