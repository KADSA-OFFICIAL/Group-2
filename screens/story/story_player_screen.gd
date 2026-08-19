extends Control

# 스토리 재생 화면 — 비주얼 노벨(미연시) 뷰.
#
# 블루 아카이브 / 니케 계열의 대화 화면 문법을 따른다:
#   배경 위에 인물이 서 있고, 하단 대사 상자에 화자 이름표와 본문이 한 글자씩 찍힌다.
#   말하는 인물은 앞으로 나오고, 듣는 인물은 물러나 어두워진다.
#   화면 아무 곳이나 누르면 다음 줄로 간다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   챕터·대본 -> StoryDatabase / StoryChapterData / StoryLineData
#   읽음 여부 -> StoryProgress
#   색        -> UITheme / HUDKit
#
# 대본을 화면에 적어 두지 않는다. 전부 .tres 에서 읽는다.
#
# ===== 연출 (#133) =====
#
# 인물은 늘 움직인다. 등장할 때 떠오르고, 말할 때 앞으로 나오고, 대사에 반응하고,
# 무대에서 내려갈 때 아래로 빠진다. 이 연출은 **아트가 없어도 성립한다** —
# 인물이 도형이어도 움직임만으로 누가 말하는지가 훨씬 잘 읽힌다.
#
# 그래서 무대를 **컨테이너가 아니라 수동 배치**로 둔다.
# HBoxContainer 에 넣으면 컨테이너가 위치를 정해 버려서 인물을 움직일 수 없다.
#
# 인물 노드는 화자가 바뀌어도 **유지한다.** 예전에는 매 줄 전부 지웠다 다시 만들어서
# 등장/퇴장을 구분할 수 없었고 애니메이션도 매번 초기화됐다.
#
# 노드 구조가 두 겹인 이유:
#   바깥(Control)  = 무대가 정하는 자리·크기.   position/scale 을 무대가 쓴다.
#   안쪽(VBox)     = 연기.                      숨쉬기·반응이 y/rotation 을 쓴다.
#   한 노드에 둘을 같이 걸면 자리 이동 트윈과 반응 트윈이 서로를 덮어쓴다.
#
# 인물 아트:
#   대사 줄에 character_id 가 있으면 그 인물의 초상을 세운다(#187).
#   id 가 없으면 지금까지처럼 화자 이름에서 색을 뽑은 **도형** 실루엣이다.
#   도형은 일부러 도형처럼 보이게 두었다 — 어설픈 그림을 흉내 내면 아트가 들어올 때
#   무엇이 임시인지 알 수 없다.
#   배경은 여전히 챕터별 그라데이션이다(배경 아트 없음).
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

# ===== 연출 수치 =====
# 전부 짧다. 건너뛰기·AUTO 로 빠르게 넘길 때 연출이 밀리면 안 된다.
const FIGURE_SIZE := Vector2(200, 380)
const STAGE_BOTTOM_MARGIN := 190.0   # 대사 상자에 발이 가리지 않을 만큼 띄운다

const MOVE_TIME := 0.30              # 자리 이동
const ENTER_TIME := 0.34             # 등장
const EXIT_TIME := 0.24              # 퇴장
const FOCUS_TIME := 0.24             # 앞으로 나오기 / 물러나기
const ENTER_RISE := 60.0             # 등장할 때 아래에서 올라오는 거리

const FOCUS_SCALE := 1.0
const BLUR_SCALE := 0.92             # 듣는 인물은 조금 작게 = 뒤에 있는 느낌
const FOCUS_LIFT := 14.0             # 말하는 인물이 앞으로(위로) 나오는 거리
const BLUR_TINT := Color(0.55, 0.53, 0.58, 1.0)

const IDLE_BOB := 5.0                # 숨쉬기 폭
const IDLE_PERIOD := 2.2

const SHAKE_TIME := 0.34
const SHAKE_STRENGTH := 14.0
const BLACKOUT_TIME := 0.45

# ===== 챕터 타이틀 / 장면 페이드 (#137) =====
# 전체 길이가 2초를 넘지 않게 잡는다. 두 번째부터는 기다리고 싶지 않은 구간이라
# 언제든 눌러서 건너뛸 수 있다.
const TITLE_FADE_IN := 0.45
const TITLE_HOLD := 0.85
const TITLE_FADE_OUT := 0.40
const CURTAIN_OPEN := 0.55    # 장면이 밝아지는 시간
const CURTAIN_CLOSE := 0.25   # 나갈 때. 나가는 길을 기다리게 하면 안 된다

