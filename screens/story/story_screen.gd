extends Control

# 스토리 화면 (메타 UI) — **챕터 선택**.
#
# 구조는 서브컬쳐 수집형 RPG 문법을 따른다: **좌 챕터 타임라인 / 우 챕터 상세 + 읽기**.
# 장르 원형의 초대형 아웃라인 넘버를 챕터 행에 그대로 썼다.
#
# 대본을 여기서 읽지 않는다:
#   예전에는 이 화면 오른쪽이 대본 전체를 세로로 쌓아 보여주는 리더였다.
#   대사·지문이 문서처럼 쌓여서 읽는 경험이 미연시가 아니라 대본 파일에 가까웠다.
#   실제 재생은 StoryPlayerScreen(비주얼 노벨 뷰)이 맡고, 여기는 **고르는 곳**이다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   챕터 목록·대본 -> StoryDatabase / StoryChapterData / StoryLineData
#   읽음 여부      -> StoryProgress (화면이 따로 세지 않는다)
#   등장인물       -> StoryChapterData.get_speakers() (여기서 대본을 다시 훑지 않는다)
#   색·조각        -> UITheme / HUDKit
#
# 이 게임에 없는 것은 만들지 않았다:
#   노드 맵, 스태미나, 추천 전투력, 3성 조건, 선택지 — 전부 시스템이 없다.

const STORY_PLAYER_SCENE := preload("res://screens/story/StoryPlayerScreen.tscn")

var _chapter_list: VBoxContainer
var _detail_body: VBoxContainer
var _read_button: Button
var _open_id: StringName = &""


func _ready() -> void:
	var ids := StoryDatabase.get_all_ids()
	if not ids.is_empty():
		_open_id = ids[0]

	_build()
	_refresh()

	# 재생 화면이 읽음을 기록하면 목록과 상세("열람" 행)가 함께 따라와야 한다.
	StoryProgress.progress_changed.connect(_refresh)


# ===== 화면 구성 =====

func _build() -> void:
	# 뜰에서 성소(sanctum)로 들어온 화면이다 — 그 건물의 장면을 배경으로 깐다(#287).
	add_child(HUDKit.make_backdrop(HUDKit.load_backdrop("sanctum")))

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(HUDKit.make_header("스토리", "story", "icon_story"))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var _col0 := _build_chapter_panel()
	body.add_child(_col0)
	var _col1 := _build_detail()
	body.add_child(_col1)



# ── 좌: 챕터 타임라인 ──
func _build_chapter_panel() -> Control:
	var panel := HUDKit.make_panel("챕터", "chapters")
	panel.custom_minimum_size = Vector2(340, 0)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HUDKit.body_of(panel).add_child(scroll)

	_chapter_list = VBoxContainer.new()
	_chapter_list.add_theme_constant_override("separation", 8)
	_chapter_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(HUDKit.hover_safe(_chapter_list))
	return panel


# ── 우: 챕터 상세 + 읽기 ──
func _build_detail() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)

	var panel := HUDKit.make_panel("", "")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	HUDKit.body_of(panel).add_child(scroll)

	_detail_body = VBoxContainer.new()
	_detail_body.add_theme_constant_override("separation", 10)
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_detail_body)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(actions)

	_read_button = HUDKit.make_cta("읽기", "read")
	_read_button.pressed.connect(_on_read_pressed)
	actions.add_child(_read_button)
	return column


# ===== 갱신 =====

func _refresh() -> void:
	_refresh_chapters()
	_refresh_detail()


func _refresh_chapters() -> void:
	_clear(_chapter_list)
	var ids := StoryDatabase.get_all_ids()
	if ids.is_empty():
		_chapter_list.add_child(HUDKit.label("저작된 챕터가 없습니다.", 12, HUDKit.text_2()))
		_chapter_list.add_child(HUDKit.label("data/story 에 .tres 를 저작하면 나타납니다.", 11, HUDKit.text_3()))
		return

	for id in ids:
		_chapter_list.add_child(_make_chapter_row(id))


