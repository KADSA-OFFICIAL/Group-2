extends Control

# 제조 화면 (메타 UI).
#
# 책임: 제작 가능한 장비를 나열하고, 제작을 EquipmentSystem 에 위임한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   장비 정의   -> EquipmentDatabase (목록·이름·보너스·제작 비용)
#   제작/보유   -> EquipmentSystem (can_craft / craft / get_owned_count)
#   재화        -> CurrencySystem (잔액, 차감은 EquipmentSystem 이 한다)
#   색          -> UITheme
#
# 제작 가능 여부와 재화 차감을 화면에서 계산하지 않는다.
# can_craft() 로 묻고 craft() 로 시킬 뿐이다.
#
# 참고: data/equipment/README.md, SYSTEM_CONVENTIONS.md

const BACK_ICON := "icon_back"
const CRAFT_ICON := "icon_craft"

# 장비 화면 경로. preload 가 아니라 **경로만** 둔다(순환 참조 방지).
# 자세한 이유는 equipment_screen.gd 의 같은 상수 주석 참고.
const EQUIPMENT_SCREEN_PATH := "res://screens/equipment/EquipmentScreen.tscn"

const SLOT_ICON_NAME := {
	EquipmentData.Slot.WEAPON: "icon_slot_weapon",
	EquipmentData.Slot.ARMOR: "icon_slot_armor",
	EquipmentData.Slot.ACCESSORY: "icon_slot_accessory",
}

var _currency_labels: Dictionary = {}
var _list_holder: VBoxContainer
var _toast: Label


func _ready() -> void:
	_build()
	_refresh_list()

	CurrencySystem.currency_changed.connect(_on_currency_changed)
	# 제작 성공은 EquipmentSystem 이 EventBus 로 알린다. 화면은 그 신호로만 갱신한다.
	EventBus.equipment_crafted.connect(_on_equipment_crafted)


# ===== 화면 구성 =====

func _build() -> void:
	add_child(UITheme.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_header())
	root.add_child(_build_currency_bar())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_list_holder = VBoxContainer.new()
	_list_holder.add_theme_constant_override("separation", 10)
	_list_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_holder)

	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 14)
	_toast.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	_toast.visible = false
	root.add_child(_toast)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var back := Button.new()
	back.text = " 뒤로"
	back.icon = _texture(BACK_ICON)
	# Button.icon 은 텍스처를 원본 크기(64px)로 그려 버튼 높이를 넘으면 잘린다.
	# expand_icon 을 켜면 버튼 크기에 맞춰 비율을 유지하며 줄어든다.
	back.expand_icon = true
	back.custom_minimum_size = Vector2(0, 40)
	back.add_theme_stylebox_override("normal", UITheme.panel_box())
	back.add_theme_stylebox_override("hover", UITheme.panel_box())
	back.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	back.add_theme_color_override("font_color", UITheme.INK)
	back.pressed.connect(func(): ScreenManager.pop())
	row.add_child(back)

	var icon := _icon(CRAFT_ICON, 24)
	if icon != null:
		row.add_child(icon)

	var title := Label.new()
	title.text = "제조"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	# 만든 장비는 장비 화면에서 착용한다. 그 다음 걸음을 여기서 바로 잇는다.
	var go_equip := Button.new()
	go_equip.text = "장비"
	go_equip.custom_minimum_size = Vector2(96, 40)
	go_equip.add_theme_font_size_override("font_size", 14)
	go_equip.add_theme_color_override("font_color", UITheme.INK)
	go_equip.add_theme_stylebox_override("normal", UITheme.panel_box())
	go_equip.add_theme_stylebox_override("hover", UITheme.panel_box())
	go_equip.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	go_equip.pressed.connect(func(): ScreenManager.swap(load(EQUIPMENT_SCREEN_PATH)))
	row.add_child(go_equip)
	return row


# 재화 표시줄. 어떤 재화를 보여줄지 고르지 않고 DEFAULT_CURRENCIES 를 그대로 순회한다.
func _build_currency_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	for currency_type in CurrencySystem.DEFAULT_CURRENCIES:
		bar.add_child(_make_currency_chip(String(currency_type)))

	var tail := Control.new()
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(tail)
	return bar


func _make_currency_chip(currency_type: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UITheme.pill_box())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)

	var icon := _icon(UITheme.currency_icon_name(currency_type), 20)
	if icon != null:
		row.add_child(icon)

	var label := _text(str(CurrencySystem.get_balance(currency_type)), 14, UITheme.INK)
	row.add_child(label)
	_currency_labels[currency_type] = label
	return chip


# ===== 목록 =====