var _chapter: StoryChapterData
var _index: int = 0

# 지금 줄을 몇 글자까지 보여줬는가. 소수로 들고 있어야 프레임률과 무관하게 일정하다.
var _revealed: float = 0.0
var _auto: bool = false
var _auto_hold: float = 0.0

# 무대에 서 있는 화자 **키**(들). 넣은 순서를 유지해서 인물이 좌우로 튀지 않게 한다.
# 키는 StoryLineData.get_speaker_key() — character_id 가 있으면 id, 없으면 이름이다.
var _stage_speakers: Array[String] = []
# 화자 키 -> 인물 노드(바깥 Control).
var _figures: Dictionary = {}
var _active_speaker: String = ""

# 연기용 트윈. 새 줄이 오면 정리해야 해서 들고 있는다.
var _idle_tween: Tween
var _emote_tween: Tween
var _shake_tween: Tween

var _shake_layer: Control
var _background: TextureRect
var _stage: Control
var _blackout: ColorRect
var _dialogue_box: PanelContainer
var _name_plate: Control
var _name_label: Label
var _text_label: Label
var _next_arrow: Label
var _battle_card: Control
var _end_card: Control
var _auto_button: Button

# 장면 전체를 덮는 검은 막. _blackout(줄 단위 암전)과 다르다:
# _blackout 은 대사 상자 **아래**에 있어 암전 중에도 대사가 읽힌다.
# 이쪽은 모든 것 위에 있어 화면 자체를 열고 닫는다.
var _curtain: ColorRect
var _title_card: Control
var _title_label: Label
var _title_caption: Label

# 타이틀이 도는 동안이다. 이때 입력은 "다음 줄"이 아니라 "건너뛰기"로 해석한다.
var _intro_active: bool = false
var _intro_tween: Tween
# 나가는 중. 연타해도 pop() 이 두 번 불리지 않게 한다.
var _closing: bool = false


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
	_play_intro()


# ===== 챕터 타이틀 / 장면 페이드 =====

# 검은 화면 → 제목 → 장면. 첫 줄은 이미 만들어져 막 뒤에 서 있다.
func _play_intro() -> void:
	if _chapter == null:
		return
	_intro_active = true
	_curtain.color.a = 1.0
	_title_card.modulate.a = 0.0
	_title_label.text = _chapter.title
	_title_caption.text = "CHAPTER %d" % _chapter.number

	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.tween_property(_title_card, "modulate:a", 1.0, TITLE_FADE_IN)
	_intro_tween.tween_interval(TITLE_HOLD)
	# 제목이 사라지는 것과 장면이 밝아지는 것을 겹친다. 따로 하면 검은 화면이 길어진다.
	_intro_tween.tween_property(_curtain, "color:a", 0.0, CURTAIN_OPEN)
	_intro_tween.parallel().tween_property(_title_card, "modulate:a", 0.0, TITLE_FADE_OUT)
	_intro_tween.tween_callback(func(): _intro_active = false)


# 타이틀 중 입력은 건너뛰기다. 두 번째부터는 기다리고 싶지 않다.
func _skip_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_curtain.color.a = 0.0
	_title_card.modulate.a = 0.0
	_intro_active = false


# 어두워진 뒤 닫는다. 연타해도 pop() 은 한 번만 부른다.
func _close() -> void:
	if _closing:
		return
	_closing = true
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_title_card.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_curtain, "color:a", 1.0, CURTAIN_CLOSE)
	tween.tween_callback(func(): ScreenManager.pop())


# ===== 화면 구성 =====

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 흔들리는 것은 배경과 인물뿐이다. 대사 상자까지 흔들면 글자를 읽을 수 없다.
	_shake_layer = Control.new()
	_shake_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shake_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shake_layer)

	_background = TextureRect.new()
	_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.stretch_mode = TextureRect.STRETCH_SCALE
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_layer.add_child(_background)

	# 인물이 서는 자리. 컨테이너가 아니라 맨 Control 이라 자식 위치를 우리가 정한다.
	_stage = Control.new()
	_stage.set_anchors_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shake_layer.add_child(_stage)

	# 암전용 검은 판. 인물 위, 대사 상자 아래에 둔다(어두워져도 대사는 읽혀야 한다).
	_blackout = ColorRect.new()
	_blackout.color = Color(0, 0, 0, 0)
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_blackout)

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

	# 막과 타이틀은 마지막에 넣어 모든 것 위에 놓는다.
	# 처음부터 닫혀 있어야 open_chapter() 전에 장면이 한 프레임 비치지 않는다.
	_curtain = ColorRect.new()
	_curtain.color = Color(0, 0, 0, 1)
	_curtain.set_anchors_preset(Control.PRESET_FULL_RECT)
	_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_curtain)

	_build_title_card()


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


