extends Control

# 제조 화면 (메타 UI).
#
# 구조는 서브컬쳐 수집형 RPG 문법을 따른다: **좌 레시피 / 중앙 결과물 / 우 재료**.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   장비 정의   -> EquipmentDatabase (목록·이름·보너스·제작 비용)
#   제작/보유   -> EquipmentSystem (can_craft / craft / get_owned_count)
#   재화        -> CurrencySystem (차감은 EquipmentSystem 이 한다)
#   색·조각     -> UITheme / HUDKit
#
# 제작 가능 여부와 재화 차감을 화면에서 계산하지 않는다.
# can_craft() 로 묻고 craft() 로 시킬 뿐이다.
#
# 이 게임에 없는 것은 만들지 않았다:
#   등급 확률표, 제작 큐·소요 시간·즉시 완료, 카테고리 탭 — 전부 시스템이 없다.
#
# 참고: data/equipment/README.md, SYSTEM_CONVENTIONS.md

# 장비 화면은 경로만 둔다(서로 참조하므로 preload 하면 순환이 된다).
const EQUIPMENT_SCREEN_PATH := "res://screens/equipment/EquipmentScreen.tscn"

const SLOT_ICON_NAME := {
	EquipmentData.Slot.WEAPON: "icon_slot_weapon",
	EquipmentData.Slot.HELMET: "icon_slot_armor",
	EquipmentData.Slot.CHEST: "icon_slot_armor",
	EquipmentData.Slot.LEGGINGS: "icon_slot_armor",
	EquipmentData.Slot.MIRROR: "icon_slot_accessory",
}

var _selected: StringName = &""

var _currency_row: HBoxContainer
var _recipe_list: VBoxContainer
var _preview_body: VBoxContainer
var _material_body: VBoxContainer
var _craft_button: Button
var _notice: Label


func _ready() -> void:
	var ids := EquipmentDatabase.get_all_ids()
	if not ids.is_empty():
		_selected = ids[0]

	_build()
	_refresh()

	CurrencySystem.currency_changed.connect(func(_t, _a, _b): _refresh())
	EventBus.equipment_crafted.connect(func(_id): _refresh())


# ===== 화면 구성 =====

func _build() -> void:
	# 뜰에서 제조소(craft)로 들어온 화면이다 — 그 건물의 장면을 배경으로 깐다(#287).
	add_child(HUDKit.make_backdrop(HUDKit.load_backdrop("craft")))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	root.add_child(head)
	head.add_child(HUDKit.make_header("제조", "craft", "icon_craft"))
	head.add_child(_expanding_gap())

	# 재화 바는 우상단(장르 문법).
	_currency_row = HBoxContainer.new()
	_currency_row.add_theme_constant_override("separation", 6)
	_currency_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_currency_row)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var _col0 := _build_recipe_panel()
	body.add_child(_col0)
	var _col1 := _build_center()
	body.add_child(_col1)
	var _col2 := _build_right()
	body.add_child(_col2)



func _build_recipe_panel() -> Control:
	var panel := HUDKit.make_panel("레시피", "recipes")
	panel.custom_minimum_size = Vector2(HUDKit.RAIL_WIDTH, 0)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HUDKit.body_of(panel).add_child(scroll)

	_recipe_list = VBoxContainer.new()
	_recipe_list.add_theme_constant_override("separation", 6)
	_recipe_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_recipe_list)
	return panel


func _build_center() -> Control:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 10)

	_preview_body = VBoxContainer.new()
	_preview_body.alignment = BoxContainer.ALIGNMENT_CENTER
	_preview_body.add_theme_constant_override("separation", 8)
	center.add_child(_preview_body)

	var serial := HUDKit.make_serial("FORGE.01 / STONE AGE")
	serial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(serial)
	return center


func _build_right() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(HUDKit.DETAIL_WIDTH, 0)
	column.add_theme_constant_override("separation", 10)

	var panel := HUDKit.make_panel("필요 재료", "materials")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HUDKit.body_of(panel).add_child(scroll)

	_material_body = VBoxContainer.new()
	_material_body.add_theme_constant_override("separation", 6)
	_material_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_material_body)

	_notice = HUDKit.label("", 13, HUDKit.accent_text(), 700)
	column.add_child(_notice)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)

	var to_gear := HUDKit.make_ghost("장비 관리", 110)
	to_gear.pressed.connect(func(): ScreenManager.swap(load(EQUIPMENT_SCREEN_PATH)))
	actions.add_child(to_gear)

	_craft_button = HUDKit.make_cta("제조", "craft")
	_craft_button.pressed.connect(_on_craft_pressed)
	actions.add_child(_craft_button)
	return column


# ===== 갱신 =====

func _refresh() -> void:
	_refresh_currency()
	_refresh_recipes()
	_refresh_preview()
	_refresh_materials()


func _refresh_currency() -> void:
	_clear(_currency_row)
	# 어떤 재화를 보여줄지 고르지 않고 DEFAULT_CURRENCIES 를 그대로 순회한다.
	for currency_type in CurrencySystem.DEFAULT_CURRENCIES:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", HUDKit.inset(4))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		chip.add_child(row)
		var icon := HUDKit.make_icon(UITheme.currency_icon_name(String(currency_type)), 16)
		if icon != null:
			row.add_child(icon)
		row.add_child(HUDKit.label(str(CurrencySystem.get_balance(String(currency_type))), 12, HUDKit.text_1(), 700))
		_currency_row.add_child(chip)


