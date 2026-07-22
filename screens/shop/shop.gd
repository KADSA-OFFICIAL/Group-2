## res://screens/shop/shop.gd
## 상점 화면. 교환(골드/보석) 탭 + 패키지(현금) 탭.
## 모든 UI 는 _ready() 에서 코드로 빌드.

extends Control

# ── 탭 ──
enum Tab { EXCHANGE, PACKAGE }
var _current_tab: Tab = Tab.EXCHANGE

# ── 탭 컨테이너 참조 ──
var _exchange_container: Control
var _package_container: Control

# ── 통화 라벨 ──
var _gold_label: Label
var _gems_label: Label

# ── 토스트 ──
var _toast_label: Label
var _toast_timer: SceneTreeTimer

# ── 탭 버튼 참조 ──
var _tab_btn_ex: Button
var _tab_btn_pkg: Button

# ── 교환소 아이템 정의 (HTML 기준) ──
const EXCHANGE_ITEMS := [
	{id="ex_gold_sm",  icon="🪙", name="골드 꾸러미",      desc="골드 +500,000",              cost=100,    currency="gems", reward_kind="gold",    reward_amt=500000,  limit=5},
	{id="ex_gold_lg",  icon="💰", name="큰 골드 꾸러미",   desc="골드 +2,500,000",            cost=450,    currency="gems", reward_kind="gold",    reward_amt=2500000, limit=2},
	{id="ex_shard",    icon="🧩", name="조각 상자",         desc="랜덤 캐릭터 조각 +10",       cost=300000, currency="gold", reward_kind="shards",  reward_amt=10,      limit=3},
	{id="ex_stamina",  icon="⚡", name="기력 회복",         desc="기력 +60 (최대 206)",        cost=50,     currency="gems", reward_kind="stamina", reward_amt=60,      limit=3},
]

# ── 패키지 아이템 정의 (HTML 기준) ──
const PACKAGE_ITEMS := [
	{id="pkg_starter", icon="🎁", name="초보자 패키지",       price_label="₩5,900 (데모 수령)",
		rewards=[{kind="gems", amt=300}, {kind="gold", amt=500000}],     limit=1},
	{id="pkg_monthly", icon="📅", name="월간 패스",            price_label="₩4,900 (데모 수령)",
		rewards=[{kind="gems", amt=300}],                                  limit=1},
	{id="pkg_gems1200",icon="💎", name="보석 1,200개",         price_label="₩12,000",
		rewards=[{kind="gems", amt=1200}],                                 limit=1},
	{id="pkg_pickup",  icon="👑", name="픽업 응원 패키지",     price_label="₩9,900",
		rewards=[{kind="gems", amt=600}],                                  limit=1},
]


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_build_ui()
	_toast_label.visible = false
	_switch_tab(Tab.EXCHANGE)


# ─────────────────────────────────────────────
# UI 빌드
# ─────────────────────────────────────────────
func _build_ui() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_vbox.add_theme_constant_override("separation", 0)
	add_child(root_vbox)

	_build_top_bar(root_vbox)
	_build_currency_bar(root_vbox)
	_build_tab_buttons(root_vbox)
	_build_tab_contents(root_vbox)
	_build_toast()


func _build_top_bar(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.custom_minimum_size = Vector2(0, 60)
	parent.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var back := Button.new()
	back.text = "← 메인"
	back.pressed.connect(func(): ScreenManager.pop())
	hbox.add_child(back)

	var title := Label.new()
	title.text = "상점"
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(title)


func _build_currency_bar(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 8)
	parent.add_child(margin)

	var panel := PanelContainer.new()
	var sb := ThemeFactory.glass_panel(false, 14)
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	margin.add_child(panel)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	panel.add_child(hbox)

	var gold_hbox := HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 6)
	gold_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(gold_hbox)
	var gold_icon := Label.new()
	gold_icon.text = "🪙"
	gold_icon.add_theme_font_size_override("font_size", 18)
	gold_hbox.add_child(gold_icon)
	_gold_label = Label.new()
	_gold_label.text = _comma(GameData.gold)
	_gold_label.add_theme_font_size_override("font_size", 16)
	_gold_label.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	gold_hbox.add_child(_gold_label)

	var gem_hbox := HBoxContainer.new()
	gem_hbox.add_theme_constant_override("separation", 6)
	gem_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(gem_hbox)
	var gem_icon := Label.new()
	gem_icon.text = "💎"
	gem_icon.add_theme_font_size_override("font_size", 18)
	gem_hbox.add_child(gem_icon)
	_gems_label = Label.new()
	_gems_label.text = _comma(GameData.gems)
	_gems_label.add_theme_font_size_override("font_size", 16)
	_gems_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	gem_hbox.add_child(_gems_label)

	GameData.currency_changed.connect(func(_k, _a):
		_gold_label.text = _comma(GameData.gold)
		_gems_label.text = _comma(GameData.gems)
	)


