## res://screens/result/result.gd
## 결과 화면 — 스테이지 클리어 보상 표시.
## HTML showResult() 대응.

extends Control

var _star_labels: Array[Label] = []
var _reward_chips: Array[Control] = []


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	# 배틀 컨텍스트 읽기
	var b: Dictionary = GameData.battle
	var tp: int = b.get("team_power", 0)
	var reco: int = b.get("reco", 1)
	var hard: bool = b.get("hard", false)
	var stage_n: int = b.get("n", 0)

	# 별 계산 (HTML 공식)
	var ratio: float = float(tp) / float(maxi(reco, 1))
	var stars: int
	if ratio >= 1.0:
		stars = 3
	elif ratio >= 0.85:
		stars = 2
	else:
		stars = 1

	# 첫 클리어 여부
	var prev_cleared: int = GameData.cleared
	var is_first_clear: bool = stage_n > prev_cleared

	# 보상 배수
	var mm: int = 2 if hard else 1
	var gold_gain := 1200 * mm
	var book_gain := 2 * mm
	var ore_gain  := 1 * mm
	var dust_gain := 10 * mm
	var exp_gain  := 320 * mm

	# GameData 업데이트
	GameData.cleared = maxi(GameData.cleared, stage_n)
	GameData.stats["clears"] = GameData.stats.get("clears", 0) + 1
	GameData.add_currency("gold", gold_gain)
	GameData.mats["book"]  = GameData.mats.get("book",  0) + book_gain
	GameData.mats["ore"]   = GameData.mats.get("ore",   0) + ore_gain
	GameData.mats["dust"]  = GameData.mats.get("dust",  0) + dust_gain
	if is_first_clear:
		GameData.add_currency("gems", 50)

	_build_ui(b, stars, hard, is_first_clear, gold_gain, book_gain, ore_gain, exp_gain, stage_n)

	# 별 + 보상 칩 애니메이션
	_animate_stars(stars)
	_animate_chips()


func _build_ui(b: Dictionary, stars: int, hard: bool, is_first_clear: bool,
		gold_gain: int, book_gain: int, ore_gain: int, exp_gain: int, stage_n: int) -> void:

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)

	var root := VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	scroll.add_child(root)

	root.add_child(_build_title(b, hard, is_first_clear))
	root.add_child(_build_stars_row(stars))
	root.add_child(_build_rewards(stars, hard, is_first_clear, gold_gain, book_gain, ore_gain))
	root.add_child(_build_exp_bar(exp_gain))
	root.add_child(_build_team_section())
	root.add_child(_build_buttons(stage_n))


# ── 제목 ──────────────────────────────────────────────────
func _build_title(b: Dictionary, hard: bool, is_first_clear: bool) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# 스테이지 코드 · 클리어 텍스트
	var diff_text := "하드 클리어" if hard else "보통 클리어"
	var stage_lbl := Label.new()
	stage_lbl.text = "%s · %s" % [b.get("code", "??"), diff_text]
	stage_lbl.add_theme_font_size_override("font_size", 32)
	stage_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(stage_lbl)

	if is_first_clear:
		var first_lbl := Label.new()
		first_lbl.text = "· 첫 클리어!"
		first_lbl.add_theme_font_size_override("font_size", 20)
		first_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
		first_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(first_lbl)

	return panel


# ── 별 표시 ───────────────────────────────────────────────
func _build_stars_row(_stars: int) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 8)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	_star_labels.clear()
	for i in 3:
		var lbl := Label.new()
		lbl.text = "★"
		lbl.add_theme_font_size_override("font_size", 48)
		lbl.add_theme_color_override("font_color", ThemeFactory.C_LINE)
		lbl.modulate.a = 0.0  # 처음엔 투명 → 애니메이션으로 나타남
		hbox.add_child(lbl)
		_star_labels.append(lbl)

	return margin


func _animate_stars(stars: int) -> void:
	for i in stars:
		await get_tree().create_timer(0.35 * (i + 1)).timeout
		if i < _star_labels.size():
			_star_labels[i].modulate.a = 1.0
			_star_labels[i].add_theme_color_override("font_color", ThemeFactory.C_GOLD)


# ── 보상 섹션 ───────────────────────────────────────────
func _build_rewards(stars: int, hard: bool, is_first_clear: bool,
		gold_gain: int, book_gain: int, ore_gain: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
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
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	_reward_chips.clear()

	var chip1 := _make_reward_chip("🪙 골드 +%s" % _comma(gold_gain), ThemeFactory.C_GOLD)
	chip1.modulate.a = 0.0
	row.add_child(chip1)
	_reward_chips.append(chip1)

	var chip2 := _make_reward_chip("📘 강화서 ×%d" % book_gain, ThemeFactory.C_CYAN)
	chip2.modulate.a = 0.0
	row.add_child(chip2)
	_reward_chips.append(chip2)

	var chip3 := _make_reward_chip("🔮 마정석 ×%d" % ore_gain, ThemeFactory.C_PINK)
	chip3.modulate.a = 0.0
	row.add_child(chip3)
	_reward_chips.append(chip3)

	if is_first_clear:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 8)
		row2.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_child(row2)

		var chip4 := _make_reward_chip("💎 보석(초회) +50", ThemeFactory.C_CYAN)
		chip4.modulate.a = 0.0
		row2.add_child(chip4)
		_reward_chips.append(chip4)

		var chip5 := _make_reward_chip("🧩 캐릭터 조각 ×5", ThemeFactory.C_AMBER)
		chip5.modulate.a = 0.0
		row2.add_child(chip5)
		_reward_chips.append(chip5)

	if hard and stars == 3:
		var chip_bonus := _make_reward_chip("🌟 하드 풀클 보너스", ThemeFactory.C_PINK)
		chip_bonus.modulate.a = 0.0
		row.add_child(chip_bonus)
		_reward_chips.append(chip_bonus)

	return panel