# ── 챕터 타이틀 ──
# 검은 막 위에 뜬다. "지금부터 이 이야기를 본다"는 신호다.
func _build_title_card() -> void:
	_title_card = Control.new()
	_title_card.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.modulate.a = 0.0
	add_child(_title_card)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title_card.add_child(column)

	_title_caption = HUDKit.caption("")
	_title_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_caption.add_theme_color_override("font_color", UITheme.ACCENT)
	column.add_child(_title_caption)

	_title_label = HUDKit.label("", 40, UITheme.CREAM, 700)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)

	# 제목 아래 기울인 액센트 선. 헤더와 같은 시그니처다.
	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar_row)
	bar_row.add_child(HUDKit.accent_bar(UITheme.ACCENT, 120, 5))


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

	var close := HUDKit.make_ghost("닫기", 96, "icon_close")
	close.custom_minimum_size = Vector2(96, 44)
	close.pressed.connect(_close)
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
	back.pressed.connect(_close)
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


# 무대 인물.
#
# character_id 가 붙은 줄이면 그 인물의 **초상**을 세우고, 아니면 지금까지처럼
# 도형(머리 원 + 몸 둥근 사각형)을 세운다. 도형인 것이 드러나야 아트가 들어올 때
# 무엇이 임시였는지 알 수 있다.
#
# 바깥 Control 은 무대가 자리를 잡는 데 쓰고, 안쪽 VBox 는 연기(숨쉬기·반응)에 쓴다.
# 안쪽 노드를 meta "inner" 로 꺼내 쓴다.
func _make_figure(line: StoryLineData) -> Control:
	var key := line.get_speaker_key()
	var display_name := line.get_speaker_name()
	var color := _figure_color(line)

	var outer := Control.new()
	outer.custom_minimum_size = FIGURE_SIZE
	outer.size = FIGURE_SIZE
	outer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 확대는 발밑을 기준으로 커져야 한다. 가운데 기준이면 발이 땅에서 뜬다.
	outer.pivot_offset = Vector2(FIGURE_SIZE.x * 0.5, FIGURE_SIZE.y)
	outer.set_meta("speaker", key)

	var inner := VBoxContainer.new()
	inner.set_anchors_preset(Control.PRESET_FULL_RECT)
	inner.alignment = BoxContainer.ALIGNMENT_END
	inner.add_theme_constant_override("separation", 0)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.pivot_offset = Vector2(FIGURE_SIZE.x * 0.5, FIGURE_SIZE.y * 0.5)
	outer.add_child(inner)
	outer.set_meta("inner", inner)

	# 초상이 있으면 도형 대신 그림을 세운다.
	var portrait := _figure_portrait(line)
	if portrait != null:
		var art := TextureRect.new()
		# 여백을 잘라내야 인물이 도형 실루엣과 비슷한 크기로 선다.
		art.texture = HUDKit.trimmed_texture(portrait)
		art.custom_minimum_size = FIGURE_SIZE
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		if HUDKit.is_bust_art(portrait):
			# 반신 초상은 발이 없어 전신과 같은 바닥선에 세울 수 없다.
			# 자리 높이에 맞춰 키우고 좌우가 잘리게 둔다 = **가까이 있는 인물**.
			# 그대로 비율만 맞춰 넣으면 자리의 3분의 2만 채우고 발밑에 빈 공간이 생겨
			# 혼자 공중에 뜬 것처럼 보인다.
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		else:
			# 전신은 잘리면 머리가 날아간다. 다 들어오게 맞춘다.
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(art)

		var art_name := HUDKit.label(display_name, 13, UITheme.CREAM, 700)
		art_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		inner.add_child(art_name)
		return outer

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
	inner.add_child(head)

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
	inner.add_child(body)

	var name_label := HUDKit.label(display_name, 13, UITheme.CREAM, 700)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(name_label)
	return outer


# 인물 색. 정의가 있으면 그 인물의 tint 를, 없으면 이름 해시 색을 쓴다.
# tint 원본은 전투 도형용이라 순색에 가깝다. VN 화면에서는 톤을 팔레트로 당긴다.
func _figure_color(line: StoryLineData) -> Color:
	var character := line.get_character()
	if character != null:
		return HUDKit.muted(character.tint)
	return _speaker_color(line.speaker)


