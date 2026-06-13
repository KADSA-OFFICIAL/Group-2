## res://screens/result/result.gd
## 결과 화면 — 전투 승패/보상 표시.
## HTML showResult() 대응.

extends Control


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	# 결과 읽기
	var win: bool = GameData.battle.get("result", false)
	var stars: int = GameData.battle.get("stars", 0)

	# 승리 시 배경 오버레이 (금색 틴트)
	if win:
		var tint := ColorRect.new()
		tint.name = "WinTint"
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.color = Color(ThemeFactory.C_GOLD.r, ThemeFactory.C_GOLD.g, ThemeFactory.C_GOLD.b, 0.07)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tint)
	else:
		var tint := ColorRect.new()
		tint.name = "LoseTint"
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.color = Color(0.0, 0.0, 0.0, 0.35)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tint)

	# 승리 시 보상 지급 (UI 빌드 전에)
	if win:
		GameData.add_currency("gold", 15000)
		# EXP 는 별도 필드 없으므로 로그만 (통계 처리)
		if stars == 3:
			GameData.add_currency("faction_token", 50)

	_build_ui(win, stars)
	if win:
		_animate_stars(stars)


func _build_ui(win: bool, stars: int) -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	scroll.add_child(root)

	root.add_child(_build_title(win))
	root.add_child(_build_stars_row(stars))
	if win:
		root.add_child(_build_rewards(stars))
	root.add_child(_build_team_section())
	root.add_child(_build_mvp_section())
	root.add_child(_build_buttons())


# ── 제목 ──────────────────────────────────────────────────
func _build_title(win: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "✨ 승리!" if win else "💀 패배"
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", ThemeFactory.C_GOLD if win else ThemeFactory.C_BAD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var code_lbl := Label.new()
	code_lbl.text = "스테이지 %s" % GameData.battle.get("code", "?")
	code_lbl.add_theme_font_size_override("font_size", 18)
	code_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	code_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(code_lbl)

	return panel


# ── 별 표시 ───────────────────────────────────────────────
var _star_labels: Array[Label] = []

func _build_stars_row(stars: int) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 8)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	_star_labels.clear()
	for i in 3:
		var lbl := Label.new()
		lbl.text = "★"
		lbl.add_theme_font_size_override("font_size", 40)
		lbl.add_theme_color_override("font_color",
			ThemeFactory.C_GOLD if i < stars else ThemeFactory.C_LINE)
		lbl.modulate.a = 0.0 if (stars > 0) else 1.0  # 애니메이션할 것들은 처음엔 투명
		hbox.add_child(lbl)
		_star_labels.append(lbl)

	return margin


func _animate_stars(stars: int) -> void:
	for i in stars:
		await get_tree().create_timer(0.3).timeout
		if i < _star_labels.size():
			_star_labels[i].modulate.a = 1.0
			_star_labels[i].add_theme_color_override("font_color", ThemeFactory.C_GOLD)


# ── 보상 섹션 (승리 시) ───────────────────────────────────
func _build_rewards(stars: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "획득 보상"
	header.add_theme_font_size_override("font_size", 18)
	header.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	vbox.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vbox.add_child(row)

	row.add_child(_make_reward_chip("🪙 골드 +15,000", ThemeFactory.C_GOLD))
	row.add_child(_make_reward_chip("⭐ EXP +1,200", ThemeFactory.C_CYAN))
	if stars == 3:
		row.add_child(_make_reward_chip("🎀 보너스 드롭", ThemeFactory.C_PINK))

	return panel


func _make_reward_chip(text: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	var sb := ThemeFactory.pill(
		Color(color.r, color.g, color.b, 0.18), 20)
	sb.border_color = color
	chip.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	chip.add_child(lbl)

	return chip


# ── 팀 표시 ───────────────────────────────────────────────
func _build_team_section() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "출격 팀"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	vbox.add_child(header)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vbox.add_child(row)

	var team_ids: Array = GameData.battle.get("team", [])
	var shown := 0
	for cid in team_ids:
		if shown >= 3:
			break
		var ch := _find_char(str(cid))
		if ch.is_empty():
			continue
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))

		var lbl := Label.new()
		lbl.text = "%s %s" % [GameData.role_icon(ch.get("role", "")), ch.get("n", "?")]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", ThemeFactory.C_INK)
		chip.add_child(lbl)
		row.add_child(chip)
		shown += 1

	return margin


# ── MVP ───────────────────────────────────────────────────
func _build_mvp_section() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 8)

	var mvp_lbl := Label.new()
	var mvp_name := _find_mvp_name()
	mvp_lbl.text = "MVP: %s" % mvp_name
	mvp_lbl.add_theme_font_size_override("font_size", 17)
	mvp_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	margin.add_child(mvp_lbl)

	return margin


func _find_mvp_name() -> String:
	var team_ids: Array = GameData.battle.get("team", [])
	var best_name := "?"
	var best_pw := -1
	for cid in team_ids:
		var ch := _find_char(str(cid))
		if ch.is_empty():
			continue
		var pw: int = int(ch.get("pw", 0))
		if pw > best_pw:
			best_pw = pw
			best_name = ch.get("n", "?")
	return best_name


# ── 버튼 행 ──────────────────────────────────────────────
func _build_buttons() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	var retry_btn := Button.new()
	retry_btn.text = "다시 도전"
	retry_btn.custom_minimum_size = Vector2(160, 52)
	retry_btn.add_theme_font_size_override("font_size", 17)
	retry_btn.pressed.connect(_on_retry)
	hbox.add_child(retry_btn)

	var home_btn := Button.new()
	home_btn.text = "홈으로"
	home_btn.custom_minimum_size = Vector2(160, 52)
	home_btn.add_theme_font_size_override("font_size", 17)
	home_btn.add_theme_stylebox_override("normal", ThemeFactory.cta_box())
	home_btn.add_theme_stylebox_override("hover", ThemeFactory.cta_box())
	home_btn.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
	home_btn.pressed.connect(_on_home)
	hbox.add_child(home_btn)

	return panel


func _on_retry() -> void:
	# 결과 → 전투 → 편성 순으로 팝하여 스테이지 선택으로 돌아감
	ScreenManager.pop()  # Result 제거
	ScreenManager.pop()  # Battle 제거


func _on_home() -> void:
	# 결과 → 전투 → 편성 → 스테이지 선택 순으로 팝하여 메인 화면 노출
	ScreenManager.pop()
	ScreenManager.pop()
	ScreenManager.pop()
	ScreenManager.pop()


# ── 유틸 ─────────────────────────────────────────────────
func _find_char(char_id: String) -> Dictionary:
	for ch in GameData.roster:
		if ch.get("id", "") == char_id:
			return ch
	return {}
