extends Control

# 교단 화면 (메타 UI).
#
# 교단은 **교주(플레이어)와 스토리에서 합류한 인물들이 모여 있는 본거지**다.
#
# 책임: 교주 정보를 보여주고 이름을 정하게 한다 + 모인 인원을 요약한다.
#
# 캐릭터 화면과 무엇이 다른가:
#   캐릭터 화면 = 인물 **한 명의 상세**(스텟/스킬/장비). 읽기 전용.
#   교단 화면   = **교주와 교단 전체**. 이름을 정하는 곳이고, 모인 인원의 요약이다.
#   그래서 명부를 여기서 다시 상세히 펼치지 않는다. 상세는 캐릭터 화면으로 보낸다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   교단 이름·직함        -> OrderSystem (문자열을 화면에 박지 않는다)
#   교주 이름·레벨·경험치 -> PlayerProfile
#   신도 명부            -> CharacterDatabase
#   편성 여부            -> PartySystem.has_character()
#   역할                 -> CharacterData.get_roles()
#   색                   -> UITheme

const BACK_ICON := "icon_back"
const ORDER_ICON := "icon_order"

const ROLE_ICON_NAME := {
	CharacterData.Role.TANK: "icon_role_tank",
	CharacterData.Role.RANGED_DEALER: "icon_role_ranged_dealer",
	CharacterData.Role.BUFFER: "icon_role_buffer",
}

const CHARACTERS_SCREEN := preload("res://screens/characters/CharactersScreen.tscn")

var _name_edit: LineEdit
var _profile_holder: VBoxContainer
var _roster_grid: GridContainer
var _leader_line: Label   # 배너의 "OOO · 트리아교의 교주" 줄


func _ready() -> void:
	_build()
	_refresh()

	PlayerProfile.profile_changed.connect(_refresh_profile)
	EventBus.party_changed.connect(func(_m): _refresh_roster())


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
	root.add_child(_build_banner())
	root.add_child(_build_profile_panel())
	root.add_child(_build_roster_panel())


# ── 교단 배너 ──
# 화면 맨 위에서 "여기가 어디인가"를 한눈에 알린다.
# 교단 상징(아이콘) + 이름 + 교주 소개 한 줄.
func _build_banner() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box_deep())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var emblem := _icon(ORDER_ICON, 56)
	if emblem != null:
		row.add_child(emblem)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)

	box.add_child(_text(OrderSystem.ORDER_NAME, 22, UITheme.INK))
	# "트리아교의 교주" — 문구 조립도 OrderSystem 이 한다.
	_leader_line = _text("", 14, UITheme.INK_DIM)
	box.add_child(_leader_line)

	return panel


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

	var icon := _icon(ORDER_ICON, 24)
	if icon != null:
		row.add_child(icon)

	var title := Label.new()
	# 교단 이름의 출처는 OrderSystem 이다.
	title.text = OrderSystem.ORDER_NAME
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	return row


# ── 교주 ──
func _build_profile_panel() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_profile_holder = VBoxContainer.new()
	_profile_holder.add_theme_constant_override("separation", 10)
	panel.add_child(_profile_holder)

	# 이름 입력은 다시 만들지 않는다(입력 중에 갈아 끼우면 글자가 끊긴다).
	# 그래서 _refresh_profile() 이 채우는 부분과 분리해 여기서 한 번만 만든다.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	_profile_holder.add_child(name_row)

	name_row.add_child(_text("%s 이름" % OrderSystem.LEADER_TITLE, 15, UITheme.INK))

	_name_edit = LineEdit.new()
	_name_edit.text = PlayerProfile.player_name
	# 비어 있을 때 무엇으로 보일지는 교단 도메인의 지식이다(OrderSystem 이 정한다).
	_name_edit.placeholder_text = OrderSystem.get_leader_display_name()
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(0, 40)
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 이름의 소유자는 PlayerProfile 이다. 화면은 값을 넘길 뿐 따로 들고 있지 않다.
	_name_edit.text_submitted.connect(func(value: String): PlayerProfile.set_player_name(value.strip_edges()))
	_name_edit.focus_exited.connect(func(): PlayerProfile.set_player_name(_name_edit.text.strip_edges()))
	name_row.add_child(_name_edit)

	return panel


