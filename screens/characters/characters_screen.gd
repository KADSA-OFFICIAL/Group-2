extends Control

# 캐릭터 화면 (메타 UI).
#
# 구조는 서브컬쳐 수집형 RPG 문법을 따른다: **좌 리스트 / 중앙 프리뷰 / 우 상세**.
# 공용 조각은 HUDKit 이 소유한다(헤더·패널·스탯 행·브래킷·CTA).
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   로스터    -> CharacterDatabase
#   캐릭터    -> CharacterData (이름/설명/역할/외형/스킬/장비)
#   스텟      -> PlayerStats 파생 getter (계산식을 여기서 다시 쓰지 않는다)
#   장비 보정 -> CharacterData.get_equipment_bonuses()
#   파티 여부 -> PartySystem.has_character()
#   색·조각   -> UITheme / HUDKit
#
# 이 게임에 없는 것은 만들지 않았다:
#   레어도 등급, 전투력, 캐릭터 레벨·EXP·돌파, 스킨 — 전부 시스템이 없다.
#   장르 문법대로면 들어갈 자리이지만, 없는 수치를 지어내면 그게 설정이 된다.

const EQUIPMENT_SCREEN_PATH := "res://screens/equipment/EquipmentScreen.tscn"

const ROLE_ICON_NAME := {
	CharacterData.Role.TANK: "icon_role_tank",
	CharacterData.Role.RANGED_DEALER: "icon_role_ranged_dealer",
	CharacterData.Role.BUFFER: "icon_role_buffer",
}

const SLOT_ICON_NAME := {
	EquipmentData.Slot.WEAPON: "icon_slot_weapon",
	EquipmentData.Slot.ARMOR: "icon_slot_armor",
	EquipmentData.Slot.ACCESSORY: "icon_slot_accessory",
}

# 좌측 세로 서브탭. 지금 내용이 있는 것만 둔다.
enum Tab { STATS, SKILLS, GEAR }

const TAB_LABELS := {
	Tab.STATS: ["스탯", "STATS"],
	Tab.SKILLS: ["스킬", "SKILLS"],
	Tab.GEAR: ["장비", "GEAR"],
}

var _selected_id: StringName = &""
var _tab: Tab = Tab.STATS

var _roster_grid: GridContainer
var _detail_body: VBoxContainer
var _tab_rail: VBoxContainer
var _preview_holder: Control
var _count_label: Label


func _ready() -> void:
	var ids := CharacterDatabase.get_all_ids()
	if not ids.is_empty():
		_selected_id = ids[0]

	_build()
	_refresh()


# ===== 화면 구성 =====
# 가장자리로 밀어낸 ㄷ자 프레임: 좌 리스트 / 중앙 프리뷰 / 우 상세 + 우하단 CTA.

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

	root.add_child(HUDKit.make_header("캐릭터", "character", "icon_characters"))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	body.add_child(_build_tab_rail())
	body.add_child(_build_roster_panel())
	body.add_child(_build_center())
	body.add_child(_build_detail_panel())


# ── 좌측 끝: 세로 서브탭 레일 ──
func _build_tab_rail() -> Control:
	_tab_rail = VBoxContainer.new()
	_tab_rail.add_theme_constant_override("separation", 6)
	return _tab_rail


func _fill_tab_rail() -> void:
	for child in _tab_rail.get_children():
		_tab_rail.remove_child(child)
		child.queue_free()

	for tab in [Tab.STATS, Tab.SKILLS, Tab.GEAR]:
		var names: Array = TAB_LABELS[tab]
		var active: bool = tab == _tab

		var holder := PanelContainer.new()
		holder.custom_minimum_size = Vector2(64, 58)
		holder.add_theme_stylebox_override("panel", HUDKit.card(active))

		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 0)
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(box)

		var ko := HUDKit.label(names[0], 12, HUDKit.text_1() if active else HUDKit.text_2(), 600)
		ko.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(ko)
		var en := HUDKit.caption(names[1])
		en.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(en)

		var button := Button.new()
		button.flat = true
		button.set_anchors_preset(Control.PRESET_FULL_RECT)
		for state in ["normal", "hover", "pressed", "focus"]:
			button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		button.pressed.connect(_on_tab_pressed.bind(tab))
		holder.add_child(button)


		_tab_rail.add_child(holder)

	_tab_rail.add_child(HUDKit.make_serial("SYS.03\nROSTER"))


