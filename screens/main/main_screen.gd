extends Control

# 메인화면 (메타 UI).
#
# 배치 원칙 — 서브컬쳐 게임 메인화면의 공통 구조를 따른다:
#   1) 캐릭터 일러스트가 화면을 꽉 채우는 "배경"이다. 패널 안에 가두지 않는다.
#   2) UI는 그 위에 반투명으로 얹는다. 불투명 패널로 그림을 가리지 않는다.
#   3) 상·하단 바는 얇게, 아이콘은 작게(UITheme.ICON_*). 화면 가운데를 비워 둔다.
#   4) 크기로 위계를 준다. 출격 CTA만 크고 밝게, 나머지 메뉴는 작고 차분하게.
#
#   상단   프로필 · 주요 재화 · 창고/설정 원형 버튼 · 길라잡이 + 퀘스트
#   중앙   대표 캐릭터 전신 일러스트 (배경 레이어) + 좌하단 이름표
#   하단   메뉴 탭 + 출격 CTA
#
# 상단과 하단의 성격을 갈라 둔다:
#   하단 = 게임을 하는 메뉴(편성/캐릭터/장비/제조)
#   상단 = 게임을 둘러싼 기능(재화 확인, 설정)
# 한국 게임 메인화면의 관례이며, 섞으면 줄이 길어지고 무엇이 중요한지 흐려진다.
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
const SETTINGS_ICON := "icon_settings"
const SHOP_ICON := "icon_shop"
const MAIL_ICON := "icon_mail"
const STORY_ICON := "icon_story"
const ORDER_ICON := "icon_order"

# 화면이 실제로 있는 메뉴만 버튼으로 만든다.
# 눌러도 아무 일이 없는 버튼은 기능을 더하지 않고 화면만 난잡하게 만든다.
const FORMATION_SCREEN := preload("res://screens/formation/FormationScreen.tscn")
const CHARACTERS_SCREEN := preload("res://screens/characters/CharactersScreen.tscn")
const EQUIPMENT_SCREEN := preload("res://screens/equipment/EquipmentScreen.tscn")
const CRAFT_SCREEN := preload("res://screens/craft/CraftScreen.tscn")
const STORAGE_SCREEN := preload("res://screens/storage/StorageScreen.tscn")
const STAGE_SELECT_SCREEN := preload("res://screens/stage/StageSelectScreen.tscn")
const SETTINGS_SCREEN := preload("res://screens/settings/SettingsScreen.tscn")
const SHOP_SCREEN := preload("res://screens/shop/ShopScreen.tscn")
const MAIL_SCREEN := preload("res://screens/mail/MailScreen.tscn")
const STORY_SCREEN := preload("res://screens/story/StoryScreen.tscn")
const ORDER_SCREEN := preload("res://screens/order/OrderScreen.tscn")

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
var _mail_holder: Control    # 우편 버튼 자리 (미수령 배지 때문에 다시 채운다)


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
	# 우편 미수령 개수의 출처는 MailSystem 이다. 여기서 세지 않는다.
	EventBus.mail_added.connect(func(_id): _fill_mail_button())
	EventBus.mail_claimed.connect(func(_id): _fill_mail_button())


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


# ── 상단: 한 줄 ──
#   프로필 | (빈칸) | 주요 재화 + 상점(+) | 우편 | 설정
#
# 요즘 서브컬쳐 메인화면의 공통 규칙을 따랐다: **상단은 한 줄이다.**
# 전에는 여기가 두 줄이었고 우측에 칩·버튼이 6개 몰려 있었다. 줄인 방법:
#   창고 버튼 제거   -> 재화 칩 자체를 누르면 창고로 간다(재화를 보러 가는 곳이다)
#   상점 버튼 제거   -> 재화 뒤 + 하나로 합쳤다(칩마다 붙던 +도 없앴다)
#   퀘스트 버튼 제거 -> 길라잡이가 곧 퀘스트다. 둘을 하나로 합쳐 하단으로 내렸다
# 결과적으로 상단 요소가 8개에서 5개로 줄고, 공중에 떠 있던 둘째 줄이 사라졌다.
func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)

	# 프로필은 파티 인원이 바뀌면 다시 채워야 하므로 자리를 잡아 두고 내용만 갈아 끼운다.
	_profile_holder = HBoxContainer.new()
	bar.add_child(_profile_holder)
	_fill_profile()

	bar.add_child(_expanding_gap())

	# 주요 재화. 어떤 재화가 주요인지는 CurrencySystem 이 정한다.
	for currency_type in CurrencySystem.get_primary_currencies():
		bar.add_child(_make_currency_chip(String(currency_type)))

	# 재화를 늘리러 가는 곳 = 상점. 칩마다 붙이지 않고 재화 묶음 끝에 하나만 둔다.
	bar.add_child(_make_round_button(SHOP_ICON, "상점", SHOP_SCREEN))

	# 우편은 받지 않은 개수를 배지로 알린다. 자리를 잡아 두고 개수만 갈아 끼운다.
	_mail_holder = HBoxContainer.new()
	bar.add_child(_mail_holder)
	_fill_mail_button()

	bar.add_child(_make_round_button(SETTINGS_ICON, "설정", SETTINGS_SCREEN))
	return bar


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
# 남은 안내가 없으면(READY) 출격 버튼과 **똑같이** 스테이지 선택으로 보낸다.
# 같은 뜻의 두 입구가 서로 다른 곳으로 가면 안 된다.
func _on_guide_pressed() -> void:
	var target = GUIDE_TARGET.get(GuideSystem.get_step())
	if target == null:
		_on_battle_pressed()
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

	# 이름이 비었을 때의 문구는 OrderSystem 이 정한다(화면마다 다르게 적지 않는다).
	var display_name := OrderSystem.get_leader_display_name()
	row.add_child(_text(display_name, 14, UITheme.INK_ON_DARK))
	# 파티 인원은 넣지 않는다. 편성 화면이 그 정보를 이미 보여주고,
	# 상단 칩에 정보가 셋이 되면 무엇이 중요한지 흐려진다.
	return plate


