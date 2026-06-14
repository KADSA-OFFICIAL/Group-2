## res://screens/main/main_screen.gd
## 메인 화면 — 블루아카이브/트릭컬 스타일.
## 모든 UI 를 코드로 빌드한다 (에디터 .tscn 덮어쓰기에 영향받지 않음).

extends Control

const STAGE_SELECT  := preload("res://screens/stage_select/StageSelect.tscn")
const RECRUIT       := preload("res://screens/recruit/Recruit.tscn")
const CHARACTERS    := preload("res://screens/characters/Characters.tscn")
const CRAFT         := preload("res://screens/craft/Craft.tscn")
const SHOP          := preload("res://screens/shop/Shop.tscn")
const MISSIONS      := preload("res://screens/missions/Missions.tscn")
const GUILD         := preload("res://screens/guild/Guild.tscn")
const MAIL_SCREEN   := preload("res://screens/mail/Mail.tscn")
const SETTINGS_SCR  := preload("res://screens/settings/Settings.tscn")
const EVENT_SCR     := preload("res://screens/event/Event.tscn")
const ATTEND_SCR    := preload("res://screens/attendance/Attendance.tscn")
const PASS_SCR      := preload("res://screens/pass/Pass.tscn")
const PROFILE_SCR   := preload("res://screens/profile/Profile.tscn")
const QUEST_SCR     := preload("res://screens/quest/Quest.tscn")

# 하단 네비 정의: [emoji, label, scene]
const NAV_ITEMS := [
	["🏹", "임무",   "Quest"],
	["🎲", "모집",   "Recruit"],
	["👥", "캐릭터", "Characters"],
	["⚒",  "제조",   "Craft"],
	["🛒", "상점",   "Shop"],
	["✅", "미션",   "Missions"],
	["🏰", "교단",   "Guild"],
	["📖", "스토리", "Story"],
]

# 런타임 참조
var _name_label: Label
var _exp_bar: ProgressBar
var _exp_text: Label
var _avatar_emoji: Label
var _level_badge: Label
var _guide_label: Label
var _toast_label: Label
var _toast_timer: SceneTreeTimer
var _curr_labels: Dictionary = {}     # kind -> Label
var _nav_buttons: Array[Button] = []
var _nav_scene_map: Dictionary = {}   # name -> PackedScene


func _ready() -> void:
	theme = ThemeFactory.build()
	# 기존 .tscn 자식 전부 제거 — 코드로 새로 그린다
	for c in get_children():
		c.queue_free()

	var bg := ThemeFactory.make_background()
	add_child(bg)

	_build_top_bar()
	_build_left_rail()
	_build_event_banners()
	_build_center_stage()
	_build_guide_tracker()
	_build_bottom_bar()
	_build_toast()

	GameData.stamina_changed.connect(func(_c, _m): _refresh_currencies())
	GameData.currency_changed.connect(func(_k, _a): _refresh_currencies())

	_refresh_player()
	_refresh_currencies()
	_update_guide_tracker()


# ════════════════════════════════════════════════════
#  TOP BAR
# ════════════════════════════════════════════════════
func _build_top_bar() -> void:
	var bar := MarginContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 78
	bar.add_theme_constant_override("margin_left", 14)
	bar.add_theme_constant_override("margin_right", 14)
	bar.add_theme_constant_override("margin_top", 12)
	bar.add_theme_constant_override("margin_bottom", 6)
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	row.add_child(_make_player_card())

	var curr := HBoxContainer.new()
	curr.add_theme_constant_override("separation", 7)
	curr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(curr)
	curr.add_child(_make_currency_pill("stamina", "⚡", true))
	curr.add_child(_make_currency_pill("gold", "🪙", true))
	curr.add_child(_make_currency_pill("gems", "💎", true))
	curr.add_child(_make_currency_pill("token", "🔮", false))

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var sys := HBoxContainer.new()
	sys.add_theme_constant_override("separation", 7)
	sys.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(sys)
	sys.add_child(_make_sys_button("🔔", func(): _toast("공지사항 — 준비 중")))
	sys.add_child(_make_sys_button("✉", func(): ScreenManager.push(MAIL_SCREEN)))
	sys.add_child(_make_sys_button("☰", func(): ScreenManager.push(SETTINGS_SCR)))


