## res://screens/main/main_screen.gd
## 메인 화면 로직. 재화/플레이어는 GameData 에서 읽고, 정복 CTA 는 StageSelect 를 push.

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

var _guide_label: Label

# ── 상단바 ──
@onready var player_name_label: Label  = %PlayerName
@onready var level_badge: Label        = %LevelBadge
@onready var exp_bar: ProgressBar      = %ExpBar
@onready var exp_text: Label           = %ExpText
@onready var stamina_value: Label      = %StaminaValue
@onready var gold_value: Label         = %GoldValue
@onready var gem_value: Label          = %GemValue
@onready var token_value: Label        = %TokenValue
# ── 하단 ──
@onready var bottom_nav: Container     = %BottomNav
@onready var conquest_button: Button   = %ConquestButton
@onready var next_stage_label: Label   = %NextStageLabel
@onready var toast_label: Label        = %Toast

var _nav_group := ButtonGroup.new()

# nav button name → scene to push (null = toast only)
var _nav_map: Dictionary

func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_nav_map = {
		"Hunt":       STAGE_SELECT,
		"Recruit":    RECRUIT,
		"Characters": CHARACTERS,
		"Craft":      CRAFT,
		"Shop":       SHOP,
		"Mission":    MISSIONS,
		"Faction":    GUILD,
		"Story":      null,
	}

	_bind_player()
	_bind_currencies()
	GameData.stamina_changed.connect(func(c, m): stamina_value.text = "%d / %d" % [c, m])

	for child in bottom_nav.get_children():
		if not (child is Button):
			continue
		var b := child as Button
		b.toggle_mode = true
		b.button_group = _nav_group
		# 버튼 자체는 투명 배경 유지, 눌림 시 미세 하이라이트만
		var pressed_sb := StyleBoxFlat.new()
		pressed_sb.set_corner_radius_all(8)
		pressed_sb.bg_color = Color(ThemeFactory.C_CYAN, 0.08)
		b.add_theme_stylebox_override("pressed",  pressed_sb)
		b.add_theme_stylebox_override("hover",    pressed_sb)
		b.pressed.connect(_on_nav_pressed.bind(b))

		var vbox := b.get_node_or_null("VBox") as VBoxContainer
		if vbox == null:
			continue
		# 아이콘과 이름 사이 간격
		vbox.add_theme_constant_override("separation", 5)

		# ── 원형 배지 배경 ──
		var icon_lbl := vbox.get_node_or_null("Icon") as Label
		if icon_lbl != null:
			icon_lbl.add_theme_font_size_override("font_size", 18)
			icon_lbl.custom_minimum_size = Vector2(38, 38)
			var badge_sb := StyleBoxFlat.new()
			badge_sb.set_corner_radius_all(999)
			badge_sb.bg_color = ThemeFactory.C_BG2
			badge_sb.border_color = Color(ThemeFactory.C_LINE)
			badge_sb.set_border_width_all(1)
			badge_sb.set_content_margin_all(6)
			icon_lbl.add_theme_stylebox_override("normal", badge_sb)

		# ── 이름 텍스트 ──
		var name_lbl := vbox.get_node_or_null("Name") as Label
		if name_lbl != null:
			name_lbl.add_theme_font_size_override("font_size", 10)
			name_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)

	# 선택된 버튼의 배지 색 강조 처리
	_nav_group.pressed.connect(_on_nav_group_pressed)

	var hunt := bottom_nav.get_node_or_null("Hunt") as Button
	if hunt:
		hunt.button_pressed = true
		_highlight_nav_icon(hunt, true)

	# top-bar system buttons
	var mail_btn := %Mail as Button
	var settings_btn := %Settings as Button
	mail_btn.pressed.connect(func(): ScreenManager.push(MAIL_SCREEN))
	settings_btn.pressed.connect(func(): ScreenManager.push(SETTINGS_SCR))

	# left-rail shortcut buttons
	var event_btn  := get_node_or_null("LeftRail/EventBtn")  as Button
	var attend_btn := get_node_or_null("LeftRail/AttendBtn") as Button
	var pass_btn   := get_node_or_null("LeftRail/PassBtn")   as Button
	if event_btn:  event_btn.pressed.connect(func():  ScreenManager.push(EVENT_SCR))
	if attend_btn: attend_btn.pressed.connect(func(): ScreenManager.push(ATTEND_SCR))
	if pass_btn:   pass_btn.pressed.connect(func():   ScreenManager.push(PASS_SCR))

	conquest_button.add_theme_stylebox_override("normal",  ThemeFactory.cta_box())
	conquest_button.add_theme_stylebox_override("hover",   ThemeFactory.cta_box())
	conquest_button.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
	conquest_button.pressed.connect(_on_conquest)
	next_stage_label.text = "33-9"

	# NavPanel 높이: 원형 배지(38) + 간격(5) + 이름(13) + 여백 = 76px
	var nav_panel := get_node_or_null("NavPanel") as PanelContainer
	if nav_panel != null:
		nav_panel.offset_top = -76.0

	toast_label.visible = false

	# ── 길라잡이 트래커 (PlayerCard 아이콘·이름 아래) ──
	var player_card := get_node("TopBar/HBoxContainer/PlayerCard") as PanelContainer
	var inner_hbox := player_card.get_child(0) as HBoxContainer
	if inner_hbox != null:
		var outer_vbox := VBoxContainer.new()
		outer_vbox.add_theme_constant_override("separation", 3)
		inner_hbox.reparent(outer_vbox, false)
		player_card.add_child(outer_vbox)

		_guide_label = Label.new()
		_guide_label.name = "GuideTracker"
		_guide_label.add_theme_font_size_override("font_size", 12)
		_guide_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
		_guide_label.mouse_filter = Control.MOUSE_FILTER_STOP
		_guide_label.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed:
				ScreenManager.push(QUEST_SCR))
		outer_vbox.add_child(_guide_label)
	_update_guide_tracker()
	_apply_circle_icons()