# 재화 칩. 누르면 창고로 간다(모든 재화를 보는 곳이다).
# 전에는 칩마다 + 버튼이 붙어 잔글자가 늘었다. + 는 재화 묶음 끝에 하나만 둔다.
#
# Button 안에 직접 내용을 넣지 않는다. Button 은 컨테이너가 아니라 자식 크기를
# 잡아 주지 않아 아이콘과 숫자가 겹친다(실제로 그렇게 깨졌다).
# 패널로 크기를 잡고 그 위에 투명 버튼을 덮는다(로스터 카드·하단 탭과 같은 방식).
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

	var button := Button.new()
	button.flat = true
	button.tooltip_text = "창고"
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(func(): ScreenManager.push(STORAGE_SCREEN))
	chip.add_child(button)
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
# ── 하단 ──
#   윗줄: (빈칸) | 길라잡이 한 줄
#   아랫줄: 메뉴 탭들 | (빈칸) | 출격 CTA
#
# 길라잡이를 출격 **바로 위**에 붙인 이유: 출격 직전에 보는 정보이고,
# 전처럼 상단에 두면 어디에도 붙지 않은 채 공중에 떠 있어 가장 난잡했다.
# 퀘스트 아이콘은 따로 두지 않는다. 길라잡이가 곧 "지금 할 일"이라 입구가 둘일 이유가 없다.
func _build_bottom_bar() -> Control:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)

	var guide_row := HBoxContainer.new()
	guide_row.add_theme_constant_override("separation", 6)
	column.add_child(guide_row)
	guide_row.add_child(_expanding_gap())

	_guide_holder = HBoxContainer.new()
	guide_row.add_child(_guide_holder)
	_fill_guide()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_child(row)

	row.add_child(_make_tab("편성", FORMATION_ICON, FORMATION_SCREEN))
	row.add_child(_make_tab("캐릭터", CHARACTERS_ICON, CHARACTERS_SCREEN))
	row.add_child(_make_tab("장비", EQUIPMENT_ICON, EQUIPMENT_SCREEN))
	row.add_child(_make_tab("제조", CRAFT_ICON, CRAFT_SCREEN))
	row.add_child(_make_tab("스토리", STORY_ICON, STORY_SCREEN))
	row.add_child(_make_tab("교단", ORDER_ICON, ORDER_SCREEN))

	row.add_child(_expanding_gap())
	row.add_child(_build_battle_button())
	return column


# 하단 줄에는 **화면이 있는 메뉴만** 둔다.
# 눌러도 아무 일이 없는 버튼은 화면을 난잡하게만 만든다.
func _make_tab(label: String, icon_path: String, scene: PackedScene) -> Control:
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
	button.tooltip_text = label
	button.pressed.connect(func(): ScreenManager.push(scene))
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


# 출격 = 스테이지 선택 화면을 연다.
# 어떤 스테이지가 있는지는 StageDatabase 가 안다. 이 화면은 목록을 모른다.
# (스테이지가 저작되지 않았으면 선택 화면이 그 사실을 알리고 바로 출격할 길을 준다.)
func _on_battle_pressed() -> void:
	ScreenManager.push(STAGE_SELECT_SCREEN)


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


# ── 우편 버튼 ──
# 미수령 개수를 배지로 겹쳐 표시한다. 개수의 출처는 MailSystem 이다.
func _fill_mail_button() -> void:
	if not is_instance_valid(_mail_holder):
		return
	_clear(_mail_holder)

	var button := _make_round_button(MAIL_ICON, "우편", MAIL_SCREEN)
	_mail_holder.add_child(button)

	var unclaimed := MailSystem.get_unclaimed_count()
	if unclaimed <= 0:
		return

	# 배지는 버튼 위에 겹친다. 별도 칸을 만들면 줄이 길어진다.
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UITheme.pill_box(UITheme.ACCENT))
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -10
	badge.offset_top = -6
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(_text(str(unclaimed), 10, UITheme.INK))
	button.add_child(badge)
