## res://screens/pass/pass.gd
## 시즌 패스 화면. 무료/프리미엄 5단계 티어 보상.

extends Control

# HTML FREE/PREM 배열 그대로 (10티어)
const FREE_REWARDS = [
	{ic="🪙", rw="골드 10만",   k="gold",  a=100000},
	{ic="📘", rw="강화서 ×3",   k="book",  a=3},
	{ic="💎", rw="보석 50",     k="gems",  a=50},
	{ic="🔮", rw="마정석 ×3",   k="ore",   a=3},
	{ic="🪙", rw="골드 30만",   k="gold",  a=300000},
	{ic="✨", rw="별가루 ×20",  k="dust",  a=20},
	{ic="💎", rw="보석 100",    k="gems",  a=100},
	{ic="📘", rw="강화서 ×5",   k="book",  a=5},
	{ic="🪙", rw="골드 50만",   k="gold",  a=500000},
	{ic="💎", rw="보석 200",    k="gems",  a=200},
]

const PREM_REWARDS = [
	{ic="💎", rw="보석 100",           k="gems",  a=100},
	{ic="🧩", rw="조각 +10",           k="shard", a=10},
	{ic="💎", rw="보석 150",           k="gems",  a=150},
	{ic="🪙", rw="골드 50만",          k="gold",  a=500000},
	{ic="🧩", rw="조각 +10",           k="shard", a=10},
	{ic="💎", rw="보석 200",           k="gems",  a=200},
	{ic="🔮", rw="마정석 ×10",         k="ore",   a=10},
	{ic="🧩", rw="조각 +20",           k="shard", a=20},
	{ic="💎", rw="보석 300",           k="gems",  a=300},
	{ic="👑", rw="보석 500 + 조각 20", k="gems",  a=500, shard=20},
]

const PASS_EXP_PER_TIER := 150

var _pass_level_label: Label
var _pass_prog_bar: ProgressBar
var _tier_rows_vbox: VBoxContainer
var _buy_btn: Button
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
	vbox.add_theme_constant_override("separation", 14)
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
	title_label.text = "시즌 패스"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title_label)

	# ── 패스 상태 카드 ──
	var status_card := PanelContainer.new()
	status_card.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 18))
	vbox.add_child(status_card)

	var status_vbox := VBoxContainer.new()
	status_vbox.add_theme_constant_override("separation", 8)
	status_card.add_child(status_vbox)

	# 패스 타입 표시
	var type_label := Label.new()
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 15)
	if GameData.pass_premium:
		type_label.text = "✨ 무료 + 프리미엄 활성화"
		type_label.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	else:
		type_label.text = "무료 패스 (프리미엄 미보유)"
		type_label.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	status_vbox.add_child(type_label)

	_pass_level_label = Label.new()
	_pass_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pass_level_label.add_theme_font_size_override("font_size", 16)
	status_vbox.add_child(_pass_level_label)

	_pass_prog_bar = ProgressBar.new()
	_pass_prog_bar.min_value = 0
	_pass_prog_bar.max_value = PASS_EXP_PER_TIER
	_pass_prog_bar.show_percentage = false
	_pass_prog_bar.custom_minimum_size = Vector2(0, 14)
	status_vbox.add_child(_pass_prog_bar)

	# ── 프리미엄 구매 버튼 (HTML: 데모 무료) ──
	_buy_btn = Button.new()
	_buy_btn.add_theme_stylebox_override("normal",  ThemeFactory.cta_box())
	_buy_btn.add_theme_stylebox_override("hover",   ThemeFactory.cta_box())
	_buy_btn.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
	_buy_btn.add_theme_font_size_override("font_size", 18)
	_buy_btn.custom_minimum_size = Vector2(0, 56)
	_buy_btn.text = "프리미엄 해금 (데모 무료)"
	_buy_btn.pressed.connect(_on_buy_premium)
	vbox.add_child(_buy_btn)

	# ── 티어 목록 ──
	var tier_header := Label.new()
	tier_header.text = "티어 보상"
	tier_header.add_theme_font_size_override("font_size", 18)
	tier_header.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	vbox.add_child(tier_header)

	_tier_rows_vbox = VBoxContainer.new()
	_tier_rows_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(_tier_rows_vbox)

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

	_refresh()


func _pass_exp() -> int:
	var s: Dictionary = GameData.stats
	return s.get("clears", 0) * 120 + s.get("pulls", 0) * 30 + s.get("levelups", 0) * 15


func _pass_level() -> int:
	return mini(10, _pass_exp() / PASS_EXP_PER_TIER)


