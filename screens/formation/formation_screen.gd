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

# ===== 출격 모드 (Sortie mode) =====
#
# 이 화면은 두 곳에서 열린다:
#   메타 메뉴  -> 편성만 바꾼다. 확정하면 화면을 닫는다.
#   스테이지 선택 -> 이 파티로 **그 스테이지에 출격**한다(#243).
#
# 두 번째 파티 선택 화면을 따로 만들지 않은 이유: 로스터·파티·시너지를 읽는 UI 를
# 두 벌 두면 한쪽만 고쳐지는 일이 생긴다(CLAUDE.md 기초 시스템 — 병렬 구현 금지).
# 달라지는 것은 **확정 버튼이 무엇을 하는가** 하나뿐이라 그 지점만 분기한다.
#
# 스테이지를 언제 시작하는가: **확정한 뒤**다. 화면을 열 때 시작하면 뒤로 눌러
# 돌아왔을 때 이미 전투가 시작되어 있다.
var _sortie: bool = false
var _sortie_stage_id: StringName = &""

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

	var _col0 := _build_roster_panel()
	body.add_child(_col0)
	var _col1 := _build_center()
	body.add_child(_col1)
	var _col2 := _build_right()
	body.add_child(_col2)



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
	_roster_grid.columns = 1
	_roster_grid.add_theme_constant_override("h_separation", 8)
	_roster_grid.add_theme_constant_override("v_separation", 8)
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(HUDKit.hover_safe(_roster_grid))
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

	var panel := HUDKit.make_panel("시너지 미리보기", "synergy preview", 14, false, "icon_synergy")
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

		# 중앙은 이 화면의 주인공이다. 카드를 크게 둬서 화면이 비어 보이지 않게 한다.
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(168, 258)
		slot.add_theme_stylebox_override("panel", HUDKit.card(filled))

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(box)

		box.add_child(HUDKit.caption("slot %02d" % (i + 1)))

		if filled:
			var character := CharacterDatabase.get_character(_selected[i])
			if character != null:
				var portrait := HUDKit.portrait_block(character, Vector2(0, 150), HUDKit.Framing.BUST)
				portrait.size_flags_vertical = Control.SIZE_EXPAND_FILL
				box.add_child(portrait)

				# 이름은 잘라내지 않고 줄바꿈한다. 잘린 이름은 정보가 아니다.
				var name_label := HUDKit.label(character.display_name, 15, HUDKit.text_1(), 700)
				name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				box.add_child(name_label)

				box.add_child(HUDKit.role_chip_row(character))
		else:
			var empty := PanelContainer.new()
			empty.add_theme_stylebox_override("panel", HUDKit.inset(10))
			empty.size_flags_vertical = Control.SIZE_EXPAND_FILL
			empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(empty)

			var hint := HUDKit.label("비어 있음", 13, HUDKit.text_3())
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hint.set_anchors_preset(Control.PRESET_FULL_RECT)
			empty.add_child(hint)

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

		# 활성 카드는 액센트로 꽉 차 있다. 그 위 글자를 액센트로 두면 안 보인다.
		var head_color: Color = HUDKit.text_on_accent() if active else HUDKit.text_1()
		var sub_color: Color = HUDKit.text_on_accent() if active else HUDKit.text_3()

		# 카드가 어느 역할의 것인지는 이름 글자보다 아이콘이 먼저 읽힌다.
		# 아이콘 이름의 출처는 UITheme 다(여기서 대응표를 다시 적지 않는다).
		var icon := HUDKit.make_icon(UITheme.role_icon_name(int(entry.get("role", -1))), 20)
		if icon != null:
			head.add_child(icon)

		var name_label := HUDKit.label(String(entry.get("name", "?")), 15, head_color, 700)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_label)
		head.add_child(HUDKit.label("×%d" % int(entry.get("count", 0)), 16, head_color, 700))

		box.add_child(HUDKit.label(String(entry.get("tier_name", "")), 12, sub_color))
		_synergy_body.add_child(panel)


func _refresh_roster() -> void:
	_clear(_roster_grid)
	var total := CharacterDatabase.get_playable_count()
	_count_label.text = "보유 %d / %d" % [total, total]
	for id in CharacterDatabase.get_playable_ids():
		_roster_grid.add_child(_make_roster_card(id))


func _make_roster_card(id: StringName) -> Control:
	var character := CharacterDatabase.get_character(id)
	var selected: bool = _selected.has(id)

	# 세로 카드 2열이 아니라 가로 리스트 행이다.
	# 2열로 두면 카드 폭이 135px 밖에 안 나와서 한글 이름이 전부 잘렸다.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)
	card.add_theme_stylebox_override("panel", HUDKit.card(selected))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	if character != null:
		row.add_child(HUDKit.portrait_block(character, Vector2(44, 52), HUDKit.Framing.HEAD))

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)

		box.add_child(HUDKit.label(character.display_name, 15, HUDKit.text_1(), 700))
		box.add_child(HUDKit.role_chip_row(character))
	else:
		row.add_child(HUDKit.label(String(id), 13, HUDKit.text_2()))

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_on_card_pressed.bind(id))
	card.add_child(button)
	# 카드는 전면 투명 버튼이 클릭을 받으므로, 호버 신호도 그 버튼에서 듣는다.
	HUDKit.hover_lift(card, button)

	return card


func _refresh_confirm() -> void:
	var full: bool = _selected.size() == PartySystem.PARTY_SIZE
	if not full:
		_confirm_button.text = "%d명 더 선택" % (PartySystem.PARTY_SIZE - _selected.size())
	elif _sortie:
		_confirm_button.text = "이 파티로 출격  SORTIE"
	else:
		_confirm_button.text = "편성 확정  CONFIRM"
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


# 출격 모드로 바꾼다. 스테이지 선택 화면이 push() 직후에 부른다.
#
# _ready() 가 이미 돌아 버튼이 만들어진 뒤이므로 문구를 다시 그린다.
# stage_id 가 비어 있어도 출격 모드다 — 저작된 스테이지가 없을 때의 출격
# (현재 전장으로 바로 들어가는 길)이 그 경우다.
func set_sortie(stage_id: StringName = &"") -> void:
	_sortie = true
	_sortie_stage_id = stage_id
	if _confirm_button != null:
		_refresh_confirm()


# 확정: PartySystem 이 유효성(인원/중복/존재 여부)을 검사하므로 여기서 다시 검사하지 않는다.
#
# 출격 모드면 파티를 반영한 **뒤에** 스테이지를 요청한다. 순서가 중요하다 —
# 스테이지를 먼저 시작하면 전장이 이전 파티로 만들어진다.
func _on_confirm_pressed() -> void:
	if not PartySystem.set_party(_selected):
		return

	if not _sortie:
		ScreenManager.pop()
		return

	if not String(_sortie_stage_id).is_empty():
		StageSystem.request_stage(_sortie_stage_id)
	ScreenManager.close_all()


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