func _make_player_card() -> Control:
	var card := PanelContainer.new()
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := ThemeFactory.round_box(ThemeFactory.C_GLASS_STRONG, 40, ThemeFactory.C_LINE, 2, 6)
	sb.content_margin_left = 7
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", sb)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			ScreenManager.push(PROFILE_SCR))

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 9)
	card.add_child(hb)

	# 아바타 (링 + 내부 원 + 레벨 배지)
	var av_wrap := Control.new()
	av_wrap.custom_minimum_size = Vector2(50, 50)
	hb.add_child(av_wrap)

	var ring := PanelContainer.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.add_theme_stylebox_override("panel", ThemeFactory.circle_box(ThemeFactory.C_PINK, ThemeFactory.C_CYAN, 2, 3))
	av_wrap.add_child(ring)

	var inner := PanelContainer.new()
	inner.add_theme_stylebox_override("panel", ThemeFactory.circle_box(ThemeFactory.C_BG1, Color(0, 0, 0, 0), 0, 2))
	ring.add_child(inner)

	_avatar_emoji = Label.new()
	_avatar_emoji.text = GameData.avatar
	_avatar_emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_avatar_emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_avatar_emoji.add_theme_font_size_override("font_size", 22)
	inner.add_child(_avatar_emoji)

	_level_badge = Label.new()
	_level_badge.text = "Lv.%d" % GameData.level
	_level_badge.add_theme_font_size_override("font_size", 10)
	_level_badge.add_theme_color_override("font_color", Color("3a1500"))
	_level_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_badge.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_level_badge.offset_left = -34
	_level_badge.offset_top = -16
	_level_badge.offset_right = 6
	_level_badge.offset_bottom = 4
	var lv_sb := ThemeFactory.round_box(ThemeFactory.C_AMBER, 8, Color(1, 1, 1, 0.35), 1)
	_level_badge.add_theme_stylebox_override("normal", lv_sb)
	av_wrap.add_child(_level_badge)

	# 이름 + EXP
	var meta := VBoxContainer.new()
	meta.add_theme_constant_override("separation", 3)
	meta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(meta)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 5)
	meta.add_child(name_row)

	_name_label = Label.new()
	_name_label.text = GameData.player_name
	_name_label.add_theme_font_size_override("font_size", 17)
	name_row.add_child(_name_label)

	if GameData.is_max_level:
		var tag := Label.new()
		tag.text = "MAX"
		tag.add_theme_font_size_override("font_size", 10)
		tag.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
		var tag_sb := ThemeFactory.round_box(Color(ThemeFactory.C_AMBER, 0.13), 6, Color(ThemeFactory.C_AMBER, 0.35), 1, 0, 3)
		tag.add_theme_stylebox_override("normal", tag_sb)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		name_row.add_child(tag)

	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(130, 7)
	_exp_bar.show_percentage = false
	_exp_bar.max_value = GameData.exp_to_next
	_exp_bar.value = GameData.exp_current
	var bg_sb := ThemeFactory.round_box(Color(0, 0, 0, 0.32), 6)
	var fg_sb := ThemeFactory.round_box(ThemeFactory.C_CYAN, 6)
	_exp_bar.add_theme_stylebox_override("background", bg_sb)
	_exp_bar.add_theme_stylebox_override("fill", fg_sb)
	meta.add_child(_exp_bar)

	_exp_text = Label.new()
	_exp_text.add_theme_font_size_override("font_size", 10)
	_exp_text.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	meta.add_child(_exp_text)

	return card


func _make_currency_pill(kind: String, icon: String, with_plus: bool) -> Control:
	var pill := PanelContainer.new()
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var sb := ThemeFactory.round_box(ThemeFactory.C_GLASS, 40, ThemeFactory.C_LINE, 2)
	sb.content_margin_left = 5
	sb.content_margin_right = 9
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", sb)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	pill.add_child(hb)

	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 14)
	ic.custom_minimum_size = Vector2(26, 26)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ic.add_theme_stylebox_override("normal",
		ThemeFactory.circle_box(Color(ThemeFactory.currency_color(kind), 0.85), Color(1, 1, 1, 0.25), 1, 3))
	hb.add_child(ic)

	var val := Label.new()
	val.add_theme_font_size_override("font_size", 15)
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hb.add_child(val)
	_curr_labels[kind] = val

	if with_plus:
		var plus := Button.new()
		plus.text = "+"
		plus.custom_minimum_size = Vector2(20, 20)
		plus.add_theme_font_size_override("font_size", 13)
		plus.add_theme_color_override("font_color", Color("06320f"))
		plus.add_theme_stylebox_override("normal", ThemeFactory.circle_box(ThemeFactory.C_GOOD, Color(0, 0, 0, 0), 0, 2))
		plus.add_theme_stylebox_override("hover", ThemeFactory.circle_box(ThemeFactory.C_GOOD.lightened(0.12), Color(0, 0, 0, 0), 0, 2))
		plus.add_theme_stylebox_override("pressed", ThemeFactory.circle_box(ThemeFactory.C_GOOD.darkened(0.1), Color(0, 0, 0, 0), 0, 2))
		plus.pressed.connect(func():
			if kind == "stamina":
				ScreenManager.push(SHOP)
			elif kind == "gold" or kind == "gems":
				ScreenManager.push(SHOP)
			else:
				ScreenManager.push(GUILD))
		hb.add_child(plus)

	return pill