func _make_circle_sb(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(999)
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(5)
	return sb


func _apply_circle_icons() -> void:
	# ── 시스템 버튼 (알림·메일·설정) ──
	for nm in ["Notice", "Mail", "Settings"]:
		var btn := get_node_or_null("TopBar/HBoxContainer/SysButtons/" + nm) as Button
		if btn == null:
			continue
		btn.custom_minimum_size = Vector2(30, 30)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_stylebox_override("normal",
			_make_circle_sb(ThemeFactory.C_BG2, Color(ThemeFactory.C_LINE), 1))
		btn.add_theme_stylebox_override("hover",
			_make_circle_sb(Color(ThemeFactory.C_CYAN, 0.18), ThemeFactory.C_CYAN, 1))
		btn.add_theme_stylebox_override("pressed",
			_make_circle_sb(Color(ThemeFactory.C_CYAN, 0.30), ThemeFactory.C_CYAN, 2))

	# ── 플레이어 아바타 패널 → 원형 ──
	var avatar := get_node_or_null(
		"TopBar/HBoxContainer/PlayerCard/HBoxContainer/Avatar") as PanelContainer
	if avatar == null:
		# reparent 후 경로가 달라질 수 있으므로 이름으로 탐색
		avatar = find_child("Avatar", true, false) as PanelContainer
	if avatar != null:
		avatar.custom_minimum_size = Vector2(38, 38)
		avatar.add_theme_stylebox_override("panel",
			_make_circle_sb(ThemeFactory.C_BG2, ThemeFactory.C_CYAN, 2))
		var badge := avatar.get_node_or_null("LevelBadge") as Label
		if badge != null:
			badge.add_theme_font_size_override("font_size", 10)

	# ── 재화 아이콘 배지 ──
	var curr_hbox := get_node_or_null("TopBar/HBoxContainer/Currencies") as HBoxContainer
	if curr_hbox != null:
		for curr_panel in curr_hbox.get_children():
			if not (curr_panel is PanelContainer):
				continue
			var inner := curr_panel.get_child(0)
			if inner == null:
				continue
			var icon_lbl := inner.get_node_or_null("Icon") as Label
			if icon_lbl == null:
				continue
			icon_lbl.add_theme_font_size_override("font_size", 13)
			icon_lbl.custom_minimum_size = Vector2(22, 22)
			icon_lbl.add_theme_stylebox_override("normal",
				_make_circle_sb(Color(ThemeFactory.C_BG2, 0.9)))
			var val_lbl := inner.get_node_or_null("StaminaValue") as Label
			if val_lbl == null:
				val_lbl = inner.get_node_or_null("GoldValue") as Label
			if val_lbl == null:
				val_lbl = inner.get_node_or_null("GemValue") as Label
			if val_lbl == null:
				val_lbl = inner.get_node_or_null("TokenValue") as Label
			if val_lbl != null:
				val_lbl.add_theme_font_size_override("font_size", 12)
			var plus_btn := inner.get_node_or_null("PlusButton") as Button
			if plus_btn != null:
				plus_btn.custom_minimum_size = Vector2(18, 18)
				plus_btn.add_theme_font_size_override("font_size", 11)
				plus_btn.add_theme_stylebox_override("normal",
					_make_circle_sb(ThemeFactory.C_BG2, Color(ThemeFactory.C_LINE), 1))
				plus_btn.add_theme_stylebox_override("hover",
					_make_circle_sb(Color(ThemeFactory.C_CYAN, 0.2), ThemeFactory.C_CYAN, 1))

	# ── 좌측 단축 버튼 (이벤트·출석·패스) ──
	for nm in ["EventBtn", "AttendBtn", "PassBtn"]:
		var btn := get_node_or_null("LeftRail/" + nm) as Button
		if btn == null:
			continue
		btn.custom_minimum_size = Vector2(46, 46)
		btn.add_theme_font_size_override("font_size", 10)
		btn.add_theme_stylebox_override("normal",
			_make_circle_sb(ThemeFactory.C_BG2, Color(ThemeFactory.C_LINE), 1))
		btn.add_theme_stylebox_override("hover",
			_make_circle_sb(Color(ThemeFactory.C_CYAN, 0.18), ThemeFactory.C_CYAN, 1))
		btn.add_theme_stylebox_override("pressed",
			_make_circle_sb(Color(ThemeFactory.C_CYAN, 0.28), ThemeFactory.C_CYAN, 2))


func _update_guide_tracker() -> void:
	if _guide_label == null:
		return
	var cur := GameData.guide_current()
	if cur == "":
		_guide_label.text = "🎉 모든 임무 완료!"
	else:
		_guide_label.text = "📌 다음 임무 · %s ›" % cur


func _bind_player() -> void:
	player_name_label.text = GameData.player_name
	level_badge.text = "Lv.%d" % GameData.level
	exp_bar.max_value = GameData.exp_to_next
	exp_bar.value = GameData.exp_current
	exp_text.text = "EXP %s / %s" % [_comma(GameData.exp_current), _comma(GameData.exp_to_next)]


func _bind_currencies() -> void:
	stamina_value.text = GameData.stamina_text()
	gold_value.text = _comma(GameData.gold)
	gem_value.text = _comma(GameData.gems)
	token_value.text = _comma(GameData.faction_token)


func _on_nav_group_pressed(btn: BaseButton) -> void:
	for child in bottom_nav.get_children():
		if child is Button:
			_highlight_nav_icon(child as Button, child == btn)


func _highlight_nav_icon(btn: Button, active: bool) -> void:
	var vbox := btn.get_node_or_null("VBox") as VBoxContainer
	if vbox == null:
		return
	var icon_lbl := vbox.get_node_or_null("Icon") as Label
	if icon_lbl == null:
		return
	var badge_sb := StyleBoxFlat.new()
	badge_sb.set_corner_radius_all(999)
	badge_sb.set_content_margin_all(6)
	if active:
		badge_sb.bg_color = Color(ThemeFactory.C_CYAN, 0.22)
		badge_sb.border_color = ThemeFactory.C_CYAN
		badge_sb.set_border_width_all(2)
		var name_lbl := vbox.get_node_or_null("Name") as Label
		if name_lbl:
			name_lbl.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	else:
		badge_sb.bg_color = ThemeFactory.C_BG2
		badge_sb.border_color = Color(ThemeFactory.C_LINE)
		badge_sb.set_border_width_all(1)
		var name_lbl := vbox.get_node_or_null("Name") as Label
		if name_lbl:
			name_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	icon_lbl.add_theme_stylebox_override("normal", badge_sb)


func _on_nav_pressed(btn: Button) -> void:
	var scene: PackedScene = _nav_map.get(btn.name, null)
	if scene != null:
		ScreenManager.push(scene)
	elif btn.name == "Story":
		_toast("스토리 — 준비 중")


func _on_conquest() -> void:
	ScreenManager.push(STAGE_SELECT)


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


var _toast_timer: SceneTreeTimer
func _toast(msg: String) -> void:
	toast_label.text = msg
	toast_label.visible = true
	if _toast_timer and _toast_timer.timeout.is_connected(_hide_toast):
		_toast_timer.timeout.disconnect(_hide_toast)
	_toast_timer = get_tree().create_timer(1.9)
	_toast_timer.timeout.connect(_hide_toast)

func _hide_toast() -> void:
	toast_label.visible = false