# ── 좌측: 로스터 리스트 ──
func _build_roster_panel() -> Control:
	var panel := HUDKit.make_panel("보유 인원", "owned units")
	panel.custom_minimum_size = Vector2(HUDKit.RAIL_WIDTH, 0)
	var body := HUDKit.body_of(panel)

	_count_label = HUDKit.label("", 12, HUDKit.text_2())
	body.add_child(_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	_roster_grid = GridContainer.new()
	_roster_grid.columns = 1
	_roster_grid.add_theme_constant_override("h_separation", 8)
	_roster_grid.add_theme_constant_override("v_separation", 8)
	_roster_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_roster_grid)
	return panel


# ── 중앙: 프리뷰. 비워 두는 자리다 ──
func _build_center() -> Control:
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 8)

	_preview_holder = Control.new()
	_preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_preview_holder)

	var serial := HUDKit.make_serial("PREVIEW / NO PORTRAIT ASSET")
	serial.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(serial)
	return center


# ── 우측: 상세 + 우하단 CTA ──
func _build_detail_panel() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(HUDKit.DETAIL_WIDTH, 0)
	column.add_theme_constant_override("separation", 10)

	var panel := HUDKit.make_panel("", "")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(panel)

	# 상세 내용은 스크롤 안에 넣는다. 안 그러면 행이 많을 때 패널이 세로로 부풀어
	# 아래 CTA 를 화면 밖으로 밀어낸다(실제로 그렇게 잘렸다).
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HUDKit.body_of(panel).add_child(scroll)

	_detail_body = VBoxContainer.new()
	_detail_body.add_theme_constant_override("separation", 6)
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_body)

	# 주 CTA 는 우하단 하나. 보조는 그 왼쪽에 아웃라인.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)

	var to_gear := HUDKit.make_ghost("장비 관리", 120)
	to_gear.pressed.connect(func(): ScreenManager.swap(load(EQUIPMENT_SCREEN_PATH)))
	actions.add_child(to_gear)

	var cta := HUDKit.make_cta("편성으로", "formation")
	cta.pressed.connect(func(): ScreenManager.swap(load("res://screens/formation/FormationScreen.tscn")))
	actions.add_child(cta)
	return column


# ===== 갱신 =====

func _refresh() -> void:
	_fill_tab_rail()
	_refresh_roster()
	_refresh_preview()
	_refresh_detail()


func _refresh_roster() -> void:
	_clear(_roster_grid)
	var total := CharacterDatabase.get_count()
	_count_label.text = "보유 %d / %d" % [total, total]

	for id in CharacterDatabase.get_all_ids():
		_roster_grid.add_child(_make_roster_card(id))


# 가로 리스트 행.
#
# 원래는 장르 관례대로 세로 카드 2열이었는데, 레일 폭이 280 이라 카드가 130px 밖에
# 안 나와서 한글 이름이 전부 잘렸다("탱커/버"). 잘린 이름은 정보가 아니므로
# 세로 카드를 포기하고 가로 행으로 바꿨다. 세로 카드는 초상 아트가 들어온 뒤에
# 폭을 다시 확보해서 되살릴 자리다.
func _make_roster_card(id: StringName) -> Control:
	var character := CharacterDatabase.get_character(id)
	var selected: bool = id == _selected_id

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 72)
	card.add_theme_stylebox_override("panel", HUDKit.card(selected))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	if character != null:
		row.add_child(HUDKit.portrait_block(character, Vector2(44, 52)))

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
		head.add_child(HUDKit.label(character.display_name, 15, HUDKit.text_1(), 700))
		if PartySystem.has_character(id):
			head.add_child(HUDKit.tag_chip("편성", UITheme.ACCENT.darkened(0.4)))

		box.add_child(HUDKit.role_chip_row(character, ROLE_ICON_NAME))
	else:
		row.add_child(HUDKit.label(String(id), 13, HUDKit.text_2()))

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_on_card_pressed.bind(id))
	card.add_child(button)

	return card


