extends Control

# 메인화면 (메타 UI).
#
# 배치 원칙 — 서브컬쳐 게임 메인화면의 공통 구조를 따른다:
#   1) 캐릭터 일러스트가 화면을 꽉 채우는 "배경"이다. 패널 안에 가두지 않는다.
#   2) UI는 그 위에 반투명으로 얹는다. 불투명 패널로 그림을 가리지 않는다.
#   3) 상·하단 바는 얇게, 아이콘은 작게(UITheme.ICON_*). 화면 가운데를 비워 둔다.
#   4) 크기로 위계를 준다. 출격 CTA만 크고 밝게, 나머지 메뉴는 작고 차분하게.
#
#   상단   프로필 · 주요 재화 · 창고/상점 원형 버튼
#   중앙   대표 캐릭터 전신 일러스트 (배경 레이어) + 좌하단 이름표
#   하단   메뉴 탭 + 출격 CTA
#
# 메인화면에 두지 않은 것과 그 이유:
#   - 파티 목록 / 시너지: 편성 화면에서 짜고 그 자리에서 미리보기까지 하므로
#     메인에 다시 두면 같은 정보가 두 곳에 생긴다.
#   - 주요 재화 외 재화: 자리가 좁다. 전체는 창고 화면에서 본다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   재화        -> CurrencySystem (주요 재화 목록도 CurrencySystem 이 정한다)
#   대표 캐릭터 -> PartySystem (조종 중인 멤버)
#   캐릭터      -> CharacterData (표시 이름/역할/외형 tint/portrait)
#   색·치수     -> UITheme
#
# 화면 전환은 ScreenManager가 한다. 이 화면은 자신을 pop 할 뿐 다음 화면을 모른다.

const CURRENCY_ICON_PATH := "res://assets/sprites/ui/icons/icon_%s.svg"

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
const STORAGE_ICON := "res://assets/sprites/ui/icons/icon_storage.svg"

# 화면이 실제로 있는 메뉴만 둔다.
# 상점·설정은 화면이 없어 버튼을 만들지 않는다(누를 곳 없는 버튼을 만들지 않는다).
# 상점 아이콘(icon_shop.svg)은 화면이 생길 때 바로 쓸 수 있도록 준비만 되어 있다.
const FORMATION_SCREEN := preload("res://screens/formation/FormationScreen.tscn")
const CHARACTERS_SCREEN := preload("res://screens/characters/CharactersScreen.tscn")
const EQUIPMENT_SCREEN := preload("res://screens/equipment/EquipmentScreen.tscn")
const CRAFT_SCREEN := preload("res://screens/craft/CraftScreen.tscn")
const STORAGE_SCREEN := preload("res://screens/storage/StorageScreen.tscn")

var _currency_labels: Dictionary = {}

# 대표 캐릭터가 바뀌면 다시 채우는 자리들.
var _art_layer: Control      # 화면을 채우는 일러스트 레이어
var _nameplate: Control      # 좌하단 이름표


func _ready() -> void:
	# 게임플레이 정지와 PROCESS_MODE_ALWAYS 는 ScreenManager 가 처리한다.
	_build()

	CurrencySystem.currency_changed.connect(_on_currency_changed)
	EventBus.party_changed.connect(func(_m): _refresh_featured())
	EventBus.party_control_changed.connect(func(_i): _refresh_featured())


func _refresh_featured() -> void:
	_fill_art()
	_fill_nameplate()


# ===== 화면 구성 =====
# 레이어 순서가 곧 배치다: 배경색 -> 일러스트 -> UI 오버레이.

