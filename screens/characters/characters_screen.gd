extends Control

# 캐릭터 화면 (메타 UI).
#
# 책임: 로스터를 훑어보고 한 명의 정의를 자세히 본다. 값을 바꾸지 않는 읽기 전용 화면이다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   로스터   -> CharacterDatabase
#   캐릭터   -> CharacterData (이름/설명/역할/외형 tint/스킬/장비)
#   스텟     -> PlayerStats 의 파생 getter (여기서 계산식을 다시 쓰지 않는다)
#   파티 여부 -> PartySystem.has_character()
#   색       -> UITheme
#
# 편성 변경은 편성 화면의 책임이라 여기서는 하지 않는다(읽기 전용).
#
# 참고: docs/combat-screen-design.md §1, SYSTEM_CONVENTIONS.md

const ROLE_ICON_PATH := {
	CharacterData.Role.TANK: "res://assets/sprites/ui/icons/icon_role_tank.svg",
	CharacterData.Role.RANGED_DEALER: "res://assets/sprites/ui/icons/icon_role_ranged_dealer.svg",
	CharacterData.Role.BUFFER: "res://assets/sprites/ui/icons/icon_role_buffer.svg",
}

# 슬롯 -> 아이콘 경로 대응표. **슬롯 목록의 출처가 아니다**(출처는 EquipmentData.Slot).
# 여기 없는 슬롯은 아이콘만 생략되고 행 자체는 그려진다.
const SLOT_ICON_PATH := {
	EquipmentData.Slot.WEAPON: "res://assets/sprites/ui/icons/icon_slot_weapon.svg",
	EquipmentData.Slot.ARMOR: "res://assets/sprites/ui/icons/icon_slot_armor.svg",
	EquipmentData.Slot.ACCESSORY: "res://assets/sprites/ui/icons/icon_slot_accessory.svg",
}

const BACK_ICON := "res://assets/sprites/ui/icons/icon_back.svg"

var _selected_id: StringName = &""
var _roster_grid: GridContainer
var _detail_holder: VBoxContainer


func _ready() -> void:
	var ids := CharacterDatabase.get_all_ids()
	if not ids.is_empty():
		_selected_id = ids[0]

	_build()
	_refresh()


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
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	root.add_child(_build_header())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	body.add_child(_build_roster_panel())
	body.add_child(_build_detail_panel())


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

	var title := Label.new()
	title.text = "캐릭터 (%d명)" % CharacterDatabase.get_count()
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	return row


func _build_roster_panel() -> Control:
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_stretch_ratio = 0.55
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_roster_grid = GridContainer.new()
	_roster_grid.columns = 3
	_roster_grid.add_theme_constant_override("h_separation", 10)
	_roster_grid.add_theme_constant_override("v_separation", 10)
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_grid)
	return scroll


func _build_detail_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.45
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	panel.add_child(scroll)

	_detail_holder = VBoxContainer.new()
	_detail_holder.add_theme_constant_override("separation", 8)
	_detail_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_holder)
	return panel


# ===== 갱신 =====

func _refresh() -> void:
	_refresh_roster()
	_refresh_detail()


func _refresh_roster() -> void:
	_clear(_roster_grid)
	for id in CharacterDatabase.get_all_ids():
		_roster_grid.add_child(_make_roster_card(id))


func _make_roster_card(id: StringName) -> Control:
	var character := CharacterDatabase.get_character(id)
	var selected := (id == _selected_id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 116)
	card.add_theme_stylebox_override("panel", UITheme.accent_box() if selected else UITheme.panel_box())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	if character != null:
		var swatch := ColorRect.new()
		swatch.color = character.tint
		swatch.custom_minimum_size = Vector2(0, 38)
		box.add_child(swatch)
		box.add_child(_text(character.display_name, 14, UITheme.INK))

		var role_row := HBoxContainer.new()
		role_row.add_theme_constant_override("separation", 3)
		box.add_child(role_row)
		# 겸직이면 get_roles() 가 2개를 돌려주므로 아이콘도 2개가 붙는다.
		for role in character.get_roles():
			var icon := _icon(ROLE_ICON_PATH.get(role, ""), 18)
			if icon != null:
				role_row.add_child(icon)

		# 파티 편성 여부는 PartySystem 이 판단한다.
		if PartySystem.has_character(id):
			box.add_child(_text("편성 중", 11, UITheme.INK))

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(_on_card_pressed.bind(id))
	card.add_child(button)
	return card


