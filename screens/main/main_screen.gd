extends Control

# 메인화면 (메타 UI) — 대표 캐릭터 일러스트를 중앙에 크게 두는 배치.
#
# 배치 의도 (트릭컬류 메인화면): 최대한 비워 두고 캐릭터를 보여준다.
#   상단   주요 재화만 (우측 정렬)
#   중앙   대표 캐릭터 전신 일러스트 (조종 중인 멤버)
#   하단   메뉴 버튼 + 출격 CTA
#
# 메인화면에 두지 않은 것과 그 이유:
#   - 파티 목록 / 시너지: 편성 화면에서 짜고 그 자리에서 미리보기까지 하므로
#     메인에 다시 두면 같은 정보가 두 곳에 생긴다.
#   - 주요 재화 외 재화: 자리가 좁다. 전체는 창고 화면에서 본다.
#
# 책임: 지금 상태를 "보여주기"만 한다. 값의 소유·계산은 전부 기초 시스템이 한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   재화     -> CurrencySystem (주요 재화 목록도 CurrencySystem 이 정한다)
#   대표 캐릭터 -> PartySystem (조종 중인 멤버)
#   캐릭터   -> CharacterData (표시 이름/역할/외형 tint/portrait)
#   색       -> UITheme
#
# 화면 전환은 ScreenManager가 한다. 이 화면은 자신을 pop 할 뿐 다음 화면을 모른다.
#
# 참고: docs/combat-screen-design.md §1(파티 3명), SYSTEM_CONVENTIONS.md

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
const STORAGE_SCREEN := preload("res://screens/storage/StorageScreen.tscn")

# 재화 칩 라벨. 재화 키 -> Label. 잔액이 바뀔 때 이 라벨만 갱신한다.
var _currency_labels: Dictionary = {}

# 대표 캐릭터가 바뀌면 다시 채우는 자리.
var _portrait_holder: PanelContainer


func _ready() -> void:
	# 게임플레이 정지와 PROCESS_MODE_ALWAYS 는 ScreenManager 가 처리한다.
	# 화면마다 따로 구현하면 새 화면에서 빠뜨리기 쉬우므로 여기서 다루지 않는다.
	_build()

	# 잔액 변경은 CurrencySystem이 알린다. 여기서 잔액을 보관하지 않는다.
	CurrencySystem.currency_changed.connect(_on_currency_changed)

	# 편성 화면에서 파티를 바꾸고 돌아오면 이 화면도 최신 상태를 보여야 한다.
	EventBus.party_changed.connect(_on_party_changed)
	# 조종 대상이 바뀌면 중앙 일러스트도 그 캐릭터로 바뀐다.
	EventBus.party_control_changed.connect(_on_control_changed)


func _on_party_changed(_members) -> void:
	_fill_portrait()


func _on_control_changed(_index: int) -> void:
	_fill_portrait()


# ===== 화면 구성 =====

func _build() -> void:
	add_child(UITheme.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_currency_bar())
	root.add_child(_build_stage())
	root.add_child(_build_bottom_bar())


# ── 상단: 주요 재화만 (우측 정렬) + 창고 진입 ──
# 어떤 재화가 주요인지는 CurrencySystem 이 정한다(화면에서 고르지 않는다).
# 나머지 재화는 창고 화면에서 전부 볼 수 있다.
func _build_currency_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	var head := Control.new()
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(head)

	for currency_type in CurrencySystem.get_primary_currencies():
		bar.add_child(_make_currency_chip(String(currency_type)))

	# 창고: 주요 재화 옆에 두어 "나머지는 여기"가 바로 읽히게 한다.
	var storage := Button.new()
	storage.text = "창고"
	storage.custom_minimum_size = Vector2(72, 36)
	storage.add_theme_font_size_override("font_size", 14)
	storage.add_theme_color_override("font_color", UITheme.INK)
	storage.add_theme_stylebox_override("normal", UITheme.pill_box())
	storage.add_theme_stylebox_override("hover", UITheme.pill_box())
	storage.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	storage.pressed.connect(func(): ScreenManager.push(STORAGE_SCREEN))
	bar.add_child(storage)
	return bar


func _make_currency_chip(currency_type: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UITheme.pill_box())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	chip.add_child(row)

	var icon := _make_icon(CURRENCY_ICON_PATH % currency_type, 20)
	if icon != null:
		row.add_child(icon)

	var label := _text(_comma(CurrencySystem.get_balance(currency_type)), 14, UITheme.INK)
	row.add_child(label)

	_currency_labels[currency_type] = label
	return chip


