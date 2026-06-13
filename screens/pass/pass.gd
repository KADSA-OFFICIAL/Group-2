## res://screens/pass/pass.gd
## 시즌 패스 화면. 무료/프리미엄 5단계 티어 보상.

extends Control

# 티어 정의
const TIERS: Array[Dictionary] = [
	{n = 1, req = 1,  free = {k = "gems",    a = 50},   prem = {k = "gems", a = 200}},
	{n = 2, req = 3,  free = {k = "gold",    a = 100000}, prem_multi = [{k = "gems", a = 300}, {k = "gold", a = 100000}]},
	{n = 3, req = 7,  free = {k = "stamina", a = 60},   prem = {k = "gems", a = 500}},
	{n = 4, req = 15, free = {k = "gems",    a = 150},  prem_multi = [{k = "gems", a = 800}, {k = "gold", a = 500000}]},
	{n = 5, req = 30, free = {k = "gems",    a = 300},  prem_multi = [{k = "gems", a = 2000}, {k = "gold", a = 2000000}]},
]

const REWARD_ICONS: Dictionary = {
	"gems": "💎", "gold": "🪙", "stamina": "⚡",
}

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
	_pass_prog_bar.max_value = 30
	_pass_prog_bar.show_percentage = false
	_pass_prog_bar.custom_minimum_size = Vector2(0, 14)
	status_vbox.add_child(_pass_prog_bar)

	# ── 프리미엄 구매 버튼 ──
	_buy_btn = Button.new()
	_buy_btn.add_theme_stylebox_override("normal",  ThemeFactory.cta_box())
	_buy_btn.add_theme_stylebox_override("hover",   ThemeFactory.cta_box())
	_buy_btn.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
	_buy_btn.add_theme_font_size_override("font_size", 18)
	_buy_btn.custom_minimum_size = Vector2(0, 56)
	_buy_btn.text = "프리미엄 패스 구매  💎×2200"
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


func _pass_level() -> int:
	return GameData.pass_claims.size()


func _refresh() -> void:
	var lv := _pass_level()
	_pass_level_label.text = "패스 Lv.%d / 30" % lv
	_pass_prog_bar.value = lv
	_buy_btn.visible = not GameData.pass_premium
	_build_tiers()


func _build_tiers() -> void:
	for c in _tier_rows_vbox.get_children():
		c.queue_free()

	var lv := _pass_level()

	for tier in TIERS:
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
		_tier_rows_vbox.add_child(row)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 10)
		row.add_child(row_hbox)

		# 티어 번호 라벨
		var tier_label := Label.new()
		tier_label.text = "Tier %d\n(Lv.%d)" % [tier.n, tier.req]
		tier_label.add_theme_font_size_override("font_size", 13)
		tier_label.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		tier_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tier_label.custom_minimum_size = Vector2(60, 0)
		row_hbox.add_child(tier_label)

		# 무료 보상 박스
		var free_key := "t%d_free" % tier.n
		var free_claimed := GameData.pass_claims.has(free_key)
		var free_unlocked := lv >= tier.req

		var free_vbox := _make_reward_box(
			tier, false, free_claimed, free_unlocked, free_key
		)
		row_hbox.add_child(free_vbox)

		# 프리미엄 보상 박스
		var prem_key := "t%d_prem" % tier.n
		var prem_claimed := GameData.pass_claims.has(prem_key)
		var prem_unlocked := GameData.pass_premium and lv >= tier.req

		var prem_vbox := _make_reward_box(
			tier, true, prem_claimed, prem_unlocked, prem_key
		)
		row_hbox.add_child(prem_vbox)


func _make_reward_box(tier: Dictionary, is_prem: bool, claimed: bool, unlocked: bool, claim_key: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(2)
	if claimed:
		sb.bg_color = Color(ThemeFactory.C_GOOD, 0.2)
		sb.border_color = ThemeFactory.C_GOOD
	elif unlocked:
		sb.bg_color = Color(ThemeFactory.C_CYAN, 0.15)
		sb.border_color = ThemeFactory.C_CYAN
	elif is_prem and not GameData.pass_premium:
		sb.bg_color = Color(0.2, 0.2, 0.2, 0.5)
		sb.border_color = ThemeFactory.C_LINE
	else:
		sb.bg_color = ThemeFactory.C_BG1
		sb.border_color = ThemeFactory.C_LINE
	panel.add_theme_stylebox_override("panel", sb)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	# 라벨: 무료/프리미엄
	var type_lbl := Label.new()
	type_lbl.text = "프리미엄" if is_prem else "무료"
	type_lbl.add_theme_font_size_override("font_size", 11)
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_prem:
		type_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	inner.add_child(type_lbl)

	# 보상 텍스트
	var rw_text := ""
	if tier.has("prem_multi") and is_prem:
		var parts := []
		for r in tier.prem_multi:
			parts.append("%s×%s" % [REWARD_ICONS.get(r.k, "?"), _comma(r.a)])
		rw_text = "\n".join(parts)
	elif tier.has("prem") and is_prem:
		rw_text = "%s×%s" % [REWARD_ICONS.get(tier.prem.k, "?"), _comma(tier.prem.a)]
	else:
		rw_text = "%s×%s" % [REWARD_ICONS.get(tier.free.k, "?"), _comma(tier.free.a)]

	var rw_lbl := Label.new()
	rw_lbl.text = rw_text
	rw_lbl.add_theme_font_size_override("font_size", 13)
	rw_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not unlocked and is_prem and not GameData.pass_premium:
		rw_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
	inner.add_child(rw_lbl)

	# 수령 버튼
	if not (is_prem and not GameData.pass_premium):
		var btn := Button.new()
		btn.text = "✓ 수령 완료" if claimed else ("수령" if unlocked else "🔒")
		btn.disabled = claimed or not unlocked
		btn.add_theme_font_size_override("font_size", 13)
		btn.pressed.connect(_on_claim_tier.bind(tier, is_prem, claim_key))
		inner.add_child(btn)
	else:
		var lock_lbl := Label.new()
		lock_lbl.text = "🔒 프리미엄 전용"
		lock_lbl.add_theme_font_size_override("font_size", 11)
		lock_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 1.0))
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(lock_lbl)

	return panel


func _on_claim_tier(tier: Dictionary, is_prem: bool, claim_key: String) -> void:
	if GameData.pass_claims.has(claim_key):
		return

	GameData.pass_claims[claim_key] = true

	if is_prem:
		if tier.has("prem_multi"):
			for r in tier.prem_multi:
				GameData.add_currency(r.k, r.a)
		elif tier.has("prem"):
			GameData.add_currency(tier.prem.k, tier.prem.a)
	else:
		GameData.add_currency(tier.free.k, tier.free.a)

	_toast("Tier %d 보상 수령!" % tier.n)
	_refresh()


func _on_buy_premium() -> void:
	if GameData.pass_premium:
		return
	if GameData.gems < 2200:
		_toast("보석이 부족해  (필요: 2200)")
		return
	GameData.gems -= 2200
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
