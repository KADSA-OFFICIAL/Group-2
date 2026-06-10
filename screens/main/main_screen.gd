## res://screens/main/main_screen.gd
## 메인 화면 로직.

extends Control

@onready var stamina_label: Label  = %StaminaLabel
@onready var gold_label: Label     = %GoldLabel
@onready var gems_label: Label     = %GemsLabel
@onready var token_label: Label    = %TokenLabel
@onready var player_name: Label    = %PlayerName
@onready var level_label: Label    = %LevelLabel
@onready var next_stage: Label     = %NextStage
@onready var clock_label: Label    = %ClockLabel
@onready var conquer_btn: Button   = %ConquerButton

const STAGE_SELECT = preload("res://screens/stage_select/StageSelect.tscn")

func _ready() -> void:
	theme = ThemeFactory.build()
	_refresh_hud()
	GameData.stamina_changed.connect(func(c, m): _refresh_hud())
	GameData.currency_changed.connect(func(k, a): _refresh_hud())
	conquer_btn.pressed.connect(func(): ScreenManager.push(STAGE_SELECT))
	_tick_clock()


func _refresh_hud() -> void:
	stamina_label.text = GameData.stamina_text()
	gold_label.text = _comma(GameData.gold)
	gems_label.text = str(GameData.gems)
	token_label.text = str(GameData.faction_token)
	player_name.text = GameData.player_name + ("  MAX" if GameData.is_max_level else "")
	level_label.text = "Lv.%d" % GameData.level
	next_stage.text = "다음: 33-9"


func _process(_delta: float) -> void:
	_tick_clock()


func _tick_clock() -> void:
	var t := Time.get_time_dict_from_system()
	var h: int = t["hour"]
	var m: int = t["minute"]
	var ampm := "AM" if h < 12 else "PM"
	h = h % 12
	if h == 0:
		h = 12
	clock_label.text = "%s %02d:%02d" % [ampm, h, m]


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