func _make_sys_button(icon: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = icon
	b.custom_minimum_size = Vector2(34, 34)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", ThemeFactory.circle_box(ThemeFactory.C_GLASS, ThemeFactory.C_LINE, 2, 5))
	b.add_theme_stylebox_override("hover", ThemeFactory.circle_box(ThemeFactory.C_GLASS_STRONG, ThemeFactory.C_CYAN, 2, 5))
	b.add_theme_stylebox_override("pressed", ThemeFactory.circle_box(Color(ThemeFactory.C_CYAN, 0.25), ThemeFactory.C_CYAN, 2, 5))
	b.pressed.connect(cb)
	return b


# ════════════════════════════════════════════════════
#  LEFT RAIL (출석 / 이벤트 / 패스)
# ════════════════════════════════════════════════════
func _build_left_rail() -> void:
	var rail := VBoxContainer.new()
	rail.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	rail.offset_left = 14
	rail.offset_top = -96
	rail.offset_right = 92
	rail.offset_bottom = 96
	rail.grow_vertical = Control.GROW_DIRECTION_BOTH
	rail.add_theme_constant_override("separation", 9)
	add_child(rail)

	rail.add_child(_make_rail_button("📅", "출석", func(): ScreenManager.push(ATTEND_SCR)))
	rail.add_child(_make_rail_button("🎉", "이벤트", func(): ScreenManager.push(EVENT_SCR)))
	rail.add_child(_make_rail_button("🎟", "패스", func(): ScreenManager.push(PASS_SCR)))


func _make_rail_button(icon: String, label: String, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(78, 56)
	b.add_theme_stylebox_override("normal", ThemeFactory.round_box(ThemeFactory.C_GLASS, 16, ThemeFactory.C_LINE, 2, 6))
	b.add_theme_stylebox_override("hover", ThemeFactory.round_box(ThemeFactory.C_GLASS_STRONG, 16, ThemeFactory.C_PINK, 2, 6))
	b.add_theme_stylebox_override("pressed", ThemeFactory.round_box(Color(ThemeFactory.C_PINK, 0.2), 16, ThemeFactory.C_PINK, 2))
	b.pressed.connect(cb)

	var hb := HBoxContainer.new()
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 5)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)

	var ic := Label.new()
	ic.text = icon
	ic.add_theme_font_size_override("font_size", 18)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(ic)

	var lb := Label.new()
	lb.text = label
	lb.add_theme_font_size_override("font_size", 13)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lb)

	return b


# ════════════════════════════════════════════════════
#  EVENT BANNERS (우측)
# ════════════════════════════════════════════════════
func _build_event_banners() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	col.offset_left = -212
	col.offset_top = 92
	col.offset_right = -14
	col.offset_bottom = 230
	col.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	col.add_theme_constant_override("separation", 9)
	add_child(col)

	col.add_child(_make_banner("NEW", "픽업 모집", ThemeFactory.C_PINK, Color("7a4fd1"),
		func(): ScreenManager.push(RECRUIT)))
	col.add_child(_make_banner("EVENT", "한정 스토리", ThemeFactory.C_CYAN, Color("3a1f8e"),
		func(): _toast("스토리 — 준비 중")))


