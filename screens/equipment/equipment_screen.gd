extends Control

# 장비 화면 (메타 UI).
#
# 구조는 서브컬쳐 수집형 RPG 문법을 따른다: **좌 인벤토리 / 중앙 착용 슬롯 / 우 상세**.
# 장르 원형은 캐릭터 실루엣 주변에 슬롯을 배치하는 것이라, 중앙에 캐릭터 자리를 두고
# 그 좌우로 슬롯을 세운 뒤 연결선을 그었다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   로스터     -> CharacterDatabase
#   장비 정의  -> EquipmentDatabase
#   보유·착탈  -> EquipmentSystem (get_owned_ids / equip / unequip)
#   착용 상태  -> CharacterData.get_equipped()
#   스텟       -> PlayerStats 파생 getter
#   색·조각    -> UITheme / HUDKit
#
# 착탈의 결과(스텟 반영)는 CharacterData/PlayerStats 가 처리한다.
# 화면은 보너스를 직접 더하지 않는다.
#
# 이 게임에 없는 것은 만들지 않았다: 강화(+15), 등급, 세트 효과, 잠금/분해.
#
# 참고: docs/combat-screen-design.md §10, SYSTEM_CONVENTIONS.md

# 제조 화면은 경로만 둔다(서로 참조하므로 preload 하면 순환이 된다).
const CRAFT_SCREEN_PATH := "res://screens/craft/CraftScreen.tscn"

const SLOT_ICON_NAME := {
	EquipmentData.Slot.WEAPON: "icon_slot_weapon",
	EquipmentData.Slot.ARMOR: "icon_slot_armor",
	EquipmentData.Slot.ACCESSORY: "icon_slot_accessory",
}

var _character_id: StringName = &""
# 우측 상세에 띄울 장비. 비어 있으면 착용 요약을 보여준다.
var _focus_equipment: StringName = &""

var _character_row: HBoxContainer
var _slot_column: VBoxContainer
var _inventory_grid: GridContainer
var _detail_body: VBoxContainer
var _notice: Label


func _ready() -> void:
	var ids := CharacterDatabase.get_all_ids()
	if not ids.is_empty():
		_character_id = ids[0]

	_build()
	_refresh()

	# 다른 화면(제조)에서 장비가 생기면 보유 목록이 달라져 있다.
	EventBus.equipment_crafted.connect(func(_id): _refresh())
	EventBus.equipment_granted.connect(func(_id, _n): _refresh())


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

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 16)
	root.add_child(head)
	head.add_child(HUDKit.make_header("장비", "equipment", "icon_equipment"))

	# 캐릭터 선택 줄은 헤더 옆에 붙인다(좌측 폭을 인벤토리에 양보한다).
	_character_row = HBoxContainer.new()
	_character_row.add_theme_constant_override("separation", 6)
	_character_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_character_row)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	body.add_child(_build_inventory_panel())
	body.add_child(_build_center())
	body.add_child(_build_detail())


# ── 좌: 인벤토리 ──
func _build_inventory_panel() -> Control:
	var panel := HUDKit.make_panel("보유 장비", "inventory")
	panel.custom_minimum_size = Vector2(HUDKit.RAIL_WIDTH, 0)
	var body := HUDKit.body_of(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	_inventory_grid = GridContainer.new()
	_inventory_grid.columns = 3
	_inventory_grid.add_theme_constant_override("h_separation", 8)
	_inventory_grid.add_theme_constant_override("v_separation", 8)
	_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_inventory_grid)
	return panel


# ── 중앙: 캐릭터 자리 + 착용 슬롯 ──
func _build_center() -> Control:
	var center := HBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 0)

	_slot_column = VBoxContainer.new()
	_slot_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_column.add_theme_constant_override("separation", 10)
	center.add_child(_slot_column)

	# 슬롯에서 캐릭터로 이어지는 연결선(장르 문법). 장식이며 정보가 아니다.
	var connector := ColorRect.new()
	connector.color = HUDKit.line()
	connector.custom_minimum_size = Vector2(28, HUDKit.HAIRLINE)
	connector.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_child(connector)

	var figure := VBoxContainer.new()
	figure.alignment = BoxContainer.ALIGNMENT_CENTER
	figure.add_theme_constant_override("separation", 6)
	center.add_child(figure)

	var silhouette := ColorRect.new()
	silhouette.name = "Silhouette"
	silhouette.custom_minimum_size = Vector2(180, 300)
	figure.add_child(silhouette)

	var serial := HUDKit.make_serial("EQP.LOADOUT")
	serial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	figure.add_child(serial)
	return center


