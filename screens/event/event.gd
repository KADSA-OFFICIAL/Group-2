## res://screens/event/event.gd
## 이벤트 화면. 미션 + 상점 두 섹션으로 구성.

extends Control

const MISSIONS = [
	{id = "e1", nm = "축제 사냥 — 스테이지 2회 클리어",  goal = 2, rw = {k = "event_coin", a = 30}},
	{id = "e2", nm = "축제 모집 — 모집 1회",             goal = 1, rw = {k = "event_coin", a = 20}},
	{id = "e3", nm = "축제 단련 — 레벨업 2회",           goal = 2, rw = {k = "event_coin", a = 20}},
	{id = "e4", nm = "축제 출석 — 출석 1회",             goal = 1, rw = {k = "event_coin", a = 20}},
	{id = "e5", nm = "축제 대장정 — 스테이지 5회 클리어", goal = 5, rw = {k = "event_coin", a = 60}},
]

const SHOP_ITEMS = [
	{id = "x1", nm = "보석 50",          ic = "💎", cost = 30,  lim = 2, rw = {k = "gems",    a = 50}},
	{id = "x2", nm = "골드 20만",        ic = "🪙", cost = 20,  lim = 3, rw = {k = "gold",    a = 200000}},
	{id = "x3", nm = "조각 +10",         ic = "🧩", cost = 50,  lim = 2, rw = {k = "shard",   a = 10}},
	{id = "x4", nm = "마정석 ×5",        ic = "🔮", cost = 25,  lim = 3, rw = {k = "ore",     a = 5}},
	{id = "x5", nm = "모집권 (보석 160)", ic = "🎟️", cost = 80,  lim = 1, rw = {k = "gems",    a = 160}},
	{id = "x6", nm = "기력 +60",         ic = "⚡", cost = 15,  lim = 3, rw = {k = "stamina", a = 60}},
]

var _coin_label: Label
var _mission_rows: VBoxContainer
var _shop_rows: VBoxContainer
var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	# ── 스크롤 루트 ──
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
	title_label.text = "🎉 이벤트"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title_label)

	# ── 이벤트 배너 카드 ──
	var banner := PanelContainer.new()
	banner.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 18))
	vbox.add_child(banner)

	var banner_inner := VBoxContainer.new()
	banner_inner.add_theme_constant_override("separation", 6)
	banner.add_child(banner_inner)

	var banner_title := Label.new()
	banner_title.text = "별빛 수호자 대전"
	banner_title.add_theme_font_size_override("font_size", 20)
	banner_title.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_inner.add_child(banner_title)

	var banner_period := Label.new()
	banner_period.text = "2026.06.01 ~ 2026.06.30"
	banner_period.add_theme_font_size_override("font_size", 13)
	banner_period.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	banner_period.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_inner.add_child(banner_period)

	var banner_desc := Label.new()
	banner_desc.text = "이벤트 미션을 완료하고 특별 보상을 획득하세요!"
	banner_desc.add_theme_font_size_override("font_size", 14)
	banner_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_inner.add_child(banner_desc)

	# ── 이벤트 코인 표시 ──
	var coin_panel := PanelContainer.new()
	coin_panel.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))
	vbox.add_child(coin_panel)

	var coin_hbox := HBoxContainer.new()
	coin_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_panel.add_child(coin_hbox)

	_coin_label = Label.new()
	_coin_label.add_theme_font_size_override("font_size", 16)
	_coin_label.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	coin_hbox.add_child(_coin_label)
	_refresh_coin()

	# ── 미션 섹션 ──
	var mission_header := Label.new()
	mission_header.text = "이벤트 미션"
	mission_header.add_theme_font_size_override("font_size", 18)
	mission_header.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	vbox.add_child(mission_header)

	_mission_rows = VBoxContainer.new()
	_mission_rows.add_theme_constant_override("separation", 8)
	vbox.add_child(_mission_rows)

	# ── 상점 섹션 ──
	var shop_header := Label.new()
	shop_header.text = "이벤트 상점"
	shop_header.add_theme_font_size_override("font_size", 18)
	shop_header.add_theme_color_override("font_color", ThemeFactory.C_PINK)
	vbox.add_child(shop_header)

	_shop_rows = VBoxContainer.new()
	_shop_rows.add_theme_constant_override("separation", 8)
	vbox.add_child(_shop_rows)

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

	_build_missions()
	_build_shop()


func _get_mission_prog(m: Dictionary) -> int:
	match m.id:
		"e1": return GameData.stats.get("clears", 0)
		"e2": return GameData.stats.get("pulls", 0)
		"e3": return GameData.stats.get("levelups", 0)
		"e4": return GameData.attend.get("day", 0)
		"e5": return GameData.stats.get("clears", 0)
	return 0


