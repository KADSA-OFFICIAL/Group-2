extends Control

# 메인화면 (메타 UI).
#
# 책임: 지금 상태를 "보여주기"만 한다. 값의 소유·계산은 전부 기초 시스템이 한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   재화   -> CurrencySystem (DEFAULT_CURRENCIES 키를 그대로 순회한다)
#   파티   -> PartySystem (PARTY_SIZE, 조종 중 인덱스)
#   캐릭터 -> CharacterData (표시 이름/역할/외형 tint)
#   시너지 -> SynergySystem.get_summary()
#   색     -> UITheme
#
# 화면 전환은 ScreenManager가 한다. 이 화면은 자신을 pop 할 뿐 다음 화면을 모른다.
#
# 참고: docs/combat-screen-design.md §1(파티 3명), §8(시너지), SYSTEM_CONVENTIONS.md

# 재화 아이콘 경로. 파일명이 재화 키와 일치하도록 맞춰 두었으므로
# 매핑 테이블 없이 키로 바로 조합한다(아이콘 목록을 여기서 다시 정의하지 않는다).
const CURRENCY_ICON_PATH := "res://assets/sprites/ui/icons/icon_%s.svg"

# 역할 아이콘. CharacterData.Role 값에 대응한다.
const ROLE_ICON_PATH := {
	CharacterData.Role.TANK: "res://assets/sprites/ui/icons/icon_role_tank.svg",
	CharacterData.Role.RANGED_DEALER: "res://assets/sprites/ui/icons/icon_role_ranged_dealer.svg",
	CharacterData.Role.BUFFER: "res://assets/sprites/ui/icons/icon_role_buffer.svg",
}

const BATTLE_ICON := "res://assets/sprites/ui/icons/icon_battle.svg"
const SYNERGY_ICON := "res://assets/sprites/ui/icons/icon_synergy.svg"
const FORMATION_ICON := "res://assets/sprites/ui/icons/icon_formation.svg"
const CHARACTERS_ICON := "res://assets/sprites/ui/icons/icon_characters.svg"
const EQUIPMENT_ICON := "res://assets/sprites/ui/icons/icon_equipment.svg"
const CRAFT_ICON := "res://assets/sprites/ui/icons/icon_craft.svg"

# 화면이 실제로 있는 메뉴만 둔다.
# 설정은 화면이 아직 없어 버튼을 만들지 않는다(누를 곳 없는 버튼을 만들지 않는다).
const FORMATION_SCREEN := preload("res://screens/formation/FormationScreen.tscn")
const CHARACTERS_SCREEN := preload("res://screens/characters/CharactersScreen.tscn")
const EQUIPMENT_SCREEN := preload("res://screens/equipment/EquipmentScreen.tscn")
const CRAFT_SCREEN := preload("res://screens/craft/CraftScreen.tscn")

# 재화 칩 라벨. 재화 키 -> Label. 잔액이 바뀔 때 이 라벨만 갱신한다.
var _currency_labels: Dictionary = {}

# 파티/시너지가 그려지는 자리. 편성이 바뀌면 이 두 곳만 다시 채운다.
var _party_holder: VBoxContainer
var _synergy_holder: HBoxContainer
var _party_heading: Label


func _ready() -> void:
	# 게임플레이 정지와 PROCESS_MODE_ALWAYS 는 ScreenManager 가 처리한다.
	# 화면마다 따로 구현하면 새 화면에서 빠뜨리기 쉬우므로 여기서 다루지 않는다.
	_build()

	# 잔액 변경은 CurrencySystem이 알린다. 여기서 잔액을 보관하지 않는다.
	CurrencySystem.currency_changed.connect(_on_currency_changed)

	# 편성 화면에서 파티를 바꾸고 돌아오면 이 화면도 최신 상태를 보여야 한다.
	# 편성 결과의 출처는 PartySystem 이고, 변경 알림은 EventBus 가 한다.
	EventBus.party_changed.connect(_on_party_changed)