func _build() -> void:
	add_child(UITheme.make_background())

	# 1) 일러스트 레이어 — 화면 전체를 차지한다. 패널·테두리 없음.
	_art_layer = Control.new()
	_art_layer.name = "ArtLayer"
	_art_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_layer)
	_fill_art()

	# 2) UI 오버레이 — 일러스트 위에 얹힌다.
	var overlay := MarginContainer.new()
	overlay.name = "Overlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_constant_override("margin_left", 14)
	overlay.add_theme_constant_override("margin_right", 14)
	overlay.add_theme_constant_override("margin_top", 12)
	# 하단 버튼은 화면 맨 아래에 바짝 붙는다. 아래 여백을 두지 않는다.
	overlay.add_theme_constant_override("margin_bottom", 0)
	add_child(overlay)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	overlay.add_child(column)

	column.add_child(_build_top_bar())

	# 가운데는 비워 둔다. 일러스트가 보이는 자리이며, 아래쪽에 이름표만 얹는다.
	var middle := VBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.alignment = BoxContainer.ALIGNMENT_END
	middle.add_theme_constant_override("separation", 8)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)

	_nameplate = HBoxContainer.new()
	_nameplate.add_theme_constant_override("separation", 6)
	middle.add_child(_nameplate)
	_fill_nameplate()

	column.add_child(_build_bottom_bar())


# ── 일러스트 레이어 ──
# portrait 가 있으면 화면을 채우고, 없으면 tint 색으로 은은하게 깐다.
# 아트 확정 전까지 도형 플레이스홀더를 쓰는 것은 docs §0 [확정] 사항이다.
func _fill_art() -> void:
	if not is_instance_valid(_art_layer):
		return
	_clear(_art_layer)

	var character := _featured_character()
	if character == null:
		return

	if character.portrait != null:
		var art := TextureRect.new()
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		art.texture = character.portrait
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# 화면을 꽉 채우되 비율은 유지한다(넘치는 부분은 잘린다).
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_art_layer.add_child(art)
		return

	# 일러스트 자리. 파일이 들어오면 위 분기로 그대로 대체된다.
	var placeholder := ColorRect.new()
	placeholder.set_anchors_preset(Control.PRESET_FULL_RECT)
	placeholder.color = Color(character.tint.r, character.tint.g, character.tint.b, 0.30)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_layer.add_child(placeholder)


# ── 좌하단 이름표 ──
# 그림 위에 직접 얹는다. 별도 칸을 만들지 않는다.
func _fill_nameplate() -> void:
	if not is_instance_valid(_nameplate):
		return
	_clear(_nameplate)

	var character := _featured_character()
	if character == null:
		_nameplate.add_child(_chip_text("편성된 파티가 없습니다."))
		return

	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.overlay_pill())
	_nameplate.add_child(plate)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	plate.add_child(row)

	for role in character.get_roles():
		var icon := _make_icon(ROLE_ICON_PATH.get(role, ""), UITheme.ICON_ROUND)
		if icon != null:
			row.add_child(icon)
	row.add_child(_text(character.display_name, 18, UITheme.INK_ON_DARK))

	# 남는 가로 공간을 밀어내 이름표가 좌측에 붙게 한다.
	var tail := Control.new()
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate.add_child(tail)


# ── 상단: 프로필 · 주요 재화 · 원형 버튼 ──
func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)

	bar.add_child(_build_profile())

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(gap)

	# 주요 재화. 어떤 재화가 주요인지는 CurrencySystem 이 정한다.
	for currency_type in CurrencySystem.get_primary_currencies():
		bar.add_child(_make_currency_chip(String(currency_type)))

	# 창고: 나머지 재화는 여기서 본다.
	bar.add_child(_make_round_button(STORAGE_ICON, "창고", STORAGE_SCREEN))
	return bar


# 프로필 자리. 플레이어 이름/레벨 시스템이 아직 없어 파티 인원만 보여준다.
# 시스템이 생기면 이 칩의 내용만 바뀐다.
func _build_profile() -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.overlay_pill())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	plate.add_child(row)

	var avatar := ColorRect.new()
	avatar.custom_minimum_size = Vector2(22, 22)
	avatar.color = UITheme.AMBER
	row.add_child(avatar)

	row.add_child(_text("파티 %d/%d" % [PartySystem.get_size(), PartySystem.PARTY_SIZE], 13, UITheme.INK_ON_DARK))
	return plate


func _make_currency_chip(currency_type: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UITheme.overlay_pill())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)

	var icon := _make_icon(CURRENCY_ICON_PATH % currency_type, UITheme.ICON_PILL)
	if icon != null:
		row.add_child(icon)

	var label := _text(_comma(CurrencySystem.get_balance(currency_type)), 13, UITheme.INK_ON_DARK)
	row.add_child(label)

	_currency_labels[currency_type] = label
	return chip