func _build_tab_buttons(parent: Container) -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 0)
	margin.add_theme_constant_override("margin_bottom", 0)
	parent.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	_tab_btn_ex = Button.new()
	_tab_btn_ex.text = "교환"
	_tab_btn_ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_btn_ex.custom_minimum_size = Vector2(0, 44)
	_tab_btn_ex.pressed.connect(func(): _switch_tab(Tab.EXCHANGE))
	hbox.add_child(_tab_btn_ex)

	_tab_btn_pkg = Button.new()
	_tab_btn_pkg.text = "패키지"
	_tab_btn_pkg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tab_btn_pkg.custom_minimum_size = Vector2(0, 44)
	_tab_btn_pkg.pressed.connect(func(): _switch_tab(Tab.PACKAGE))
	hbox.add_child(_tab_btn_pkg)


func _build_tab_contents(parent: Container) -> void:
	# 두 컨테이너를 같은 스크롤 안에 넣고 visible 로 전환
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)

	# 스크롤 안에 VBox 로 둘 다 담기
	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(wrapper)

	_exchange_container = _build_exchange_tab()
	wrapper.add_child(_exchange_container)

	_package_container = _build_package_tab()
	wrapper.add_child(_package_container)


func _build_exchange_tab() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "🏪  교환  —  재화로 아이템 교환"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	vbox.add_child(header)

	for item in EXCHANGE_ITEMS:
		vbox.add_child(_make_exchange_card(item))

	return margin


func _make_exchange_card(item: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Card_" + item.id
	var sb := ThemeFactory.glass_panel(false, 16)
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var buy_count := _get_buy_count(item.id)
	var limit: int = item.get("limit", 3)
	var sold_out := buy_count >= limit
	if sold_out:
		sb.bg_color = Color(0.12, 0.10, 0.22, 0.5)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = item.get("icon", "?")
	icon_lbl.add_theme_font_size_override("font_size", 34)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if sold_out:
		icon_lbl.modulate.a = 0.45
	hbox.add_child(icon_lbl)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 2)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 16)
	if sold_out:
		name_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	info_vbox.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = item.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	info_vbox.add_child(desc_lbl)

	var cost_icon: String = "💎" if item.get("currency", "gold") == "gems" else "🪙"
	var cost_lbl := Label.new()
	cost_lbl.text = "%s %s" % [cost_icon, _comma(item.get("cost", 0))]
	cost_lbl.add_theme_font_size_override("font_size", 14)
	cost_lbl.add_theme_color_override("font_color",
		ThemeFactory.C_CYAN if item.get("currency", "gold") == "gems" else ThemeFactory.C_GOLD)
	info_vbox.add_child(cost_lbl)

	var remain := limit - buy_count
	var limit_lbl := Label.new()
	limit_lbl.text = "구매 가능 %d / %d" % [remain, limit]
	limit_lbl.add_theme_font_size_override("font_size", 12)
	limit_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	info_vbox.add_child(limit_lbl)

	var btn := Button.new()
	btn.name = "BuyBtn_" + item.id
	btn.custom_minimum_size = Vector2(90, 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if sold_out:
		btn.text = "품절"
		btn.disabled = true
		var dim_sb := ThemeFactory.glass_panel(false, 12)
		dim_sb.bg_color = Color(0.2, 0.2, 0.2, 0.4)
		btn.add_theme_stylebox_override("normal", dim_sb)
		btn.add_theme_stylebox_override("disabled", dim_sb)
	else:
		btn.text = "구매"
		var buy_sb := ThemeFactory.glass_panel(true, 12)
		buy_sb.border_color = ThemeFactory.C_GOLD
		btn.add_theme_stylebox_override("normal", buy_sb)
		btn.pressed.connect(_on_exchange_buy.bind(item, panel))

	hbox.add_child(btn)
	return panel


func _build_package_tab() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 16)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var header := Label.new()
	header.text = "📦  패키지  —  특별 혜택"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	vbox.add_child(header)

	for item in PACKAGE_ITEMS:
		vbox.add_child(_make_package_card(item))

	return margin


