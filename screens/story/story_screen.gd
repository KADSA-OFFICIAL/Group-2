extends Control

# 스토리 화면 (메타 UI).
#
# 구조는 서브컬쳐 수집형 RPG 문법을 따른다: **좌 챕터 타임라인 / 우 대본 리더**.
# 장르 원형의 초대형 아웃라인 넘버와 진행률 바를 챕터 행에 그대로 썼다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   챕터 목록·대본 -> StoryDatabase / StoryChapterData / StoryLineData
#   읽음 여부      -> StoryProgress (화면이 따로 세지 않는다)
#   색·조각        -> UITheme / HUDKit
#
# 대본을 화면에 적어 두지 않는다. 전부 .tres 에서 읽는다.
#
# 이 게임에 없는 것은 만들지 않았다:
#   노드 맵, 스태미나, 추천 전투력, 3성 조건, 선택지 — 전부 시스템이 없다.
#   대화 뷰(비주얼 노벨)는 배경·스프라이트 아트가 없어 리더 형태로 둔다.

var _chapter_list: VBoxContainer
var _reader_body: VBoxContainer
var _reader_title: Label
var _reader_caption: Label
var _open_id: StringName = &""


func _ready() -> void:
	var ids := StoryDatabase.get_all_ids()
	if not ids.is_empty():
		_open_id = ids[0]

	_build()
	_refresh()

	StoryProgress.progress_changed.connect(_refresh_chapters)


# ===== 화면 구성 =====

func _build() -> void:
	add_child(HUDKit.make_backdrop())

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

	body.add_child(_build_chapter_panel())
	body.add_child(_build_reader())


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
	scroll.add_child(_chapter_list)
	return panel


# ── 우: 대본 리더 ──
func _build_reader() -> Control:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)

	var panel := HUDKit.make_panel("", "")
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(panel)

	var body := HUDKit.body_of(panel)

	_reader_title = HUDKit.label("", 20, HUDKit.text_1(), 700)
	body.add_child(_reader_title)
	_reader_caption = HUDKit.caption("")
	body.add_child(_reader_caption)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)

	_reader_body = VBoxContainer.new()
	_reader_body.add_theme_constant_override("separation", 8)
	_reader_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_reader_body)
	return column


# ===== 갱신 =====

func _refresh() -> void:
	_refresh_chapters()
	_refresh_reader()


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

	return card


func _refresh_reader() -> void:
	_clear(_reader_body)
	var chapter := StoryDatabase.get_chapter(_open_id) if _open_id != &"" else null
	if chapter == null:
		_reader_title.text = "스토리"
		_reader_caption.text = ""
		return

	# 연 시점에 읽음으로 기록한다(스크롤을 추적하지 않으므로 "열어 봤다"가 기준이다).
	StoryProgress.mark_read(_open_id)

	_reader_title.text = chapter.title
	_reader_caption.text = "CHAPTER %d  ·  %d LINES" % [chapter.number, chapter.lines.size()]

	if not chapter.summary.is_empty():
		var summary := HUDKit.label(chapter.summary, 12, HUDKit.text_3())
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_reader_body.add_child(summary)

	for line in chapter.lines:
		if line == null:
			continue
		_reader_body.add_child(_make_line(line))


func _make_line(line: StoryLineData) -> Control:
	match line.kind:
		StoryLineData.Kind.DIALOGUE:
			return _make_dialogue(line)
		StoryLineData.Kind.BATTLE:
			return _make_battle(line)
		_:
			return _make_narration(line)


# 지문은 가운데 흐린 글씨. 대사와 한눈에 구분되어야 한다.
func _make_narration(line: StoryLineData) -> Control:
	var label := HUDKit.label(line.text, 12, HUDKit.text_3())
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


# 대사는 화자 태그가 상자 위로 돌출된 형태(장르의 다이얼로그 박스 문법).
func _make_dialogue(line: StoryLineData) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tag_row := HBoxContainer.new()
	box.add_child(tag_row)
	var tag := PanelContainer.new()
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = UITheme.ACCENT
	tag_style.set_corner_radius_all(0)
	tag_style.set_content_margin_all(4)
	tag.add_theme_stylebox_override("panel", tag_style)
	tag.add_child(HUDKit.label(line.speaker, 11, UITheme.INK, 700))
	tag_row.add_child(tag)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HUDKit.inset(10))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(panel)

	var body := HUDKit.label(line.text, 14, HUDKit.text_1())
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(body)
	return box


# 전투 지점. 지금은 "여기서 전투가 있다"는 표시만 한다.
# stage_id 가 채워지면 이 자리에 출격 버튼을 붙이면 된다.
func _make_battle(line: StoryLineData) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HUDKit.card(true))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var icon := HUDKit.make_icon("icon_battle", 20)
	if icon != null:
		row.add_child(icon)

	var text := line.text if not line.text.is_empty() else "전투"
	var label := HUDKit.label(text, 13, HUDKit.text_1(), 600)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(HUDKit.caption("battle"))
	return panel


# ===== 조작 =====

func _on_chapter_pressed(id: StringName) -> void:
	_open_id = id
	_refresh_reader()
	_refresh_chapters()


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