func _refresh_list() -> void:
	if not is_instance_valid(_list_holder):
		return
	_clear(_list_holder)

	var ids := EquipmentDatabase.get_all_ids()
	if ids.is_empty():
		_list_holder.add_child(_text("제작할 수 있는 장비가 없습니다.", 14, UITheme.INK_ON_DARK))
		return

	for id in ids:
		_list_holder.add_child(_make_recipe_card(id))


func _make_recipe_card(id: StringName) -> Control:
	var data: EquipmentData = EquipmentDatabase.get_equipment(id)
	# 제작 가능 여부는 EquipmentSystem 이 판단한다(재화 비교를 여기서 하지 않는다).
	var craftable := EquipmentSystem.can_craft(id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_box())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var slot_icon := _icon(SLOT_ICON_NAME.get(data.slot, ""), 40)
	if slot_icon != null:
		row.add_child(slot_icon)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	title_row.add_child(_text(data.display_name, 16, UITheme.INK))
	title_row.add_child(_text("(%s)" % data.get_slot_name(), 13, UITheme.INK_DIM))
	title_row.add_child(_text("보유 %d" % EquipmentSystem.get_owned_count(id), 13, UITheme.INK_DIM))

	info.add_child(_text(_bonus_text(data), 13, UITheme.INK_DIM))

	# 비용: 보유/필요를 함께 보여주고, 모자란 재료만 눈에 띄게 한다.
	var cost_row := HBoxContainer.new()
	cost_row.add_theme_constant_override("separation", 8)
	info.add_child(cost_row)
	if data.craft_cost.is_empty():
		cost_row.add_child(_text("재료 없음", 13, UITheme.INK_DIM))
	else:
		for currency_type in data.craft_cost:
			cost_row.add_child(_make_cost_chip(String(currency_type), int(data.craft_cost[currency_type])))

	var button := Button.new()
	button.text = "제조"
	button.custom_minimum_size = Vector2(96, 44)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_stylebox_override("normal", UITheme.accent_box() if craftable else UITheme.panel_box_deep())
	button.add_theme_stylebox_override("hover", UITheme.accent_box() if craftable else UITheme.panel_box_deep())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	button.disabled = not craftable
	button.pressed.connect(_on_craft_pressed.bind(id))
	row.add_child(button)
	return card


func _make_cost_chip(currency_type: String, need: int) -> Control:
	var have := CurrencySystem.get_balance(currency_type)
	var enough := have >= need

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var icon := _icon(UITheme.currency_icon_name(currency_type), 18)
	if icon != null:
		row.add_child(icon)

	# 모자란 재료는 진하게(INK) 두어 눈에 띄게 하고, 충족한 재료는 흐리게 둔다.
	row.add_child(_text("%d/%d" % [have, need], 13, UITheme.INK_DIM if enough else UITheme.INK))
	return row


# ===== 조작 =====

func _on_craft_pressed(id: StringName) -> void:
	var data: EquipmentData = EquipmentDatabase.get_equipment(id)
	# 재화 차감과 보유 추가는 EquipmentSystem 이 한다. 실패해도 화면이 상태를 바꾸지 않는다.
	if EquipmentSystem.craft(id):
		_show_toast("%s 제조 완료" % (data.display_name if data else String(id)))
	else:
		_show_toast("재료가 부족합니다")


func _on_equipment_crafted(_id: StringName) -> void:
	_refresh_list()


func _on_currency_changed(currency_type: String, _amount: int, new_balance: int) -> void:
	var label: Label = _currency_labels.get(currency_type)
	if label != null and is_instance_valid(label):
		label.text = str(new_balance)
	# 잔액이 바뀌면 제작 가능 여부도 바뀌므로 목록을 다시 그린다.
	_refresh_list()


func _show_toast(message: String) -> void:
	if not is_instance_valid(_toast):
		return
	_toast.text = message
	_toast.visible = true


# ===== 공용 조각 =====

func _bonus_text(data: EquipmentData) -> String:
	var parts: Array[String] = []
	if data.physical_attack_bonus != 0: parts.append("물공 +%d" % data.physical_attack_bonus)
	if data.magic_attack_bonus != 0: parts.append("마공 +%d" % data.magic_attack_bonus)
	if data.physical_defense_bonus != 0: parts.append("물방 +%d" % data.physical_defense_bonus)
	if data.magic_defense_bonus != 0: parts.append("마방 +%d" % data.magic_defense_bonus)
	if data.hp_bonus != 0: parts.append("HP +%d" % data.hp_bonus)
	return "  ".join(parts) if not parts.is_empty() else "보너스 없음"


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _icon(icon_name: String, size: int) -> TextureRect:
	var texture := _texture(icon_name)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# 아이콘 **이름**("icon_back")을 받는다. 경로와 확장자 해석은 UITheme 이 한다.
func _texture(icon_name: String) -> Texture2D:
	var path := UITheme.icon_path(icon_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D