# 인물 초상. 캐릭터는 PortraitSystem(선택 > 저작 기본값)을, 적은 자기 초상을 쓴다.
func _figure_portrait(line: StoryLineData) -> Texture2D:
	var character := line.get_character()
	if character == null:
		return null
	if character is CharacterData:
		return PortraitSystem.get_portrait(character)
	return character.portrait


func _inner_of(figure: Control) -> Control:
	return figure.get_meta("inner") as Control


# 무대에서 i번째 인물이 설 자리. 인원 수에 따라 고르게 편다.
func _slot_position(index: int, count: int) -> Vector2:
	var view := get_viewport_rect().size
	var center_x: float = view.x * float(index + 1) / float(count + 1)
	return Vector2(center_x - FIGURE_SIZE.x * 0.5, view.y - STAGE_BOTTOM_MARGIN - FIGURE_SIZE.y)


# 지금 화자를 무대에 올리고 나머지는 물러나게 한다.
#
# 무대 인원을 STAGE_CAPACITY 로 제한한다: 챕터에 화자가 여섯이면 여섯을 다 세울 수 없다.
# 가장 오래 말하지 않은 인물부터 내린다.
# line 이 null 이거나 화자가 없는 줄(지문·전투)이면 무대는 그대로 두고 강조만 푼다.
func _update_stage(line: StoryLineData) -> void:
	# 무대 식별은 **키**로 한다. id 가 있으면 id, 없으면 이름 문자열이다.
	# 그래서 같은 인물이 줄마다 다르게 적혀 있어도(띄어쓰기 등) 하나로 묶인다.
	var key := line.get_speaker_key() if line != null else ""

	if not key.is_empty() and not _stage_speakers.has(key):
		if _stage_speakers.size() >= STAGE_CAPACITY:
			_exit_figure(_stage_speakers[0])
		_stage_speakers.append(key)

		var figure := _make_figure(line)
		_figures[key] = figure
		_stage.add_child(figure)

		# 등장: 제자리 아래에서 떠오르며 나타난다.
		#
		# 여기서 페이드인 트윈을 따로 걸지 않는다. 바로 뒤에 _layout_figures() 가
		# 같은 modulate 를 트윈하는데, 두 트윈이 같은 속성을 물면 늦게 끝나는 쪽이
		# 새 값을 덮어써서 인물이 반투명하게 남는다(실제로 alpha 0.76 으로 굳었다).
		# 시작값만 잡아 두고 나머지는 _layout_figures() 하나가 맡는다.
		var slot := _slot_position(_stage_speakers.size() - 1, _stage_speakers.size())
		figure.position = slot + Vector2(0, ENTER_RISE)
		figure.modulate.a = 0.0
		figure.scale = Vector2(BLUR_SCALE, BLUR_SCALE)

	_active_speaker = key
	_layout_figures()


# 무대에서 내린다. 노드를 바로 지우지 않고 아래로 빠지는 걸 보여준 뒤 지운다.
func _exit_figure(speaker: String) -> void:
	_stage_speakers.erase(speaker)
	var figure: Control = _figures.get(speaker)
	_figures.erase(speaker)
	if figure == null or not is_instance_valid(figure):
		return
	# 자리 이동 트윈이 아직 돌고 있으면 내려가는 중에 다시 끌어올린다.
	_kill_figure_tween(figure)
	var tween := figure.create_tween()
	figure.set_meta("tween", tween)
	tween.set_parallel(true)
	tween.tween_property(figure, "position:y", figure.position.y + ENTER_RISE, EXIT_TIME)
	tween.tween_property(figure, "modulate:a", 0.0, EXIT_TIME)
	tween.chain().tween_callback(figure.queue_free)


