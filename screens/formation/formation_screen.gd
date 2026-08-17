extends Control

# 편성 화면 (메타 UI).
#
# 구조는 서브컬쳐 수집형 RPG 문법을 따른다: **좌 로스터 / 중앙 파티 슬롯 / 우 시너지**.
# 공용 조각은 HUDKit 이 소유한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   로스터   -> CharacterDatabase (id 목록과 정의)
#   파티     -> PartySystem (인원 상한 PARTY_SIZE, 현재 편성)
#   캐릭터   -> CharacterData (표시 이름/역할/외형 tint)
#   시너지   -> SynergySystem.get_summary()  (여기서 역할 수를 세지 않는다)
#   색·조각  -> UITheme / HUDKit
#
# 선택 상태는 "확정 전 임시 선택"이라 이 화면이 들고 있다가,
# 확정 버튼을 눌렀을 때만 PartySystem.set_party() 로 넘긴다.
# (선택할 때마다 파티를 바꾸면 취소가 불가능해진다.)
#
# 참고: docs/combat-screen-design.md §1(파티 3명), §8(시너지)

# 캐릭터 화면은 경로만 둔다. 그쪽도 이 화면을 참조하므로 서로 preload 하면 순환이 된다.
const CHARACTERS_SCREEN_PATH := "res://screens/characters/CharactersScreen.tscn"

const ROLE_ICON_NAME := {
	CharacterData.Role.TANK: "icon_role_tank",
	CharacterData.Role.RANGED_DEALER: "icon_role_ranged_dealer",
	CharacterData.Role.BUFFER: "icon_role_buffer",
}

# 확정 전 임시 선택 (character_id). 순서가 곧 파티 순서다.
var _selected: Array[StringName] = []

var _roster_grid: GridContainer
var _slot_row: HBoxContainer
var _synergy_body: VBoxContainer
var _confirm_button: Button
var _count_label: Label


func _ready() -> void:
	for character in PartySystem.get_members():
		_selected.append(character.character_id)

	_build()
	_refresh()


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

	root.add_child(HUDKit.make_header("편성", "formation", "icon_formation"))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	body.add_child(_build_roster_panel())
	body.add_child(_build_center())
	body.add_child(_build_right())


# ── 좌: 로스터 ──
func _build_roster_panel() -> Control:
	var panel := HUDKit.make_panel("로스터", "roster")
	panel.custom_minimum_size = Vector2(HUDKit.RAIL_WIDTH, 0)
	var body := HUDKit.body_of(panel)

	_count_label = HUDKit.label("", 12, HUDKit.text_2())
	body.add_child(_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	_roster_grid = GridContainer.new()
	_roster_grid.columns = 2
	_roster_grid.add_theme_constant_override("h_separation", 8)
	_roster_grid.add_theme_constant_override("v_separation", 8)
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_grid)
	return panel


# ── 중앙: 파티 슬롯. 가운데는 비워 두고 슬롯만 얹는다 ──
func _build_center() -> Control:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 10)

	var cap := HUDKit.caption("party slots")
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(cap)

	_slot_row = HBoxContainer.new()
	_slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_slot_row.add_theme_constant_override("separation", 12)
	center.add_child(_slot_row)

	var serial := HUDKit.make_serial("PARTY.CFG / SLOTS %d" % PartySystem.PARTY_SIZE)
	serial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(serial)
	return center


# ── 우: 시너지 + 우하단 CTA ──
func _build_right() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(HUDKit.DETAIL_WIDTH, 0)
	column.add_theme_constant_override("separation", 10)

	var panel := HUDKit.make_panel("시너지 미리보기", "synergy preview")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HUDKit.body_of(panel).add_child(scroll)

	_synergy_body = VBoxContainer.new()
	_synergy_body.add_theme_constant_override("separation", 6)
	_synergy_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_synergy_body)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)

	# 누구를 넣을지 고르려면 스텟을 봐야 한다. 상세는 캐릭터 화면의 책임이다.
	var detail := HUDKit.make_ghost("인물 상세", 110)
	detail.pressed.connect(func(): ScreenManager.swap(load(CHARACTERS_SCREEN_PATH)))
	actions.add_child(detail)

	_confirm_button = HUDKit.make_cta("편성 확정", "confirm")
	_confirm_button.pressed.connect(_on_confirm_pressed)
	actions.add_child(_confirm_button)
	return column


