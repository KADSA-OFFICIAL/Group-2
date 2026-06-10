## res://screens/main/main_screen.gd
## 메인 화면 로직. 재화/플레이어는 GameData 에서 읽고, 정복 CTA 는 StageSelect 를 push.

extends Control

const STAGE_SELECT := preload("res://screens/stage_select/StageSelect.tscn")

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

const NAV_DESC := {
	"Hunt":       "임무 — 메인 스토리 / 캠페인 스테이지",
	"Recruit":    "모집(가챠) — 새 캐릭터 합류. 수익화 핵심",
	"Characters": "캐릭터 — 보유 / 육성 / 편성",
	"Craft":      "제조 — 재료 합성 / 장비 제작",
	"Shop":       "상점 — 일반 / 한정 / 교환",
	"Mission":    "미션 — 일일 / 주간 / 도전 과제",
	"Faction":    "교단 — 길드 / 협동 콘텐츠",
	"Story":      "스토리 — 해금한 이야기 재관람 (극장)",
}

var _nav_group := ButtonGroup.new()


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_bind_player()
	_bind_currencies()
	GameData.stamina_changed.connect(func(c, m): stamina_value.text = "%d / %d" % [c, m])

	for child in bottom_nav.get_children():
		if child is Button:
			var b := child as Button
			b.toggle_mode = true
			b.button_group = _nav_group
			b.add_theme_stylebox_override("pressed", ThemeFactory.accent_box(14))
			b.pressed.connect(_on_nav_pressed.bind(b))
	var hunt := bottom_nav.get_node_or_null("Hunt") as Button
	if hunt:
		hunt.button_pressed = true

	conquest_button.add_theme_stylebox_override("normal",  ThemeFactory.cta_box())
	conquest_button.add_theme_stylebox_override("hover",   ThemeFactory.cta_box())
	conquest_button.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
	conquest_button.pressed.connect(_on_conquest)
	next_stage_label.text = "33-9"

	toast_label.visible = false


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


func _on_nav_pressed(btn: Button) -> void:
	_toast(NAV_DESC.get(btn.name, btn.name))


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