# 작은 원형 아이콘 버튼. 라벨 없이 아이콘만 둔다.
func _make_round_button(icon_path: String, tooltip: String, scene: PackedScene) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	button.icon = _load_texture(icon_path)
	button.custom_minimum_size = Vector2(36, 36)
	button.expand_icon = true
	button.add_theme_stylebox_override("normal", UITheme.overlay_pill())
	button.add_theme_stylebox_override("hover", UITheme.overlay_pill(UITheme.SURFACE))
	button.add_theme_stylebox_override("pressed", UITheme.overlay_pill(UITheme.SURFACE_DEEP))
	button.pressed.connect(func(): ScreenManager.push(scene))
	return button


# ── 하단: 메뉴 버튼 + 출격 CTA ──
# 버튼을 하나의 바로 묶지 않는다. 각자 떨어진 아이콘으로 화면 아래에 바짝 붙인다.
# 감싸는 패널이 없으므로 일러스트가 버튼 사이로 그대로 보인다.
func _build_bottom_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN

	row.add_child(_make_tab("편성", FORMATION_ICON, FORMATION_SCREEN))
	row.add_child(_make_tab("캐릭터", CHARACTERS_ICON, CHARACTERS_SCREEN))
	row.add_child(_make_tab("장비", EQUIPMENT_ICON, EQUIPMENT_SCREEN))
	row.add_child(_make_tab("제조", CRAFT_ICON, CRAFT_SCREEN))

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)

	row.add_child(_build_battle_button())
	return row


# 하단 메뉴 버튼: 아이콘 위 + 라벨 아래. 테두리·배경 패널을 두지 않는다.
# 아이콘 자체에 이미 굵은 윤곽선이 있어 사각 프레임을 덧대면 답답해진다.
func _make_tab(label: String, icon_path: String, scene: PackedScene) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(58, 62)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)

	var icon := _make_icon(icon_path, 34)
	if icon != null:
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)

	# 라벨은 그림 위에 바로 얹히므로 외곽선을 넣어 어떤 배경에서도 읽히게 한다.
	var text := _text(label, 12, UITheme.INK_ON_DARK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_outline_color", UITheme.OUTLINE)
	text.add_theme_constant_override("outline_size", 4)
	box.add_child(text)

	# 눌리는 영역만 담당하는 투명 버튼. 배경·테두리 없음.
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func(): ScreenManager.push(scene))
	holder.add_child(button)
	return holder


# 출격만 알약 배경을 가진다. 유일한 주요 동작이라 눈에 띄어야 하기 때문이다.
# 나머지 메뉴 버튼에는 배경을 두지 않는다.
func _build_battle_button() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(172, 62)

	var button := Button.new()
	button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	button.offset_top = -54
	button.offset_bottom = -4
	button.add_theme_stylebox_override("normal", UITheme.overlay_accent(26))
	button.add_theme_stylebox_override("hover", UITheme.overlay_accent(26))
	button.add_theme_stylebox_override("pressed", UITheme.overlay_pill(UITheme.SURFACE_DEEP))
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_font_size_override("font_size", 19)
	button.text = " 출격"
	button.icon = _load_texture(BATTLE_ICON)
	button.pressed.connect(_on_battle_pressed)
	holder.add_child(button)
	return holder


# 출격 = 이 화면을 닫아 게임플레이를 드러낸다.
# 어떤 스테이지로 갈지 고르는 것은 이 화면의 책임이 아니다(스테이지 선택은 후속).
func _on_battle_pressed() -> void:
	ScreenManager.pop()


func _on_currency_changed(currency_type: String, _amount: int, new_balance: int) -> void:
	var label: Label = _currency_labels.get(currency_type)
	if label != null and is_instance_valid(label):
		label.text = _comma(new_balance)


# 대표 캐릭터 = 지금 조종 중인 멤버. 없으면 첫 멤버.
func _featured_character() -> CharacterData:
	var controlled := PartySystem.get_controlled_member()
	if controlled != null:
		return controlled
	var members := PartySystem.get_members()
	return members[0] if not members.is_empty() else null


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


func _chip_text(value: String) -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.overlay_pill())
	plate.add_child(_text(value, 14, UITheme.INK_ON_DARK))
	return plate


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