func _make_package_card(item: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Card_" + item.id
	var sb := ThemeFactory.glass_panel(false, 16)
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)

	var is_bought := _is_package_bought(item.id)
	if is_bought:
		sb.bg_color = Color(0.15, 0.15, 0.15, 0.5)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	var icon_lbl := Label.new()
	icon_lbl.text = item.get("icon", "?")
	icon_lbl.add_theme_font_size_override("font_size", 34)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_bought:
		icon_lbl.modulate.a = 0.45
	hbox.add_child(icon_lbl)

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 3)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	var name_lbl := Label.new()
	name_lbl.text = item.get("name", "?")
	name_lbl.add_theme_font_size_override("font_size", 16)
	if is_bought:
		name_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	info_vbox.add_child(name_lbl)

	# 보상 목록
	var rewards_hbox := HBoxContainer.new()
	rewards_hbox.add_theme_constant_override("separation", 8)
	info_vbox.add_child(rewards_hbox)
	for rw in item.get("rewards", []):
		var rw_lbl := Label.new()
		rw_lbl.text = _reward_text(rw)
		rw_lbl.add_theme_font_size_override("font_size", 13)
		rw_lbl.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		rewards_hbox.add_child(rw_lbl)

	# 가격 라벨
	var price_lbl := Label.new()
	price_lbl.text = item.get("price_label", "")
	price_lbl.add_theme_font_size_override("font_size", 14)
	price_lbl.add_theme_color_override("font_color",
		ThemeFactory.C_GOOD if item.get("price_label", "").contains("데모") else ThemeFactory.C_CYAN)
	info_vbox.add_child(price_lbl)

	# 구매 버튼
	var btn := Button.new()
	btn.name = "BuyBtn_" + item.id
	btn.custom_minimum_size = Vector2(100, 40)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if is_bought:
		btn.text = "구매 완료"
		btn.disabled = true
		var dim_sb := ThemeFactory.glass_panel(false, 12)
		dim_sb.bg_color = Color(0.2, 0.2, 0.2, 0.4)
		btn.add_theme_stylebox_override("normal", dim_sb)
		btn.add_theme_stylebox_override("disabled", dim_sb)
	else:
		btn.text = "데모 수령" if item.get("price_label", "").contains("데모") else "구매"
		btn.add_theme_stylebox_override("normal", ThemeFactory.cta_box())
		btn.add_theme_stylebox_override("hover",   ThemeFactory.cta_box())
		btn.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
		btn.pressed.connect(_on_package_buy.bind(item, panel))

	hbox.add_child(btn)
	return panel


func _reward_text(rw: Dictionary) -> String:
	match rw.get("kind", ""):
		"gold":    return "🪙 +%s" % _comma(rw.get("amt", 0))
		"gems":    return "💎 +%s" % _comma(rw.get("amt", 0))
		"stamina": return "⚡ +%d" % rw.get("amt", 0)
		"book":    return "📘 ×%d" % rw.get("amt", 0)
		"ore":     return "🔮 ×%d" % rw.get("amt", 0)
		"dust":    return "🌫 ×%d" % rw.get("amt", 0)
	return "?"


# ─────────────────────────────────────────────
# 탭 전환
# ─────────────────────────────────────────────
func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	_exchange_container.visible = (tab == Tab.EXCHANGE)
	_package_container.visible = (tab == Tab.PACKAGE)

	if _tab_btn_ex and _tab_btn_pkg:
		if tab == Tab.EXCHANGE:
			_tab_btn_ex.add_theme_stylebox_override("normal", ThemeFactory.accent_box(14))
			_tab_btn_pkg.remove_theme_stylebox_override("normal")
		else:
			_tab_btn_pkg.add_theme_stylebox_override("normal", ThemeFactory.accent_box(14))
			_tab_btn_ex.remove_theme_stylebox_override("normal")