func _refresh_recipes() -> void:
	_clear(_recipe_list)
	var ids := EquipmentDatabase.get_all_ids()
	if ids.is_empty():
		_recipe_list.add_child(HUDKit.label("제작할 수 있는 장비가 없습니다.", 12, HUDKit.text_2()))
		return
	for id in ids:
		_recipe_list.add_child(_make_recipe_row(id))


func _make_recipe_row(id: StringName) -> Control:
	var item := EquipmentDatabase.get_equipment(id)
	var selected: bool = id == _selected
	# 제작 가능 여부는 EquipmentSystem 이 판단한다(재화 비교를 여기서 하지 않는다).
	var craftable := EquipmentSystem.can_craft(id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", HUDKit.card(selected))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	if item != null:
		var icon := HUDKit.make_icon(SLOT_ICON_NAME.get(item.slot, ""), 30)
		if icon != null:
			row.add_child(icon)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 1)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(box)
		# 고른 행은 액센트로 꽉 차 있으므로 글자를 잉크로 뒤집는다.
		var name_color: Color = HUDKit.text_on_accent() if selected else HUDKit.text_1()
		box.add_child(HUDKit.label(item.display_name, 15, name_color, 700))
		box.add_child(HUDKit.caption("%s / owned %d" % [item.get_slot_name(), EquipmentSystem.get_owned_count(id)]))

		# 제작 불가는 흐리게(장르 문법).
		#
		# 0.45 까지 내리면 지금 고른 행까지 같이 흐려져서 무엇을 보고 있는지 알 수 없다
		# (재료가 하나도 없는 초반에는 모든 행이 제작 불가라 화면 전체가 흐려졌다).
		# 고른 행은 흐리게 하지 않고, 나머지도 읽을 수는 있는 정도까지만 내린다.
		if not craftable and not selected:
			row.modulate = Color(1, 1, 1, 0.6)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_on_recipe_pressed.bind(id))
	card.add_child(button)
	# 카드는 전면 투명 버튼이 클릭을 받으므로, 호버 신호도 그 버튼에서 듣는다.
	HUDKit.hover_lift(card, button)

	return card


func _refresh_preview() -> void:
	_clear(_preview_body)
	var item := _current()
	if item == null:
		_preview_body.add_child(HUDKit.label("레시피를 고르세요", 13, HUDKit.text_2()))
		return

	var icon := HUDKit.make_icon(SLOT_ICON_NAME.get(item.slot, ""), 120)
	if icon != null:
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_preview_body.add_child(icon)

	var name_label := HUDKit.label(item.display_name, 22, HUDKit.text_1(), 700)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_body.add_child(name_label)

	var cap := HUDKit.caption(String(item.equipment_id))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_body.add_child(cap)

	var bonus := PanelContainer.new()
	bonus.add_theme_stylebox_override("panel", HUDKit.inset(8))
	_preview_body.add_child(bonus)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	bonus.add_child(box)
	var any := false
	for pair in [["물리 공격", "p.atk", item.physical_attack_bonus], ["마법 공격", "m.atk", item.magic_attack_bonus],
			["물리 방어", "p.def", item.physical_defense_bonus], ["마법 방어", "m.def", item.magic_defense_bonus],
			["최대 HP", "hp", item.hp_bonus]]:
		if int(pair[2]) != 0:
			box.add_child(HUDKit.stat_row(pair[0], pair[1], "+%d" % int(pair[2])))
			any = true
	if not any:
		box.add_child(HUDKit.label("보너스 없음", 12, HUDKit.text_3()))


func _refresh_materials() -> void:
	_clear(_material_body)
	var item := _current()
	if item == null:
		_craft_button.disabled = true
		return

	if item.craft_cost.is_empty():
		_material_body.add_child(HUDKit.label("재료 없음", 12, HUDKit.text_3()))
	for currency_type in item.craft_cost:
		var need := int(item.craft_cost[currency_type])
		var have := CurrencySystem.get_balance(String(currency_type))
		var enough := have >= need

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 30)

		var icon := HUDKit.make_icon(UITheme.currency_icon_name(String(currency_type)), 20)
		if icon != null:
			row.add_child(icon)

		var name_label := HUDKit.label(String(currency_type), 12, HUDKit.text_2())
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		# 부족분은 적색(장르 문법: 미충족 재화는 적색).
		row.add_child(HUDKit.label("%d / %d" % [have, need], 13,
			HUDKit.text_1() if enough else HUDKit.down_color(), 700))
		_material_body.add_child(row)

	var craftable := EquipmentSystem.can_craft(item.equipment_id)
	_craft_button.disabled = not craftable
	_craft_button.text = "제조  CRAFT" if craftable else "재료 부족"


# ===== 조작 =====

func _on_recipe_pressed(id: StringName) -> void:
	if id == _selected:
		return
	_selected = id
	_refresh_recipes()
	_refresh_preview()
	_refresh_materials()


func _on_craft_pressed() -> void:
	var item := _current()
	if item == null:
		return
	# 재화 차감과 보유 추가는 EquipmentSystem 이 한다.
	if EquipmentSystem.craft(item.equipment_id):
		_show_notice("%s 제조 완료" % item.display_name)
	else:
		_show_notice("재료가 부족합니다")


func _show_notice(message: String) -> void:
	if is_instance_valid(_notice):
		_notice.text = message


# ===== 조각 =====

func _current() -> EquipmentData:
	return EquipmentDatabase.get_equipment(_selected) if _selected != &"" else null


func _expanding_gap() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