func _make_chapter_row(id: StringName) -> Control:
	var chapter := StoryDatabase.get_chapter(id)
	var is_read := StoryProgress.is_read(id)
	var open: bool = id == _open_id

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 92)
	card.add_theme_stylebox_override("panel", HUDKit.card(open))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	# 펼친 카드는 액센트로 꽉 차 있다. 그 위에서는 액센트 글자가 안 보이므로 잉크로 쓴다.
	var head_color: Color = HUDKit.text_on_accent() if open else HUDKit.text_1()

	if chapter != null:
		# 초대형 넘버(장르 문법). 읽은 챕터는 흐리게.
		var number_color: Color = head_color if (open or not is_read) else HUDKit.text_3()
		if not open and not is_read:
			number_color = HUDKit.accent_text()
		var number := HUDKit.label("%02d" % chapter.number, 44, number_color, 700)
		number.custom_minimum_size = Vector2(64, 0)
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(number)

		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(box)

		var title := HUDKit.label(chapter.title, 16, head_color, 700)
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(title)
		box.add_child(HUDKit.caption("chapter %d" % chapter.number))

		var meta := HBoxContainer.new()
		meta.add_theme_constant_override("separation", 8)
		box.add_child(meta)
		var meta_color: Color = HUDKit.text_on_accent() if open else HUDKit.text_3()
		meta.add_child(HUDKit.label("%d줄" % chapter.lines.size(), 12, meta_color))
		var battles := chapter.get_battle_count()
		if battles > 0:
			meta.add_child(HUDKit.label("전투 %d" % battles, 12, meta_color))
		# 미열람 표시는 칩으로. 글자색만 바꾸면 카드가 액센트로 찼을 때 묻힌다.
		if is_read:
			meta.add_child(HUDKit.label("읽음", 12, meta_color, 700))
		else:
			meta.add_child(HUDKit.tag_chip("NEW", UITheme.NEGATIVE))

	var button := Button.new()
	button.flat = true
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.pressed.connect(_on_chapter_pressed.bind(id))
	card.add_child(button)
	# 카드는 전면 투명 버튼이 클릭을 받으므로, 호버 신호도 그 버튼에서 듣는다.
	HUDKit.hover_lift(card, button)

	return card


# 고른 챕터의 요약·등장인물·분량. 대본 본문은 여기서 보여주지 않는다.
func _refresh_detail() -> void:
	_clear(_detail_body)
	var chapter := StoryDatabase.get_chapter(_open_id) if _open_id != &"" else null
	_read_button.disabled = chapter == null

	if chapter == null:
		_detail_body.add_child(HUDKit.label("왼쪽에서 챕터를 고르세요.", 14, HUDKit.text_2()))
		return

	_detail_body.add_child(HUDKit.label(chapter.title, 26, HUDKit.text_1(), 700))
	_detail_body.add_child(HUDKit.caption("chapter %d" % chapter.number))

	if not chapter.summary.is_empty():
		var summary := HUDKit.label(chapter.summary, 14, HUDKit.text_2())
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_body.add_child(summary)

	_detail_body.add_child(HUDKit.rule())

	_detail_body.add_child(HUDKit.stat_row("분량", "lines", "%d줄" % chapter.lines.size()))
	_detail_body.add_child(HUDKit.stat_row("전투", "battles", "%d회" % chapter.get_battle_count()))
	_detail_body.add_child(HUDKit.stat_row(
		"열람", "read", "읽음" if StoryProgress.is_read(_open_id) else "아직"))

	# 등장인물 목록의 출처는 StoryChapterData 다(여기서 대본을 다시 훑지 않는다).
	var speakers := chapter.get_speakers()
	if speakers.is_empty():
		return

	_detail_body.add_child(HUDKit.rule())
	_detail_body.add_child(HUDKit.section("등장인물", "cast"))

	var cast := HFlowContainer.new()
	cast.add_theme_constant_override("h_separation", 6)
	cast.add_theme_constant_override("v_separation", 6)
	_detail_body.add_child(cast)
	for speaker in speakers:
		cast.add_child(HUDKit.tag_chip(speaker, UITheme.STONE_DARK))


# ===== 조작 =====

func _on_chapter_pressed(id: StringName) -> void:
	_open_id = id
	_refresh_detail()
	_refresh_chapters()


# 재생은 StoryPlayerScreen 이 맡는다. push() 가 돌려준 인스턴스에 챕터를 넘긴다.
func _on_read_pressed() -> void:
	if _open_id == &"":
		return
	var player := ScreenManager.push(STORY_PLAYER_SCENE)
	if player != null:
		player.call("open_chapter", _open_id)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