func _refresh() -> void:
	var exp := _pass_exp()
	var lv := _pass_level()
	_pass_level_label.text = "Lv.%d 패스 레벨" % lv
	var cur_in_tier := exp - lv * PASS_EXP_PER_TIER
	if lv >= 10:
		_pass_prog_bar.value = PASS_EXP_PER_TIER
	else:
		_pass_prog_bar.value = cur_in_tier

	if GameData.pass_premium:
		_buy_btn.text = "프리미엄 패스 보유 중 ✦"
		_buy_btn.disabled = true
	else:
		_buy_btn.text = "프리미엄 해금 (데모 무료)"
		_buy_btn.disabled = false
	_build_tiers()


func _build_tiers() -> void:
	for c in _tier_rows_vbox.get_children():
		c.queue_free()

	var lv := _pass_level()

	for i in 10:
		var reached := lv >= (i + 1)
		var free_key := "f%d" % i
		var prem_key := "p%d" % i

		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel",
			ThemeFactory.glass_panel(reached, 14))
		_tier_rows_vbox.add_child(row)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 10)
		row.add_child(row_hbox)

		var tier_label := Label.new()
		tier_label.text = "Lv.%d" % (i + 1)
		tier_label.add_theme_font_size_override("font_size", 14)
		tier_label.add_theme_color_override("font_color",
			ThemeFactory.C_GOLD if reached else ThemeFactory.C_LINE)
		tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tier_label.custom_minimum_size = Vector2(42, 0)
		row_hbox.add_child(tier_label)

		row_hbox.add_child(_make_reward_cell(
			FREE_REWARDS[i], free_key, reached, false))
		row_hbox.add_child(_make_reward_cell(
			PREM_REWARDS[i], prem_key, reached, true))


func _make_reward_cell(def: Dictionary, claim_key: String, reached: bool, is_prem: bool) -> Control:
	var claimed := GameData.pass_claims.has(claim_key)
	var prem_locked := is_prem and not GameData.pass_premium

	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	if claimed:
		sb.bg_color = Color(ThemeFactory.C_GOOD, 0.2)
		sb.border_color = ThemeFactory.C_GOOD
	elif reached and not prem_locked:
		sb.bg_color = Color(ThemeFactory.C_CYAN, 0.15)
		sb.border_color = ThemeFactory.C_CYAN
	else:
		sb.bg_color = ThemeFactory.C_BG1
		sb.border_color = ThemeFactory.C_LINE
	panel.add_theme_stylebox_override("panel", sb)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 3)
	panel.add_child(inner)

	var type_lbl := Label.new()
	type_lbl.text = "프리미엄" if is_prem else "무료"
	type_lbl.add_theme_font_size_override("font_size", 10)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_prem:
		type_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	inner.add_child(type_lbl)

	var ic_lbl := Label.new()
	ic_lbl.text = def.ic
	ic_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic_lbl.add_theme_font_size_override("font_size", 20)
	inner.add_child(ic_lbl)

	var rw_lbl := Label.new()
	rw_lbl.text = def.rw
	rw_lbl.add_theme_font_size_override("font_size", 11)
	rw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if prem_locked:
		rw_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_FAINT)
	inner.add_child(rw_lbl)

	if prem_locked:
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒 프리미엄 전용"
		lock_lbl.add_theme_font_size_override("font_size", 10)
		lock_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_FAINT)
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(lock_lbl)
	else:
		var btn := Button.new()
		btn.text = "✓ 완료" if claimed else ("수령" if reached else "🔒")
		btn.disabled = claimed or not reached
		btn.add_theme_font_size_override("font_size", 12)
		btn.pressed.connect(_on_claim_cell.bind(def, claim_key))
		inner.add_child(btn)

	return panel


func _on_claim_cell(def: Dictionary, claim_key: String) -> void:
	if GameData.pass_claims.has(claim_key):
		return
	GameData.pass_claims[claim_key] = true
	_grant_reward(def)
	_toast("%s 수령!" % def.rw)
	_refresh()


func _grant_reward(def: Dictionary) -> void:
	match def.k:
		"book":  GameData.mats["book"]  = GameData.mats.get("book", 0)  + def.a
		"ore":   GameData.mats["ore"]   = GameData.mats.get("ore", 0)   + def.a
		"dust":  GameData.mats["dust"]  = GameData.mats.get("dust", 0)  + def.a
		"shard":
			if GameData.roster.size() > 0:
				var idx := randi() % GameData.roster.size()
				GameData.roster[idx]["shards"] = GameData.roster[idx].get("shards", 0) + def.a
		_:
			GameData.add_currency(def.k, def.a)
	if def.has("shard"):
		if GameData.roster.size() > 0:
			var idx := randi() % GameData.roster.size()
			GameData.roster[idx]["shards"] = GameData.roster[idx].get("shards", 0) + def.shard


func _on_buy_premium() -> void:
	if GameData.pass_premium:
		return
	GameData.pass_premium = true
	_toast("프리미엄 패스 활성화!")
	_refresh()


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
