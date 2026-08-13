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


const ROLE_ICON_NAME := {
	CharacterData.Role.TANK: "icon_role_tank",
	CharacterData.Role.RANGED_DEALER: "icon_role_ranged_dealer",
	CharacterData.Role.BUFFER: "icon_role_buffer",
}

const BATTLE_ICON := "icon_battle"
const FORMATION_ICON := "icon_formation"
const CHARACTERS_ICON := "icon_characters"
const EQUIPMENT_ICON := "icon_equipment"
const CRAFT_ICON := "icon_craft"
const STORAGE_ICON := "icon_storage"
const QUEST_ICON := "icon_quest"
const STORY_ICON := "icon_story"
const ORDER_ICON := "icon_order"

# 화면이 실제로 있는 메뉴만 둔다.
# 상점·설정은 화면이 없어 버튼을 만들지 않는다(누를 곳 없는 버튼을 만들지 않는다).
# 상점 아이콘(icon_shop.svg)은 화면이 생길 때 바로 쓸 수 있도록 준비만 되어 있다.
const FORMATION_SCREEN := preload("res://screens/formation/FormationScreen.tscn")
const CHARACTERS_SCREEN := preload("res://screens/characters/CharactersScreen.tscn")
const EQUIPMENT_SCREEN := preload("res://screens/equipment/EquipmentScreen.tscn")
const CRAFT_SCREEN := preload("res://screens/craft/CraftScreen.tscn")
const STORAGE_SCREEN := preload("res://screens/storage/StorageScreen.tscn")

# 길라잡이 단계 -> 데려갈 화면.
# GuideSystem 은 화면을 알지 않는다(인프라가 화면에 의존하면 안 된다). 그 대응을 여기서 한다.
# Step.READY 는 여기 없다. 그때는 화면을 닫아 게임플레이를 드러낸다(= 출격).
const GUIDE_TARGET := {
	GuideSystem.Step.PARTY_INCOMPLETE: FORMATION_SCREEN,
	GuideSystem.Step.NO_EQUIPMENT: CRAFT_SCREEN,
	GuideSystem.Step.EQUIPMENT_IDLE: EQUIPMENT_SCREEN,
}

var _currency_labels: Dictionary = {}

# 대표 캐릭터가 바뀌면 다시 채우는 자리들.
var _art_layer: Control      # 화면을 채우는 일러스트 레이어
var _nameplate: Control      # 좌하단 이름표
var _profile_holder: Control # 상단 프로필 칩이 들어가는 자리
var _guide_holder: Control   # 길라잡이 문구가 들어가는 자리 (퀘스트 아이콘 옆)


func _ready() -> void:
	# 게임플레이 정지와 PROCESS_MODE_ALWAYS 는 ScreenManager 가 처리한다.
	_build()

	CurrencySystem.currency_changed.connect(_on_currency_changed)
	EventBus.party_changed.connect(func(_m): _refresh_featured())
	EventBus.party_control_changed.connect(func(_i): _refresh_featured())
	# 프로필(이름/레벨)의 출처는 PlayerProfile 이다. 그 신호로만 갱신한다.
	PlayerProfile.profile_changed.connect(_fill_profile)
	# 다음에 할 일의 출처는 GuideSystem 이다. 여기서 판정하지 않는다.
	GuideSystem.step_changed.connect(func(_step): _fill_guide())


func _refresh_featured() -> void:
	_fill_art()
	_fill_nameplate()
	# 프로필도 파티 인원을 보여주므로 같이 갱신한다.
	# (전에는 _build() 에서 한 번만 만들어 편성이 바뀌어도 옛 인원이 남아 있었다.)
	_fill_profile()
	# 길라잡이 문구에 남은 인원 수가 들어가므로, 단계가 그대로여도 문구는 달라질 수 있다.
	# (GuideSystem.step_changed 는 단계가 바뀔 때만 쏜다.)
	_fill_guide()


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
	# 프로필·재화 칩은 화면 맨 위에 붙는다. 위 여백을 최소로 둔다.
	overlay.add_theme_constant_override("margin_top", 6)
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
	plate.add_theme_stylebox_override("panel", UITheme.overlay_text_pill())
	_nameplate.add_child(plate)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	plate.add_child(row)

	for role in character.get_roles():
		var icon := _make_icon(ROLE_ICON_NAME.get(role, ""), UITheme.ICON_ROUND)
		if icon != null:
			row.add_child(icon)
	row.add_child(_text(character.display_name, 18, UITheme.INK_ON_DARK))

	# 남는 가로 공간을 밀어내 이름표가 좌측에 붙게 한다.
	var tail := Control.new()
	tail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate.add_child(tail)