func _on_party_changed(_members) -> void:
	_fill_party()
	_fill_synergy()


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
	root.add_theme_constant_override("separation", 16)
	margin.add_child(root)

	root.add_child(_build_currency_bar())
	root.add_child(_build_party_section())
	root.add_child(_build_synergy_section())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	root.add_child(_build_menu_row())
	root.add_child(_build_battle_button())


# ── 상단: 재화 표시줄 ──
# CurrencySystem.DEFAULT_CURRENCIES 를 그대로 순회한다.
# 어떤 재화를 보여줄지 여기서 고르지 않으므로, 재화가 추가되면 자동으로 나타난다.
func _build_currency_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	for currency_type in CurrencySystem.DEFAULT_CURRENCIES:
		bar.add_child(_make_currency_chip(String(currency_type)))

	var tail := Control.new()
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(tail)
	return bar


func _make_currency_chip(currency_type: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UITheme.pill_box())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)

	var icon := _make_icon(CURRENCY_ICON_PATH % currency_type, 22)
	if icon != null:
		row.add_child(icon)

	var label := Label.new()
	label.text = _comma(CurrencySystem.get_balance(currency_type))
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", UITheme.INK)
	row.add_child(label)

	_currency_labels[currency_type] = label
	return chip


func _on_currency_changed(currency_type: String, _amount: int, new_balance: int) -> void:
	var label: Label = _currency_labels.get(currency_type)
	if label != null and is_instance_valid(label):
		label.text = _comma(new_balance)


# ── 중앙: 파티 프리뷰 ──
func _build_party_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	_party_heading = _make_heading("")
	section.add_child(_party_heading)

	# 편성이 바뀌면 이 자리만 다시 채운다.
	_party_holder = VBoxContainer.new()
	_party_holder.add_theme_constant_override("separation", 8)
	section.add_child(_party_holder)

	_fill_party()
	return section


func _fill_party() -> void:
	if not is_instance_valid(_party_holder):
		return
	_clear(_party_holder)
	_party_heading.text = "파티 (%d / %d)" % [PartySystem.get_size(), PartySystem.PARTY_SIZE]

	var members := PartySystem.get_members()
	if members.is_empty():
		_party_holder.add_child(_make_note("편성된 파티가 없습니다."))
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_party_holder.add_child(row)

	for i in members.size():
		row.add_child(_make_member_card(members[i], i == PartySystem.get_controlled_index()))


func _make_member_card(character: CharacterData, is_controlled: bool) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(180, 0)
	# 조종 중인 멤버는 강조색 패널로 구분한다(조종 여부의 출처는 PartySystem).
	card.add_theme_stylebox_override(
		"panel", UITheme.accent_box() if is_controlled else UITheme.panel_box()
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	# 초상화 자리: 아트가 정해지기 전이라 도형 플레이스홀더를 쓴다(docs §0 [확정]).
	# 색은 CharacterData.tint 를 그대로 반영한다.
	var portrait := ColorRect.new()
	portrait.color = character.tint
	portrait.custom_minimum_size = Vector2(0, 64)
	box.add_child(portrait)

	var name_label := Label.new()
	name_label.text = character.display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", UITheme.INK)
	box.add_child(name_label)

	# 역할: 겸직이면 아이콘이 2개가 된다. 역할 목록의 출처는 CharacterData.get_roles().
	var role_row := HBoxContainer.new()
	role_row.add_theme_constant_override("separation", 4)
	box.add_child(role_row)

	for role in character.get_roles():
		var role_icon := _make_icon(ROLE_ICON_PATH.get(role, ""), 20)
		if role_icon != null:
			role_row.add_child(role_icon)

	var role_label := Label.new()
	role_label.text = character.get_roles_display_name()
	role_label.add_theme_font_size_override("font_size", 13)
	role_label.add_theme_color_override("font_color", UITheme.INK_DIM)
	role_row.add_child(role_label)

	if is_controlled:
		var tag := Label.new()
		tag.text = "조종 중"
		tag.add_theme_font_size_override("font_size", 12)
		tag.add_theme_color_override("font_color", UITheme.INK)
		box.add_child(tag)

	return card


# ── 시너지 현황 ──
# 카운트와 단계는 SynergySystem이 계산한다. 여기서 역할 수를 다시 세지 않는다.
func _build_synergy_section() -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var heading_row := HBoxContainer.new()
	heading_row.add_theme_constant_override("separation", 6)
	var synergy_icon := _make_icon(SYNERGY_ICON, 22)
	if synergy_icon != null:
		heading_row.add_child(synergy_icon)
	heading_row.add_child(_make_heading("시너지"))
	section.add_child(heading_row)

	_synergy_holder = HBoxContainer.new()
	_synergy_holder.add_theme_constant_override("separation", 8)
	section.add_child(_synergy_holder)

	_fill_synergy()
	return section


func _fill_synergy() -> void:
	if not is_instance_valid(_synergy_holder):
		return
	_clear(_synergy_holder)
	# 카운트·단계는 SynergySystem 이 계산한다(배타 규칙 포함).
	for entry in SynergySystem.get_summary(PartySystem.get_members()):
		_synergy_holder.add_child(_make_synergy_chip(entry))


func _make_synergy_chip(entry: Dictionary) -> Control:
	var active: bool = entry.get("tier", SynergySystem.Tier.NONE) != SynergySystem.Tier.NONE

	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UITheme.panel_box() if active else UITheme.panel_box_deep())

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	chip.add_child(box)

	var title := Label.new()
	title.text = "%s %d" % [entry.get("name", "?"), entry.get("count", 0)]
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UITheme.INK)
	box.add_child(title)

	var tier := Label.new()
	tier.text = String(entry.get("tier_name", ""))
	tier.add_theme_font_size_override("font_size", 12)
	tier.add_theme_color_override("font_color", UITheme.INK if active else UITheme.INK_DIM)
	box.add_child(tier)

	return chip


