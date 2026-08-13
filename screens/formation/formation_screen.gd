extends Control

# 편성 화면 (메타 UI).
#
# 책임: 로스터에서 파티 멤버를 고르고, 확정 시 PartySystem 에 넘긴다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   로스터   -> CharacterDatabase (id 목록과 정의)
#   파티     -> PartySystem (인원 상한 PARTY_SIZE, 현재 편성)
#   캐릭터   -> CharacterData (표시 이름/역할/외형 tint)
#   시너지   -> SynergySystem.get_summary()
#   색       -> UITheme
#
# 선택 상태는 "확정 전 임시 선택"이라 이 화면이 들고 있다가,
# 확정 버튼을 눌렀을 때만 PartySystem.set_party() 로 넘긴다.
# (선택할 때마다 파티를 바꾸면 취소가 불가능해진다.)
#
# 참고: docs/combat-screen-design.md §1(파티 3명), §8(시너지)

const ROLE_ICON_NAME := {
	CharacterData.Role.TANK: "icon_role_tank",
	CharacterData.Role.RANGED_DEALER: "icon_role_ranged_dealer",
	CharacterData.Role.BUFFER: "icon_role_buffer",
}

const SYNERGY_ICON := "icon_synergy"
const BACK_ICON := "icon_back"

# 확정 전 임시 선택 (character_id). 순서가 곧 파티 순서다.
var _selected: Array[StringName] = []

var _roster_grid: GridContainer
var _slot_row: HBoxContainer
var _synergy_row: HBoxContainer
var _confirm_button: Button
var _title_label: Label


func _ready() -> void:
	# 현재 편성을 초기 선택으로 가져온다(들어오자마자 지금 상태가 보이도록).
	for character in PartySystem.get_members():
		_selected.append(character.character_id)

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
	root.add_child(_build_slots())
	root.add_child(_build_synergy())
	root.add_child(_build_roster())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	root.add_child(_build_footer())


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
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_title_label)
	return row


# ── 현재 선택 슬롯 (PARTY_SIZE 칸) ──
func _build_slots() -> Control:
	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", 10)
	return _slot_row


# ── 시너지 미리보기 ──
# 선택이 바뀔 때마다 즉시 갱신한다. 확정 전에 조합 결과를 볼 수 있어야 편성이 의미가 있다.
func _build_synergy() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 6)
	var icon := _icon(SYNERGY_ICON, 20)
	if icon != null:
		heading.add_child(icon)
	var label := Label.new()
	label.text = "시너지 미리보기"
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	heading.add_child(label)
	section.add_child(heading)

	_synergy_row = HBoxContainer.new()
	_synergy_row.add_theme_constant_override("separation", 8)
	section.add_child(_synergy_row)
	return section


# ── 로스터 ──
func _build_roster() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 6)

	var label := Label.new()
	label.text = "로스터 (%d명)" % CharacterDatabase.get_count()
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	section.add_child(label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 220)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(scroll)

	_roster_grid = GridContainer.new()
	_roster_grid.columns = 5
	_roster_grid.add_theme_constant_override("h_separation", 10)
	_roster_grid.add_theme_constant_override("v_separation", 10)
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_grid)
	return section


func _build_footer() -> Control:
	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(0, 56)
	_confirm_button.add_theme_font_size_override("font_size", 18)
	_confirm_button.add_theme_color_override("font_color", UITheme.INK)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	return _confirm_button


# ===== 갱신 =====
# 선택이 바뀌면 슬롯·시너지·로스터·확정 버튼을 다시 그린다.
func _refresh() -> void:
	_title_label.text = "편성 (%d / %d)" % [_selected.size(), PartySystem.PARTY_SIZE]
	_refresh_slots()
	_refresh_synergy()
	_refresh_roster()
	_refresh_confirm()


