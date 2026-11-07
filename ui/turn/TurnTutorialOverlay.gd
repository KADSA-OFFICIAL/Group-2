extends Control
class_name TurnTutorialOverlay

# 턴제 튜토리얼의 화면 — 하이라이트와 대사 패널 (#594 프롤로그).
#
# 니케·트릭컬 프롤로그의 문법을 따른다:
#   읽는 중  — 화면 전체를 어둡게 하고 가르칠 곳만 뚫어 비춘다. 아래에 말하는 인물의
#              초상과 대사가 뜬다. 아무 곳이나 누르면 넘어간다(전투는 그동안 멈춰 있다).
#   하는 중  — 어둠은 옅게 남기고 비춘 곳에 맥박 치는 테두리와 화살표를 둔다. 위에는 지금
#              할 일 한 줄만 남는다. 클릭은 아래 HUD 로 흘려보낸다 — 무엇을 받을지는
#              TutorialSystem 관문이 정한다(이 화면은 막지 않는다).
#
# 단일 출처:
#   단계·진행     -> TutorialSystem (이 화면은 신호를 듣고 그리기만 한다)
#   비출 자리     -> TurnBattleHUD.tutorial_rect() (이번 프레임에 실제로 그린 자리)
#   화자 이름·초상 -> StoryLineData 와 같은 해석(CharacterDatabase -> EnemyDatabase -> StoryCastDatabase),
#                    초상은 PortraitSystem / GameEdition 을 거친다(검열판 대응).

const DIM_READING := 0.62
const DIM_DOING := 0.28
const HOLE_PAD := 8.0
const BORDER_W := 3.0
const ARROW_SIZE := 18.0
const PANEL_W := 760.0
const PANEL_MARGIN := 18.0
const PORTRAIT_SIZE := Vector2(132.0, 156.0)
const GOAL_H := 44.0
const HINT_TEXT := "▶ 화면을 눌러 계속"

## 비출 자리를 물어볼 HUD. 전투 화면이 넣어 준다.
var hud: TurnBattleHUD = null

var _step: TutorialStepData = null
var _reading: bool = false
var _phase: float = 0.0
var _hole: Rect2 = Rect2()
# "a|b" 의 두 번째부터. 구멍은 하나만 뚫고(네 조각 어둠은 구멍 하나만 된다) 나머지는 테두리만 두른다 —
# 둘을 한 사각형으로 합치면 그 사이 화면까지 통째로 밝아져 무엇을 보라는지 흐려진다.
var _extras: Array[Rect2] = []

var _panel: PanelContainer = null
var _portrait: TextureRect = null
var _name_label: Label = null
var _title_label: Label = null
var _body_label: Label = null
var _hint_label: Label = null
var _goal: PanelContainer = null
var _goal_label: Label = null


func _ready() -> void:
	name = "TurnTutorialOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	TutorialSystem.step_changed.connect(_on_step_changed)
	TutorialSystem.finished.connect(_on_finished)
	_apply_visibility()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _dark_box(16))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(row)

	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = PORTRAIT_SIZE
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)

	_name_label = HUDKit.label("", 20, UITheme.AMBER, 700)
	box.add_child(_name_label)
	_title_label = HUDKit.label("", 15, Color(UITheme.CREAM, 0.7), 600)
	box.add_child(_title_label)
	_body_label = HUDKit.label("", 18, UITheme.CREAM)
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_body_label)
	_hint_label = HUDKit.label(HINT_TEXT, 13, Color(UITheme.CREAM, 0.6))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_hint_label)

	for child in [_name_label, _title_label, _body_label, _hint_label]:
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	_goal = PanelContainer.new()
	_goal.add_theme_stylebox_override("panel", _dark_box(10))
	_goal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_goal)
	_goal_label = HUDKit.label("", 16, UITheme.CREAM, 600)
	_goal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_goal.add_child(_goal_label)


# 어두운 판. 대사 상자는 어떤 전장 그림 위에서도 밝은 글자가 읽혀야 한다(스토리 화면과 같은 이유).
static func _dark_box(pad: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UITheme.BG, 0.94)
	box.border_color = Color(UITheme.AMBER, 0.85)
	box.set_border_width_all(2)
	box.set_corner_radius_all(14)
	box.set_content_margin_all(pad)
	return box


# ===== 신호 =====

func _on_step_changed(step: TutorialStepData, _index: int, _total: int, reading: bool) -> void:
	# 실시간 안내도 같은 신호를 쓴다. 턴제 안내일 때만 그린다(실시간은 HUD 가 그린다).
	if not TutorialSystem.is_turn_active():
		return
	_step = step
	_reading = reading
	_fill_panel()
	_apply_visibility()


func _on_finished(_stage_id: StringName) -> void:
	_step = null
	_reading = false
	_apply_visibility()


func _fill_panel() -> void:
	if _step == null:
		return
	var who := _resolve_speaker(_step.speaker_id)
	_name_label.text = String(who["name"])
	_name_label.visible = not _name_label.text.is_empty()
	_portrait.texture = who["portrait"]
	_portrait.visible = _portrait.texture != null
	_title_label.text = _step.title
	_body_label.text = _step.body
	_goal_label.text = _step.title