# ── 상단: 프로필 · 주요 재화 · 원형 버튼 ──
# 두 줄이다.
#   1줄: 프로필 | (빈칸) | 주요 재화 | 창고
#   2줄:              (빈칸) | 길라잡이 문구 | 퀘스트
# 퀘스트를 재화·창고 바로 아래에 두어 우측 상단을 하나의 묶음으로 읽히게 한다.
func _build_top_bar() -> Control:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	stack.add_child(bar)

	# 프로필은 파티 인원이 바뀌면 다시 채워야 하므로 자리를 잡아 두고 내용만 갈아 끼운다.
	_profile_holder = HBoxContainer.new()
	bar.add_child(_profile_holder)
	_fill_profile()

	bar.add_child(_expanding_gap())

	# 주요 재화. 어떤 재화가 주요인지는 CurrencySystem 이 정한다.
	for currency_type in CurrencySystem.get_primary_currencies():
		bar.add_child(_make_currency_chip(String(currency_type)))

	# 창고: 나머지 재화는 여기서 본다.
	bar.add_child(_make_round_button(STORAGE_ICON, "창고", STORAGE_SCREEN))

	# 퀘스트 줄: 길라잡이 문구가 퀘스트 아이콘 왼쪽에 붙는다.
	var quest_row := HBoxContainer.new()
	quest_row.add_theme_constant_override("separation", 6)
	stack.add_child(quest_row)

	quest_row.add_child(_expanding_gap())

	_guide_holder = HBoxContainer.new()
	quest_row.add_child(_guide_holder)
	_fill_guide()

	# 퀘스트 버튼도 길라잡이와 같은 곳으로 데려간다.
	# 지금 퀘스트의 내용이 곧 "다음에 할 일" 이므로 두 입구가 갈리면 안 된다.
	var quest := _make_round_button(QUEST_ICON, "퀘스트 — 다음에 할 일", null)
	quest.pressed.connect(_on_guide_pressed)
	quest_row.add_child(quest)

	return stack


# 남는 가로 공간을 밀어내는 빈 칸. 클릭을 가로채지 않는다.
func _expanding_gap() -> Control:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


# ── 길라잡이 ──
# 문구와 판정은 GuideSystem 이 소유한다. 여기서 "다음에 할 일"을 다시 판단하지 않는다.
func _fill_guide() -> void:
	if not is_instance_valid(_guide_holder):
		return
	_clear(_guide_holder)

	var plate := Button.new()
	plate.text = GuideSystem.get_text()
	plate.tooltip_text = "누르면 해당 화면으로 갑니다"
	plate.custom_minimum_size = Vector2(0, 40)
	plate.add_theme_font_size_override("font_size", 13)
	plate.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	plate.add_theme_stylebox_override("normal", UITheme.overlay_text_pill())
	plate.add_theme_stylebox_override("hover", UITheme.overlay_text_pill(UITheme.SURFACE_DEEP))
	plate.add_theme_stylebox_override("pressed", UITheme.overlay_text_pill(UITheme.SURFACE_DEEP))
	plate.pressed.connect(_on_guide_pressed)
	_guide_holder.add_child(plate)


# 길라잡이를 누르면 그 단계의 화면으로 간다.
# 남은 안내가 없으면(READY) 화면을 닫아 게임플레이를 드러낸다 — 출격과 같은 동작이다.
func _on_guide_pressed() -> void:
	var target = GUIDE_TARGET.get(GuideSystem.get_step())
	if target == null:
		ScreenManager.pop()
		return
	ScreenManager.push(target)


# 프로필 자리. 이름·레벨의 출처는 PlayerProfile 이다.
func _fill_profile() -> void:
	if not is_instance_valid(_profile_holder):
		return
	_clear(_profile_holder)
	_profile_holder.add_child(_build_profile())


# 아바타 + 레벨 + 이름 + 파티 인원.
# 레벨·이름은 PlayerProfile 이, 파티 인원은 PartySystem 이 출처다.
# 이름이 비어 있으면 PlayerProfile 이 기본 이름을 만들지 않으므로 여기서 대체 문구를 쓴다.
func _build_profile() -> Control:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.overlay_text_pill())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	plate.add_child(row)

	var avatar := ColorRect.new()
	avatar.custom_minimum_size = Vector2(24, 24)
	avatar.color = UITheme.AMBER
	row.add_child(avatar)

	row.add_child(_text("Lv.%d" % PlayerProfile.level, 14, UITheme.ACCENT))

	var display_name := PlayerProfile.player_name
	if display_name.is_empty():
		display_name = "이름 없음"
	row.add_child(_text(display_name, 14, UITheme.INK_ON_DARK))

	# 어두운 오버레이 위이므로 흐린 글자에 INK_DIM(어두운 색)을 쓰면 안 읽힌다.
	row.add_child(_text("파티 %d/%d" % [PartySystem.get_size(), PartySystem.PARTY_SIZE], 12, UITheme.TAN_DEEP))
	return plate


