## res://screens/stage_select/stage_select.gd
## 정복(스테이지 선택) 화면 로직. HTML 프로토타입의 JS 를 그대로 옮긴 초안.
## 씬 트리는 GODOT_ARCHITECTURE.md 5번 참고. ⭐노드는 Unique Name(%) 으로 참조.

extends Control

# ── 노드 참조 (Unique Name) ──
@onready var back_button: Button   = %BackButton
@onready var prev_chapter: Button  = %PrevChapter
@onready var next_chapter: Button  = %NextChapter
@onready var chapter_number: Label = %ChapterNumber
@onready var chapter_name: Label   = %ChapterName
@onready var diff_normal: Button   = %DiffNormal
@onready var diff_hard: Button     = %DiffHard
@onready var stamina_label: Label  = %StaminaLabel
@onready var track: Control        = %Track
@onready var map_line: Line2D      = %MapLine
@onready var stage_code: Label     = %StageCode
@onready var stage_name: Label     = %StageName
@onready var power_value: Label    = %PowerValue
@onready var cost_value: Label     = %CostValue
@onready var star_value: Label     = %StarValue
@onready var drop_row: HBoxContainer = %DropRow
@onready var sweep_button: Button  = %SweepButton
@onready var deploy_button: Button = %DeployButton
@onready var toast_label: Label    = %Toast

# ── 상태 ──
var _chapters: Array[ChapterData] = []
var _chap_index: int = 2          # 33장
var _hard: bool = false
var _sel_index: int = 8           # 33-9
var _node_wraps: Array[Control] = []   # 맵 노드(생성됨)

const COLS := 5

# ── 드롭 더미 (HTML 과 동일) ──
const DROPS_NORMAL := [["🪙","골드",true],["📘","강화서",false],["🔮","마정석",false],["🧩","조각",true]]
const DROPS_HARD   := [["🪙","골드",true],["📕","상급 강화서",false],["💎","순도 마정석",false],["🧩","★조각",true],["🎀","한정 재료",true]]


func _ready() -> void:
	theme = ThemeFactory.build()   # 폰트는 프로젝트 기본에서 가져옴
	var bg := ThemeFactory.make_background()
	add_child(bg)
	move_child(bg, 0)

	back_button.pressed.connect(func(): ScreenManager.pop())
	prev_chapter.pressed.connect(func(): _change_chapter(-1))
	next_chapter.pressed.connect(func(): _change_chapter(1))
	diff_normal.pressed.connect(func(): _set_difficulty(false))
	diff_hard.pressed.connect(func(): _set_difficulty(true))
	sweep_button.pressed.connect(_on_sweep)
	deploy_button.pressed.connect(_on_deploy)
	track.resized.connect(_layout_nodes)

	GameData.stamina_changed.connect(func(_c, _m): _refresh_stamina())

	toast_label.visible = false
	_refresh_chapters()
	_refresh_stamina()
	await get_tree().process_frame   # 레이아웃 확정 후 노드 배치
	_render_map()
	_fill_panel()


# ─────────────────────────────────────────────
func _refresh_chapters() -> void:
	_chapters = ChapterDB.all_chapters(_hard)
	var ch := _chapters[_chap_index]
	chapter_number.text = ch.number_label
	chapter_name.text = ch.name
	diff_normal.button_pressed = not _hard
	diff_hard.button_pressed = _hard


func _refresh_stamina() -> void:
	stamina_label.text = GameData.stamina_text()


# ── 뱀 모양 경로 좌표 (Track 크기 기준 %) ──
func _node_pct(i: int) -> Vector2:
	var col := i % COLS
	@warning_ignore("integer_division")
	var row := i / COLS
	var x_pct := (10.0 + col * 20.0) if (row % 2 == 0) else (90.0 - col * 20.0)
	var y_pct := 18.0 + row * 42.0
	return Vector2(x_pct / 100.0, y_pct / 100.0)


func _render_map() -> void:
	# 기존 노드 제거
	for w in _node_wraps:
		w.queue_free()
	_node_wraps.clear()

	var stages := _chapters[_chap_index].stages
	for i in stages.size():
		var s: StageData = stages[i]
		var node_wrap := _make_node(s, i)
		track.add_child(node_wrap)
		_node_wraps.append(node_wrap)

	_layout_nodes()
	_update_selection_visual()


func _make_node(s: StageData, i: int) -> Control:
	var wrap := Control.new()
	wrap.custom_minimum_size = Vector2(80, 100)
	wrap.size = Vector2(80, 100)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var btn := Button.new()
	btn.name = "Core"
	btn.custom_minimum_size = Vector2(80, 80)
	btn.text = "🔒" if (s.is_boss and s.is_locked()) else s.code
	btn.disabled = s.is_locked()
	btn.add_theme_stylebox_override("normal", _node_box(s))
	btn.pressed.connect(_on_node_pressed.bind(i))
	wrap.add_child(btn)

	# 별 표시
	if s.stars >= 0:
		var stars := Label.new()
		stars.name = "Stars"
		stars.text = _star_text(s.stars)
		stars.position = Vector2(0, 82)
		stars.size = Vector2(80, 16)
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stars.add_theme_color_override("font_color", ThemeFactory.C_GOLD)
		wrap.add_child(stars)

	return wrap


