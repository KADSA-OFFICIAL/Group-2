extends Control

# 스토리 재생 화면 — 비주얼 노벨(미연시) 뷰.
#
# 블루 아카이브 / 니케 계열의 대화 화면 문법을 따른다:
#   배경 위에 인물이 서 있고, 하단 대사 상자에 화자 이름표와 본문이 한 글자씩 찍힌다.
#   말하는 인물만 밝고 나머지는 어둡다. 화면 아무 곳이나 누르면 다음 줄로 간다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   챕터·대본 -> StoryDatabase / StoryChapterData / StoryLineData
#   읽음 여부 -> StoryProgress
#   색        -> UITheme / HUDKit
#
# 대본을 화면에 적어 두지 않는다. 전부 .tres 에서 읽는다.
#
# 아트가 없다:
#   배경도 캐릭터 스프라이트도 아직 없다. 그래서 배경은 챕터별 그라데이션,
#   인물은 화자 이름에서 색을 뽑은 실루엣으로 대신한다.
#   **일부러 도형처럼 보이게** 두었다. 어설픈 그림을 흉내 내면 아트가 들어올 때
#   무엇이 임시인지 알 수 없다. StoryLineData.speaker 가 로스터 id 와 이어지면
#   그때 _make_figure() 안만 바꾸면 된다.
#
# 이 화면이 밝지 않은 이유:
#   대사 상자는 그림 위에 얹히므로 반투명 어두운 판 + 밝은 글자다.
#   나머지 메타 화면(밝은 면 + 잉크 글자)과 반대인데, VN 대사 상자는 어떤 그림 위에서도
#   글자가 읽혀야 하기 때문이다. 밝은 판을 쓰면 배경이 밝을 때 글자가 사라진다.

# 초당 몇 글자를 찍을지. 설정으로 뺄 수 있게 상수로 둔다.
const TYPE_CHARS_PER_SECOND := 45.0

# AUTO 일 때 한 줄을 다 보여준 뒤 기다리는 시간(초).
const AUTO_HOLD_SECONDS := 1.6

# 인물 플레이스홀더에 쓸 색. 화자 이름에서 하나를 고른다.
# 흙 톤 팔레트 안에서만 고른다(형광색을 넣으면 이 게임의 색이 아니게 된다).
const FIGURE_COLORS := [
	UITheme.SKY, UITheme.CORAL, UITheme.LEAF,
	UITheme.LILAC, UITheme.AMBER, UITheme.STONE_GRAY,
]

# 무대에 동시에 세우는 인물 수. 셋 이상이면 화면이 인물로 가득 찬다.
const STAGE_CAPACITY := 2

var _chapter: StoryChapterData
var _index: int = 0

# 지금 줄을 몇 글자까지 보여줬는가. 소수로 들고 있어야 프레임률과 무관하게 일정하다.
var _revealed: float = 0.0
var _auto: bool = false
var _auto_hold: float = 0.0

# 무대에 서 있는 화자 이름(들). 넣은 순서를 유지해서 인물이 좌우로 튀지 않게 한다.
var _stage_speakers: Array[String] = []

var _background: TextureRect
var _stage_row: HBoxContainer
var _dialogue_box: PanelContainer
var _name_plate: Control
var _name_label: Label
var _text_label: Label
var _next_arrow: Label
var _battle_card: Control
var _end_card: Control
var _auto_button: Button


# 기울인 이름표. Control 에 skew 속성이 없어서 폴리곤으로 직접 그린다.
# MarginContainer 를 상속하는 이유: 자식 라벨 크기에 맞춰 판이 저절로 커진다.
class SkewPlate:
	extends MarginContainer

	var fill: Color = Color.WHITE
	var slant: float = 10.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_theme_constant_override("margin_left", 20)
		add_theme_constant_override("margin_right", 20)
		add_theme_constant_override("margin_top", 5)
		add_theme_constant_override("margin_bottom", 5)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(slant, 0), Vector2(w, 0),
			Vector2(w - slant, h), Vector2(0, h),
		]), fill)


func _ready() -> void:
	_build()
	set_process(true)


# 바깥(챕터 선택 화면)에서 불러 어떤 챕터를 재생할지 정한다.
# push() 직후에 부르므로 _ready() 는 이미 끝나 있다.
func open_chapter(chapter_id: StringName) -> void:
	_chapter = StoryDatabase.get_chapter(chapter_id)
	# 연 시점에 읽음으로 기록한다. 끝까지 봐야 기록하면 중간에 닫은 사람이 계속 NEW 를 본다.
	if _chapter != null:
		StoryProgress.mark_read(chapter_id)
	_apply_chapter_background()
	_index = 0
	_show_line()