func _make_currency_chip(currency_type: String) -> Control:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UITheme.overlay_text_pill())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	chip.add_child(row)

	var icon := _make_icon(UITheme.currency_icon_name(currency_type), UITheme.ICON_PILL)
	if icon != null:
		row.add_child(icon)

	var label := _text(_comma(CurrencySystem.get_balance(currency_type)), 13, UITheme.INK_ON_DARK)
	row.add_child(label)

	_currency_labels[currency_type] = label
	return chip


# 작은 원형 아이콘 버튼. 라벨 없이 아이콘만 둔다.
# scene 이 null 이면 아무 연결도 하지 않는다(호출부가 직접 pressed 를 잇는다).
func _make_round_button(icon_path: String, tooltip: String, scene: PackedScene) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	button.icon = _load_texture(icon_path)
	button.custom_minimum_size = Vector2(32, 32)
	button.expand_icon = true
	button.add_theme_stylebox_override("normal", UITheme.overlay_pill())
	button.add_theme_stylebox_override("hover", UITheme.overlay_pill(UITheme.SURFACE))
	button.add_theme_stylebox_override("pressed", UITheme.overlay_pill(UITheme.SURFACE_DEEP))
	if scene != null:
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
	# 스토리·교단은 아직 시스템이 없어 누를 수 없다. 자리는 나머지 메뉴와 같은 줄에 둔다.
	# (누르면 아무 일도 없는 버튼을 두지 않는다. 시스템이 생기면 화면만 연결하면 된다.)
	row.add_child(_make_tab("스토리", STORY_ICON, null))
	row.add_child(_make_tab("교단", ORDER_ICON, null))

	row.add_child(_expanding_gap())

	row.add_child(_build_battle_button())
	return row


# 하단 메뉴 버튼: 아이콘 위 + 라벨 아래. 테두리·배경 패널을 두지 않는다.
# 아이콘 자체에 이미 굵은 윤곽선이 있어 사각 프레임을 덧대면 답답해진다.
# scene 이 null 이면 화면이 없는 메뉴다. 흐리게 그리고 누를 수 없게 둔다.
func _make_tab(label: String, icon_path: String, scene: PackedScene) -> Control:
	var ready_to_open := scene != null

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(58, 62)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(box)

	var icon := _make_icon(icon_path, UITheme.ICON_NAV)
	if icon != null:
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		# 화면이 없는 메뉴는 반투명하게 그려 "지금은 못 들어간다"를 알린다.
		if not ready_to_open:
			icon.modulate = Color(1, 1, 1, 0.4)
		box.add_child(icon)

	# 라벨은 그림 위에 바로 얹히므로 외곽선을 넣어 어떤 배경에서도 읽히게 한다.
	var text := _text(label, 12, UITheme.INK_ON_DARK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_outline_color", UITheme.OUTLINE)
	text.add_theme_constant_override("outline_size", 4)
	if not ready_to_open:
		text.modulate = Color(1, 1, 1, 0.45)
	box.add_child(text)

	# 눌리는 영역만 담당하는 투명 버튼. 배경·테두리 없음.
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if ready_to_open:
		button.pressed.connect(func(): ScreenManager.push(scene))
	else:
		button.disabled = true
		button.tooltip_text = "%s — 준비 중(시스템 없음)" % label
	holder.add_child(button)
	return holder


# 출격만 알약 배경을 가진다. 유일한 주요 동작이라 눈에 띄어야 하기 때문이다.
# 나머지 메뉴 버튼에는 배경을 두지 않는다.
#
# 아이콘을 Button.icon 으로 넣지 않고 직접 조립한다.
# Button.icon 은 텍스처를 원본 크기(SVG 임포트 기준 64px)로 그리기 때문에
# 버튼이 그보다 낮으면 아이콘이 잘린다. TextureRect 로 크기를 지정해 얹는다.
func _build_battle_button() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(172, 62)

	var plate := PanelContainer.new()
	plate.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	plate.offset_top = -54
	plate.offset_bottom = -4
	plate.add_theme_stylebox_override("panel", UITheme.overlay_accent(26))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(plate)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(row)

	var icon := _make_icon(BATTLE_ICON, UITheme.ICON_CTA)
	if icon != null:
		row.add_child(icon)

	var label := _text("출격", 19, UITheme.INK)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)

	# 눌리는 영역만 담당하는 투명 버튼.
	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	button.offset_top = -54
	button.offset_bottom = -4
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", UITheme.overlay_pill(UITheme.SURFACE_DEEP))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.text = ""
	button.tooltip_text = "출격"
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
	plate.add_theme_stylebox_override("panel", UITheme.overlay_text_pill())
	plate.add_child(_text(value, 14, UITheme.INK_ON_DARK))
	return plate


func _make_icon(icon_name: String, size: int) -> TextureRect:
	var texture := _load_texture(icon_name)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# 아이콘 **이름**("icon_back")을 받는다. 경로와 확장자 해석은 UITheme 이 한다.
func _load_texture(icon_name: String) -> Texture2D:
	var path := UITheme.icon_path(icon_name)
	if path.is_empty():
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
