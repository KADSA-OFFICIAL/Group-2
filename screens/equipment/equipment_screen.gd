extends Control

# 장비 화면 (메타 UI).
#
# 책임: 캐릭터를 고르고, 보유한 장비를 슬롯에 착용/해제한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   로스터     -> CharacterDatabase
#   장비 정의  -> EquipmentDatabase (슬롯별 목록)
#   보유·착탈  -> EquipmentSystem (get_owned_ids / equip / unequip)
#   착용 상태  -> CharacterData.get_equipped()
#   스텟       -> PlayerStats 파생 getter
#   색         -> UITheme
#
# 착탈의 결과(스텟 반영)는 CharacterData/PlayerStats 가 처리한다.
# 화면은 보너스를 직접 더하지 않는다.
#
# 참고: docs/combat-screen-design.md §10, SYSTEM_CONVENTIONS.md

const BACK_ICON := "res://assets/sprites/ui/icons/icon_back.svg"
const EQUIPMENT_ICON := "res://assets/sprites/ui/icons/icon_equipment.svg"

const SLOT_ICON_PATH := {
	EquipmentData.Slot.WEAPON: "res://assets/sprites/ui/icons/icon_slot_weapon.svg",
	EquipmentData.Slot.ARMOR: "res://assets/sprites/ui/icons/icon_slot_armor.svg",
	EquipmentData.Slot.ACCESSORY: "res://assets/sprites/ui/icons/icon_slot_accessory.svg",
}

var _selected_id: StringName = &""
var _character_row: HBoxContainer
var _slot_holder: VBoxContainer
var _stat_holder: VBoxContainer
var _notice: Label


func _ready() -> void:
	var ids := CharacterDatabase.get_all_ids()
	if not ids.is_empty():
		_selected_id = ids[0]

	_build()
	_refresh()

	# 다른 화면(제조)에서 장비를 만들고 돌아오면 보유 목록이 달라져 있다.
	EventBus.equipment_crafted.connect(func(_id): _refresh())


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

	# 캐릭터 선택 줄
	_character_row = HBoxContainer.new()
	_character_row.add_theme_constant_override("separation", 8)
	root.add_child(_character_row)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := ScrollContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 0.62
	left.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(left)

	_slot_holder = VBoxContainer.new()
	_slot_holder.add_theme_constant_override("separation", 10)
	_slot_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_slot_holder)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UITheme.panel_box())
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.38
	body.add_child(right)

	_stat_holder = VBoxContainer.new()
	_stat_holder.add_theme_constant_override("separation", 5)
	right.add_child(_stat_holder)

	_notice = Label.new()
	_notice.add_theme_font_size_override("font_size", 13)
	_notice.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	_notice.visible = false
	root.add_child(_notice)


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

	var icon := _icon(EQUIPMENT_ICON, 24)
	if icon != null:
		row.add_child(icon)

	var title := Label.new()
	title.text = "장비"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	return row


# ===== 갱신 =====

func _refresh() -> void:
	_refresh_characters()
	_refresh_slots()
	_refresh_stats()


func _refresh_characters() -> void:
	_clear(_character_row)
	for id in CharacterDatabase.get_all_ids():
		var character := CharacterDatabase.get_character(id)
		var button := Button.new()
		button.text = character.display_name if character else String(id)
		button.custom_minimum_size = Vector2(0, 38)
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", UITheme.INK)
		var selected: bool = (id == _selected_id)
		button.add_theme_stylebox_override("normal", UITheme.accent_box() if selected else UITheme.panel_box())
		button.add_theme_stylebox_override("hover", UITheme.accent_box() if selected else UITheme.panel_box())
		button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
		button.pressed.connect(_on_character_pressed.bind(id))
		_character_row.add_child(button)


func _refresh_slots() -> void:
	_clear(_slot_holder)
	var character := _current_character()
	if character == null:
		_slot_holder.add_child(_text("캐릭터가 없습니다.", 14, UITheme.INK_ON_DARK))
		return

	# 슬롯 목록은 EquipmentData.Slot 이 출처다. 화면에서 정의하지 않는다.
	# (아래 SLOT_ICON_PATH 는 아이콘 경로 대응표일 뿐 슬롯 목록이 아니다.
	#  그걸 순회하면 새 슬롯이 추가돼도 조용히 빠진다.)
	for slot in EquipmentData.Slot.values():
		_slot_holder.add_child(_make_slot_panel(character, slot))


