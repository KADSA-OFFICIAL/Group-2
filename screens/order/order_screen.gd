extends Control

# 교단 화면 (메타 UI).
#
# 교단은 **교주(플레이어)와 스토리에서 합류한 인물들이 모여 있는 본거지**다.
# 구조는 서브컬쳐 수집형 RPG 문법을 따른다: **좌 교주 카드 / 중앙 상징 / 우 명부**.
#
# 캐릭터 화면과 무엇이 다른가:
#   캐릭터 화면 = 인물 **한 명의 상세**(스텟/스킬/장비).
#   교단 화면   = **교주와 교단 전체**. 이름을 정하는 곳이고, 모인 인원의 요약이다.
#   그래서 명부를 여기서 상세히 펼치지 않는다. 상세는 캐릭터 화면으로 보낸다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   교단 이름·직함        -> OrderSystem (문자열을 화면에 박지 않는다)
#   교주 이름·레벨·경험치 -> PlayerProfile
#   신도 명부            -> CharacterDatabase
#   편성 여부            -> PartySystem.has_character()
#   역할                 -> CharacterData.get_roles()
#   색·조각              -> UITheme / HUDKit

const CHARACTERS_SCREEN_PATH := "res://screens/characters/CharactersScreen.tscn"

var _name_edit: LineEdit
var _profile_body: VBoxContainer
var _roster_grid: GridContainer
var _leader_line: Label


func _ready() -> void:
	_build()
	_refresh()

	PlayerProfile.profile_changed.connect(_refresh_profile)
	EventBus.party_changed.connect(func(_m): _refresh_roster())


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

	# 교단 이름의 출처는 OrderSystem 이다.
	root.add_child(HUDKit.make_header(OrderSystem.ORDER_NAME, "the order", "icon_order"))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var _col0 := _build_leader_panel()
	body.add_child(_col0)
	var _col1 := _build_center()
	body.add_child(_col1)
	var _col2 := _build_roster_panel()
	body.add_child(_col2)



# ── 좌: 교주 ──
func _build_leader_panel() -> Control:
	var panel := HUDKit.make_panel("교주", "leader")
	panel.custom_minimum_size = Vector2(HUDKit.RAIL_WIDTH, 0)
	var body := HUDKit.body_of(panel)

	# 이름 입력은 다시 만들지 않는다(입력 중에 갈아 끼우면 글자가 끊긴다).
	body.add_child(HUDKit.caption("leader name"))
	_name_edit = LineEdit.new()
	_name_edit.text = PlayerProfile.player_name
	_name_edit.placeholder_text = OrderSystem.get_leader_display_name()
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 38)
	_name_edit.add_theme_stylebox_override("normal", HUDKit.inset(8))
	_name_edit.add_theme_stylebox_override("focus", HUDKit.ghost_hover())
	_name_edit.add_theme_color_override("font_color", HUDKit.text_1())
	# 기본 placeholder 색은 이 밝은 면에서 거의 안 보인다. 이름을 아직 안 정한
	# 플레이어에게는 이 자리가 유일한 안내라서 명시한다.
	_name_edit.add_theme_color_override("font_placeholder_color", HUDKit.text_3())
	_name_edit.add_theme_font_size_override("font_size", 15)
	# 이름의 소유자는 PlayerProfile 이다. 화면은 값을 넘길 뿐이다.
	_name_edit.text_submitted.connect(func(v: String): PlayerProfile.set_player_name(v.strip_edges()))
	_name_edit.focus_exited.connect(func(): PlayerProfile.set_player_name(_name_edit.text.strip_edges()))
	body.add_child(_name_edit)

	_profile_body = VBoxContainer.new()
	_profile_body.add_theme_constant_override("separation", 4)
	body.add_child(_profile_body)

	body.add_child(HUDKit.make_serial("ORD.TRIA / SEC-01"))
	return panel


# ── 중앙: 교단 상징 ──
func _build_center() -> Control:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 10)

	var emblem := HUDKit.make_icon("icon_order", 180)
	if emblem != null:
		emblem.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		center.add_child(emblem)

	var name_label := HUDKit.label(OrderSystem.ORDER_NAME, 30, HUDKit.text_1(), 700)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(name_label)

	_leader_line = HUDKit.label("", 13, HUDKit.text_2())
	_leader_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_leader_line)
	return center