func _refresh_slots() -> void:
	_clear(_slot_row)
	for i in PartySystem.PARTY_SIZE:
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(150, 90)
		slot.add_theme_stylebox_override("panel", UITheme.panel_box() if i < _selected.size() else UITheme.panel_box_deep())

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		slot.add_child(box)

		if i < _selected.size():
			var character := CharacterDatabase.get_character(_selected[i])
			if character != null:
				var swatch := ColorRect.new()
				swatch.color = character.tint
				swatch.custom_minimum_size = Vector2(0, 34)
				box.add_child(swatch)
				box.add_child(_text(character.display_name, 15, UITheme.INK))
				box.add_child(_text(character.get_roles_display_name(), 12, UITheme.INK_DIM))
		else:
			box.add_child(_text("비어 있음", 14, UITheme.INK_DIM))

		_slot_row.add_child(slot)


func _refresh_synergy() -> void:
	_clear(_synergy_row)
	# 시너지는 SynergySystem 이 계산한다. 여기서 역할 수를 세지 않는다.
	for entry in SynergySystem.get_summary(_selected_characters()):
		var active: bool = entry.get("tier", SynergySystem.Tier.NONE) != SynergySystem.Tier.NONE

		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", UITheme.panel_box() if active else UITheme.panel_box_deep())

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		chip.add_child(box)
		box.add_child(_text("%s %d" % [entry.get("name", "?"), entry.get("count", 0)], 14, UITheme.INK))
		box.add_child(_text(String(entry.get("tier_name", "")), 12, UITheme.INK if active else UITheme.INK_DIM))

		_synergy_row.add_child(chip)


func _refresh_roster() -> void:
	_clear(_roster_grid)
	for id in CharacterDatabase.get_all_ids():
		_roster_grid.add_child(_make_roster_card(id))


func _make_roster_card(id: StringName) -> Control:
	var character := CharacterDatabase.get_character(id)
	var selected := _selected.has(id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 120)
	# 선택된 캐릭터는 강조색으로 구분한다.
	card.add_theme_stylebox_override("panel", UITheme.accent_box() if selected else UITheme.panel_box())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	if character != null:
		var swatch := ColorRect.new()
		swatch.color = character.tint
		swatch.custom_minimum_size = Vector2(0, 40)
		box.add_child(swatch)
		box.add_child(_text(character.display_name, 14, UITheme.INK))

		# 겸직이면 get_roles() 가 2개를 돌려주므로 아이콘도 2개가 붙는다.
		var role_row := HBoxContainer.new()
		role_row.add_theme_constant_override("separation", 3)
		box.add_child(role_row)
		for role in character.get_roles():
			var icon := _icon(ROLE_ICON_NAME.get(role, ""), 18)
			if icon != null:
				role_row.add_child(icon)
		role_row.add_child(_text(character.get_roles_display_name(), 11, UITheme.INK_DIM))
	else:
		box.add_child(_text(String(id), 14, UITheme.INK))

	# 카드 전체를 누를 수 있게 투명 버튼을 덮는다.
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


func _refresh_confirm() -> void:
	var full := _selected.size() == PartySystem.PARTY_SIZE
	_confirm_button.text = "편성 확정" if full else "%d명 더 선택하세요" % (PartySystem.PARTY_SIZE - _selected.size())
	_confirm_button.disabled = not full
	_confirm_button.add_theme_stylebox_override(
		"normal", UITheme.accent_box() if full else UITheme.panel_box_deep()
	)


# ===== 조작 =====

# 카드를 누르면 선택/해제한다. 이미 가득 찬 상태에서 새 캐릭터를 누르면 무시한다.
func _on_card_pressed(id: StringName) -> void:
	if _selected.has(id):
		_selected.erase(id)
	elif _selected.size() < PartySystem.PARTY_SIZE:
		_selected.append(id)
	else:
		return
	_refresh()


# 확정: PartySystem 이 유효성(인원/중복/존재 여부)을 검사하므로 여기서 다시 검사하지 않는다.
func _on_confirm_pressed() -> void:
	if PartySystem.set_party(_selected):
		ScreenManager.pop()


func _on_back_pressed() -> void:
	ScreenManager.pop()


# ===== 공용 조각 =====

func _selected_characters() -> Array:
	var out: Array = []
	for id in _selected:
		var character := CharacterDatabase.get_character(id)
		if character != null:
			out.append(character)
	return out


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
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
