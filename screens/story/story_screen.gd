extends Control

# 스토리 화면 (메타 UI).
#
# 책임: 챕터 목록을 보여주고, 고른 챕터의 대본을 읽게 한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   챕터 목록·대본 -> StoryDatabase / StoryChapterData / StoryLineData
#   읽음 여부      -> StoryProgress (화면이 따로 세지 않는다)
#   색            -> UITheme
#
# 대본을 화면에 적어 두지 않는다. 전부 .tres 에서 읽는다.
#
# 전투 연결은 아직 없다(저작된 StageData 가 없다). 아래 _make_battle() 주석 참고.

const BACK_ICON := "icon_back"
const STORY_ICON := "icon_story"
const BATTLE_ICON := "icon_battle"

# 목록 <-> 본문을 오가는 자리.
var _body: VBoxContainer
var _title_label: Label

# 지금 보고 있는 챕터. 비어 있으면 목록 화면이다.
var _open_id: StringName = &""


func _ready() -> void:
	_build()
	_show_list()
	# 읽음 표시가 바뀌면 목록도 따라간다(본문을 보고 있을 때는 건드리지 않는다).
	StoryProgress.progress_changed.connect(func():
		if String(_open_id).is_empty():
			_show_list()
	)


# ===== 화면 구성 =====

func _build() -> void:
	add_child(UITheme.make_background())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	root.add_child(_build_header())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_body)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# 본문을 보고 있으면 목록으로, 목록이면 화면을 닫는다.
	var back := Button.new()
	back.text = " 뒤로"
	back.icon = _texture(BACK_ICON)
	back.expand_icon = true
	back.custom_minimum_size = Vector2(0, 40)
	back.add_theme_stylebox_override("normal", UITheme.panel_box())
	back.add_theme_stylebox_override("hover", UITheme.panel_box())
	back.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	back.add_theme_color_override("font_color", UITheme.INK)
	back.pressed.connect(_on_back_pressed)
	row.add_child(back)

	var icon := _icon(STORY_ICON, 24)
	if icon != null:
		row.add_child(icon)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", UITheme.INK_ON_DARK)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_title_label)
	return row


# ===== 목록 =====

func _show_list() -> void:
	_open_id = &""
	# 진행도의 출처는 StoryProgress 다. 여기서 세지 않는다.
	var total := StoryDatabase.get_count()
	if total > 0:
		_title_label.text = "스토리  %d / %d" % [StoryProgress.get_read_count(), total]
	else:
		_title_label.text = "스토리"
	_clear(_body)

	var ids := StoryDatabase.get_all_ids()
	if ids.is_empty():
		_body.add_child(_empty_notice())
		return

	for id in ids:
		_body.add_child(_make_chapter_card(id))


func _empty_notice() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	box.add_child(_text("저작된 챕터가 없습니다.", 16, UITheme.INK))
	box.add_child(_text("data/story 에 StoryChapterData(.tres)를 저작하면 여기 나타납니다.", 13, UITheme.INK_DIM))
	return panel


func _make_chapter_card(id: StringName) -> Control:
	var chapter := StoryDatabase.get_chapter(id)

	var is_read := StoryProgress.is_read(id)

	var card := PanelContainer.new()
	# 읽지 않은 챕터를 강조한다. 할 일이 먼저 보이는 편이 낫다.
	card.add_theme_stylebox_override("panel", UITheme.panel_box() if is_read else UITheme.accent_box())
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	if chapter == null:
		row.add_child(_text(String(id), 16, UITheme.INK))
		return card

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	info.add_child(title_row)
	title_row.add_child(_text("Chapter %d" % chapter.number, 13, UITheme.INK_DIM))
	title_row.add_child(_text(chapter.title, 16, UITheme.INK))
	title_row.add_child(_text("읽음" if is_read else "새 이야기", 12, UITheme.INK_DIM if is_read else UITheme.INK))

	if not chapter.summary.is_empty():
		var summary := _text(chapter.summary, 13, UITheme.INK_DIM)
		summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(summary)

	# 분량과 전투 횟수는 챕터가 스스로 센다(화면에서 다시 세지 않는다).
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 10)
	info.add_child(meta)
	meta.add_child(_text("%d줄" % chapter.lines.size(), 12, UITheme.INK_DIM))
	var battles := chapter.get_battle_count()
	if battles > 0:
		meta.add_child(_text("전투 %d회" % battles, 12, UITheme.INK_DIM))

	var button := Button.new()
	button.text = "다시 읽기" if is_read else "읽기"
	button.custom_minimum_size = Vector2(96, 44)
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", UITheme.INK)
	button.add_theme_stylebox_override("normal", UITheme.accent_box())
	button.add_theme_stylebox_override("hover", UITheme.accent_box())
	button.add_theme_stylebox_override("pressed", UITheme.panel_box_deep())
	button.pressed.connect(_show_chapter.bind(id))
	row.add_child(button)
	return card


# ===== 본문 =====

func _show_chapter(id: StringName) -> void:
	var chapter := StoryDatabase.get_chapter(id)
	if chapter == null:
		return

	_open_id = id
	# 연 시점에 읽음으로 기록한다. 끝까지 읽었는지는 알 수 없고(스크롤 추적을 하지 않는다),
	# "열어 봤다"를 기준으로 삼는 편이 단순하고 예측 가능하다.
	StoryProgress.mark_read(id)
	_title_label.text = "Chapter %d  %s" % [chapter.number, chapter.title]
	_clear(_body)

	for line in chapter.lines:
		if line == null:
			continue
		_body.add_child(_make_line(line))


func _make_line(line: StoryLineData) -> Control:
	match line.kind:
		StoryLineData.Kind.DIALOGUE:
			return _make_dialogue(line)
		StoryLineData.Kind.BATTLE:
			return _make_battle(line)
		_:
			return _make_narration(line)


# 지문은 가운데 흐린 글씨로 둔다. 대사와 한눈에 구분되어야 한다.
func _make_narration(line: StoryLineData) -> Control:
	var label := _text(line.text, 13, UITheme.TAN_DEEP)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _make_dialogue(line: StoryLineData) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)

	box.add_child(_text(line.speaker, 13, UITheme.ACCENT))

	var body := _text(line.text, 15, UITheme.INK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)
	return panel


# 전투 지점. 지금은 "여기서 전투가 있다"는 표시만 한다.
# 실제 전투로 보내려면 StageData 저작 + 승리 조건 판정이 필요하다(둘 다 아직 없다).
# stage_id 가 채워지면 이 자리에 출격 버튼을 붙이면 된다.
func _make_battle(line: StoryLineData) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UITheme.panel_box_deep())
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	panel.add_child(row)

	var icon := _icon(BATTLE_ICON, 20)
	if icon != null:
		row.add_child(icon)

	var text := line.text if not line.text.is_empty() else "전투"
	row.add_child(_text(text, 14, UITheme.INK))

	if not String(line.stage_id).is_empty():
		row.add_child(_text("(%s)" % String(line.stage_id), 12, UITheme.INK_DIM))
	return row


# ===== 조작 =====

func _on_back_pressed() -> void:
	if String(_open_id).is_empty():
		ScreenManager.pop()
	else:
		_show_list()


# ===== 공용 조각 =====

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()


func _text(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _icon(icon_name: String, size: int) -> TextureRect:
	var texture := _texture(icon_name)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# 아이콘 **이름**("icon_back")을 받는다. 경로와 확장자 해석은 UITheme 이 한다.
func _texture(icon_name: String) -> Texture2D:
	var path := UITheme.icon_path(icon_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D
