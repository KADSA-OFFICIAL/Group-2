extends Control

# 상점 화면 (메타 UI).
#
# 책임: 판매 목록을 보여주고 구매를 ShopSystem 에 위임한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   판매 목록·가격 -> ShopDatabase / ShopEntryData
#   구매 판정·실행 -> ShopSystem (can_buy / buy)
#   장비 이름·보너스 -> EquipmentDatabase / EquipmentData
#   재화            -> CurrencySystem (차감은 ShopSystem 이 한다)
#   색              -> UITheme
#
# 재화 비교와 차감을 화면에서 하지 않는다. can_buy() 로 묻고 buy() 로 시킬 뿐이다.

const BACK_ICON := "icon_back"
const SHOP_ICON := "icon_shop"

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
	# 구매 결과는 EquipmentSystem 이 EventBus 로 알린다. 화면은 그 신호로 갱신한다.
	EventBus.equipment_granted.connect(func(_id, _count): _refresh_list())


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
	back.expand_icon = true
	back.custom_minimum_size = Vector2(0, 40)
	back.add_theme_stylebox_override("normal", UITheme.panel_box())
	back.add_theme_stylebox_override("hover", UITheme.panel_box())
	back.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	back.add_theme_color_override("font_color", UITheme.INK)
	back.pressed.connect(func(): ScreenManager.pop())
	row.add_child(back)

	var icon := _icon(SHOP_ICON, 24)
	if icon != null:
		row.add_child(icon)

	var title := Label.new()
	title.text = "상점"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	return row


# 재화 표시줄. 어떤 재화를 보여줄지 고르지 않고 DEFAULT_CURRENCIES 를 순회한다.
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

	var ids := ShopDatabase.get_all_ids()
	if ids.is_empty():
		_list_holder.add_child(_empty_notice())
		return

	for id in ids:
		_list_holder.add_child(_make_entry_card(id))


# 판매 항목이 저작되지 않았을 때. 오류가 아니라 정상 상태다.
func _empty_notice() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_text("판매 중인 물건이 없습니다.", 16, UITheme.INK))
	box.add_child(_text("data/shop 에 ShopEntryData(.tres)를 저작하면 여기 나타납니다.", 13, UITheme.INK_DIM))
	return panel


func _make_entry_card(entry_id: StringName) -> Control:
	var entry := ShopDatabase.get_entry(entry_id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.panel_box())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	if entry == null:
		row.add_child(_text(String(entry_id), 16, UITheme.INK))
		return card

	# 장비 정보의 출처는 EquipmentDatabase 다.
	var item := EquipmentDatabase.get_equipment(entry.equipment_id)

	var slot_icon := _icon(SLOT_ICON_NAME.get(item.slot, "") if item != null else "", 40)
	if slot_icon != null:
		row.add_child(slot_icon)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	title_row.add_child(_text(item.display_name if item != null else String(entry.equipment_id), 16, UITheme.INK))
	if item != null:
		title_row.add_child(_text("(%s)" % item.get_slot_name(), 13, UITheme.INK_DIM))
	if entry.count > 1:
		title_row.add_child(_text("x%d" % entry.count, 13, UITheme.INK_DIM))
	title_row.add_child(_text("보유 %d" % EquipmentSystem.get_owned_count(entry.equipment_id), 13, UITheme.INK_DIM))

	# 가격: 보유/필요를 함께 보여주고 모자란 것만 눈에 띄게 한다.
	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 8)
	info.add_child(price_row)
	if entry.price.is_empty():
		price_row.add_child(_text("무료", 13, UITheme.INK_DIM))
	else:
		for currency_type in entry.price:
			price_row.add_child(_make_price_chip(String(currency_type), int(entry.price[currency_type])))

	# 구매 가능 판정은 ShopSystem 이 한다(재화 비교를 여기서 하지 않는다).
	var affordable := ShopSystem.can_buy(entry_id)

	var button := Button.new()
	button.text = "구매"
	button.custom_minimum_size = Vector2(96, 44)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_stylebox_override("normal", UITheme.accent_box() if affordable else UITheme.panel_box_deep())
	button.add_theme_stylebox_override("hover", UITheme.accent_box() if affordable else UITheme.panel_box_deep())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	button.disabled = not affordable
	button.pressed.connect(_on_buy_pressed.bind(entry_id))
	row.add_child(button)
	return card


func _make_price_chip(currency_type: String, need: int) -> Control:
	var have := CurrencySystem.get_balance(currency_type)
	var enough := have >= need

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var icon := _icon(UITheme.currency_icon_name(currency_type), 18)
	if icon != null:
		row.add_child(icon)

	# 모자란 재료는 진하게(INK) 두어 눈에 띄게 하고, 충족한 것은 흐리게 둔다.
	row.add_child(_text("%d/%d" % [have, need], 13, UITheme.INK_DIM if enough else UITheme.INK))
	return row


# ===== 조작 =====

func _on_buy_pressed(entry_id: StringName) -> void:
	var entry := ShopDatabase.get_entry(entry_id)
	var item := EquipmentDatabase.get_equipment(entry.equipment_id) if entry != null else null
	# 재화 차감과 지급은 ShopSystem 이 한다. 실패해도 화면이 상태를 바꾸지 않는다.
	if ShopSystem.buy(entry_id):
		_show_toast("%s 구매 완료" % (item.display_name if item != null else String(entry_id)))
	else:
		_show_toast("구매할 수 없습니다")


func _on_currency_changed(currency_type: String, _amount: int, new_balance: int) -> void:
	var label: Label = _currency_labels.get(currency_type)
	if label != null and is_instance_valid(label):
		label.text = str(new_balance)
	# 잔액이 바뀌면 구매 가능 여부도 바뀌므로 목록을 다시 그린다.
	_refresh_list()


func _show_toast(message: String) -> void:
	if not is_instance_valid(_toast):
		return
	_toast.text = message
	_toast.visible = true


# ===== 공용 조각 =====

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