# ===== 갱신 =====

func _refresh() -> void:
	_refresh_slots()
	_refresh_synergy()
	_refresh_roster()
	_refresh_confirm()


func _refresh_slots() -> void:
	_clear(_slot_row)
	for i in PartySystem.PARTY_SIZE:
		var filled: bool = i < _selected.size()

		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(150, 190)
		slot.add_theme_stylebox_override("panel", HUDKit.card(filled))

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(box)

		box.add_child(HUDKit.caption("slot %02d" % (i + 1)))

		if filled:
			var character := CharacterDatabase.get_character(_selected[i])
			if character != null:
				var swatch := ColorRect.new()
				swatch.color = Color(character.tint.r, character.tint.g, character.tint.b, 0.5)
				swatch.custom_minimum_size = Vector2(0, 90)
				swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
				box.add_child(swatch)

				var name_label := HUDKit.label(character.display_name, 13, HUDKit.text_1(), 600)
				name_label.clip_text = true
				box.add_child(name_label)

				var role_row := HBoxContainer.new()
				role_row.add_theme_constant_override("separation", 3)
				box.add_child(role_row)
				for role in character.get_roles():
					var icon := HUDKit.make_icon(ROLE_ICON_NAME.get(role, ""), 16)
					if icon != null:
						role_row.add_child(icon)
		else:
			var empty := HUDKit.label("비어 있음", 12, HUDKit.text_3())
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
			box.add_child(empty)

		if filled:
			slot.add_child(HUDKit.make_brackets())
		_slot_row.add_child(slot)


func _refresh_synergy() -> void:
	_clear(_synergy_body)
	# 시너지는 SynergySystem 이 계산한다. 여기서 역할 수를 세지 않는다.
	for entry in SynergySystem.get_summary(_selected_characters()):
		var active: bool = entry.get("tier", SynergySystem.Tier.NONE) != SynergySystem.Tier.NONE

		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", HUDKit.card(active))
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		panel.add_child(box)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 8)
		box.add_child(head)

		var name_label := HUDKit.label(String(entry.get("name", "?")), 14, HUDKit.text_1(), 600)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		head.add_child(HUDKit.label("×%d" % int(entry.get("count", 0)), 14,
			UITheme.ACCENT if active else HUDKit.text_3(), 700))

		box.add_child(HUDKit.label(String(entry.get("tier_name", "")), 11,
			UITheme.ACCENT if active else HUDKit.text_3()))
		_synergy_body.add_child(panel)


func _refresh_roster() -> void:
	_clear(_roster_grid)
	var total := CharacterDatabase.get_count()
	_count_label.text = "보유 %d / %d" % [total, total]
	for id in CharacterDatabase.get_all_ids():
		_roster_grid.add_child(_make_roster_card(id))


func _make_roster_card(id: StringName) -> Control:
	var character := CharacterDatabase.get_character(id)
	var selected: bool = _selected.has(id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 112)
	card.add_theme_stylebox_override("panel", HUDKit.card(selected))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	if character != null:
		var swatch := ColorRect.new()
		swatch.color = Color(character.tint.r, character.tint.g, character.tint.b, 0.5)
		swatch.custom_minimum_size = Vector2(0, 46)
		swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(swatch)

		var role_row := HBoxContainer.new()
		role_row.add_theme_constant_override("separation", 2)
		box.add_child(role_row)
		for role in character.get_roles():
			var icon := HUDKit.make_icon(ROLE_ICON_NAME.get(role, ""), 15)
			if icon != null:
				role_row.add_child(icon)
		if selected:
			role_row.add_child(HUDKit.label("선택", 10, UITheme.ACCENT, 700))

		var name_label := HUDKit.label(character.display_name, 12, HUDKit.text_1(), 600)
		name_label.clip_text = true
		box.add_child(name_label)
	else:
		box.add_child(HUDKit.label(String(id), 12, HUDKit.text_2()))

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_on_card_pressed.bind(id))
	card.add_child(button)

	if selected:
		card.add_child(HUDKit.make_brackets())
	return card


func _refresh_confirm() -> void:
	var full: bool = _selected.size() == PartySystem.PARTY_SIZE
	_confirm_button.text = "편성 확정  CONFIRM" if full else "%d명 더 선택" % (PartySystem.PARTY_SIZE - _selected.size())
	_confirm_button.disabled = not full


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


# ===== 조각 =====

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