func _refresh_coin() -> void:
	_coin_label.text = "이벤트 코인:  🌟 %d" % GameData.event_coin


func _build_missions() -> void:
	for c in _mission_rows.get_children():
		c.queue_free()

	for m in MISSIONS:
		var prog := _get_mission_prog(m)
		var done: bool = prog >= m.goal
		var claimed := GameData.event_claims.has(m.id)

		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
		_mission_rows.add_child(row)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 10)
		row.add_child(row_hbox)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 4)
		row_hbox.add_child(info_vbox)

		var name_label := Label.new()
		name_label.text = m.nm
		name_label.add_theme_font_size_override("font_size", 15)
		info_vbox.add_child(name_label)

		var prog_bar := ProgressBar.new()
		prog_bar.min_value = 0
		prog_bar.max_value = m.goal
		prog_bar.value = mini(prog, m.goal)
		prog_bar.show_percentage = false
		prog_bar.custom_minimum_size = Vector2(0, 12)
		info_vbox.add_child(prog_bar)

		var prog_label := Label.new()
		prog_label.text = "%d / %d  →  🌟×%d" % [mini(prog, m.goal), m.goal, m.rw.a]
		prog_label.add_theme_font_size_override("font_size", 12)
		prog_label.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		info_vbox.add_child(prog_label)

		var claim_btn := Button.new()
		claim_btn.text = "수령" if (done and not claimed) else ("완료" if claimed else "진행 중")
		claim_btn.disabled = not done or claimed
		claim_btn.custom_minimum_size = Vector2(70, 0)
		claim_btn.pressed.connect(_on_mission_claim.bind(m.id, m.rw))
		row_hbox.add_child(claim_btn)


func _build_shop() -> void:
	for c in _shop_rows.get_children():
		c.queue_free()

	for item in SHOP_ITEMS:
		var bought: int = GameData.event_buys.get(item.id, 0)
		var maxed: bool = bought >= item.lim

		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
		_shop_rows.add_child(row)

		var row_hbox := HBoxContainer.new()
		row_hbox.add_theme_constant_override("separation", 10)
		row.add_child(row_hbox)

		var icon_label := Label.new()
		icon_label.text = item.ic
		icon_label.add_theme_font_size_override("font_size", 28)
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row_hbox.add_child(icon_label)

		var info_vbox := VBoxContainer.new()
		info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vbox.add_theme_constant_override("separation", 4)
		row_hbox.add_child(info_vbox)

		var item_name := Label.new()
		item_name.text = item.nm
		item_name.add_theme_font_size_override("font_size", 15)
		info_vbox.add_child(item_name)

		var cost_row := HBoxContainer.new()
		cost_row.add_theme_constant_override("separation", 8)
		info_vbox.add_child(cost_row)

		var cost_label := Label.new()
		cost_label.text = "🌟×%d" % item.cost
		cost_label.add_theme_font_size_override("font_size", 13)
		cost_label.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
		cost_row.add_child(cost_label)

		var count_label := Label.new()
		count_label.text = "%d / %d" % [bought, item.lim]
		count_label.add_theme_font_size_override("font_size", 12)
		count_label.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		cost_row.add_child(count_label)

		var buy_btn := Button.new()
		buy_btn.text = "구매" if not maxed else "한도 초과"
		buy_btn.disabled = maxed
		buy_btn.custom_minimum_size = Vector2(80, 0)
		buy_btn.pressed.connect(_on_shop_buy.bind(item))
		row_hbox.add_child(buy_btn)


func _on_mission_claim(mission_id: String, rw: Dictionary) -> void:
	if GameData.event_claims.has(mission_id):
		return
	GameData.event_claims[mission_id] = true
	GameData.add_currency(rw.k, rw.a)
	_refresh_coin()
	_build_missions()
	_toast("🌟 ×%d 수령!" % rw.a)


func _on_shop_buy(item: Dictionary) -> void:
	var bought: int = GameData.event_buys.get(item.id, 0)
	if bought >= item.lim:
		_toast("구매 한도에 도달했어")
		return
	if GameData.event_coin < item.cost:
		_toast("이벤트 코인이 부족해")
		return

	GameData.event_coin -= item.cost
	GameData.event_buys[item.id] = bought + 1

	var rw: Dictionary = item.rw
	match rw.k:
		"gems", "gold", "stamina":
			GameData.add_currency(rw.k, rw.a)
		"ore":
			GameData.mats["ore"] = GameData.mats.get("ore", 0) + rw.a
		"shard":
			if GameData.roster.size() > 0:
				var idx := randi() % GameData.roster.size()
				GameData.roster[idx]["shards"] = GameData.roster[idx].get("shards", 0) + rw.a

	_refresh_coin()
	_build_shop()
	_toast("%s 구매 완료!" % item.nm)


func _toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false