# ── 우: 상세 + 우하단 CTA ──
func _build_detail() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(HUDKit.DETAIL_WIDTH, 0)
	column.add_theme_constant_override("separation", 10)

	var panel := HUDKit.make_panel("상세", "detail")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HUDKit.body_of(panel).add_child(scroll)

	_detail_body = VBoxContainer.new()
	_detail_body.add_theme_constant_override("separation", 6)
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_body)

	_notice = HUDKit.label("", 12, UITheme.ACCENT)
	column.add_child(_notice)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)

	var to_craft := HUDKit.make_ghost("제조하러", 110)
	to_craft.pressed.connect(func(): ScreenManager.swap(load(CRAFT_SCREEN_PATH)))
	actions.add_child(to_craft)

	var equip := HUDKit.make_cta("착용", "equip")
	equip.pressed.connect(_on_equip_pressed)
	actions.add_child(equip)
	return column


# ===== 갱신 =====

func _refresh() -> void:
	_refresh_characters()
	_refresh_slots()
	_refresh_inventory()
	_refresh_detail()


func _refresh_characters() -> void:
	_clear(_character_row)
	for id in CharacterDatabase.get_all_ids():
		var character := CharacterDatabase.get_character(id)
		var active: bool = id == _character_id
		var button := Button.new()
		button.text = character.display_name if character else String(id)
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", HUDKit.text_1() if active else HUDKit.text_2())
		button.add_theme_stylebox_override("normal", HUDKit.card(active))
		button.add_theme_stylebox_override("hover", HUDKit.ghost_hover())
		button.add_theme_stylebox_override("pressed", HUDKit.ghost())
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		button.pressed.connect(_on_character_pressed.bind(id))
		_character_row.add_child(button)


func _refresh_slots() -> void:
	_clear(_slot_column)
	var character := _current_character()
	if character == null:
		_slot_column.add_child(HUDKit.label("캐릭터가 없습니다.", 12, HUDKit.text_2()))
		return

	# 슬롯 목록의 출처는 EquipmentData.Slot 이다(아래 대응표는 아이콘용일 뿐이다).
	for slot in EquipmentData.Slot.values():
		_slot_column.add_child(_make_slot(character, slot))


func _make_slot(character: CharacterData, slot: int) -> Control:
	var item := character.get_equipped(slot)
	var filled := item != null

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(190, 76)
	panel.add_theme_stylebox_override("panel", HUDKit.card(filled))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var icon := HUDKit.make_icon(SLOT_ICON_NAME.get(slot, ""), 34)
	if icon != null:
		row.add_child(icon)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)

	box.add_child(HUDKit.caption(_slot_en(slot)))
	var name_label := HUDKit.label(
		item.display_name if filled else "비어 있음", 13,
		HUDKit.text_1() if filled else HUDKit.text_3(), 600)
	name_label.clip_text = true
	box.add_child(name_label)

	if filled:
		var off := HUDKit.make_ghost("해제", 56)
		off.custom_minimum_size = Vector2(56, 30)
		off.add_theme_font_size_override("font_size", 11)
		off.pressed.connect(_on_unequip_pressed.bind(slot))
		row.add_child(off)
	return panel


func _refresh_inventory() -> void:
	_clear(_inventory_grid)
	var owned := EquipmentSystem.get_owned_ids()
	if owned.is_empty():
		var empty := VBoxContainer.new()
		empty.add_theme_constant_override("separation", 6)
		empty.add_child(HUDKit.label("보유한 장비가 없습니다.", 12, HUDKit.text_2()))
		var go := HUDKit.make_ghost("제조하러 가기", 130)
		go.pressed.connect(func(): ScreenManager.swap(load(CRAFT_SCREEN_PATH)))
		empty.add_child(go)
		_inventory_grid.add_child(empty)
		return

	for id in owned:
		_inventory_grid.add_child(_make_item_card(id))


func _make_item_card(id: StringName) -> Control:
	var item := EquipmentDatabase.get_equipment(id)
	var selected: bool = id == _focus_equipment

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 84)
	card.add_theme_stylebox_override("panel", HUDKit.card(selected))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	if item != null:
		var icon := HUDKit.make_icon(SLOT_ICON_NAME.get(item.slot, ""), 30)
		if icon != null:
			icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			box.add_child(icon)
		var name_label := HUDKit.label(item.display_name, 11, HUDKit.text_1())
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.clip_text = true
		box.add_child(name_label)
		var count := HUDKit.label("×%d" % EquipmentSystem.get_owned_count(id), 10, HUDKit.text_3())
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(count)

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_on_item_pressed.bind(id))
	card.add_child(button)

	if selected:
		card.add_child(HUDKit.make_brackets())
	return card