# ===== 화면 구성 =====

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_background = TextureRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_build_stage()
	_build_dialogue()

	# 화면 아무 곳이나 눌러 진행. 위 조작 버튼들보다 **먼저** 넣어야
	# 버튼이 이 판보다 위에 놓여 클릭을 먼저 가져간다.
	var catcher := Button.new()
	catcher.flat = true
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus"]:
		catcher.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	catcher.pressed.connect(_advance)
	add_child(catcher)

	_build_battle_card()
	_build_end_card()
	_build_top_bar()


# ── 인물이 서는 자리 ──
func _build_stage() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	_stage_row = HBoxContainer.new()
	# 인물은 바닥에 발을 붙이고 서야 한다. 대사 상자 높이만큼 띄운다.
	_stage_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_stage_row.offset_top = -640.0
	_stage_row.offset_bottom = -196.0
	_stage_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_stage_row.add_theme_constant_override("separation", 80)
	_stage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_stage_row)


# ── 하단 대사 상자 ──
func _build_dialogue() -> void:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	# 상자 높이는 고정이다. 줄 길이에 따라 상자가 커졌다 작아지면 글자가 위아래로 튄다.
	# 두세 줄이 들어갈 만큼 잡아 두고 짧은 대사에서는 아래가 비게 둔다.
	column.offset_top = -182.0
	column.offset_left = 60.0
	column.offset_right = -60.0
	column.offset_bottom = -26.0
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(column)

	# 이름표는 상자 위로 걸쳐 나온다(이 장르의 대사 상자 문법).
	var plate_row := HBoxContainer.new()
	plate_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(plate_row)

	var plate := SkewPlate.new()
	plate.fill = UITheme.ACCENT
	_name_label = HUDKit.label("", 17, UITheme.INK, 700)
	plate.add_child(_name_label)
	plate_row.add_child(plate)
	_name_plate = plate

	_dialogue_box = PanelContainer.new()
	_dialogue_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_dialogue_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 그림 위에 얹히므로 반투명 어두운 판이다. 위 주석 참고.
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.13, 0.11, 0.09, 0.82)
	box.set_corner_radius_all(HUDKit.RADIUS)
	box.set_border_width_all(HUDKit.BORDER)
	box.border_color = Color(UITheme.CREAM.r, UITheme.CREAM.g, UITheme.CREAM.b, 0.30)
	box.set_content_margin_all(22)
	_dialogue_box.add_theme_stylebox_override("panel", box)
	column.add_child(_dialogue_box)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialogue_box.add_child(inner)

	_text_label = HUDKit.label("", 20, UITheme.CREAM)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(_text_label)

	var arrow_row := HBoxContainer.new()
	arrow_row.alignment = BoxContainer.ALIGNMENT_END
	arrow_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(arrow_row)
	_next_arrow = HUDKit.label("▼", 14, Color(UITheme.CREAM.r, UITheme.CREAM.g, UITheme.CREAM.b, 0.7))
	arrow_row.add_child(_next_arrow)


# ── 우상단 조작 ──
func _build_top_bar() -> void:
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -330.0
	row.offset_top = 16.0
	row.offset_right = -16.0
	row.offset_bottom = 62.0
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	_auto_button = HUDKit.make_ghost("AUTO", 90)
	_auto_button.custom_minimum_size = Vector2(90, 44)
	_auto_button.pressed.connect(_toggle_auto)
	row.add_child(_auto_button)

	var skip := HUDKit.make_ghost("건너뛰기", 110)
	skip.custom_minimum_size = Vector2(110, 44)
	skip.pressed.connect(_finish)
	row.add_child(skip)

	var close := HUDKit.make_ghost("닫기", 80)
	close.custom_minimum_size = Vector2(80, 44)
	close.pressed.connect(func(): ScreenManager.pop())
	row.add_child(close)