# ── 신도 명부 ──
func _build_roster_panel() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)
	section.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	section.add_child(heading)

	var label := _text("모인 인원", 16, UITheme.INK_ON_DARK)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)

	# 상세는 캐릭터 화면의 책임이다. 여기서 같은 내용을 다시 펼치지 않는다.
	var detail := Button.new()
	detail.text = "인물 상세"
	detail.custom_minimum_size = Vector2(120, 36)
	detail.add_theme_font_size_override("font_size", 13)
	detail.add_theme_color_override("font_color", UITheme.INK)
	detail.add_theme_stylebox_override("normal", UITheme.panel_box())
	detail.add_theme_stylebox_override("hover", UITheme.panel_box())
	detail.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	detail.pressed.connect(func(): ScreenManager.push(CHARACTERS_SCREEN))
	heading.add_child(detail)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_child(scroll)

	_roster_grid = GridContainer.new()
	_roster_grid.columns = 4
	_roster_grid.add_theme_constant_override("h_separation", 10)
	_roster_grid.add_theme_constant_override("v_separation", 10)
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_grid)
	return section


# ===== 갱신 =====

func _refresh() -> void:
	_refresh_profile()
	_refresh_roster()


func _refresh_profile() -> void:
	if not is_instance_valid(_profile_holder):
		return

	# 이름 입력 줄(0번)은 남기고 그 아래만 다시 만든다.
	for i in range(_profile_holder.get_child_count() - 1, 0, -1):
		var child := _profile_holder.get_child(i)
		_profile_holder.remove_child(child)
		child.queue_free()

	# 입력 중이 아니라면 바깥에서 바뀐 이름을 따라간다.
	if is_instance_valid(_name_edit) and not _name_edit.has_focus():
		_name_edit.text = PlayerProfile.player_name

	# 배너의 교주 줄도 이름을 따라간다.
	if is_instance_valid(_leader_line):
		_leader_line.text = "%s · %s" % [
			OrderSystem.get_leader_display_name(),
			OrderSystem.get_leader_title_line(),
		]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_profile_holder.add_child(row)

	row.add_child(_stat("레벨", "Lv.%d" % PlayerProfile.level))
	row.add_child(_stat("누적 경험치", str(PlayerProfile.exp_total)))
	# 교단 인원 수의 출처는 OrderSystem 이다(명부는 CharacterDatabase 가 소유한다).
	row.add_child(_stat("모인 인원", "%d명" % OrderSystem.get_member_count()))
	row.add_child(_stat("편성", "%d/%d" % [PartySystem.get_size(), PartySystem.PARTY_SIZE]))


func _stat(label_text: String, value_text: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.add_child(_text(label_text, 12, UITheme.INK_DIM))
	box.add_child(_text(value_text, 16, UITheme.INK))
	return box


func _refresh_roster() -> void:
	if not is_instance_valid(_roster_grid):
		return
	_clear(_roster_grid)

	for id in CharacterDatabase.get_all_ids():
		_roster_grid.add_child(_make_member_card(id))


func _make_member_card(id: StringName) -> Control:
	var character := CharacterDatabase.get_character(id)
	var in_party := PartySystem.has_character(id)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 96)
	# 편성 중인 인원을 강조한다.
	card.add_theme_stylebox_override("panel", UITheme.accent_box() if in_party else UITheme.panel_box())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)

	if character == null:
		box.add_child(_text(String(id), 14, UITheme.INK))
		return card

	var swatch := ColorRect.new()
	swatch.color = character.tint
	swatch.custom_minimum_size = Vector2(0, 30)
	box.add_child(swatch)

	box.add_child(_text(character.display_name, 14, UITheme.INK))

	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 3)
	box.add_child(role_row)
	for role in character.get_roles():
		var icon := _icon(ROLE_ICON_NAME.get(role, ""), 16)
		if icon != null:
			role_row.add_child(icon)
	if in_party:
		role_row.add_child(_text("편성 중", 11, UITheme.INK))

	return card


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
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