func _animate_chips() -> void:
	for i in _reward_chips.size():
		await get_tree().create_timer(0.2 * (i + 1) + 1.0).timeout
		if i < _reward_chips.size():
			_reward_chips[i].modulate.a = 1.0


func _make_reward_chip(text: String, color: Color) -> Control:
	var chip := PanelContainer.new()
	var sb := ThemeFactory.pill(Color(color.r, color.g, color.b, 0.18), 20)
	sb.border_color = color
	chip.add_theme_stylebox_override("panel", sb)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	chip.add_child(lbl)

	return chip


# ── EXP 바 ────────────────────────────────────────────────
func _build_exp_bar(exp_gain: int) -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 4)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var exp_row := HBoxContainer.new()
	exp_row.add_theme_constant_override("separation", 8)
	vbox.add_child(exp_row)

	var exp_icon := Label.new()
	exp_icon.text = "⭐"
	exp_row.add_child(exp_icon)

	var exp_lbl := Label.new()
	exp_lbl.text = "EXP +%d" % exp_gain
	exp_lbl.add_theme_font_size_override("font_size", 15)
	exp_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	exp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	exp_row.add_child(exp_lbl)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = GameData.exp_to_next
	bar.value = GameData.exp_current
	bar.custom_minimum_size = Vector2(0, 14)
	vbox.add_child(bar)

	# EXP 채우기 애니메이션
	var target_exp := mini(GameData.exp_current + exp_gain, GameData.exp_to_next)
	_animate_exp_bar(bar, target_exp)

	return margin


func _animate_exp_bar(bar: ProgressBar, target: int) -> void:
	await get_tree().create_timer(1.5).timeout
	bar.value = target


# ── 팀 표시 (MVP 크라운 포함) ─────────────────────────────
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
	var mvp_name := _find_mvp_name(team_ids)

	var shown := 0
	for cid in team_ids:
		if shown >= 4:
			break
		var ch := _find_char(str(cid))
		if ch.is_empty():
			continue
		var is_mvp := ch.get("n", "") == mvp_name

		var chip := PanelContainer.new()
		var chip_sb := ThemeFactory.pill(ThemeFactory.C_BG2, 20)
		if is_mvp:
			chip_sb.border_color = ThemeFactory.C_GOLD
			chip_sb.set_border_width_all(2)
		chip.add_theme_stylebox_override("panel", chip_sb)

		var chip_hbox := HBoxContainer.new()
		chip_hbox.add_theme_constant_override("separation", 4)
		chip.add_child(chip_hbox)

		if is_mvp:
			var crown := Label.new()
			crown.text = "👑"
			crown.add_theme_font_size_override("font_size", 14)
			chip_hbox.add_child(crown)

		var lbl := Label.new()
		lbl.text = "%s %s" % [GameData.role_icon(ch.get("role", "")), ch.get("n", "?")]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color",
			ThemeFactory.C_GOLD if is_mvp else ThemeFactory.C_INK)
		chip_hbox.add_child(lbl)

		row.add_child(chip)
		shown += 1

	return margin


func _find_mvp_name(team_ids: Array) -> String:
	var best_name := ""
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
func _build_buttons(stage_n: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(hbox)

	# 다시 도전 → 편성 화면으로
	var retry_btn := Button.new()
	retry_btn.text = "다시 도전"
	retry_btn.custom_minimum_size = Vector2(160, 52)
	retry_btn.add_theme_font_size_override("font_size", 17)
	retry_btn.pressed.connect(_on_retry)
	hbox.add_child(retry_btn)

	# 다음 스테이지 (n>=10 이면 비활성)
	var next_btn := Button.new()
	next_btn.text = "다음 스테이지"
	next_btn.custom_minimum_size = Vector2(160, 52)
	next_btn.add_theme_font_size_override("font_size", 17)
	next_btn.add_theme_stylebox_override("normal", ThemeFactory.cta_box())
	next_btn.add_theme_stylebox_override("hover", ThemeFactory.cta_box())
	next_btn.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
	if stage_n >= 10:
		next_btn.disabled = true
	else:
		next_btn.pressed.connect(_on_next_stage)
	hbox.add_child(next_btn)

	return panel


func _on_retry() -> void:
	# Result → Battle/Formation 제거 → 스테이지 선택으로
	ScreenManager.pop()
	ScreenManager.pop()


func _on_next_stage() -> void:
	# 다음 스테이지: n+1 로 battle 컨텍스트 갱신 후 편성 화면으로
	GameData.battle["n"] = GameData.battle.get("n", 0) + 1
	var code: String = GameData.battle.get("code", "33-1")
	var parts := code.split("-")
	if parts.size() == 2:
		var new_n := str(GameData.battle["n"])
		GameData.battle["code"] = parts[0] + "-" + new_n
	ScreenManager.pop()  # Result
	ScreenManager.pop()  # Battle
	# Formation 이 스택에 남아 다음 스테이지를 편성하도록


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
