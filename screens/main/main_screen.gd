## res://screens/main/main_screen.gd
## 메인 화면. 상단바는 .tscn 의 %노드에 바인딩, 하단바(네비+정복 CTA)는 NavBar/GlowButton
## 컴포넌트로 코드에서 조립한다 → HTML 과 동일한 결과 보장.

extends Control

const STAGE_SELECT      := preload("res://screens/stage_select/StageSelect.tscn")
const _NavBarScript     := preload("res://ui/nav_bar.gd")
const _GlowButtonScript := preload("res://ui/glow_button.gd")

const NAV := [
	{ "name":"Hunt",       "label":"임무",   "icon_path":"res://assets/icons/hunt.svg" },
	{ "name":"Recruit",    "label":"모집",   "icon_path":"res://assets/icons/recruit.svg", "highlight":true },
	{ "name":"Characters", "label":"캐릭터", "icon_path":"res://assets/icons/characters.svg" },
	{ "name":"Craft",      "label":"제조",   "icon_path":"res://assets/icons/craft.svg" },
	{ "name":"Shop",       "label":"상점",   "icon_path":"res://assets/icons/shop.svg" },
	{ "name":"Mission",    "label":"미션",   "icon_path":"res://assets/icons/mission.svg" },
	{ "name":"Faction",    "label":"교단",   "icon_path":"res://assets/icons/faction.svg" },
	{ "name":"Story",      "label":"스토리", "icon_path":"res://assets/icons/story.svg" },
]
const NAV_DESC := {
	"Hunt":"임무 — 메인 스토리/캠페인", "Recruit":"모집(가챠) — 새 캐릭터 합류",
	"Characters":"캐릭터 — 보유/육성/편성", "Craft":"제조 — 합성/제작",
	"Shop":"상점 — 일반/한정/교환", "Mission":"미션 — 일일/주간 과제",
	"Faction":"교단 — 길드/협동", "Story":"스토리 — 재관람(극장)",
}

@onready var player_name_label: Label = %PlayerName
@onready var level_badge: Label       = %LevelBadge
@onready var exp_bar: ProgressBar      = %ExpBar
@onready var exp_text: Label           = %ExpText
@onready var stamina_value: Label      = %StaminaValue
@onready var gold_value: Label         = %GoldValue
@onready var gem_value: Label          = %GemValue
@onready var token_value: Label        = %TokenValue

var _toast: Label

const _ICON := {
	"energy": "res://assets/icons/energy.svg",
	"gold":   "res://assets/icons/gold.svg",
	"gem":    "res://assets/icons/gem.svg",
	"token":  "res://assets/icons/token.svg",
	"notice": "res://assets/icons/notice.svg",
	"mail":   "res://assets/icons/mail.svg",
	"settings": "res://assets/icons/settings.svg",
}


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_bind_player()
	_bind_currencies()
	_bind_icons()
	GameData.stamina_changed.connect(func(c, m): stamina_value.text = "%d / %d" % [c, m])

	_build_bottom_bar()
	_build_toast()


func _bind_icons() -> void:
	var base := "TopBar/HBoxContainer/Currencies"
	var pairs := [
		[base + "/Stamina/HBoxContainer/Icon", "energy"],
		[base + "/Gold/HBoxContainer/Icon",    "gold"],
		[base + "/Gem/HBoxContainer/Icon",     "gem"],
		[base + "/Token/HBoxContainer/Icon",   "token"],
	]
	for p in pairs:
		var node := get_node_or_null(p[0]) as TextureRect
		if node:
			node.texture = load(_ICON[p[1]])

	var sys_node := get_node_or_null("TopBar/HBoxContainer/SysButtons")
	if sys_node:
		var sys_keys := ["notice", "mail", "settings"]
		for j in sys_keys.size():
			var btn := sys_node.get_child(j) as Button
			if btn:
				btn.icon = load(_ICON[sys_keys[j]])


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


func _build_bottom_bar() -> void:
	var bar := MarginContainer.new()
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.add_theme_constant_override("margin_left", 22)
	bar.add_theme_constant_override("margin_right", 22)
	bar.add_theme_constant_override("margin_bottom", 18)
	bar.add_theme_constant_override("margin_top", 6)
	add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_END
	bar.add_child(row)

	var nav := _NavBarScript.new()
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(nav)
	nav.setup(NAV)
	nav.nav_selected.connect(func(nav_name): _show_toast(NAV_DESC.get(nav_name, nav_name)))
	nav.set_active("Hunt")

	var cta_col := VBoxContainer.new()
	cta_col.alignment = BoxContainer.ALIGNMENT_END
	cta_col.add_theme_constant_override("separation", 8)
	cta_col.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(cta_col)

	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", ThemeFactory.pill(Color(0, 0, 0, 0.45), 40))
	pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 8)
	pill.add_child(pill_row)
	var st := Label.new()
	st.text = "33-9"
	st.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	pill_row.add_child(st)
	var st2 := Label.new()
	st2.text = "다음 스테이지"
	st2.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	st2.add_theme_font_size_override("font_size", 13)
	pill_row.add_child(st2)
	cta_col.add_child(pill)

	var cta := _GlowButtonScript.new()
	cta.text = "정복"
	cta.subtitle = "CONQUEST"
	cta.icon = load("res://assets/icons/conquest.svg")
	cta.custom_minimum_size = Vector2(230, 86)
	cta.pressed.connect(_on_conquest)
	cta_col.add_child(cta)


func _build_toast() -> void:
	_toast = Label.new()
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position.y = 120
	_toast.add_theme_stylebox_override("normal", ThemeFactory.pill(Color(0, 0, 0, 0.85), 40))
	_toast.add_theme_color_override("font_color", ThemeFactory.C_INK)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	add_child(_toast)


func _on_conquest() -> void:
	ScreenManager.push(STAGE_SELECT)


func _comma(v: int) -> String:
	var s := str(v); var out := ""; var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out; c += 1
		if c % 3 == 0 and i != 0: out = "," + out
	return out


var _tt: SceneTreeTimer
func _show_toast(msg: String) -> void:
	_toast.text = "  " + msg + "  "
	_toast.visible = true
	if _tt and _tt.timeout.is_connected(_hide_toast):
		_tt.timeout.disconnect(_hide_toast)
	_tt = get_tree().create_timer(1.9)
	_tt.timeout.connect(_hide_toast)

func _hide_toast() -> void:
	_toast.visible = false
