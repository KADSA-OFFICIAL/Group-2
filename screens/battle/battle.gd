## res://screens/battle/battle.gd
## 전투 화면 — 자동 전투 진행 + 결과 판정.
## HTML showBattle() 대응.

extends Control

const RESULT_SCENE := preload("res://screens/result/Result.tscn")

# ── 노드 참조 (동적 생성) ──
var _wave_label: Label
var _enemy_label: Label
var _enemy_hp_bar: ProgressBar
var _team_chips: HBoxContainer
var _progress_bar: ProgressBar
var _status_label: Label

# ── 상태 ──
var _current_wave: int = 1
const TOTAL_WAVES: int = 3


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	_build_ui()

	# 한 프레임 뒤에 코루틴 시작 (UI 레이아웃 확정 후)
	await get_tree().process_frame
	_run_battle()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("separation", 0)
	add_child(root)

	root.add_child(_build_top_hud())
	root.add_child(_build_enemy_area())
	root.add_child(_build_team_row())
	root.add_child(_build_action_area())


# ── 상단 HUD ──────────────────────────────────────────────
func _build_top_hud() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	var code_lbl := Label.new()
	code_lbl.text = "스테이지 %s" % GameData.battle.get("code", "?")
	code_lbl.add_theme_font_size_override("font_size", 18)
	code_lbl.add_theme_color_override("font_color", ThemeFactory.C_INK)
	code_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(code_lbl)

	_wave_label = Label.new()
	_wave_label.text = "웨이브 1/%d" % TOTAL_WAVES
	_wave_label.add_theme_font_size_override("font_size", 18)
	_wave_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	hbox.add_child(_wave_label)

	return panel


# ── 적 표시 영역 ──────────────────────────────────────────
func _build_enemy_area() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# 적 이모지
	_enemy_label = Label.new()
	var n: int = GameData.battle.get("n", 1)
	_enemy_label.text = "👹" if n >= 9 else "👾"
	_enemy_label.add_theme_font_size_override("font_size", 72)
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_enemy_label)

	# 적 이름
	var name_lbl := Label.new()
	name_lbl.text = "새벽의 군주" if n >= 9 else "군단병"
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", ThemeFactory.C_PINK if n >= 9 else ThemeFactory.C_INK)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)

	# HP 바
	var hp_container := VBoxContainer.new()
	hp_container.add_theme_constant_override("separation", 4)
	vbox.add_child(hp_container)

	var hp_label := Label.new()
	hp_label.text = "HP"
	hp_label.add_theme_font_size_override("font_size", 14)
	hp_label.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_container.add_child(hp_label)

	_enemy_hp_bar = ProgressBar.new()
	_enemy_hp_bar.custom_minimum_size = Vector2(300, 20)
	_enemy_hp_bar.max_value = 100.0
	_enemy_hp_bar.value = 100.0
	_enemy_hp_bar.show_percentage = false
	hp_container.add_child(_enemy_hp_bar)

	return panel


# ── 플레이어 팀 칩 ────────────────────────────────────────
func _build_team_row() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(false, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	_team_chips = HBoxContainer.new()
	_team_chips.add_theme_constant_override("separation", 8)
	_team_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_team_chips)

	var team_ids: Array = GameData.battle.get("team", [])
	for cid in team_ids:
		var ch := _find_char(str(cid))
		if ch.is_empty():
			continue
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", ThemeFactory.pill(ThemeFactory.C_BG2, 20))

		var lbl := Label.new()
		lbl.text = "%s %s" % [GameData.role_icon(ch.get("role", "")), ch.get("n", "?")]
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", ThemeFactory.C_INK)
		chip.add_child(lbl)
		_team_chips.add_child(chip)

	return panel


# ── 자동 전투 진행 영역 ───────────────────────────────────
func _build_action_area() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 0))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_status_label = Label.new()
	_status_label.text = "자동 전투 중..."
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(_status_label)

	_progress_bar = ProgressBar.new()
	_progress_bar.custom_minimum_size = Vector2(400, 24)
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.show_percentage = false
	vbox.add_child(_progress_bar)

	return panel


# ── 전투 코루틴 ───────────────────────────────────────────
func _run_battle() -> void:
	const WAVE_DURATION := 1.0

	for wave in TOTAL_WAVES:
		_current_wave = wave + 1
		_wave_label.text = "웨이브 %d/%d" % [_current_wave, TOTAL_WAVES]
		_status_label.text = "웨이브 %d 전투 중..." % _current_wave
		_progress_bar.value = 0.0
		_enemy_hp_bar.value = 100.0

		# Tween 으로 1.0초에 걸쳐 진행 바 + HP 바 애니메이션
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(_progress_bar, "value", 1.0, WAVE_DURATION)
		tw.tween_property(_enemy_hp_bar, "value", 0.0, WAVE_DURATION)
		await tw.finished

		_status_label.text = "웨이브 %d 클리어!" % _current_wave
		await get_tree().create_timer(0.4).timeout

	# ── 결과 판정 ──
	_status_label.text = "결과 계산 중..."
	await get_tree().create_timer(0.5).timeout

	var reco: int = GameData.battle.get("reco", 1)
	var my_pw: int = GameData.combat_power
	var win: bool

	if my_pw >= reco * 0.8:
		win = true
	else:
		# 60% 확률로 승리
		win = randf() < 0.6

	# 별 계산
	var stars: int
	if not win:
		stars = 0
	elif my_pw >= reco:
		stars = 3
	elif my_pw >= reco * 0.8:
		stars = 2
	else:
		stars = 1

	# GameData 에 결과 저장
	GameData.battle["result"] = win
	GameData.battle["stars"] = stars

	# 기력 소모 (승리 시)
	if win:
		GameData.spend_stamina(10)

	ScreenManager.push(RESULT_SCENE)


# ── 유틸 ─────────────────────────────────────────────────
func _find_char(char_id: String) -> Dictionary:
	for ch in GameData.roster:
		if ch.get("id", "") == char_id:
			return ch
	return {}
