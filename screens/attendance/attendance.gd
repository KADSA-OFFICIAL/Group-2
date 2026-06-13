## res://screens/attendance/attendance.gd
## 출석 체크 화면. GameData.attend(day, done_today)로 상태 관리.

extends Control

# 보상 정의 (1-indexed; index 0 unused)
const DAY_REWARDS = [
	{},                                   # 0 unused
	{k = "gold",    a = 10000},           # day 1
	{k = "gems",    a = 50},              # day 2
	{k = "stamina", a = 30},              # day 3
	{k = "gems",    a = 100},             # day 4
	{k = "gold",    a = 50000},           # day 5
	{k = "gems",    a = 200},             # day 6
	{k = "gems",    a = 500},             # day 7 (stamina 60 added separately)
]

const REWARD_ICONS: Dictionary = {
	"gold":    "🪙",
	"gems":    "💎",
	"stamina": "⚡",
}

var _grid_row: HBoxContainer
var _streak_label: Label
var _cta_button: Button
var _toast_label: Label
var _toast_timer: SceneTreeTimer


func _ready() -> void:
	theme = ThemeFactory.build()
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	# ── 루트 마진 ──
	var root_margin := MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 16)
	root_margin.add_theme_constant_override("margin_right", 16)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_bottom", 16)
	add_child(root_margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	root_margin.add_child(vbox)

	# ── 상단바: 뒤로가기 + 제목 ──
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = "← 뒤로"
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.pressed.connect(func(): ScreenManager.pop())
	top_bar.add_child(back_btn)

	var title_label := Label.new()
	title_label.text = "출석 체크"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(title_label)

	# ── 월 부제목 ──
	var now := Time.get_datetime_dict_from_system()
	var subtitle := Label.new()
	subtitle.text = "%d월 출석 현황" % now.month
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", ThemeFactory.C_INK_DIM)
	vbox.add_child(subtitle)

	# ── 연속 출석 라벨 ──
	_streak_label = Label.new()
	_streak_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_streak_label.add_theme_font_size_override("font_size", 15)
	_streak_label.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
	vbox.add_child(_streak_label)

	# ── 7일 그리드 ──
	var grid_panel := PanelContainer.new()
	grid_panel.add_theme_stylebox_override("panel", ThemeFactory.glass_panel(true, 18))
	vbox.add_child(grid_panel)

	var grid_margin := MarginContainer.new()
	grid_margin.add_theme_constant_override("margin_left", 8)
	grid_margin.add_theme_constant_override("margin_right", 8)
	grid_margin.add_theme_constant_override("margin_top", 12)
	grid_margin.add_theme_constant_override("margin_bottom", 12)
	grid_panel.add_child(grid_margin)

	_grid_row = HBoxContainer.new()
	_grid_row.add_theme_constant_override("separation", 6)
	grid_margin.add_child(_grid_row)

	# ── CTA 버튼 ──
	_cta_button = Button.new()
	_cta_button.add_theme_stylebox_override("normal",  ThemeFactory.cta_box())
	_cta_button.add_theme_stylebox_override("hover",   ThemeFactory.cta_box())
	_cta_button.add_theme_stylebox_override("pressed", ThemeFactory.cta_box())
	_cta_button.add_theme_font_size_override("font_size", 20)
	_cta_button.custom_minimum_size = Vector2(0, 60)
	_cta_button.pressed.connect(_on_claim)
	vbox.add_child(_cta_button)

	# ── 토스트 ──
	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_toast_label.set_anchors_preset(Control.PRESET_CENTER)
	_toast_label.offset_left = -240
	_toast_label.offset_right = 240
	_toast_label.offset_top = -28
	_toast_label.offset_bottom = 28
	_toast_label.add_theme_font_size_override("font_size", 16)
	_toast_label.visible = false
	add_child(_toast_label)

	_refresh()


func _refresh() -> void:
	_build_grid()
	_streak_label.text = "연속 %d일 출석 중" % GameData.attend.day

	if GameData.attend.done_today:
		_cta_button.text = "오늘 완료"
		_cta_button.disabled = true
	else:
		_cta_button.text = "오늘 출석 체크"
		_cta_button.disabled = false


func _build_grid() -> void:
	# 기존 자식 제거
	for c in _grid_row.get_children():
		c.queue_free()

	var today_day: int = GameData.attend.day  # 이미 완료한 마지막 일차

	for d in range(1, 8):
		var day_box := _make_day_box(d, today_day)
		_grid_row.add_child(day_box)


func _make_day_box(day_num: int, completed_day: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(80, 100)

	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(12)
	sb.set_border_width_all(2)

	if day_num <= completed_day:
		# 수령 완료
		sb.bg_color = Color(ThemeFactory.C_GOOD, 0.25)
		sb.border_color = ThemeFactory.C_GOOD
	elif day_num == completed_day + 1:
		# 오늘 수령 가능
		sb.bg_color = Color(ThemeFactory.C_CYAN, 0.25)
		sb.border_color = ThemeFactory.C_CYAN
	else:
		# 미래
		sb.bg_color = ThemeFactory.C_BG1
		sb.border_color = ThemeFactory.C_LINE

	panel.add_theme_stylebox_override("panel", sb)

	var inner := VBoxContainer.new()
	inner.alignment = BoxContainer.ALIGNMENT_CENTER
	inner.add_theme_constant_override("separation", 4)
	panel.add_child(inner)

	# 날짜 숫자
	var day_label := Label.new()
	day_label.text = "Day %d" % day_num
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_label.add_theme_font_size_override("font_size", 12)
	if day_num <= completed_day:
		day_label.add_theme_color_override("font_color", ThemeFactory.C_GOOD)
	elif day_num == completed_day + 1:
		day_label.add_theme_color_override("font_color", ThemeFactory.C_CYAN)
	inner.add_child(day_label)

	# 보상 아이콘
	var rw: Dictionary = DAY_REWARDS[day_num]
	var icon_label := Label.new()
	icon_label.text = REWARD_ICONS.get(rw.k, "?")
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 24)
	inner.add_child(icon_label)

	# 보상 수량
	var amount_label := Label.new()
	var extra := " +⚡60" if (day_num == 7) else ""
	amount_label.text = _comma(rw.a) + extra
	amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount_label.add_theme_font_size_override("font_size", 11)
	inner.add_child(amount_label)

	# 완료 체크
	if day_num <= completed_day:
		var check := Label.new()
		check.text = "✓"
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.add_theme_font_size_override("font_size", 16)
		check.add_theme_color_override("font_color", ThemeFactory.C_GOOD)
		inner.add_child(check)

	return panel


func _on_claim() -> void:
	if GameData.attend.done_today:
		return

	var next_day: int = GameData.attend.day + 1
	if next_day > 7:
		next_day = 1

	var rw: Dictionary = DAY_REWARDS[next_day]
	GameData.add_currency(rw.k, rw.a)

	# day 7 보너스 스태미나
	if next_day == 7:
		GameData.add_currency("stamina", 60)

	GameData.attend.day = next_day
	GameData.attend.done_today = true

	# 7일 완료 시 day 리셋 예약 (다음 날 done_today = false 처리는 게임 세션 시작 로직에서)
	var rw_text: String = REWARD_ICONS.get(rw.k, "") + " " + _comma(rw.a)
	if next_day == 7:
		rw_text += " +⚡60"
	_toast("%s 수령!" % rw_text)
	_refresh()


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
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)


func _hide_toast() -> void:
	_toast_label.visible = false