func _refresh_detail() -> void:
	_clear(_detail_holder)

	var character := CharacterDatabase.get_character(_selected_id) if _selected_id != &"" else null
	if character == null:
		_detail_holder.add_child(_text("캐릭터가 없습니다.", 14, UITheme.INK_DIM))
		return

	# 이름 + 역할
	_detail_holder.add_child(_text(character.display_name, 20, UITheme.INK))

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 4)
	_detail_holder.add_child(role_row)
	for role in character.get_roles():
		var icon := _icon(ROLE_ICON_PATH.get(role, ""), 20)
		if icon != null:
			role_row.add_child(icon)
	role_row.add_child(_text(character.get_roles_display_name(), 14, UITheme.INK_DIM))

	if not character.description.is_empty():
		var desc := _text(character.description, 13, UITheme.INK_DIM)
		desc.clip_text = false
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_holder.add_child(desc)

	_detail_holder.add_child(HSeparator.new())

	# 스텟: 파생값은 PlayerStats 가 계산한다. 여기서 공식을 다시 쓰지 않는다.
	var stats := character.get_stats()
	_detail_holder.add_child(_text("스텟", 16, UITheme.INK))
	_add_stat_row("최대 HP", str(stats.get_max_hp()))
	_add_stat_row("물리 공격", str(stats.get_physical_attack()))
	_add_stat_row("마법 공격", str(stats.get_magic_attack()))
	_add_stat_row("물리 방어", str(stats.get_physical_defense()))
	_add_stat_row("마법 방어", str(stats.get_magic_defense()))
	_add_stat_row("근력 / 신앙", "%d / %d" % [stats.strength, stats.faith])

	_detail_holder.add_child(HSeparator.new())

	# 장비: EquipmentData.Slot 을 순회한다. 슬롯 목록을 화면에서 정의하지 않는다.
	# (SLOT_ICON_PATH 는 아이콘 경로 대응표일 뿐이다. 그걸 순회하면 새 슬롯이 조용히 빠진다.)
	_detail_holder.add_child(_text("장비", 16, UITheme.INK))
	for slot in EquipmentData.Slot.values():
		_add_slot_row(character, slot)

	# 스킬: 정의만 표시한다(발동은 후속 시스템의 몫).
	_detail_holder.add_child(HSeparator.new())
	_detail_holder.add_child(_text("스킬", 16, UITheme.INK))
	if character.skills.is_empty():
		_detail_holder.add_child(_text("등록된 스킬이 없습니다.", 13, UITheme.INK_DIM))
	else:
		for skill in character.skills:
			if skill != null:
				_add_stat_row(skill.display_name, "위력 %d" % skill.base_power)


func _add_stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := _text(label_text, 13, UITheme.INK_DIM)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_text(value_text, 13, UITheme.INK))

	_detail_holder.add_child(row)


func _add_slot_row(character: CharacterData, slot: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var icon := _icon(SLOT_ICON_PATH.get(slot, ""), 20)
	if icon != null:
		row.add_child(icon)

	var equipped := character.get_equipped(slot)
	var name_label := _text(equipped.display_name if equipped != null else "비어 있음", 13,
		UITheme.INK if equipped != null else UITheme.INK_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	_detail_holder.add_child(row)


# ===== 조작 =====

func _on_card_pressed(id: StringName) -> void:
	if id == _selected_id:
		return
	_selected_id = id
	_refresh()


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