# ── 전투 줄에 뜨는 카드 ──
# 지금은 "여기서 전투가 있다"는 표시만 한다. stage_id 연결은 아직 못 한다
# (승리 조건 판정과 스테이지 로딩이 없다 — 스테이지 선택 화면과 같은 제약이다).
func _build_battle_card() -> void:
	_battle_card = PanelContainer.new()
	# 인물보다 위, 화면 상단에 띄운다. 가운데에 두면 인물을 가린다.
	_battle_card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_battle_card.offset_left = -170.0
	_battle_card.offset_right = 170.0
	_battle_card.offset_top = 34.0
	_battle_card.offset_bottom = 122.0
	_battle_card.add_theme_stylebox_override("panel", HUDKit.card(true))
	_battle_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_card.visible = false
	add_child(_battle_card)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_card.add_child(row)

	var icon := HUDKit.make_icon("icon_battle", 34)
	if icon != null:
		row.add_child(icon)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(box)
	box.add_child(HUDKit.label("전투", 20, HUDKit.text_on_accent(), 700))
	box.add_child(HUDKit.caption("battle"))


# ── 마지막 줄 다음에 뜨는 카드 ──
func _build_end_card() -> void:
	_end_card = PanelContainer.new()
	_end_card.set_anchors_preset(Control.PRESET_CENTER)
	_end_card.offset_left = -190.0
	_end_card.offset_right = 190.0
	_end_card.offset_top = -90.0
	_end_card.offset_bottom = 60.0
	_end_card.add_theme_stylebox_override("panel", HUDKit.panel(20))
	_end_card.visible = false
	add_child(_end_card)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 12)
	_end_card.add_child(box)

	var title := HUDKit.label("이 챕터를 끝까지 봤습니다", 17, HUDKit.text_1(), 700)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)

	var again := HUDKit.make_ghost("다시 보기", 120)
	again.pressed.connect(_restart)
	actions.add_child(again)

	var back := HUDKit.make_cta("목록으로", "back")
	back.pressed.connect(func(): ScreenManager.pop())
	actions.add_child(back)


# ===== 배경 =====

# 챕터마다 다른 배경을 준다. 실제 배경 아트가 들어오면 이 함수만 갈아 끼우면 된다.
func _apply_chapter_background() -> void:
	var number: int = _chapter.number if _chapter != null else 1
	var base: Color = FIGURE_COLORS[(number * 2) % FIGURE_COLORS.size()]

	var gradient := Gradient.new()
	gradient.set_color(0, base.lerp(UITheme.CREAM, 0.55))
	gradient.set_color(1, base.lerp(UITheme.INK, 0.45))

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	_background.texture = texture


# ===== 인물 =====

# 화자 이름에서 색을 고른다. 같은 이름은 늘 같은 색이 나와야 한다.
func _speaker_color(speaker: String) -> Color:
	if speaker.is_empty():
		return UITheme.STONE_GRAY
	return FIGURE_COLORS[absi(speaker.hash()) % FIGURE_COLORS.size()]


# 임시 인물. 머리(원) + 몸(둥근 사각형) + 이름.
# 도형인 것이 드러나야 아트가 들어올 때 무엇이 임시였는지 알 수 있다.
func _make_figure(speaker: String) -> Control:
	var color := _speaker_color(speaker)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_meta("speaker", speaker)

	var head := PanelContainer.new()
	head.custom_minimum_size = Vector2(96, 96)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var head_box := StyleBoxFlat.new()
	head_box.bg_color = color
	head_box.set_corner_radius_all(999)
	head_box.set_border_width_all(3)
	head_box.border_color = color.darkened(0.35)
	head.add_theme_stylebox_override("panel", head_box)
	column.add_child(head)

	var body := PanelContainer.new()
	body.custom_minimum_size = Vector2(168, 250)
	body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_box := StyleBoxFlat.new()
	body_box.bg_color = color
	body_box.corner_radius_top_left = 76
	body_box.corner_radius_top_right = 76
	body_box.corner_radius_bottom_left = 10
	body_box.corner_radius_bottom_right = 10
	body_box.set_border_width_all(3)
	body_box.border_color = color.darkened(0.35)
	body.add_theme_stylebox_override("panel", body_box)
	column.add_child(body)

	var name_label := HUDKit.label(speaker, 13, UITheme.CREAM, 700)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	return column


# 지금 화자를 무대에 올리고 나머지는 어둡게 한다.
#
# 무대 인원을 STAGE_CAPACITY 로 제한한다: 챕터에 화자가 여섯이면 여섯을 다 세울 수 없다.
# 가장 오래 말하지 않은 인물부터 내린다.
func _update_stage(speaker: String) -> void:
	if not speaker.is_empty():
		if not _stage_speakers.has(speaker):
			if _stage_speakers.size() >= STAGE_CAPACITY:
				_stage_speakers.remove_at(0)
			_stage_speakers.append(speaker)
			_rebuild_figures()
	_apply_focus(speaker)