# ── 하단: 메뉴 진입 ──
# 화면이 실제로 있는 메뉴만 버튼으로 둔다.
func _build_menu_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	row.add_child(_make_menu_button("편성", FORMATION_ICON, FORMATION_SCREEN))
	row.add_child(_make_menu_button("캐릭터", CHARACTERS_ICON, CHARACTERS_SCREEN))
	row.add_child(_make_menu_button("장비", EQUIPMENT_ICON, EQUIPMENT_SCREEN))
	row.add_child(_make_menu_button("제조", CRAFT_ICON, CRAFT_SCREEN))

	var tail := Control.new()
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(tail)
	return row


func _make_menu_button(label: String, icon_path: String, scene: PackedScene) -> Button:
	var button := Button.new()
	button.text = " " + label
	button.icon = _load_texture(icon_path)
	button.custom_minimum_size = Vector2(140, 48)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_stylebox_override("normal", UITheme.panel_box())
	button.add_theme_stylebox_override("hover", UITheme.panel_box())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	# 화면을 위에 쌓는다. 돌아오면 이 화면이 다시 보인다(상태는 유지된다).
	button.pressed.connect(func(): ScreenManager.push(scene))
	return button


# ── 하단: 출격 ──
func _build_battle_button() -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 60)
	button.add_theme_stylebox_override("normal", UITheme.accent_box())
	button.add_theme_stylebox_override("hover", UITheme.accent_box())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_font_size_override("font_size", 20)
	button.text = "  출격"
	button.icon = _load_texture(BATTLE_ICON)
	button.expand_icon = false
	button.pressed.connect(_on_battle_pressed)
	return button


# 출격 = 이 화면을 닫아 게임플레이를 드러낸다.
# 어떤 스테이지로 갈지 고르는 것은 이 화면의 책임이 아니다(스테이지 선택은 후속).
func _on_battle_pressed() -> void:
	ScreenManager.pop()


# ===== 공용 조각 =====

func _make_heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	return label


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _make_note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	return label


# 아이콘 텍스처가 없으면 null을 반환한다(아이콘 누락이 화면 전체를 깨뜨리지 않게).
func _make_icon(path: String, size: int) -> TextureRect:
	var texture := _load_texture(path)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _load_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


func _comma(value: int) -> String:
	var digits := str(value)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i != 0:
			out = "," + out
	return out