# ── 우: 명부 + 우하단 CTA ──
func _build_roster_panel() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(HUDKit.DETAIL_WIDTH, 0)
	column.add_theme_constant_override("separation", 10)

	var panel := HUDKit.make_panel("모인 인원", "members")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HUDKit.body_of(panel).add_child(scroll)

	_roster_grid = GridContainer.new()
	_roster_grid.columns = 1
	_roster_grid.add_theme_constant_override("h_separation", 8)
	_roster_grid.add_theme_constant_override("v_separation", 8)
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_grid)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)

	# 상세는 캐릭터 화면의 책임이다. 여기서 같은 내용을 다시 펼치지 않는다.
	var detail := HUDKit.make_cta("인물 상세", "detail")
	detail.pressed.connect(func(): ScreenManager.swap(load(CHARACTERS_SCREEN_PATH)))
	actions.add_child(detail)
	return column


# ===== 갱신 =====

func _refresh() -> void:
	_refresh_profile()
	_refresh_roster()


func _refresh_profile() -> void:
	if not is_instance_valid(_profile_body):
		return
	_clear(_profile_body)

	# 입력 중이 아니라면 바깥에서 바뀐 이름을 따라간다.
	if is_instance_valid(_name_edit) and not _name_edit.has_focus():
		_name_edit.text = PlayerProfile.player_name

	if is_instance_valid(_leader_line):
		_leader_line.text = "%s · %s" % [
			OrderSystem.get_leader_display_name(), OrderSystem.get_leader_title_line()]

	# 삼각근 Lv.과 다음 Lv.까지의 진행도. 누적 프로틴은 진행도에서 도출되므로 따로 적지 않는다.
	var progress := PlayerProfile.get_level_progress()
	_profile_body.add_child(HUDKit.stat_row(
		"삼각근", "deltoid", "Lv.%d" % PlayerProfile.deltoid_level,
		"×%.2f" % PlayerProfile.get_stat_multiplier()))
	_profile_body.add_child(HUDKit.stat_row(
		"프로틴", "protein", "%s / %s" % [
			HUDKit.comma(int(progress["current"])), HUDKit.comma(int(progress["required"]))]))
	_profile_body.add_child(HUDKit.stat_row("모인 인원", "members", "%d명" % OrderSystem.get_member_count()))
	_profile_body.add_child(HUDKit.stat_row("편성", "party", "%d / %d" % [PartySystem.get_size(), PartySystem.PARTY_SIZE]))


func _refresh_roster() -> void:
	if not is_instance_valid(_roster_grid):
		return
	_clear(_roster_grid)
	for id in CharacterDatabase.get_all_ids():
		_roster_grid.add_child(_make_member_card(id))


func _make_member_card(id: StringName) -> Control:
	var character := CharacterDatabase.get_character(id)
	var in_party: bool = PartySystem.has_character(id)

	# 3열 그리드였는데 명부 폭이 340 이라 카드가 100px 밖에 안 나와서 이름이 전부
	# 잘렸다. 여기는 "누가 모여 있나"를 읽는 곳이므로 이름이 잘리면 목적을 잃는다.
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 68)
	card.add_theme_stylebox_override("panel", HUDKit.card(in_party))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	if character != null:
		row.add_child(HUDKit.portrait_block(character, Vector2(40, 48)))

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(box)

		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 6)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(head)
		head.add_child(HUDKit.label(character.display_name, 14, HUDKit.text_1(), 700))
		if in_party:
			# 칩으로 둔다. 글자색만으로 표시하면 편성된(액센트로 찬) 카드에서 묻힌다.
			head.add_child(HUDKit.tag_chip("편성", UITheme.ACCENT.darkened(0.4)))

		box.add_child(HUDKit.role_chip_row(character))
	else:
		row.add_child(HUDKit.label(String(id), 13, HUDKit.text_2()))

	return card


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