# 모든 인물을 제자리로 보내고, 말하는 인물만 앞으로 낸다.
#
# 자리 이동과 포커스를 한 함수에서 처리하는 이유: 둘 다 바깥 Control 의 position 을
# 건드리기 때문이다. 따로 두면 두 트윈이 서로를 덮어써서 인물이 어긋난 자리에 남는다.
func _layout_figures() -> void:
	var count := _stage_speakers.size()
	for i in range(count):
		var speaker: String = _stage_speakers[i]
		var figure: Control = _figures.get(speaker)
		if figure == null or not is_instance_valid(figure):
			continue

		var active: bool = speaker == _active_speaker
		var target := _slot_position(i, count)
		# 말하는 인물은 앞으로(위로) 나온다.
		if active:
			target.y -= FOCUS_LIFT

		var scale_to: float = FOCUS_SCALE if active else BLUR_SCALE
		var tint: Color = Color(1, 1, 1, 1) if active else BLUR_TINT

		# 줄을 빠르게 넘기면 이 함수가 연달아 불린다. 앞 트윈을 죽이지 않으면
		# 아직 돌던 트윈이 새 트윈의 결과를 덮어써서 인물이 어긋난 자리·반투명으로 굳는다.
		_kill_figure_tween(figure)
		var tween := figure.create_tween()
		figure.set_meta("tween", tween)
		tween.set_parallel(true)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(figure, "position", target, MOVE_TIME)
		tween.tween_property(figure, "scale", Vector2(scale_to, scale_to), FOCUS_TIME)
		tween.tween_property(figure, "modulate", tint, FOCUS_TIME)

		# 말하지 않는 인물은 연기를 초기화한다. 반응 중에 화자가 바뀌면
		# 기울어지거나 뜬 채로 굳는다.
		if not active:
			var inner := _inner_of(figure)
			if inner != null:
				inner.rotation = 0.0
				inner.position.y = 0.0

	_start_idle()


func _kill_figure_tween(figure: Control) -> void:
	if not figure.has_meta("tween"):
		return
	var previous = figure.get_meta("tween")
	if previous is Tween and previous.is_valid():
		previous.kill()


# 말하는 인물만 아주 느리게 위아래로 흔든다. 정지 화면처럼 보이지 않게 하는 최소한이다.
func _start_idle() -> void:
	if _idle_tween != null and _idle_tween.is_valid():
		_idle_tween.kill()
	var figure: Control = _figures.get(_active_speaker)
	if figure == null or not is_instance_valid(figure):
		return
	var inner := _inner_of(figure)
	if inner == null:
		return
	inner.position.y = 0.0
	_idle_tween = inner.create_tween()
	_idle_tween.set_loops()
	_idle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(inner, "position:y", -IDLE_BOB, IDLE_PERIOD * 0.5)
	_idle_tween.tween_property(inner, "position:y", 0.0, IDLE_PERIOD * 0.5)


# 인물 반응.
#
# 무엇을 할지는 대본이 정한다(StoryLineData.emotion). 화면은 그 지시를 몸짓으로 옮길
# 뿐이고, 본문을 훑지 않는다. AUTO 해석도 StoryLineData 가 한다.
func _emote(speaker: String, emotion: int) -> void:
	if _emote_tween != null and _emote_tween.is_valid():
		_emote_tween.kill()
	var figure: Control = _figures.get(speaker)
	if figure == null or not is_instance_valid(figure):
		return
	var inner := _inner_of(figure)
	if inner == null:
		return

	inner.rotation = 0.0
	_emote_tween = inner.create_tween()
	_emote_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	match emotion:
		StoryLineData.Emotion.SURPRISE:
			# 놀람·강조: 튀어오른다.
			_emote_tween.tween_property(inner, "position:y", -22.0, 0.12)
			_emote_tween.tween_property(inner, "position:y", 0.0, 0.18)
		StoryLineData.Emotion.QUESTION:
			# 의문: 고개를 갸웃한다.
			_emote_tween.tween_property(inner, "rotation", 0.05, 0.14)
			_emote_tween.tween_property(inner, "rotation", 0.0, 0.20)
		StoryLineData.Emotion.DOWN:
			# 머뭇거림·낙담: 처진다.
			_emote_tween.tween_property(inner, "position:y", 7.0, 0.20)
			_emote_tween.tween_property(inner, "position:y", 0.0, 0.26)
		_:
			# 평범한 대사: 가볍게 끄덕인다.
			_emote_tween.tween_property(inner, "position:y", -8.0, 0.10)
			_emote_tween.tween_property(inner, "position:y", 0.0, 0.16)

	# 반응이 끝나면 숨쉬기를 다시 건다(반응 트윈이 idle 을 덮어썼으므로).
	_emote_tween.tween_callback(_start_idle)


# ===== 화면 연출 =====