func _refresh_detail() -> void:
	_clear(_detail_body)
	var character := _current_character()
	if character == null:
		return

	var item := EquipmentDatabase.get_equipment(_focus_equipment) if _focus_equipment != &"" else null

	if item == null:
		# 고른 장비가 없으면 지금 착용 상태의 합계를 보여준다.
		_detail_body.add_child(HUDKit.label(character.display_name, 18, HUDKit.text_1(), 700))
		_detail_body.add_child(HUDKit.caption("current loadout"))
		var bonuses := character.get_equipment_bonuses()
		for pair in [["물리 공격", "p.atk", "physical_attack"], ["마법 공격", "m.atk", "magic_attack"],
				["물리 방어", "p.def", "physical_defense"], ["마법 방어", "m.def", "magic_defense"],
				["최대 HP", "hp", "hp"]]:
			_detail_body.add_child(_delta_row(pair[0], pair[1], int(bonuses[pair[2]])))
		_detail_body.add_child(HUDKit.label("좌측에서 장비를 고르면 비교가 나옵니다.", 11, HUDKit.text_3()))
		return

	# 고른 장비 상세
	_detail_body.add_child(HUDKit.label(item.display_name, 18, HUDKit.text_1(), 700))
	_detail_body.add_child(HUDKit.caption("%s / %s" % [_slot_en(item.slot), String(item.equipment_id)]))
	_detail_body.add_child(HUDKit.stat_row("부위", "slot", item.get_slot_name()))
	_detail_body.add_child(HUDKit.stat_row("보유", "owned", "×%d" % EquipmentSystem.get_owned_count(item.equipment_id)))

	if not item.description.is_empty():
		var desc := HUDKit.label(item.description, 12, HUDKit.text_2())
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_body.add_child(desc)

	_detail_body.add_child(HUDKit.section("옵션", "options"))
	for pair in [["물리 공격", "p.atk", item.physical_attack_bonus], ["마법 공격", "m.atk", item.magic_attack_bonus],
			["물리 방어", "p.def", item.physical_defense_bonus], ["마법 방어", "m.def", item.magic_defense_bonus],
			["최대 HP", "hp", item.hp_bonus]]:
		if int(pair[2]) != 0:
			_detail_body.add_child(HUDKit.stat_row(pair[0], pair[1], "+%d" % int(pair[2])))

	# 비교 블록 — 지금 그 슬롯에 낀 것과의 차이. 장르 문법의 핵심 요소다.
	_detail_body.add_child(HUDKit.section("교체 시 변화", "delta vs equipped"))
	var current := character.get_equipped(item.slot)
	_detail_body.add_child(HUDKit.label(
		"현재: %s" % (current.display_name if current != null else "비어 있음"), 12, HUDKit.text_2()))
	for pair in [["물리 공격", "p.atk", "physical_attack_bonus"], ["마법 공격", "m.atk", "magic_attack_bonus"],
			["물리 방어", "p.def", "physical_defense_bonus"], ["마법 방어", "m.def", "magic_defense_bonus"],
			["최대 HP", "hp", "hp_bonus"]]:
		var after := int(item.get(pair[2]))
		var before := int(current.get(pair[2])) if current != null else 0
		_detail_body.add_child(_delta_row(pair[0], pair[1], after - before))


func _delta_row(ko: String, en: String, amount: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 24)
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(HUDKit.label(ko, 12, HUDKit.text_2()))
	left.add_child(HUDKit.caption(en))
	row.add_child(left)
	row.add_child(HUDKit.delta(amount))
	return row


# ===== 조작 =====

func _on_character_pressed(id: StringName) -> void:
	if id == _character_id:
		return
	_character_id = id
	_refresh()


func _on_item_pressed(id: StringName) -> void:
	_focus_equipment = id
	_refresh_inventory()
	_refresh_detail()


# 착탈은 EquipmentSystem 이 한다(보유 검사 포함). 화면은 결과만 다시 그린다.
func _on_equip_pressed() -> void:
	var character := _current_character()
	if character == null or _focus_equipment == &"":
		_show_notice("좌측에서 장비를 고르세요")
		return
	if EquipmentSystem.equip(character, _focus_equipment):
		_show_notice("착용했습니다")
	else:
		_show_notice("착용할 수 없습니다")
	_refresh()


func _on_unequip_pressed(slot: int) -> void:
	var character := _current_character()
	if character == null:
		return
	EquipmentSystem.unequip(character, slot)
	_show_notice("해제했습니다")
	_refresh()


func _show_notice(message: String) -> void:
	if is_instance_valid(_notice):
		_notice.text = message


# ===== 조각 =====

func _slot_en(slot: int) -> String:
	match slot:
		EquipmentData.Slot.WEAPON:
			return "weapon"
		EquipmentData.Slot.ARMOR:
			return "armor"
		EquipmentData.Slot.ACCESSORY:
			return "accessory"
		_:
			return "slot"


func _current_character() -> CharacterData:
	return CharacterDatabase.get_character(_character_id) if _character_id != &"" else null


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
