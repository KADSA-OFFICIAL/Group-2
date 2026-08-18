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
#   색·조각         -> UITheme / HUDKit
#
# 재화 비교와 차감을 화면에서 하지 않는다. can_buy() 로 묻고 buy() 로 시킬 뿐이다.

const SLOT_ICON_NAME := {
	EquipmentData.Slot.WEAPON: "icon_slot_weapon",
	EquipmentData.Slot.ARMOR: "icon_slot_armor",
	EquipmentData.Slot.ACCESSORY: "icon_slot_accessory",
}

# 토스트가 스스로 사라지기까지의 시간(초).
const TOAST_SECONDS := 2.5

var _currency_labels: Dictionary = {}
var _list_holder: VBoxContainer
var _toast: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	_build()
	_refresh_list()

	CurrencySystem.currency_changed.connect(_on_currency_changed)
	# 구매 결과는 EquipmentSystem 이 EventBus 로 알린다. 화면은 그 신호로 갱신한다.
	EventBus.equipment_granted.connect(func(_id, _count): _refresh_list())


# ===== 화면 구성 =====

func _build() -> void:
	add_child(HUDKit.make_backdrop())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	# 헤더 오른쪽 끝에 재화 표시줄을 붙인다. 살 수 있는지 판단하려면 잔액이 늘 보여야 한다.
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	root.add_child(head)
	head.add_child(HUDKit.make_header("상점", "shop", "icon_shop"))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_build_currency_bar())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	_list_holder = VBoxContainer.new()
	_list_holder.add_theme_constant_override("separation", 10)
	_list_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_holder)

	_toast = HUDKit.label("", 14, HUDKit.text_1(), 700)
	_toast.visible = false
	root.add_child(_toast)



# 재화 표시줄. 어떤 재화를 보여줄지 고르지 않고 DEFAULT_CURRENCIES 를 순회한다.
func _build_currency_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for currency_type in CurrencySystem.DEFAULT_CURRENCIES:
		var key := String(currency_type)
		var chip := HUDKit.currency_chip(key, HUDKit.comma(CurrencySystem.get_balance(key)))
		# 잔액만 갱신하려고 칩 안의 라벨을 기억해 둔다.
		_currency_labels[key] = _find_label(chip)
		bar.add_child(chip)
	return bar


# currency_chip 이 만든 칩 안의 수량 라벨을 찾는다.
# 칩의 내부 구조를 화면이 다시 만들지 않으려고 조회로 얻는다.
func _find_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label:
			return child
		var found := _find_label(child)
		if found != null:
			return found
	return null


# ===== 목록 =====

func _refresh_list() -> void:
	if not is_instance_valid(_list_holder):
		return
	_clear(_list_holder)

	var ids := ShopDatabase.get_all_ids()
	if ids.is_empty():
		# 판매 항목이 저작되지 않았을 때. 오류가 아니라 정상 상태다.
		_list_holder.add_child(HUDKit.empty_notice(
			"판매 중인 물건이 없습니다.",
			"data/shop 에 ShopEntryData(.tres)를 저작하면 여기 나타납니다."))
		return

	for id in ids:
		_list_holder.add_child(_make_entry_card(id))


func _make_entry_card(entry_id: StringName) -> Control:
	var entry := ShopDatabase.get_entry(entry_id)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HUDKit.card())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	if entry == null:
		row.add_child(HUDKit.label(String(entry_id), 15, HUDKit.text_1(), 700))
		return card

	# 장비 정보의 출처는 EquipmentDatabase 다.
	var item := EquipmentDatabase.get_equipment(entry.equipment_id)

	var slot_icon := HUDKit.make_icon(SLOT_ICON_NAME.get(item.slot, "") if item != null else "", 44)
	if slot_icon != null:
		slot_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(slot_icon)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	title_row.add_child(HUDKit.label(
		item.display_name if item != null else String(entry.equipment_id), 16, HUDKit.text_1(), 700))
	if item != null:
		title_row.add_child(HUDKit.caption(item.get_slot_name()))
	if entry.count > 1:
		title_row.add_child(HUDKit.tag_chip("x%d" % entry.count, UITheme.SKY))
	title_row.add_child(HUDKit.label(
		"보유 %d" % EquipmentSystem.get_owned_count(entry.equipment_id), 12, HUDKit.text_3()))

	# 가격: 보유/필요를 함께 보여주고 모자란 것만 눈에 띄게 한다.
	var price_row := HBoxContainer.new()
	price_row.add_theme_constant_override("separation", 6)
	info.add_child(price_row)
	if entry.price.is_empty():
		price_row.add_child(HUDKit.label("무료", 13, HUDKit.text_2()))
	else:
		for currency_type in entry.price:
			price_row.add_child(_make_price_chip(String(currency_type), int(entry.price[currency_type])))

	# 구매 가능 판정은 ShopSystem 이 한다(재화 비교를 여기서 하지 않는다).
	var affordable := ShopSystem.can_buy(entry_id)

	var button := HUDKit.make_cta("구매", "buy") if affordable else HUDKit.make_ghost("재화 부족", 130)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.disabled = not affordable
	button.pressed.connect(_on_buy_pressed.bind(entry_id))
	row.add_child(button)
	return card


func _make_price_chip(currency_type: String, need: int) -> Control:
	var have := CurrencySystem.get_balance(currency_type)
	var enough := have >= need

	# 모자란 가격은 하락색으로 칠해 눈에 띄게 한다.
	# 예전에는 글자 진하기만 바꿨는데(INK vs INK_DIM), 밝은 카드 위에서는
	# 그 차이가 거의 안 보였다.
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel",
		HUDKit.chip(HUDKit.inset_fill() if enough else UITheme.NEGATIVE))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)

	var icon := HUDKit.make_icon(UITheme.currency_icon_name(currency_type), 18)
	if icon != null:
		row.add_child(icon)

	row.add_child(HUDKit.label("%s / %s" % [HUDKit.comma(have), HUDKit.comma(need)], 13,
		HUDKit.text_1() if enough else HUDKit.text_on_category(), 700))
	return p


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
		label.text = HUDKit.comma(new_balance)
	# 잔액이 바뀌면 구매 가능 여부도 바뀌므로 목록을 다시 그린다.
	_refresh_list()


# 토스트는 스스로 사라진다. 예전에는 한 번 뜨면 화면에 계속 남아서,
# 다음에 무엇을 눌러도 옛 메시지가 붙어 있었다.
func _show_toast(message: String) -> void:
	if not is_instance_valid(_toast):
		return
	_toast.text = message
	_toast.visible = true
	_toast_timer = get_tree().create_timer(TOAST_SECONDS)
	_toast_timer.timeout.connect(func():
		if is_instance_valid(_toast) and _toast.text == message:
			_toast.visible = false
	)


# ===== 공용 조각 =====

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