# 화자 id -> 이름·초상. 스토리 대사와 **같은 해석**을 쓰려고 StoryLineData 를 빌린다
# (해석 순서를 여기 다시 적으면 출처가 둘이 된다).
static func _resolve_speaker(speaker_id: StringName) -> Dictionary:
	var out := {"name": "", "portrait": null}
	if String(speaker_id).is_empty():
		return out
	var probe := StoryLineData.new()
	probe.character_id = speaker_id
	out["name"] = probe.get_speaker_name()
	var character := probe.get_character()
	if character is CharacterData:
		out["portrait"] = PortraitSystem.get_portrait(character)
	elif character != null and "portrait" in character and character.portrait != null:
		out["portrait"] = GameEdition.texture(character.portrait)
	return out


func _apply_visibility() -> void:
	var active := _step != null and TutorialSystem.is_turn_active()
	visible = active
	_panel.visible = active and _reading
	_goal.visible = active and not _reading
	# 읽는 중에는 이 화면이 클릭을 먹는다(누르면 넘어간다). 하는 중에는 HUD 로 흘려보낸다.
	mouse_filter = Control.MOUSE_FILTER_STOP if active and _reading \
		else Control.MOUSE_FILTER_IGNORE
	queue_redraw()


# ===== 입력 =====

func _gui_input(event: InputEvent) -> void:
	if not _reading:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		TutorialSystem.confirm()
	elif event is InputEventScreenTouch and event.pressed:
		accept_event()
		TutorialSystem.confirm()


# ===== 그리기 =====

func _process(delta: float) -> void:
	# 다음 단계가 뜨기를 기다리는 동안(행동 연출·첫 궁극기 컷인)에는 비켜 준다.
	# 지난 단계의 배너와 구멍이 연출 위에 남으면 컷인을 가린다.
	var hide_now := TutorialSystem.is_turn_step_pending()
	if _step != null and TutorialSystem.is_turn_active():
		visible = not hide_now
	if not visible:
		return
	_phase += delta * 4.0
	_layout()
	queue_redraw()


func _layout() -> void:
	_hole = Rect2()
	_extras.clear()
	if hud != null and _step != null and not String(_step.highlight).is_empty():
		var parts := String(_step.highlight).split("|", false)
		for i in range(parts.size()):
			var r := hud.tutorial_rect(parts[i].strip_edges())
			if not r.has_area():
				continue
			if not _hole.has_area():
				_hole = r.grow(HOLE_PAD)
			else:
				_extras.append(r.grow(HOLE_PAD))

	var w := minf(PANEL_W, size.x - PANEL_MARGIN * 2.0)
	_panel.size = Vector2(w, 0.0)
	_panel.reset_size()
	_panel.size.x = w
	# 비춘 곳을 가리지 않는 쪽(위/아래)에 패널을 둔다.
	var below := not _hole.has_area() or _hole.get_center().y < size.y * 0.5
	var y := size.y - _panel.size.y - PANEL_MARGIN if below else PANEL_MARGIN + 52.0
	_panel.position = Vector2((size.x - w) * 0.5, y)

	_goal.reset_size()
	# 상단 바 높이(웨이브 알약과 배속 버튼 사이)에 둔다. 아래로 내리면 적 정보 카드를 가린다.
	_goal.position = Vector2((size.x - _goal.size.x) * 0.5, 6.0)


func _draw() -> void:
	if _step == null:
		return
	var dim := Color(0.0, 0.0, 0.0, DIM_READING if _reading else DIM_DOING)
	if not _hole.has_area():
		draw_rect(Rect2(Vector2.ZERO, size), dim)
		return

	# 구멍을 뺀 네 조각으로 어둡게 한다(셰이더 없이).
	var h := _hole
	draw_rect(Rect2(0.0, 0.0, size.x, h.position.y), dim)
	draw_rect(Rect2(0.0, h.end.y, size.x, size.y - h.end.y), dim)
	draw_rect(Rect2(0.0, h.position.y, h.position.x, h.size.y), dim)
	draw_rect(Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y), dim)

	# 맥박 치는 테두리. 하는 중에 더 또렷하다 — 지금 누를 곳이다.
	var pulse := 0.55 + 0.45 * sin(_phase)
	var grow := 2.0 + 3.0 * pulse
	draw_rect(h.grow(grow), Color(UITheme.AMBER, 0.55 + 0.45 * pulse), false, BORDER_W)
	for extra in _extras:
		draw_rect(extra.grow(grow), Color(UITheme.AMBER, 0.35 + 0.45 * pulse), false, BORDER_W - 1.0)

	if not _reading:
		# 위에서 가리키는 화살표. 화면 위쪽 영역이면 아래에서 가리킨다.
		var bob := 6.0 * sin(_phase * 1.3)
		var cx := h.get_center().x
		var tip: Vector2
		var dir := 1.0
		if h.position.y > ARROW_SIZE * 3.0:
			tip = Vector2(cx, h.position.y - 6.0 + bob)
		else:
			tip = Vector2(cx, h.end.y + 6.0 - bob)
			dir = -1.0
		var a := ARROW_SIZE
		draw_colored_polygon(PackedVector2Array([
			tip,
			tip + Vector2(-a * 0.7, -a * dir),
			tip + Vector2(a * 0.7, -a * dir),
		]), UITheme.AMBER)