# 중앙 프리뷰.
#
# 예전에는 tint 색면 한 장만 덩그러니 깔았다. 색면만 있으면 그게 캐릭터를 가리키는
# 건지 그냥 배경인지 알 수 없어서, 이름과 역할 칩을 아래에 붙여 한 덩어리로 만든다.
# 초상 아트가 들어오면 portrait_block 이 알아서 색면 대신 그림을 채운다.
func _refresh_preview() -> void:
	_clear(_preview_holder)
	var character := _current()
	if character == null:
		return

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 12)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_holder.add_child(column)

	var art := HUDKit.portrait_block(character, Vector2(230, 330))
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(art)

	var name_label := HUDKit.label(character.display_name, 26, HUDKit.text_1(), 700)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)

	var chips := HUDKit.role_chip_row(character, ROLE_ICON_NAME)
	(chips as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(chips)


func _refresh_detail() -> void:
	_clear(_detail_body)
	var character := _current()
	if character == null:
		_detail_body.add_child(HUDKit.label("캐릭터가 없습니다.", 13, HUDKit.text_2()))
		return

	# 1) 이름 블록 — 한글 이름 + 영문 코드네임 + 역할 뱃지
	_detail_body.add_child(HUDKit.label(character.display_name, 22, HUDKit.text_1(), 700))
	_detail_body.add_child(HUDKit.caption(String(character.character_id)))

	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 6)
	_detail_body.add_child(badge_row)
	for role in character.get_roles():
		badge_row.add_child(_role_badge(role))
	if PartySystem.has_character(character.character_id):
		badge_row.add_child(HUDKit.label("· 편성 중", 12, HUDKit.accent_text(), 700))

	_detail_body.add_child(_rule())

	match _tab:
		Tab.SKILLS:
			_fill_skills(character)
		Tab.GEAR:
			_fill_gear(character)
		_:
			_fill_stats(character)


# 스탯 탭 — 파생값은 PlayerStats 가 계산한다. 장비 보정분을 액센트로 병기한다.
func _fill_stats(character: CharacterData) -> void:
	var stats := character.get_stats()
	var bonuses := character.get_equipment_bonuses()

	_detail_body.add_child(HUDKit.section("전투 스탯", "combat stats"))
	_detail_body.add_child(HUDKit.stat_row("최대 HP", "hp", str(stats.get_max_hp()), _bonus(bonuses["hp"])))
	_detail_body.add_child(HUDKit.stat_row("물리 공격", "p.atk", str(stats.get_physical_attack()), _bonus(bonuses["physical_attack"])))
	_detail_body.add_child(HUDKit.stat_row("마법 공격", "m.atk", str(stats.get_magic_attack()), _bonus(bonuses["magic_attack"])))
	_detail_body.add_child(HUDKit.stat_row("물리 방어", "p.def", str(stats.get_physical_defense()), _bonus(bonuses["physical_defense"])))
	_detail_body.add_child(HUDKit.stat_row("마법 방어", "m.def", str(stats.get_magic_defense()), _bonus(bonuses["magic_defense"])))

	_detail_body.add_child(_rule())
	_detail_body.add_child(HUDKit.section("기초 스탯", "base"))
	_detail_body.add_child(HUDKit.stat_row("근력", "str", str(stats.strength)))
	_detail_body.add_child(HUDKit.stat_row("방어력", "def", str(stats.defense)))
	_detail_body.add_child(HUDKit.stat_row("신앙심", "faith", str(stats.faith)))
	_detail_body.add_child(HUDKit.stat_row("지능", "int", str(stats.intelligence)))

	_detail_body.add_child(_rule())
	_detail_body.add_child(HUDKit.section("배수", "multipliers"))
	_detail_body.add_child(HUDKit.stat_row("공격 속도", "atk spd", "%.2f×" % stats.get_attack_speed_multiplier()))
	_detail_body.add_child(HUDKit.stat_row("이동 속도", "move spd", "%.2f×" % stats.get_move_speed_multiplier()))
	_detail_body.add_child(HUDKit.stat_row("여신 강화", "goddess", "%.2f×" % stats.get_goddess_skill_boost()))


