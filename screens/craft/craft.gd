## res://screens/craft/craft.gd
## 제조소 화면. 데이터 출처(단일 원천)는 EquipmentDatabase(장비 정의) + EquipmentSystem(제작/보유),
## 재화는 CurrencySystem 이다. 이 화면은 정의를 읽어 목록을 그리고, 제작은 EquipmentSystem.craft() 로 위임한다.
## (제작 재화 차감·인벤토리 관리는 EquipmentSystem 이 담당 — 여기서 재정의하지 않는다.)

extends Control

var _list_vbox: VBoxContainer
var _gold_label: Label
var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)
	_build_ui()

	# 제작·재화 변동 시 목록/잔액 갱신
	if not EventBus.equipment_crafted.is_connected(_on_equipment_crafted):
		EventBus.equipment_crafted.connect(_on_equipment_crafted)
	CurrencySystem.currency_changed.connect(func(_t, _a, _b): _refresh())


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_make_topbar())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	var scroll_margin := MarginContainer.new()
	scroll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_margin.add_theme_constant_override("margin_left", 16)
	scroll_margin.add_theme_constant_override("margin_right", 16)
	scroll_margin.add_theme_constant_override("margin_top", 8)
	scroll_margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(scroll_margin)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 12)
	scroll_margin.add_child(_list_vbox)

	_build_recipe_list()

	_toast_label = Label.new()
	_toast_label.name = "Toast"
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -240.0; _toast_label.offset_top = -24.0
	_toast_label.offset_right = 240.0; _toast_label.offset_bottom = 24.0
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
	title.text = "제조소"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ThemeFactory.C_INK)
	hbox.add_child(title)

	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer2)

	# 골드 잔액 (CurrencySystem 단일 원천)
	var gold_pill := PanelContainer.new()
	gold_pill.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))
	hbox.add_child(gold_pill)
	_gold_label = Label.new()
	_gold_label.text = "🪙 %s" % _comma(CurrencySystem.get_balance("gold"))
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
	gold_pill.add_child(_gold_label)

	return mc


func _build_recipe_list() -> void:
	for c in _list_vbox.get_children():
		c.queue_free()

	var ids := EquipmentDatabase.get_all_ids()
	if ids.is_empty():
		var empty := Label.new()
		empty.text = "등록된 장비가 없습니다.\n(data/equipment/*.tres 추가 시 제조 목록에 표시됩니다)"
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", ThemeFactory.C_INK_FAINT)
		_list_vbox.add_child(empty)
		return

	for id in ids:
		_list_vbox.add_child(_make_recipe_card(id))


func _make_recipe_card(id: StringName) -> PanelContainer:
	var data: EquipmentData = EquipmentDatabase.get_equipment(id)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 16))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	panel.add_child(hbox)

	# 아이콘 (텍스처 있으면 사용, 없으면 슬롯 이모지)
	if data.icon != null:
		var tex := TextureRect.new()
		tex.texture = data.icon
		tex.custom_minimum_size = Vector2(48, 48)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hbox.add_child(tex)
	else:
		var icon_lbl := Label.new()
		icon_lbl.text = _slot_icon(data.slot)
		icon_lbl.add_theme_font_size_override("font_size", 36)
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.custom_minimum_size = Vector2(48, 0)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hbox.add_child(icon_lbl)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var nm_lbl := Label.new()
	nm_lbl.text = "%s  ·  %s" % [data.display_name, data.get_slot_name()]
	nm_lbl.add_theme_font_size_override("font_size", 16)
	info.add_child(nm_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = "재료: %s" % _cost_text(data.craft_cost)
	cost_lbl.add_theme_font_size_override("font_size", 13)
	cost_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	info.add_child(cost_lbl)

	var owned_lbl := Label.new()
	owned_lbl.text = "보유 %d개  ·  %s" % [EquipmentSystem.get_owned_count(id), _bonus_text(data)]
	owned_lbl.add_theme_font_size_override("font_size", 13)
	owned_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	info.add_child(owned_lbl)

	var btn := Button.new()
	btn.text = "제조"
	btn.custom_minimum_size = Vector2(70, 42)
	btn.add_theme_stylebox_override("normal",  ThemeFactory.accent_box(12))
	btn.add_theme_stylebox_override("hover",   ThemeFactory.accent_box(12))
	btn.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(12))
	btn.add_theme_color_override("font_color", ThemeFactory.C_BG0)
	if EquipmentSystem.can_craft(id):
		btn.pressed.connect(_on_craft.bind(id))
	else:
		btn.disabled = true
	hbox.add_child(btn)

	return panel


func _on_craft(id: StringName) -> void:
	# 제작·재화 차감은 EquipmentSystem 이 담당 (단일 원천 위임).
	if EquipmentSystem.craft(id):
		var data: EquipmentData = EquipmentDatabase.get_equipment(id)
		_toast("제조 완료! %s" % (data.display_name if data else String(id)))
	else:
		_toast("재화가 부족합니다")


func _on_equipment_crafted(_id: StringName) -> void:
	_refresh()


func _refresh() -> void:
	if is_instance_valid(_gold_label):
		_gold_label.text = "🪙 %s" % _comma(CurrencySystem.get_balance("gold"))
	if is_instance_valid(_list_vbox):
		_build_recipe_list()


# ── 표시 헬퍼 ──
func _slot_icon(slot: int) -> String:
	match slot:
		EquipmentData.Slot.WEAPON:    return "⚔"
		EquipmentData.Slot.ARMOR:     return "🛡"
		EquipmentData.Slot.ACCESSORY: return "💍"
	return "❔"


func _bonus_text(data: EquipmentData) -> String:
	var parts: Array[String] = []
	if data.physical_attack_bonus != 0: parts.append("물공+%d" % data.physical_attack_bonus)
	if data.magic_attack_bonus != 0:    parts.append("마공+%d" % data.magic_attack_bonus)
	if data.physical_defense_bonus != 0: parts.append("물방+%d" % data.physical_defense_bonus)
	if data.magic_defense_bonus != 0:   parts.append("마방+%d" % data.magic_defense_bonus)
	if data.hp_bonus != 0:              parts.append("HP+%d" % data.hp_bonus)
	return "  ".join(parts) if not parts.is_empty() else "보너스 없음"


func _cost_text(craft_cost: Dictionary) -> String:
	if craft_cost.is_empty():
		return "무료"
	var parts: Array[String] = []
	for currency_type in craft_cost:
		var need: int = int(craft_cost[currency_type])
		var have: int = CurrencySystem.get_balance(currency_type)
		parts.append("%s %s/%s" % [_currency_icon(String(currency_type)), _comma(have), _comma(need)])
	return "  ".join(parts)


func _currency_icon(key: String) -> String:
	match key:
		"gold":          return "🪙"
		"gems":          return "💎"
		"faith_stone":   return "🔯"
		"stone":         return "🪨"
		"tin":           return "🥉"
		"copper":        return "🟤"
		"iron_ore":      return "⛏"
		"coal":          return "⚫"
	return "•%s" % key


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