func _make_slot_panel(character: CharacterData, slot: int) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	# 슬롯 머리: 아이콘 + 착용 중인 장비 + 해제 버튼
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)

	var icon := _icon(SLOT_ICON_PATH.get(slot, ""), 28)
	if icon != null:
		head.add_child(icon)

	var equipped := character.get_equipped(slot)
	var head_label := _text(
		equipped.display_name if equipped != null else "비어 있음",
		15, UITheme.INK if equipped != null else UITheme.INK_DIM
	)
	head_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(head_label)

	if equipped != null:
		var unequip := Button.new()
		unequip.text = "해제"
		unequip.custom_minimum_size = Vector2(72, 34)
		unequip.add_theme_font_size_override("font_size", 13)
		unequip.add_theme_color_override("font_color", UITheme.INK)
		unequip.add_theme_stylebox_override("normal", UITheme.panel_box_deep())
		unequip.add_theme_stylebox_override("hover", UITheme.panel_box_deep())
		unequip.pressed.connect(_on_unequip_pressed.bind(slot))
		head.add_child(unequip)

	# 이 슬롯에 넣을 수 있는 보유 장비 목록.
	var owned := _owned_ids_for_slot(slot)
	if owned.is_empty():
		box.add_child(_text("보유한 장비가 없습니다. 제조에서 만들 수 있습니다.", 12, UITheme.INK_DIM))
		return panel

	var list := HBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	box.add_child(list)

	for id in owned:
		var data: EquipmentData = EquipmentDatabase.get_equipment(id)
		var is_on: bool = equipped != null and equipped.equipment_id == id

		var button := Button.new()
		button.text = "%s x%d" % [data.display_name, EquipmentSystem.get_owned_count(id)]
		button.custom_minimum_size = Vector2(0, 34)
		button.add_theme_font_size_override("font_size", 13)
		button.add_theme_color_override("font_color", UITheme.INK)
		button.add_theme_stylebox_override("normal", UITheme.accent_box() if is_on else UITheme.panel_box_deep())
		button.add_theme_stylebox_override("hover", UITheme.accent_box() if is_on else UITheme.panel_box_deep())
		button.disabled = is_on
		button.pressed.connect(_on_equip_pressed.bind(id))
		list.add_child(button)

	return panel


# 보유 중이면서 해당 슬롯인 장비 id 목록.
func _owned_ids_for_slot(slot: int) -> Array:
	var out: Array = []
	for id in EquipmentSystem.get_owned_ids():
		var data: EquipmentData = EquipmentDatabase.get_equipment(id)
		if data != null and data.slot == slot:
			out.append(id)
	return out


func _refresh_stats() -> void:
	_clear(_stat_holder)
	var character := _current_character()
	if character == null:
		return

	_stat_holder.add_child(_text(character.display_name, 17, UITheme.INK))
	_stat_holder.add_child(_text("장비 반영 스텟", 13, UITheme.INK_DIM))
	_stat_holder.add_child(HSeparator.new())

	# 파생값은 PlayerStats 가 계산한다. 장비 보너스를 화면에서 더하지 않는다.
	var stats := character.get_stats()
	_add_stat("최대 HP", stats.get_max_hp())
	_add_stat("물리 공격", stats.get_physical_attack())
	_add_stat("마법 공격", stats.get_magic_attack())
	_add_stat("물리 방어", stats.get_physical_defense())
	_add_stat("마법 방어", stats.get_magic_defense())


func _add_stat(label_text: String, value: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _text(label_text, 13, UITheme.INK_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_text(str(value), 13, UITheme.INK))
	_stat_holder.add_child(row)


# ===== 조작 =====

func _on_character_pressed(id: StringName) -> void:
	if id == _selected_id:
		return
	_selected_id = id
	_refresh()


# 착탈은 EquipmentSystem 이 한다(보유 검사 포함). 화면은 결과만 다시 그린다.
func _on_equip_pressed(id: StringName) -> void:
	var character := _current_character()
	if character == null:
		return
	if EquipmentSystem.equip(character, id):
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
	if not is_instance_valid(_notice):
		return
	_notice.text = message
	_notice.visible = true


# ===== 공용 조각 =====

func _current_character() -> CharacterData:
	return CharacterDatabase.get_character(_selected_id) if _selected_id != &"" else null


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


func _icon(path: String, size: int) -> TextureRect:
	var texture := _texture(path)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