# 배경과 인물만 흔든다. 대사 상자까지 흔들면 글자를 읽을 수 없다.
func _shake() -> void:
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_layer.position = Vector2.ZERO
	_shake_tween = _shake_layer.create_tween()
	var steps := 6
	for i in range(steps):
		# 점점 잦아든다. 일정한 진폭으로 흔들면 기계처럼 보인다.
		var decay := 1.0 - float(i) / float(steps)
		var offset := Vector2(
			randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH) * decay,
			randf_range(-SHAKE_STRENGTH, SHAKE_STRENGTH) * decay * 0.6)
		_shake_tween.tween_property(_shake_layer, "position", offset, SHAKE_TIME / float(steps))
	_shake_tween.tween_property(_shake_layer, "position", Vector2.ZERO, SHAKE_TIME / float(steps))


# 암전. 어두워졌다 돌아온다. 대사 상자는 위에 있어 계속 읽힌다.
func _blackout_flash() -> void:
	var tween := _blackout.create_tween()
	tween.tween_property(_blackout, "color:a", 0.85, BLACKOUT_TIME * 0.45)
	tween.tween_property(_blackout, "color:a", 0.0, BLACKOUT_TIME * 0.55).set_delay(0.15)


# 대본이 지시한 화면 연출을 건다.
#
# 전투 줄은 따로 지시하지 않아도 흔들린다 — 그건 본문 추측이 아니라 **줄 종류**가
# 정하는 것이라 저작 실수로 잘못 걸릴 여지가 없다.
# 다만 저작자가 명시한 연출이 있으면 그쪽이 이긴다(전투인데 암전을 원할 수 있다).
func _apply_screen_effect(line: StoryLineData) -> void:
	match line.screen_effect:
		StoryLineData.ScreenEffect.BLACKOUT:
			_blackout_flash()
		StoryLineData.ScreenEffect.SHAKE:
			_shake()
		_:
			if line.kind == StoryLineData.Kind.BATTLE:
				_shake()


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

	var text := _line_text(line)

	match line.kind:
		StoryLineData.Kind.DIALOGUE:
			_name_plate.visible = true
			# 이름과 색의 출처는 StoryLineData 다(id 가 있으면 캐릭터 정의에서 온다).
			_name_label.text = line.get_speaker_name()
			(_name_plate as SkewPlate).fill = _figure_color(line)
			_name_plate.queue_redraw()
			_text_label.add_theme_color_override("font_color", UITheme.CREAM)
			_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_update_stage(line)
			# 무엇을 할지는 대본이 정한다. AUTO 해석도 StoryLineData 가 한다.
			_emote(line.get_speaker_key(), line.resolve_emotion())
		StoryLineData.Kind.BATTLE:
			_name_plate.visible = false
			# 전투 줄은 text 가 비어 있을 수 있다. 그때도 무엇이 일어나는지는 알려야 한다.
			_text_label.add_theme_color_override("font_color", UITheme.CREAM)
			_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_update_stage(null)
		_:
			# 지문은 이름표 없이, 흐리고 가운데로. 대사와 한눈에 구분되어야 한다.
			_name_plate.visible = false
			_text_label.add_theme_color_override("font_color",
				Color(UITheme.CREAM.r, UITheme.CREAM.g, UITheme.CREAM.b, 0.78))
			_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_update_stage(null)

	_apply_screen_effect(line)
	_text_label.text = text
	_text_label.visible_characters = 0


func _line_text(line: StoryLineData) -> String:
	if line.kind == StoryLineData.Kind.BATTLE and line.text.is_empty():
		return "전투가 시작된다."
	return line.text


func _process(delta: float) -> void:
	# 타이틀이 도는 동안에는 타자기를 세워 둔다.
	# 막 뒤에서 이미 다 찍혀 있으면 장면이 열렸을 때 첫 줄을 놓친다.
	if _chapter == null or _end_card.visible or _intro_active or _closing:
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
	if _chapter == null or _end_card.visible or _closing:
		return

	# 타이틀 중 입력은 진행이 아니라 건너뛰기다.
	if _intro_active:
		_skip_intro()
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
	# 무대를 비우고 처음부터. 다시 보기이므로 등장 연출도 다시 나와야 한다.
	for speaker in _figures.keys():
		var figure: Control = _figures[speaker]
		if is_instance_valid(figure):
			figure.queue_free()
	_figures.clear()
	_stage_speakers.clear()
	_active_speaker = ""
	_index = 0
	_end_card.visible = false
	_blackout.color.a = 0.0
	_show_line()
	# 다시 보기도 타이틀부터다. 처음 볼 때와 같은 흐름이어야 한다.
	_play_intro()


func _finish() -> void:
	_auto = false
	_battle_card.visible = false
	_end_card.visible = true
	_next_arrow.visible = false