func _node_box(s: StageData) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(40)            # 원형
	sb.set_border_width_all(3)
	if s.is_locked():
		sb.bg_color = ThemeFactory.C_BG1
		sb.border_color = ThemeFactory.C_LINE
	elif s.is_cleared():
		sb.bg_color = Color("1c4d36")
		sb.border_color = Color("2f7d52")
	else:  # current
		sb.bg_color = ThemeFactory.C_BG2
		sb.border_color = ThemeFactory.C_CYAN
	return sb


func _star_text(n: int) -> String:
	return "★".repeat(n) + "☆".repeat(3 - n)


func _layout_nodes() -> void:
	if _node_wraps.is_empty():
		return
	var pts := PackedVector2Array()
	var sz := track.size
	for i in _node_wraps.size():
		var pct := _node_pct(i)
		var center := Vector2(pct.x * sz.x, pct.y * sz.y)
		var w := _node_wraps[i]
		w.position = center - Vector2(40, 50)   # 노드 80x100 의 중심 보정
		pts.append(center)
	map_line.points = pts
	map_line.width = 3.0
	map_line.default_color = Color(0.745, 0.667, 1.0, 0.35)


func _on_node_pressed(i: int) -> void:
	_sel_index = i
	_update_selection_visual()
	_fill_panel()


func _update_selection_visual() -> void:
	for i in _node_wraps.size():
		var core := _node_wraps[i].get_node("Core") as Button
		if i == _sel_index:
			core.add_theme_color_override("font_color", ThemeFactory.C_AMBER)
			_node_wraps[i].scale = Vector2(1.08, 1.08)
		else:
			core.remove_theme_color_override("font_color")
			_node_wraps[i].scale = Vector2.ONE


# ── 우측 상세 패널 ──
func _fill_panel() -> void:
	var s: StageData = _chapters[_chap_index].stages[_sel_index]
	stage_code.text = s.code
	stage_name.text = "새벽의 군주" if s.is_boss else s.name

	power_value.text = "%s  (내 %s)" % [
		_comma(s.recommended_power), _comma(GameData.combat_power)]
	power_value.add_theme_color_override(
		"font_color",
		ThemeFactory.C_GOOD if GameData.combat_power >= s.recommended_power else ThemeFactory.C_BAD)

	cost_value.text = "%d  / %d 보유" % [s.stamina_cost, GameData.stamina]
	star_value.text = ("%d / 3 ★" % s.stars) if s.stars >= 0 else "미개방"

	# 드롭
	for c in drop_row.get_children():
		c.queue_free()
	var drops = DROPS_HARD if _hard else DROPS_NORMAL
	for d in drops:
		drop_row.add_child(_make_drop(d[0], d[1], d[2]))

	# 소탕은 클리어한 스테이지만
	sweep_button.disabled = not s.is_cleared()
	sweep_button.text = "소탕 ×%d" % s.sweep_ticket_cost if s.is_cleared() else "소탕(클리어 시)"


func _make_drop(icon: String, _name: String, first: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(60, 60)
	var box := ThemeFactory.glass_panel(false, 14)
	if first:
		box.border_color = ThemeFactory.C_GOLD
	p.add_theme_stylebox_override("panel", box)
	var l := Label.new()
	l.text = icon
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 28)
	p.add_child(l)
	return p


# ── 액션 ──
func _change_chapter(delta: int) -> void:
	var nc := _chap_index + delta
	if nc < 0 or nc >= _chapters.size():
		_toast("마지막 챕터야")
		return
	_chap_index = nc
	_sel_index = 8
	_refresh_chapters()
	_render_map()
	_fill_panel()


func _set_difficulty(hard: bool) -> void:
	if _hard == hard:
		return
	_hard = hard
	_refresh_chapters()
	_render_map()
	_fill_panel()


func _on_sweep() -> void:
	var s: StageData = _chapters[_chap_index].stages[_sel_index]
	if not s.is_cleared():
		return
	# TODO: 소탕 티켓 차감 + 보상 지급 로직 연결
	_toast("%s 소탕 — 보상 즉시 획득" % s.code)


func _on_deploy() -> void:
	var s: StageData = _chapters[_chap_index].stages[_sel_index]
	GameData.battle["code"] = s.code
	GameData.battle["n"] = _sel_index
	GameData.battle["reco"] = s.recommended_power
	GameData.battle["hard"] = _hard
	if GameData.combat_power < s.recommended_power:
		_toast("권장 전투력 미달 — 그래도 출격 가능")
	ScreenManager.push(preload("res://screens/formation/Formation.tscn"))


# ── 유틸 ──
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
	_toast_timer = get_tree().create_timer(1.8)
	_toast_timer.timeout.connect(_hide_toast)

func _hide_toast() -> void:
	toast_label.visible = false
