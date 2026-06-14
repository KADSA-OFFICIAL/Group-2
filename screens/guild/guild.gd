## res://screens/guild/guild.gd
## 교단(길드) 화면 — 체크인, 멤버 목록, 토큰 상점. 모든 UI 는 _ready() 에서 코드로 생성한다.

extends Control

# ── 상점 아이템 정의 ──────────────────────────────────────────────────────
var SHOP_ITEMS = [
	{id="g1", nm="조각 상자",   ic="🧩", cost=80,  limit=3,
	 action=func():
		if GameData.roster.size() > 0:
			var idx := randi() % GameData.roster.size()
			GameData.roster[idx]["shards"] = GameData.roster[idx].get("shards", 0) + 10},
	{id="g2", nm="골드 상자",   ic="🪙", cost=50,  limit=5,
	 action=func(): GameData.add_currency("gold", 300000)},
	{id="g3", nm="보석 주머니", ic="💎", cost=100, limit=2,
	 action=func(): GameData.add_currency("gems", 50)},
	{id="g4", nm="기력 회복",   ic="⚡", cost=60,  limit=3,
	 action=func(): GameData.add_currency("stamina", 60)},
	{id="g5", nm="강화서 묶음", ic="📘", cost=30,  limit=3,
	 action=func(): GameData.add_currency("gold", 120000)},
]

const MEMBERS = [
	{rank="단장",   name="별고래", lv=73},
	{rank="부단장", name="세라",   lv=70},
	{rank="단원",   name="카이",   lv=66},
	{rank="단원",   name="리코",   lv=58},
	{rank="단원",   name="노바",   lv=51},
]

# ── 런타임 ────────────────────────────────────────────────────────────────
var _checkin_btn: Button
var _token_title: Label
var _shop_cards: Array[Dictionary] = []   # [{btn, id}]

var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_build_ui()


# ── UI 빌드 ───────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_make_topbar())

	# 스크롤
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 16)
	scroll_margin.add_theme_constant_override("margin_right", 16)
	scroll_margin.add_theme_constant_override("margin_top", 12)
	scroll_margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(scroll_margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 16)
	scroll_margin.add_child(content)

	content.add_child(_make_guild_card())
	content.add_child(_make_checkin_section())
	content.add_child(_make_members_section())
	content.add_child(_make_shop_section())

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
	title.text = "교단"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ThemeFactory.C_INK)
	hbox.add_child(title)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer2)

	return mc


# ── 길드 카드 ──────────────────────────────────────────────────────────────
func _make_guild_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 22))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	vbox.add_child(name_row)

	var guild_name := Label.new()
	guild_name.text = "새벽단"
	guild_name.add_theme_font_size_override("font_size", 24)
	guild_name.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	name_row.add_child(guild_name)

	var level_lbl := Label.new()
	level_lbl.text = "Lv.12"
	level_lbl.add_theme_font_size_override("font_size", 16)
	level_lbl.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	level_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(level_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(spacer)

	var member_lbl := Label.new()
	member_lbl.text = "24/30명"
	member_lbl.add_theme_font_size_override("font_size", 14)
	member_lbl.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.7))
	member_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_row.add_child(member_lbl)

	var desc := Label.new()
	desc.text = "어둠을 밝히는 새벽의 수호자들"
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.65))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc)

	return panel


# ── 체크인 섹션 ──────────────────────────────────────────────────────────
func _make_checkin_section() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 18))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var label := Label.new()
	label.text = "오늘의 교단 보상"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	hbox.add_child(label)

	_checkin_btn = Button.new()
	_checkin_btn.custom_minimum_size = Vector2(200, 40)
	if GameData.guild_checked:
		_checkin_btn.text = "오늘 수령 완료"
		_checkin_btn.disabled = true
	else:
		_checkin_btn.text = "출석 체크  토큰 +20"
		_checkin_btn.disabled = false
		_checkin_btn.add_theme_stylebox_override("normal",  ThemeFactory.accent_box(14))
		_checkin_btn.add_theme_stylebox_override("hover",   ThemeFactory.accent_box(14))
		_checkin_btn.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(14))
		_checkin_btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
	_checkin_btn.pressed.connect(_on_checkin)
	hbox.add_child(_checkin_btn)

	return panel


# ── 멤버 섹션 ──────────────────────────────────────────────────────────────
func _make_members_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header := Label.new()
	header.text = "교단원 목록"
	header.add_theme_font_size_override("font_size", 17)
	header.add_theme_color_override("font_color", ThemeFactory.C_INK)
	section.add_child(header)

	for member in MEMBERS:
		var row := _make_member_row(member)
		section.add_child(row)

	return section


func _make_member_row(member: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 14))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var rank_lbl := Label.new()
	rank_lbl.text = str(member.get("rank", ""))
	rank_lbl.custom_minimum_size = Vector2(60, 0)
	rank_lbl.add_theme_font_size_override("font_size", 13)
	rank_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	hbox.add_child(rank_lbl)

	var name_lbl := Label.new()
	name_lbl.text = str(member.get("name", ""))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 15)
	hbox.add_child(name_lbl)

	var lv_lbl := Label.new()
	lv_lbl.text = "Lv.%d" % int(member.get("lv", 0))
	lv_lbl.add_theme_font_size_override("font_size", 14)
	lv_lbl.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.7))
	hbox.add_child(lv_lbl)

	return panel