func _make_banner(tag: String, title: String, a: Color, b: Color, cb: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(198, 64)
	btn.add_theme_stylebox_override("normal", ThemeFactory.gradient_round_box(a, b, 120, 16))
	var hover := ThemeFactory.gradient_round_box(a.lightened(0.08), b.lightened(0.08), 120, 16)
	hover.border_color = ThemeFactory.C_AMBER
	hover.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", ThemeFactory.gradient_round_box(a, b, 120, 16))
	btn.pressed.connect(cb)

	var tag_lb := Label.new()
	tag_lb.text = tag
	tag_lb.add_theme_font_size_override("font_size", 10)
	tag_lb.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tag_lb.offset_left = 10
	tag_lb.offset_top = 8
	tag_lb.offset_right = 60
	tag_lb.offset_bottom = 24
	tag_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_sb := ThemeFactory.round_box(Color(0, 0, 0, 0.5), 6, Color(0, 0, 0, 0), 0, 0, 4)
	tag_lb.add_theme_stylebox_override("normal", tag_sb)
	btn.add_child(tag_lb)

	var title_lb := Label.new()
	title_lb.text = title
	title_lb.add_theme_font_size_override("font_size", 19)
	title_lb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	title_lb.offset_left = 12
	title_lb.offset_top = -30
	title_lb.offset_right = 190
	title_lb.offset_bottom = -6
	title_lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(title_lb)

	return btn


# ════════════════════════════════════════════════════
#  CENTER STAGE (캐릭터 영역)
# ════════════════════════════════════════════════════
func _build_center_stage() -> void:
	var stage := Control.new()
	stage.set_anchors_preset(Control.PRESET_CENTER)
	stage.offset_left = -150
	stage.offset_top = -200
	stage.offset_right = 150
	stage.offset_bottom = 150
	stage.grow_horizontal = Control.GROW_DIRECTION_BOTH
	stage.grow_vertical = Control.GROW_DIRECTION_BOTH
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)

	# 글로우
	var glow := TextureRect.new()
	glow.texture = ThemeFactory.radial_glow_tex(Color("ffb478"), 0.45)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	glow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(glow)

	# 캐릭터 실루엣 카드
	var char_card := PanelContainer.new()
	char_card.set_anchors_preset(Control.PRESET_CENTER)
	char_card.offset_left = -90
	char_card.offset_top = -150
	char_card.offset_right = 90
	char_card.offset_bottom = 110
	char_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	char_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	char_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cc_sb := StyleBoxFlat.new()
	cc_sb.bg_color = Color(1, 1, 1, 0.05)
	cc_sb.corner_radius_top_left = 90
	cc_sb.corner_radius_top_right = 90
	cc_sb.corner_radius_bottom_left = 24
	cc_sb.corner_radius_bottom_right = 24
	cc_sb.border_color = Color(1, 1, 1, 0.3)
	cc_sb.set_border_width_all(2)
	char_card.add_theme_stylebox_override("panel", cc_sb)
	stage.add_child(char_card)

	var ph := Label.new()
	ph.text = "[ 대표 캐릭터 ]"
	ph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ph.add_theme_font_size_override("font_size", 18)
	ph.add_theme_color_override("font_color", Color(0.74, 0.67, 1.0, 0.4))
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	char_card.add_child(ph)

	# 네임카드
	var namecard := PanelContainer.new()
	namecard.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	namecard.offset_left = -90
	namecard.offset_top = -8
	namecard.offset_right = 90
	namecard.offset_bottom = 52
	namecard.grow_horizontal = Control.GROW_DIRECTION_BOTH
	namecard.mouse_filter = Control.MOUSE_FILTER_IGNORE
	namecard.add_theme_stylebox_override("panel",
		ThemeFactory.round_box(Color(0, 0, 0, 0.4), 14, ThemeFactory.C_LINE, 2, 0, 8))
	stage.add_child(namecard)

	var nc_vb := VBoxContainer.new()
	nc_vb.add_theme_constant_override("separation", 2)
	nc_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	namecard.add_child(nc_vb)

	var nm := Label.new()
	nm.text = "대표 캐릭터"
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.add_theme_font_size_override("font_size", 16)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nc_vb.add_child(nm)

	var role := Label.new()
	role.text = "★★★ · 교단:새벽단"
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.add_theme_font_size_override("font_size", 12)
	role.add_theme_color_override("font_color", Color(0.74, 0.67, 1.0, 0.85))
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nc_vb.add_child(role)


# ════════════════════════════════════════════════════
#  GUIDE TRACKER (길라잡이 칩)
# ════════════════════════════════════════════════════
func _build_guide_tracker() -> void:
	var chip := PanelContainer.new()
	chip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chip.offset_left = 14
	chip.offset_top = -132
	chip.offset_bottom = -94
	chip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := ThemeFactory.round_box(Color(0.04, 0.03, 0.09, 0.65), 40,
		Color(ThemeFactory.C_CYAN.r, ThemeFactory.C_CYAN.g, ThemeFactory.C_CYAN.b, 0.45), 2, 6)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 7
	sb.content_margin_bottom = 7
	chip.add_theme_stylebox_override("panel", sb)
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			ScreenManager.push(QUEST_SCR))
	add_child(chip)

	_guide_label = Label.new()
	_guide_label.add_theme_font_size_override("font_size", 13)
	_guide_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	_guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_guide_label)