# ─────────────────────────────────────────────
# 구매 핸들러
# ─────────────────────────────────────────────
func _on_exchange_buy(item: Dictionary, card: PanelContainer) -> void:
	var cost: int = item.get("cost", 0)
	var currency: String = item.get("currency", "gold")

	if currency == "gems" and GameData.gems < cost:
		_toast("💎 보석 부족 (%s 필요)" % _comma(cost))
		return
	if currency == "gold" and GameData.gold < cost:
		_toast("🪙 골드 부족 (%s 필요)" % _comma(cost))
		return

	var buy_count := _get_buy_count(item.id)
	if buy_count >= item.get("limit", 3):
		_toast("구매 한도에 도달했습니다")
		return

	GameData.add_currency(currency, -cost)

	var rk: String = item.get("reward_kind", "")
	var ra: int = item.get("reward_amt", 0)
	match rk:
		"gold":    GameData.add_currency("gold", ra)
		"stamina": GameData.add_currency("stamina", ra)
		"gems":    GameData.add_currency("gems", ra)
		"shards":
			# 랜덤 캐릭터에 조각 추가
			if GameData.roster.size() > 0:
				var target := GameData.roster[randi() % GameData.roster.size()]
				target["shards"] = target.get("shards", 0) + ra
				GameData.roster_changed.emit()
		"book":  GameData.mats["book"]  = GameData.mats.get("book",  0) + ra
		"ore":   GameData.mats["ore"]   = GameData.mats.get("ore",   0) + ra
		"dust":  GameData.mats["dust"]  = GameData.mats.get("dust",  0) + ra

	GameData.shop_buys[item.id] = buy_count + 1

	var new_count := _get_buy_count(item.id)
	var limit: int = item.get("limit", 3)

	var btn := card.get_node_or_null("HBoxContainer/BuyBtn_" + item.id) as Button
	if btn and new_count >= limit:
		btn.text = "품절"
		btn.disabled = true

	_toast("✅ %s 구매 완료 (%d / %d)" % [item.get("name", ""), new_count, limit])


func _on_package_buy(item: Dictionary, card: PanelContainer) -> void:
	if _is_package_bought(item.id):
		_toast("이미 구매한 패키지입니다")
		return

	# 보상 지급
	for rw in item.get("rewards", []):
		var kind: String = rw.get("kind", "")
		var amt: int = rw.get("amt", 0)
		match kind:
			"gold", "gems", "stamina":
				GameData.add_currency(kind, amt)
			"book": GameData.mats["book"]  = GameData.mats.get("book",  0) + amt
			"ore":  GameData.mats["ore"]   = GameData.mats.get("ore",   0) + amt
			"dust": GameData.mats["dust"]  = GameData.mats.get("dust",  0) + amt

	if item.get("limit", 0) > 0:
		GameData.shop_buys[item.id] = true

	var rw_parts: Array[String] = []
	for rw in item.get("rewards", []):
		rw_parts.append(_reward_text(rw))
	_toast("✅ %s 수령: %s" % [item.get("name", ""), " / ".join(rw_parts)])

	# 버튼 갱신
	var btn := card.get_node_or_null("HBoxContainer/BuyBtn_" + item.id) as Button
	if btn and item.get("limit", 0) > 0:
		btn.text = "구매 완료"
		btn.disabled = true


# ─────────────────────────────────────────────
# 구매 상태 조회
# ─────────────────────────────────────────────
func _get_buy_count(item_id: String) -> int:
	var v = GameData.shop_buys.get(item_id, 0)
	if v is int:
		return v
	return 0


func _is_package_bought(item_id: String) -> bool:
	var v = GameData.shop_buys.get(item_id, false)
	if v is bool:
		return v
	if v is int:
		return v > 0
	return false


# ─────────────────────────────────────────────
# 토스트
# ─────────────────────────────────────────────
func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -230.0
	_toast_label.offset_top = -28.0
	_toast_label.offset_right = 230.0
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


func _toast(msg: String) -> void:
	_toast_label.text = "  %s  " % msg
	_toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false


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