# ── 상점 섹션 ──────────────────────────────────────────────────────────────
func _make_shop_section() -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 10)
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_token_title = Label.new()
	_token_title.text = "교단 상점 (보유 🔮%d)" % GameData.faction_token
	_token_title.add_theme_font_size_override("font_size", 17)
	_token_title.add_theme_color_override("font_color", ThemeFactory.C_INK)
	section.add_child(_token_title)

	_shop_cards.clear()
	for item in SHOP_ITEMS:
		var card_data := {"btn": null as Button, "id": str(item.get("id", ""))}
		var card := _make_shop_card(item, card_data)
		section.add_child(card)
		_shop_cards.append(card_data)

	return section


func _make_shop_card(item: Dictionary, card_data: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# 아이콘
	var icon_lbl := Label.new()
	icon_lbl.text = str(item.get("ic", ""))
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.custom_minimum_size = Vector2(40, 0)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(icon_lbl)

	# 이름 + 비용
	var info_vbox := VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_vbox.add_theme_constant_override("separation", 3)
	hbox.add_child(info_vbox)

	var nm_lbl := Label.new()
	nm_lbl.text = str(item.get("nm", ""))
	nm_lbl.add_theme_font_size_override("font_size", 15)
	info_vbox.add_child(nm_lbl)

	var cost_lbl := Label.new()
	var buys: int = int(GameData.guild_buys.get(str(item.get("id", "")), 0))
	var limit: int = int(item.get("limit", 0))
	cost_lbl.text = "🔮%d  (%d/%d회)" % [int(item.get("cost", 0)), buys, limit]
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", Color(ThemeFactory.C_INK, 0.7))
	info_vbox.add_child(cost_lbl)

	# 구매 버튼
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(70, 36)
	var at_limit := buys >= limit
	var can_afford := GameData.faction_token >= int(item.get("cost", 0))
	if at_limit:
		btn.text = "완료"
		btn.disabled = true
	elif not can_afford:
		btn.text = "구매"
		btn.disabled = true
	else:
		btn.text = "구매"
		btn.disabled = false
		btn.add_theme_stylebox_override("normal",  ThemeFactory.accent_box(12))
		btn.add_theme_stylebox_override("hover",   ThemeFactory.accent_box(12))
		btn.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(12))
		btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
	btn.pressed.connect(_on_shop_buy.bind(item))
	card_data["btn"] = btn
	hbox.add_child(btn)

	return panel


# ── 이벤트 처리 ──────────────────────────────────────────────────────────
func _on_checkin() -> void:
	if GameData.guild_checked:
		return
	GameData.guild_checked = true
	GameData.add_currency("faction_token", 20)
	_checkin_btn.text = "출석 완료  내일 다시!"
	_checkin_btn.disabled = true
	_checkin_btn.remove_theme_stylebox_override("normal")
	_checkin_btn.remove_theme_stylebox_override("hover")
	_checkin_btn.remove_theme_stylebox_override("pressed")
	_checkin_btn.remove_theme_color_override("font_color")
	_token_title.text = "교단 상점 (보유 🔮%d)" % GameData.faction_token
	_toast("교단 토큰 +20 수령!")


func _on_shop_buy(item: Dictionary) -> void:
	var item_id: String = str(item.get("id", ""))
	var cost: int = int(item.get("cost", 0))
	var limit: int = int(item.get("limit", 0))
	var buys: int = int(GameData.guild_buys.get(item_id, 0))

	if buys >= limit:
		_toast("이번 주 구매 한도 초과")
		return
	if GameData.faction_token < cost:
		_toast("교단 토큰이 부족해")
		return

	GameData.faction_token -= cost
	GameData.guild_buys[item_id] = buys + 1

	# 아이템 효과 적용
	var action: Callable = item.get("action", Callable())
	if action.is_valid():
		action.call()

	_token_title.text = "교단 상점 (보유 🔮%d)" % GameData.faction_token
	_toast("%s 구매 완료! (🔮-%d)" % [str(item.get("nm", "")), cost])

	# 버튼 상태 갱신 — 해당 카드 버튼을 찾아 업데이트
	for card_data in _shop_cards:
		if str(card_data.get("id", "")) == item_id:
			var btn: Button = card_data.get("btn") as Button
			if btn:
				var new_buys: int = int(GameData.guild_buys.get(item_id, 0))
				if new_buys >= limit:
					btn.text = "완료"
					btn.disabled = true
					btn.remove_theme_stylebox_override("normal")
					btn.remove_theme_stylebox_override("hover")
					btn.remove_theme_stylebox_override("pressed")
					btn.remove_theme_color_override("font_color")
				elif GameData.faction_token < cost:
					btn.disabled = true
					btn.remove_theme_stylebox_override("normal")
					btn.remove_theme_stylebox_override("hover")
					btn.remove_theme_stylebox_override("pressed")
					btn.remove_theme_color_override("font_color")
			break


# ── 토스트 ────────────────────────────────────────────────────────────────
func _toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false