# ════════════════════════════════════════════════════
#  BOTTOM BAR (네비 + 정복 CTA)
# ════════════════════════════════════════════════════
func _build_bottom_bar() -> void:
	var bar := MarginContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -94
	bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bar.add_theme_constant_override("margin_left", 14)
	bar.add_theme_constant_override("margin_right", 14)
	bar.add_theme_constant_override("margin_top", 6)
	bar.add_theme_constant_override("margin_bottom", 14)
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)

	# 네비 패널
	var nav_panel := PanelContainer.new()
	nav_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	var np_sb := ThemeFactory.round_box(Color(0.08, 0.05, 0.15, 0.78), 20, ThemeFactory.C_LINE, 2, 8)
	np_sb.content_margin_left = 12
	np_sb.content_margin_right = 12
	np_sb.content_margin_top = 8
	np_sb.content_margin_bottom = 8
	nav_panel.add_theme_stylebox_override("panel", np_sb)
	row.add_child(nav_panel)

	var nav_row := HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 6)
	nav_panel.add_child(nav_row)

	var nav_group := ButtonGroup.new()
	for item in NAV_ITEMS:
		var b := _make_nav_item(item[0], item[1], item[2], nav_group)
		nav_row.add_child(b)
		_nav_buttons.append(b)

	_nav_scene_map = {
		"Quest": QUEST_SCR, "Recruit": RECRUIT, "Characters": CHARACTERS,
		"Craft": CRAFT, "Shop": SHOP, "Missions": MISSIONS, "Guild": GUILD, "Story": null,
	}

	# 첫 항목(임무) 활성 표시
	if not _nav_buttons.is_empty():
		_nav_buttons[0].set_pressed_no_signal(true)
		_style_nav_item(_nav_buttons[0], true)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	# 정복 CTA
	row.add_child(_make_conquest_cta())


func _make_nav_item(icon: String, label: String, scene_name: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.custom_minimum_size = Vector2(60, 64)
	b.add_theme_stylebox_override("normal", ThemeFactory.round_box(Color(0, 0, 0, 0), 12))
	b.add_theme_stylebox_override("hover", ThemeFactory.round_box(Color(1, 1, 1, 0.06), 12))
	b.add_theme_stylebox_override("pressed", ThemeFactory.round_box(Color(1, 1, 1, 0.06), 12))
	b.set_meta("scene_name", scene_name)
	b.pressed.connect(_on_nav_pressed.bind(scene_name))
	b.toggled.connect(func(on: bool): _style_nav_item(b, on))

	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 4)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)

	var ic := Label.new()
	ic.name = "Icon"
	ic.text = icon
	ic.custom_minimum_size = Vector2(40, 40)
	ic.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ic.add_theme_font_size_override("font_size", 20)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.add_theme_stylebox_override("normal",
		ThemeFactory.round_box(Color(1, 1, 1, 0.08), 14, ThemeFactory.C_LINE, 1))
	vb.add_child(ic)

	var lb := Label.new()
	lb.name = "Name"
	lb.text = label
	lb.add_theme_font_size_override("font_size", 11)
	lb.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(lb)

	return b


func _style_nav_item(b: Button, active: bool) -> void:
	var ic := b.get_node_or_null("VBoxContainer/Icon") as Label
	var lb := b.get_node_or_null("VBoxContainer/Name") as Label
	if active:
		if ic:
			ic.add_theme_stylebox_override("normal",
				ThemeFactory.round_box(ThemeFactory.C_CYAN, 14, Color(1, 1, 1, 0.45), 2))
		if lb:
			lb.add_theme_color_override("font_color", Color(1, 1, 1))
	else:
		if ic:
			ic.add_theme_stylebox_override("normal",
				ThemeFactory.round_box(Color(1, 1, 1, 0.08), 14, ThemeFactory.C_LINE, 1))
		if lb:
			lb.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)