func _fill_skills(character: CharacterData) -> void:
	_detail_body.add_child(HUDKit.section("스킬", "skills"))
	if character.skills.is_empty():
		_detail_body.add_child(HUDKit.label("등록된 스킬이 없습니다.", 13, HUDKit.text_2()))
		_detail_body.add_child(HUDKit.make_serial("SKILL SLOTS UNASSIGNED"))
		return
	for skill in character.skills:
		if skill == null:
			continue
		_detail_body.add_child(HUDKit.stat_row(skill.display_name, "power", str(skill.base_power)))


func _fill_gear(character: CharacterData) -> void:
	_detail_body.add_child(HUDKit.section("장착", "equipped"))
	# 슬롯 목록의 출처는 EquipmentData.Slot 이다.
	for slot in EquipmentData.Slot.values():
		var item := character.get_equipped(slot)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.custom_minimum_size = Vector2(0, 30)

		var icon := HUDKit.make_icon(SLOT_ICON_NAME.get(slot, ""), 20)
		if icon != null:
			row.add_child(icon)

		var name_label := HUDKit.label(
			item.display_name if item != null else "비어 있음",
			13, HUDKit.text_1() if item != null else HUDKit.text_3())
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		_detail_body.add_child(row)

	var bonuses := character.get_equipment_bonuses()
	_detail_body.add_child(_rule())
	_detail_body.add_child(HUDKit.section("장비 보정 합계", "gear bonus"))
	for pair in [["물리 공격", "p.atk", "physical_attack"], ["마법 공격", "m.atk", "magic_attack"],
			["물리 방어", "p.def", "physical_defense"], ["마법 방어", "m.def", "magic_defense"], ["최대 HP", "hp", "hp"]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var left := HBoxContainer.new()
		left.add_theme_constant_override("separation", 6)
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		left.add_child(HUDKit.label(pair[0], 12, HUDKit.text_2()))
		left.add_child(HUDKit.caption(pair[1]))
		row.add_child(left)
		row.add_child(HUDKit.delta(int(bonuses[pair[2]])))
		_detail_body.add_child(row)


# ===== 조각 =====

func _role_badge(role: int) -> Control:
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", HUDKit.inset(4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	badge.add_child(row)
	var icon := HUDKit.make_icon(ROLE_ICON_NAME.get(role, ""), 16)
	if icon != null:
		row.add_child(icon)
	row.add_child(HUDKit.label(CharacterData.role_to_name(role), 11, HUDKit.text_2(), 600))
	return badge


func _bonus(amount: int) -> String:
	return "(+%d)" % amount if amount > 0 else ""


func _rule() -> Control:
	var rule := ColorRect.new()
	rule.color = HUDKit.line()
	rule.custom_minimum_size = Vector2(0, HUDKit.DIVIDER)
	return rule


func _current() -> CharacterData:
	return CharacterDatabase.get_character(_selected_id) if _selected_id != &"" else null


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


# ===== 조작 =====

func _on_card_pressed(id: StringName) -> void:
	if id == _selected_id:
		return
	_selected_id = id
	_refresh_roster()
	_refresh_preview()
	_refresh_detail()


func _on_tab_pressed(tab: Tab) -> void:
	if tab == _tab:
		return
	_tab = tab
	_fill_tab_rail()
	_refresh_detail()