func _rebuild_figures() -> void:
	for child in _stage_row.get_children():
		_stage_row.remove_child(child)
		child.queue_free()
	for name in _stage_speakers:
		_stage_row.add_child(_make_figure(name))


# 말하는 인물만 밝게. 지문일 때는 전부 어둡게 해서 "지금은 아무도 말하지 않는다"를 보인다.
func _apply_focus(speaker: String) -> void:
	for child in _stage_row.get_children():
		var control := child as Control
		if control == null:
			continue
		var active: bool = String(control.get_meta("speaker", "")) == speaker
		control.modulate = Color(1, 1, 1, 1) if active else Color(0.55, 0.53, 0.58, 1)


# ===== 재생 =====

func _current_line() -> StoryLineData:
	if _chapter == null or _index < 0 or _index >= _chapter.lines.size():
		return null
	return _chapter.lines[_index]


func _show_line() -> void:
	var line := _current_line()
	if line == null:
		_finish()
		return

	_revealed = 0.0
	_auto_hold = 0.0
	_end_card.visible = false
	_battle_card.visible = line.kind == StoryLineData.Kind.BATTLE

	match line.kind:
		StoryLineData.Kind.DIALOGUE:
			_name_plate.visible = true
			_name_label.text = line.speaker
			(_name_plate as SkewPlate).fill = _speaker_color(line.speaker)
			_name_plate.queue_redraw()
			_text_label.add_theme_color_override("font_color", UITheme.CREAM)
			_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_update_stage(line.speaker)
		StoryLineData.Kind.BATTLE:
			_name_plate.visible = false
			# 전투 줄은 text 가 비어 있을 수 있다. 그때도 무엇이 일어나는지는 알려야 한다.
			_text_label.add_theme_color_override("font_color", UITheme.CREAM)
			_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_update_stage("")
		_:
			# 지문은 이름표 없이, 흐리고 가운데로. 대사와 한눈에 구분되어야 한다.
			_name_plate.visible = false
			_text_label.add_theme_color_override("font_color",
				Color(UITheme.CREAM.r, UITheme.CREAM.g, UITheme.CREAM.b, 0.78))
			_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_update_stage("")

	_text_label.text = _line_text(line)
	_text_label.visible_characters = 0


func _line_text(line: StoryLineData) -> String:
	if line.kind == StoryLineData.Kind.BATTLE and line.text.is_empty():
		return "전투가 시작된다."
	return line.text


func _process(delta: float) -> void:
	if _chapter == null or _end_card.visible:
		return
	var total := _text_label.text.length()

	if _revealed < float(total):
		_revealed = minf(_revealed + TYPE_CHARS_PER_SECOND * delta, float(total))
		_text_label.visible_characters = int(_revealed)
		# 아직 찍는 중에는 다음 표시를 감춘다. 다 찍힌 줄에서만 깜빡인다.
		_next_arrow.visible = false
		return

	_next_arrow.visible = true
	# 다 찍힌 줄에서만 깜빡인다. 진행할 수 있다는 표시다.
	_next_arrow.modulate.a = 0.35 + 0.45 * absf(sin(Time.get_ticks_msec() / 400.0))

	if _auto:
		_auto_hold += delta
		if _auto_hold >= AUTO_HOLD_SECONDS:
			_auto_hold = 0.0
			_advance()


# ===== 조작 =====

func _unhandled_input(event: InputEvent) -> void:
	if _end_card.visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_advance()
		get_viewport().set_input_as_handled()


# 다음 줄로. 아직 찍는 중이면 먼저 그 줄을 전부 보여준다.
# (한 번의 입력으로 두 가지가 일어나면 대사를 놓친다.)
func _advance() -> void:
	if _chapter == null or _end_card.visible:
		return

	var total := _text_label.text.length()
	if _revealed < float(total):
		_revealed = float(total)
		_text_label.visible_characters = total
		return

	_index += 1
	if _index >= _chapter.lines.size():
		_finish()
		return
	_show_line()


func _toggle_auto() -> void:
	_auto = not _auto
	_auto_hold = 0.0
	# 켜진 상태를 버튼 모양으로 드러낸다.
	_auto_button.add_theme_stylebox_override("normal",
		HUDKit.cta() if _auto else HUDKit.ghost())


func _restart() -> void:
	_stage_speakers.clear()
	_rebuild_figures()
	_index = 0
	_end_card.visible = false
	_show_line()


func _finish() -> void:
	_auto = false
	_battle_card.visible = false
	_end_card.visible = true
	_next_arrow.visible = false