func _make_conquest_cta() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	col.add_theme_constant_override("separation", 5)
	col.alignment = BoxContainer.ALIGNMENT_END

	var info := PanelContainer.new()
	info.size_flags_horizontal = Control.SIZE_SHRINK_END
	info.add_theme_stylebox_override("panel",
		ThemeFactory.round_box(Color(0, 0, 0, 0.45), 40, ThemeFactory.C_LINE, 2, 0, 4))
	var info_hb := HBoxContainer.new()
	info_hb.add_theme_constant_override("separation", 6)
	info.add_child(info_hb)
	var code := Label.new()
	code.text = "33-9"
	code.add_theme_font_size_override("font_size", 15)
	code.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	info_hb.add_child(code)
	var sub := Label.new()
	sub.text = "다음 정복 스테이지"
	sub.add_theme_font_size_override("font_size", 12)
	sub.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	info_hb.add_child(sub)
	col.add_child(info)

	var cta := Button.new()
	cta.custom_minimum_size = Vector2(180, 60)
	cta.add_theme_stylebox_override("normal", ThemeFactory.cta_box())
	var hov := ThemeFactory.cta_box()
	hov.bg_color = Color("ff7280")
	cta.add_theme_stylebox_override("hover", hov)
	cta.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
	cta.pressed.connect(_on_conquest)

	var cta_hb := HBoxContainer.new()
	cta_hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	cta_hb.alignment = BoxContainer.ALIGNMENT_CENTER
	cta_hb.add_theme_constant_override("separation", 8)
	cta_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta.add_child(cta_hb)

	var sword := Label.new()
	sword.text = "⚔"
	sword.add_theme_font_size_override("font_size", 26)
	sword.add_theme_color_override("font_color", Color(1, 1, 1))
	sword.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_hb.add_child(sword)

	var cta_txt := VBoxContainer.new()
	cta_txt.add_theme_constant_override("separation", 0)
	cta_txt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_hb.add_child(cta_txt)
	var big := Label.new()
	big.text = "정복"
	big.add_theme_font_size_override("font_size", 26)
	big.add_theme_color_override("font_color", Color(1, 1, 1))
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_txt.add_child(big)
	var small := Label.new()
	small.text = "CONQUEST"
	small.add_theme_font_size_override("font_size", 10)
	small.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	small.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta_txt.add_child(small)

	col.add_child(cta)
	return col


# ════════════════════════════════════════════════════
#  TOAST
# ════════════════════════════════════════════════════
func _build_toast() -> void:
	_toast_label = Label.new()
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -240
	_toast_label.offset_top = 86
	_toast_label.offset_right = 240
	_toast_label.offset_bottom = 130
	_toast_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 15)
	_toast_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_toast_label.add_theme_stylebox_override("normal",
		ThemeFactory.round_box(Color(0, 0, 0, 0.85), 40, ThemeFactory.C_CYAN, 2, 0, 8))
	_toast_label.visible = false
	add_child(_toast_label)


# ════════════════════════════════════════════════════
#  로직
# ════════════════════════════════════════════════════
func _on_nav_pressed(scene_name: String) -> void:
	var scene: PackedScene = _nav_scene_map.get(scene_name, null)
	if scene != null:
		ScreenManager.push(scene)
	elif scene_name == "Story":
		_toast("스토리 — 준비 중")


func _on_conquest() -> void:
	ScreenManager.push(STAGE_SELECT)


func _refresh_player() -> void:
	if _name_label: _name_label.text = GameData.player_name
	if _level_badge: _level_badge.text = "Lv.%d" % GameData.level
	if _avatar_emoji: _avatar_emoji.text = GameData.avatar
	if _exp_bar:
		_exp_bar.max_value = GameData.exp_to_next
		_exp_bar.value = GameData.exp_current
	if _exp_text:
		_exp_text.text = "EXP %s / %s" % [_comma(GameData.exp_current), _comma(GameData.exp_to_next)]


func _refresh_currencies() -> void:
	if _curr_labels.has("stamina"):
		_curr_labels["stamina"].text = GameData.stamina_text()
	if _curr_labels.has("gold"):
		_curr_labels["gold"].text = _comma(GameData.gold)
	if _curr_labels.has("gems"):
		_curr_labels["gems"].text = _comma(GameData.gems)
	if _curr_labels.has("token"):
		_curr_labels["token"].text = _comma(GameData.faction_token)


func _update_guide_tracker() -> void:
	if _guide_label == null:
		return
	var cur := GameData.guide_current()
	if cur == "":
		_guide_label.text = "🎉 모든 임무 완료!"
	else:
		_guide_label.text = "📌 다음 임무 · %s ›" % cur


func _comma(v: int) -> String:
	var s := str(v)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i != 0:
			out = "," + out
	return out


func _toast(msg: String) -> void:
	_toast_label.text = msg
	_toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.9)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false