# ── 중앙: 대표 캐릭터 일러스트만 ──
# 좌우 레일(파티·시너지)을 두지 않는다. 둘 다 편성 화면에 있고,
# 메인은 캐릭터를 보여주는 자리로 비워 둔다.
func _build_stage() -> Control:
	_portrait_holder = PanelContainer.new()
	_portrait_holder.add_theme_stylebox_override("panel", UITheme.panel_box(22))
	_portrait_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_portrait_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_fill_portrait()
	return _portrait_holder


# 중앙 일러스트. portrait 가 있으면 그림을, 없으면 tint 색 플레이스홀더를 둔다.
# 아트가 정해지기 전까지 도형 플레이스홀더를 쓰는 것은 docs §0 [확정] 사항이다.
func _fill_portrait() -> void:
	if not is_instance_valid(_portrait_holder):
		return
	_clear(_portrait_holder)

	var character := _featured_character()
	if character == null:
		_portrait_holder.add_child(_center_note("편성된 파티가 없습니다."))
		return

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_portrait_holder.add_child(box)

	if character.portrait != null:
		var art := TextureRect.new()
		art.texture = character.portrait
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# 세로 전신 일러스트를 비율 유지로 가운데 맞춘다.
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(art)
	else:
		# 일러스트 자리. 파일이 들어오면 위 분기로 그대로 대체된다.
		var placeholder := ColorRect.new()
		placeholder.color = character.tint
		placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(placeholder)
		box.add_child(_center_note("일러스트 자리 (portrait 미지정)"))

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 6)
	box.add_child(name_row)
	for role in character.get_roles():
		var icon := _make_icon(ROLE_ICON_PATH.get(role, ""), 22)
		if icon != null:
			name_row.add_child(icon)
	name_row.add_child(_text(character.display_name, 20, UITheme.INK))


# 대표 캐릭터 = 지금 조종 중인 멤버. 없으면 첫 멤버.
# 조종 대상의 출처는 PartySystem 이다.
func _featured_character() -> CharacterData:
	var controlled := PartySystem.get_controlled_member()
	if controlled != null:
		return controlled
	var members := PartySystem.get_members()
	return members[0] if not members.is_empty() else null


# ── 하단: 메뉴 + 출격 CTA ──
func _build_bottom_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	row.add_child(_make_menu_button("편성", FORMATION_ICON, FORMATION_SCREEN))
	row.add_child(_make_menu_button("캐릭터", CHARACTERS_ICON, CHARACTERS_SCREEN))
	row.add_child(_make_menu_button("장비", EQUIPMENT_ICON, EQUIPMENT_SCREEN))
	row.add_child(_make_menu_button("제조", CRAFT_ICON, CRAFT_SCREEN))

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)

	row.add_child(_build_battle_button())
	return row


func _make_menu_button(label: String, icon_path: String, scene: PackedScene) -> Button:
	var button := Button.new()
	button.text = " " + label
	button.icon = _load_texture(icon_path)
	button.custom_minimum_size = Vector2(128, 56)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_stylebox_override("normal", UITheme.panel_box())
	button.add_theme_stylebox_override("hover", UITheme.panel_box())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	# 화면을 위에 쌓는다. 돌아오면 이 화면이 다시 보인다(상태는 유지된다).
	button.pressed.connect(func(): ScreenManager.push(scene))
	return button


func _build_battle_button() -> Control:
	var button := Button.new()
	button.custom_minimum_size = Vector2(200, 56)
	button.add_theme_stylebox_override("normal", UITheme.accent_box())
	button.add_theme_stylebox_override("hover", UITheme.accent_box())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_font_size_override("font_size", 20)
	button.text = "  출격"
	button.icon = _load_texture(BATTLE_ICON)
	button.pressed.connect(_on_battle_pressed)
	return button


# 출격 = 이 화면을 닫아 게임플레이를 드러낸다.
# 어떤 스테이지로 갈지 고르는 것은 이 화면의 책임이 아니다(스테이지 선택은 후속).
func _on_battle_pressed() -> void:
	ScreenManager.pop()


func _on_currency_changed(currency_type: String, _amount: int, new_balance: int) -> void:
	var label: Label = _currency_labels.get(currency_type)
	if label != null and is_instance_valid(label):
		label.text = _comma(new_balance)


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


func _center_note(value: String) -> Label:
	var label := _text(value, 14, UITheme.INK_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
