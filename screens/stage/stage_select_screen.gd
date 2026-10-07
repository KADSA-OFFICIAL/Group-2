extends Control

# 스테이지 선택 화면 (메타 UI) — "스테이지 리스트".
#
# 책임: 저작된 스테이지를 챕터별 맵으로 보여 주고, 고른 스테이지로 출격한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   스테이지 목록/정의 -> StageDatabase / StageData
#   챕터·컨셉          -> StageData.chapter_to_display_name() (#408)
#   클리어 기록·현재 스테이지 -> StageProgress
#   파티               -> PartySystem (그림은 CharacterData.walk_frames)
#   작전 설명          -> StageData.briefing
#   주요 재화          -> CurrencySystem.get_primary_currencies()
#   컨셉 배경 그림     -> HUDKit.load_concept_backdrop() (전투와 같은 그림, #505)
#   색·조각            -> UITheme / HUDKit
#
# 레이아웃 (#555): 챕터 한 장 = 맵 한 장. 스테이지는 지그재그로 놓인 마름모 타일이고
# (screens/stage/stage_tile.gd), 좌우 화살표로 챕터를 넘긴다. 챕터에 속하지 않는
# 스테이지(테스트)는 마지막 장에 모인다.
#
# 진행 표시는 StageProgress 기록에서 도출한다:
#   - 챕터 순서로 처음 만나는 "안 깬" 스테이지 = 현재 스테이지 -> NEW, 처음 열 때 파티가 그 위에 선다.
#   - 그 뒤 스테이지 -> 자물쇠 **그림만** 그린다. 눌러도 출격된다(해금 규칙은 #541 범위).
#
# 타일을 누르면 파티(도트 워크 시트)가 그 타일까지 걸어가고, 오른쪽 팝업에 번호·이름·
# 작전 설명(StageData.briefing)이 뜬다. 팝업의 출격(또는 같은 타일을 한 번 더 누름) ->
# 캐릭터 선택(편성 화면 출격 모드). StageData.description 은 개발 메모라 화면에 띄우지 않는다.
#
# 저작된 스테이지가 하나도 없을 때는 목록이 빈 것을 정상 상태로 다루고,
# 지금까지처럼 바로 출격할 수 있는 길을 남겨 둔다.
#
# 참고: docs/combat-screen-design.md §5, data/stages/README.md

const StageTile := preload("res://screens/stage/stage_tile.gd")

# 컨셉 -> 타일 윗면 색. 컨셉의 출처는 StageData.Concept 이고,
# 그 컨셉이 어떤 색을 쓰는지는 이 화면이 정한다(장비 슬롯 아이콘과 같은 규약).
const CONCEPT_COLOR := {
	StageData.Concept.LAND: UITheme.SAGE,
	StageData.Concept.SEA: UITheme.SKY,
	StageData.Concept.SKY: UITheme.LILAC,
}

# 챕터 밖(테스트) 타일과 보스 타일의 색.
const EXTRA_COLOR := UITheme.STONE_GRAY
const BOSS_COLOR := Color("8E2F3C")

# 편성 화면은 경로만 둔다. 출격은 이 화면 -> 편성(출격 모드) 한 방향이라 순환은 아니지만,
# 화면끼리 preload 하지 않는 이 프로젝트의 규약을 따른다.
const FORMATION_SCREEN_PATH := "res://screens/formation/FormationScreen.tscn"

# 이웃 타일 간격 = 마름모 반폭/반높이 x 이 값. 1.0 이면 모서리가 딱 맞붙는다.
const TILE_GAP: float = 1.12

# 각 장(page): { "chapter": int, "ids": Array[StringName] }. 챕터 밖 장의 chapter 는 NO_CHAPTER.
var _pages: Array = []
var _page_index := 0

var _art: TextureRect
var _map: Control
var _tiles: Array = []
var _chapter_label: Label
var _prev_button: Control
var _next_button: Control
var _dots: HBoxContainer

# 타일마다 배치가 끝난 자리(_map 좌표). 등장 연출 중에도 파티는 이 값을 기준으로 걷는다.
var _tile_rest: Array = []

# ===== 파티 (도트 캐릭터) =====
# 파티는 타일이 아니라 화면이 그린다 — 타일 사이를 걸어 다니기 때문이다.
# 그림은 CharacterData.walk_frames(4방향 워크 시트)다. 이름 규약은 WalkAnimation 이 정한다.

# 파티 키(px). 워크 시트는 walk_sprite_scale 을 곱하면 모두 108px 로 맞춰져 있다(README 참고).
const PARTY_SCALE: float = 0.85
# 시트의 원점은 Player 충돌 캡슐 가운데이고, 발은 그 아래 15px 에 있다(characters/README.md).
const PARTY_FEET: float = 15.0
const WALK_SPEED: float = 300.0          # px/s
const WALK_STAGGER: float = 0.08         # 줄지어 걷도록 한 명씩 늦게 출발한다

var _party_root: Node2D
var _walkers: Array = []                 # { "root": Node2D, "sprite": AnimatedSprite2D, "slot": Vector2 }
var _walk_tweens: Array = []
var _party_index := -1                   # 파티가 서 있는(또는 가는) 타일 칸. -1 이면 이 장에 없다.
var _party_stage_id: StringName = &""

# ===== 팝업 =====
const POPUP_W: float = 340.0
const POPUP_MARGIN: float = 28.0

var _selected_id: StringName = &""
var _popup: PanelContainer
var _popup_number: Label
var _popup_number_box: StyleBoxFlat
var _popup_boss: Control
var _popup_name: Label
var _popup_briefing: Label
var _shift_tween: Tween


func _ready() -> void:
	_build()
	_build_party()
	_collect_pages()
	_page_index = _initial_page()
	_party_stage_id = StageProgress.get_current_stage_id()
	_show_page(false)
	StageProgress.progress_changed.connect(_on_progress_changed)
	resized.connect(_layout_tiles)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_turn_page(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_turn_page(1)
		get_viewport().set_input_as_handled()


# ===== 화면 구성 =====

func _build() -> void:
	# 바닥: 단색 -> 챕터 배경 그림 -> 위아래 어둡게(글자 대비).
	var base := ColorRect.new()
	base.color = HUDKit.ground_bg()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	_art = TextureRect.new()
	_art.name = "Art"
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(_art)

	add_child(HUDKit.edge_shade(true, 150.0))
	add_child(HUDKit.edge_shade(false, 110.0))

	_map = Control.new()
	_map.name = "Map"
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)

	# 파티는 타일 위에 그린다. 발 위치(y)로 정렬해 앞줄이 뒷줄을 가린다.
	_party_root = Node2D.new()
	_party_root.name = "Party"
	_party_root.y_sort_enabled = true
	add_child(_party_root)

	add_child(_make_top_bar())

	_prev_button = _make_arrow(-1, "이전 챕터")
	_prev_button.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_prev_button.position = Vector2(20.0, -60.0)
	add_child(_prev_button)

	_next_button = _make_arrow(1, "다음 챕터")
	_next_button.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_next_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_next_button.position = Vector2(-20.0 - _next_button.custom_minimum_size.x, -60.0)
	add_child(_next_button)

	_dots = HBoxContainer.new()
	_dots.add_theme_constant_override("separation", 8)
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dots.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_dots.offset_bottom = -22.0
	add_child(_dots)

	_popup = _make_popup()
	add_child(_popup)


# 오른쪽 팝업: 고른 스테이지의 번호·이름·작전 설명과 출격 버튼.
# 설명의 출처는 StageData.briefing 이다 — description 은 개발 메모라 쓰지 않는다.
func _make_popup() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "StagePopup"
	panel.visible = false
	panel.add_theme_stylebox_override("panel", HUDKit.panel(22))
	panel.custom_minimum_size = Vector2(POPUP_W, 0)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_set_popup_offset(panel, 0.0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)

	var number_chip := PanelContainer.new()
	number_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_popup_number_box = StyleBoxFlat.new()
	_popup_number_box.set_corner_radius_all(999)
	_popup_number_box.content_margin_left = 14
	_popup_number_box.content_margin_right = 14
	_popup_number_box.content_margin_top = 2
	_popup_number_box.content_margin_bottom = 3
	number_chip.add_theme_stylebox_override("panel", _popup_number_box)
	_popup_number = HUDKit.label("", 18, UITheme.CREAM, 700)
	number_chip.add_child(_popup_number)
	head.add_child(number_chip)

	_popup_boss = HUDKit.tag_chip("BOSS", BOSS_COLOR)
	_popup_boss.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_popup_boss)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)

	var close := Button.new()
	close.tooltip_text = "닫기"
	close.custom_minimum_size = Vector2(36, 36)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var close_icon := HUDKit.load_icon("icon_close")
	if close_icon != null:
		close.icon = close_icon
		close.expand_icon = true
		close.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		close.add_theme_constant_override("icon_max_width", 18)
	else:
		close.text = "X"
	close.add_theme_stylebox_override("normal", HUDKit.ghost())
	close.add_theme_stylebox_override("hover", HUDKit.ghost_hover())
	close.add_theme_stylebox_override("pressed", HUDKit.ghost_pressed())
	close.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	close.pressed.connect(_close_popup)
	head.add_child(close)

	_popup_name = HUDKit.label("", 26, HUDKit.text_1(), 700)
	_popup_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_popup_name)

	var divider := ColorRect.new()
	divider.color = HUDKit.line()
	divider.custom_minimum_size = Vector2(0, HUDKit.DIVIDER)
	box.add_child(divider)

	_popup_briefing = HUDKit.label("", 15, HUDKit.text_2())
	_popup_briefing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_briefing.custom_minimum_size = Vector2(POPUP_W - 44.0, 0)
	_popup_briefing.add_theme_constant_override("line_spacing", 4)
	box.add_child(_popup_briefing)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	box.add_child(gap)

	var launch := HUDKit.make_cta("출격", "sortie")
	launch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	launch.pressed.connect(func():
		if not String(_selected_id).is_empty():
			_open_party_select(_selected_id))
	box.add_child(launch)
	return panel


# 팝업을 오른쪽 가장자리에서 slide 만큼 바깥으로 민 자리에 둔다(등장 연출용).
func _set_popup_offset(panel: Control, slide: float) -> void:
	panel.offset_right = -POPUP_MARGIN + slide
	panel.offset_left = -POPUP_MARGIN - POPUP_W + slide
	panel.offset_top = -170.0
	panel.offset_bottom = 170.0


func _make_top_bar() -> Control:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	margin.add_child(row)

	var back := Button.new()
	back.tooltip_text = "뒤로"
	back.custom_minimum_size = Vector2(52, 52)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var back_icon := HUDKit.load_icon("icon_back")
	if back_icon != null:
		back.icon = back_icon
		back.expand_icon = true
		back.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		back.add_theme_constant_override("icon_max_width", 26)
	else:
		back.text = "←"
	back.add_theme_stylebox_override("normal", UITheme.overlay_pill())
	back.add_theme_stylebox_override("hover", UITheme.overlay_pill(UITheme.SURFACE))
	back.add_theme_stylebox_override("pressed", UITheme.overlay_pill(UITheme.SURFACE_DEEP))
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	back.pressed.connect(func(): ScreenManager.pop())
	row.add_child(back)

	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(titles)
	var title := HUDKit.outlined_label("스테이지 리스트", 30, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(title)
	_chapter_label = HUDKit.outlined_label("", 16, 6)
	_chapter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_chapter_label.add_theme_color_override("font_color", UITheme.AMBER.lightened(0.35))
	titles.add_child(_chapter_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(spacer)

	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 10)
	chips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chips)
	for currency_type in CurrencySystem.get_primary_currencies():
		var type := String(currency_type)
		chips.add_child(HUDKit.currency_chip(type, HUDKit.comma(CurrencySystem.get_balance(type)), 20))
	return margin


# 이전/다음 챕터 화살표. 원판 + 꺾쇠를 그리고 아래에 글자를 단다.
func _make_arrow(direction: int, caption: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.custom_minimum_size = Vector2(84, 0)

	var button := Button.new()
	button.tooltip_text = caption
	button.custom_minimum_size = Vector2(64, 64)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal", "hover", "pressed", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.draw.connect(func():
		var c := button.size * 0.5
		var hot := button.is_hovered()
		button.draw_circle(c, 30.0, Color(UITheme.BG, 0.55 if hot else 0.38))
		var w := 11.0 * direction
		var points := PackedVector2Array([
			c + Vector2(-w * 0.6, -17.0), c + Vector2(w * 0.8, 0.0), c + Vector2(-w * 0.6, 17.0)])
		button.draw_polyline(points, UITheme.INK, 13.0, true)
		button.draw_polyline(points, UITheme.CREAM, 7.0, true))
	button.mouse_entered.connect(button.queue_redraw)
	button.mouse_exited.connect(button.queue_redraw)
	button.pressed.connect(_turn_page.bind(direction))
	box.add_child(button)

	box.add_child(HUDKit.outlined_label(caption, 15, 6))
	return box


# ===== 장(page) =====

func _collect_pages() -> void:
	_pages.clear()
	for chapter in StageDatabase.get_authored_chapters():
		_pages.append({ "chapter": chapter, "ids": StageDatabase.get_ids_by_chapter(chapter) })
	var chapterless := StageDatabase.get_chapterless_ids()
	if not chapterless.is_empty():
		_pages.append({ "chapter": StageData.NO_CHAPTER, "ids": chapterless })


# 처음 열 장 = 현재 스테이지가 있는 챕터. 다 깼으면 마지막 챕터.
func _initial_page() -> int:
	var current := StageProgress.get_current_stage_id()
	var last_chapter_page := 0
	for i in _pages.size():
		if _pages[i].chapter == StageData.NO_CHAPTER:
			continue
		last_chapter_page = i
		if _pages[i].ids.has(current):
			return i
	return last_chapter_page


func _turn_page(step: int) -> void:
	var target := clampi(_page_index + step, 0, maxi(_pages.size() - 1, 0))
	if target == _page_index:
		return
	_page_index = target
	_show_page(true, step)


func _on_progress_changed() -> void:
	_show_page(false)


func _show_page(animate: bool, step: int = 0) -> void:
	# 장이 바뀌면 팝업이 가리키던 타일이 사라진다. 고른 것을 풀고 지도를 제자리로 돌린다.
	_close_popup(false)
	# 파티 자리(칸 번호)도 이전 장 기준이다. 새 장의 배치가 끝난 뒤 다시 정한다.
	_stop_walking()
	_party_index = -1

	for tile in _tiles:
		tile.queue_free()
	_tiles.clear()
	for child in _map.get_children():
		child.queue_free()

	_refresh_chrome()

	if _pages.is_empty():
		_art.texture = null
		_map.add_child(_empty_notice())
		return

	var page: Dictionary = _pages[_page_index]
	_art.texture = HUDKit.load_concept_backdrop(page.chapter)

	var current := StageProgress.get_current_stage_id()
	var locked_ids := _locked_ids(current)
	var setups: Array = []

	for id in page.ids:
		var stage := StageDatabase.get_stage(id)
		var is_current: bool = id == current
		var number := stage.get_stage_number_text() if stage != null else ""

		var tile := StageTile.new()
		tile.name = "Tile_" + String(id)
		tile.set_meta("stage_id", id)
		tile.pressed.connect(_on_tile_pressed.bind(id))
		_tiles.append(tile)
		setups.append([
			_tile_color(stage, page.chapter),
			number if not number.is_empty() else "EX",
			_short_name(stage, number, id),
			_is_boss(stage),
			locked_ids.has(id),
			is_current,
		])

	# 아이소메트릭 겹침: 아래 줄(짝수 칸)이 위 줄 앞에 그려지도록 위 줄을 먼저 붙인다.
	for i in range(1, _tiles.size(), 2):
		_map.add_child(_tiles[i])
	for i in range(0, _tiles.size(), 2):
		_map.add_child(_tiles[i])
	# 알약 크기를 재야 해서 트리에 붙인 뒤에 채운다.
	for i in _tiles.size():
		_tiles[i].callv("setup", setups[i])

	_layout_tiles()
	_play_intro(animate, step)
	_place_party_for_page(page, current)


# 자물쇠 그림을 그릴 id 들: 챕터 순서로 현재 스테이지보다 뒤에 있고 아직 안 깬 것.
# 챕터 밖(테스트)은 진행 경로가 아니므로 잠그지 않는다. **그림뿐이다** — 눌러도 출격된다.
func _locked_ids(current: StringName) -> Dictionary:
	var out := {}
	if String(current).is_empty():
		return out
	var passed := false
	for chapter in StageDatabase.get_authored_chapters():
		for id in StageDatabase.get_ids_by_chapter(chapter):
			if passed and not StageProgress.is_cleared(id):
				out[id] = true
			if id == current:
				passed = true
	return out


# 화살표·점·챕터 이름을 지금 장에 맞춘다.
func _refresh_chrome() -> void:
	_prev_button.visible = _page_index > 0
	_next_button.visible = _page_index < _pages.size() - 1

	if _pages.is_empty():
		_chapter_label.text = ""
	else:
		_chapter_label.text = StageData.chapter_to_display_name(_pages[_page_index].chapter)

	for child in _dots.get_children():
		child.queue_free()
	if _pages.size() > 1:
		for i in _pages.size():
			var dot := Panel.new()
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var on := i == _page_index
			dot.custom_minimum_size = Vector2(26 if on else 10, 10)
			var box := StyleBoxFlat.new()
			box.bg_color = UITheme.CREAM if on else Color(UITheme.CREAM, 0.45)
			box.border_color = Color(UITheme.INK, 0.6)
			box.set_border_width_all(1)
			box.set_corner_radius_all(5)
			dot.add_theme_stylebox_override("panel", box)
			_dots.add_child(dot)


# 타일을 지그재그로 화면 가운데에 놓는다. 짝수 칸이 아래 줄, 홀수 칸이 위 줄이다.
func _layout_tiles() -> void:
	if _tiles.is_empty() or _map == null:
		return
	var step_x := StageTile.HALF_W * TILE_GAP
	var half_dy := StageTile.HALF_H * TILE_GAP * 0.5
	var count := _tiles.size()
	_tile_rest.resize(count)
	var span := (count - 1) * step_x
	# 윗바(약 90px)를 뺀 영역의 가운데. 블록 아래 옆면·이름판 몫만큼 살짝 올린다.
	var center := Vector2(size.x * 0.5, 90.0 + (size.y - 90.0) * 0.5 - 10.0)
	var anchor := Vector2(StageTile.HALF_W, StageTile.HEAD_ROOM + StageTile.HALF_H)
	for i in count:
		var dy := half_dy if i % 2 == 0 else -half_dy
		if count == 1:
			dy = 0.0
		var top_center := Vector2(center.x - span * 0.5 + i * step_x, center.y + dy)
		_tiles[i].position = top_center - anchor
		_tile_rest[i] = _tiles[i].position

	# 서 있는 파티는 새 자리로 따라간다(걷는 중이면 그 걸음이 끝날 자리로 간다).
	if not _is_walking() and _party_index >= 0:
		_snap_party(_party_index)


func _play_intro(animate: bool, step: int) -> void:
	for i in _tiles.size():
		var tile: Control = _tiles[i]
		tile.modulate.a = 0.0
		tile.scale = Vector2(0.9, 0.9)
		var tween := tile.create_tween().set_parallel(true)
		var delay := 0.05 * i if animate else 0.04 * i
		tween.tween_property(tile, "modulate:a", 1.0, 0.22).set_delay(delay)
		tween.tween_property(tile, "scale", Vector2.ONE, 0.32).set_delay(delay) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if animate and step != 0:
			var rest := tile.position
			tile.position.x += 60.0 * step
			tween.tween_property(tile, "position", rest, 0.3).set_delay(delay) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


# ===== 타일 데이터 =====

func _tile_color(stage: StageData, chapter: int) -> Color:
	if _is_boss(stage):
		return BOSS_COLOR
	if chapter == StageData.NO_CHAPTER:
		return EXTRA_COLOR
	return CONCEPT_COLOR.get(StageData.chapter_to_concept(chapter), UITheme.ACCENT)


# 보스 웨이브가 하나라도 있으면 보스 스테이지다.
func _is_boss(stage: StageData) -> bool:
	if stage == null:
		return false
	for wave in stage.waves:
		if wave != null and wave.is_boss:
			return true
	return false


# 알약에 번호가 이미 있으므로 display_name 앞의 번호("1-1 ")는 떼고 보여 준다.
func _short_name(stage: StageData, number: String, id: StringName) -> String:
	if stage == null:
		return String(id)
	var full := stage.display_name
	if not number.is_empty() and full.begins_with(number):
		return full.substr(number.length()).strip_edges()
	return full


# 저작된 스테이지가 없을 때. 오류가 아니라 정상 상태다.
# 지금까지 출격 버튼이 하던 일(화면 닫고 게임플레이 진입)을 여기서 이어 준다.
func _empty_notice() -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := HUDKit.empty_notice(
		"저작된 스테이지가 없습니다.",
		"data/stages 에 StageData(.tres)를 저작하면 여기 나타납니다.")
	panel.custom_minimum_size = Vector2(520, 0)
	center.add_child(panel)

	var box := panel.get_meta("body") as VBoxContainer

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(actions)

	var button := HUDKit.make_cta("현재 스테이지로 출격", "launch")
	button.pressed.connect(_on_launch_pressed)
	actions.add_child(button)
	return center


# ===== 파티 (도트 캐릭터) =====

# 파티 멤버마다 워크 시트를 하나씩 세운다. 시트가 없는 캐릭터는 건너뛴다.
func _build_party() -> void:
	var members := PartySystem.get_members()
	var slots := _party_slots(members.size())
	for i in mini(members.size(), slots.size()):
		var character: CharacterData = members[i]
		if character == null or character.walk_frames == null:
			continue

		var root := Node2D.new()
		root.name = "Walker_" + String(character.character_id)
		_party_root.add_child(root)

		var shadow := Polygon2D.new()
		var ring := PackedVector2Array()
		for k in 20:
			var a := TAU * k / 20.0
			ring.append(Vector2(cos(a) * 24.0, sin(a) * 7.0))
		shadow.polygon = ring
		shadow.color = Color(0, 0, 0, 0.25)
		root.add_child(shadow)

		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = character.walk_frames
		sprite.scale = character.walk_sprite_scale * PARTY_SCALE
		sprite.offset = character.walk_sprite_offset
		sprite.position = Vector2(0.0, -PARTY_FEET * PARTY_SCALE)
		# 배율 1 시트(#419 도트 규격)는 Nearest 로 도트를 살린다. 축소 시트는 선형 필터 그대로다.
		# 규칙의 출처는 EnemyBase / Player 와 같다.
		sprite.texture_filter = (CanvasItem.TEXTURE_FILTER_NEAREST
			if character.walk_sprite_scale == Vector2.ONE
			else CanvasItem.TEXTURE_FILTER_PARENT_NODE)
		sprite.animation = WalkAnimation.ANIMATIONS[WalkAnimation.DOWN]
		sprite.frame = 0
		root.add_child(sprite)

		_walkers.append({ "root": root, "sprite": sprite, "slot": slots[i] })
	_party_root.visible = false


# 타일 윗면 가운데를 기준으로 한 멤버별 발 자리. 앞에 오는 칸이 뒷줄이다.
func _party_slots(count: int) -> Array:
	match count:
		1:
			return [Vector2(0.0, -14.0)]
		2:
			return [Vector2(-30.0, -14.0), Vector2(30.0, -14.0)]
		3:
			return [Vector2(0.0, -40.0), Vector2(-50.0, -12.0), Vector2(50.0, -12.0)]
		_:
			return [Vector2(-32.0, -40.0), Vector2(32.0, -40.0), Vector2(-62.0, -12.0), Vector2(62.0, -12.0)]


# 장을 열 때 파티를 어디 세울지. 파티가 서 있던 스테이지가 이 장에 있으면 거기,
# 없으면 이 장의 현재 스테이지, 그것도 없으면 이 장에서는 숨긴다(타일을 누르면 걸어 들어온다).
func _place_party_for_page(page: Dictionary, current: StringName) -> void:
	_stop_walking()
	var index: int = page.ids.find(_party_stage_id)
	if index < 0:
		index = page.ids.find(current)
		if index >= 0:
			_party_stage_id = current
	_party_index = index
	if index < 0 or _walkers.is_empty():
		_party_root.visible = false
		return
	_snap_party(index)
	_party_root.visible = true
	_party_root.modulate.a = 0.0
	create_tween().tween_property(_party_root, "modulate:a", 1.0, 0.25).set_delay(0.12)


func _tile_anchor(index: int) -> Vector2:
	return _tile_rest[index] + StageTile.top_anchor()


func _snap_party(index: int) -> void:
	var anchor := _tile_anchor(index)
	for w in _walkers:
		w.root.position = anchor + w.slot
		_stand(w.sprite)
	_mark_occupied(index)


# 파티가 서 있는 타일 표시. -1 이면 어느 타일에도 없다(걷는 중 포함).
func _mark_occupied(index: int) -> void:
	for i in _tiles.size():
		_tiles[i].set_occupied(i == index)


func _stand(sprite: AnimatedSprite2D) -> void:
	sprite.stop()
	sprite.animation = WalkAnimation.ANIMATIONS[WalkAnimation.DOWN]
	sprite.frame = 0


func _is_walking() -> bool:
	for t in _walk_tweens:
		if t != null and t.is_valid() and t.is_running():
			return true
	return false


func _stop_walking() -> void:
	for t in _walk_tweens:
		if t != null and t.is_valid():
			t.kill()
	_walk_tweens.clear()


# 파티를 index 칸까지 걸린다. 사이에 있는 타일을 차례로 밟고 간다(지그재그 길을 따라).
# 이 장에 파티가 없으면 화면 왼쪽 밖에서 걸어 들어온다.
func _walk_party_to(index: int) -> void:
	if _walkers.is_empty() or index < 0 or index >= _tiles.size():
		return

	var path: Array = []
	if _party_index < 0:
		var entry := _tile_anchor(index)
		var start := Vector2(-80.0 - _party_root.position.x, entry.y)
		for w in _walkers:
			w.root.position = start + w.slot
		_party_root.visible = true
		_party_root.modulate.a = 1.0
		path.append(entry)
	else:
		var step := 1 if index > _party_index else -1
		var i := _party_index
		while i != index:
			i += step
			path.append(_tile_anchor(i))
	if path.is_empty():
		return

	_party_index = index
	_party_stage_id = _tiles[index].get_meta("stage_id")
	_stop_walking()
	_mark_occupied(-1)

	for k in _walkers.size():
		var w: Dictionary = _walkers[k]
		var root: Node2D = w.root
		var sprite: AnimatedSprite2D = w.sprite
		var tween := create_tween()
		tween.tween_interval(WALK_STAGGER * k)
		var from := root.position
		for point in path:
			var to: Vector2 = point + w.slot
			var dir := to - from
			tween.tween_callback(sprite.play.bind(WalkAnimation.animation_for(dir)))
			tween.tween_property(root, "position", to, dir.length() / WALK_SPEED)
			from = to
		tween.tween_callback(_stand.bind(sprite))
		# 마지막으로 도착하는 멤버가 타일을 "차지했다"고 표시한다.
		if k == _walkers.size() - 1:
			tween.tween_callback(_mark_occupied.bind(index))
		_walk_tweens.append(tween)


# ===== 조작 =====

# 타일을 누르면: 파티가 그 타일로 걸어가고, 오른쪽 팝업에 이름·설명이 뜬다.
# 이미 고른 타일을 한 번 더 누르면 팝업의 출격 버튼과 같다.
func _on_tile_pressed(id: StringName) -> void:
	if id == _selected_id and _popup.visible:
		_open_party_select(id)
		return

	_selected_id = id
	for tile in _tiles:
		tile.set_selected(tile.get_meta("stage_id") == id)
	_open_popup(id)
	_walk_party_to(_tiles.find(_tile_for(id)))


func _tile_for(id: StringName) -> Control:
	for tile in _tiles:
		if tile.get_meta("stage_id") == id:
			return tile
	return null


func _open_popup(id: StringName) -> void:
	var stage := StageDatabase.get_stage(id)
	var number := stage.get_stage_number_text() if stage != null else ""
	var chapter := stage.chapter if stage != null else StageData.NO_CHAPTER

	_popup_number.text = number if not number.is_empty() else "EX"
	_popup_number_box.bg_color = StageTile._vivid(_tile_color(stage, chapter)).darkened(0.35)
	_popup_boss.visible = _is_boss(stage)
	_popup_name.text = _short_name(stage, number, id)
	_popup_briefing.text = stage.briefing if stage != null else ""
	_popup_briefing.visible = not _popup_briefing.text.is_empty()

	var was_open := _popup.visible
	_popup.visible = true
	# 다음 챕터 화살표 자리를 팝업이 덮는다. 열려 있는 동안은 숨긴다(방향키로는 넘길 수 있다).
	_next_button.visible = false

	var tween := _popup.create_tween().set_parallel(true)
	if was_open:
		# 다른 타일로 바꿔 고른 것. 살짝 튕겨서 내용이 바뀐 것을 알린다.
		_popup.pivot_offset = _popup.size * 0.5
		_popup.scale = Vector2(0.97, 0.97)
		tween.tween_property(_popup, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_popup.modulate.a = 0.0
		_set_popup_offset(_popup, 48.0)
		tween.tween_property(_popup, "modulate:a", 1.0, 0.2)
		tween.tween_property(_popup, "offset_left", -POPUP_MARGIN - POPUP_W, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(_popup, "offset_right", -POPUP_MARGIN, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_shift_map(true)


func _close_popup(animate: bool = true) -> void:
	_selected_id = &""
	for tile in _tiles:
		if is_instance_valid(tile):
			tile.set_selected(false)
	if _popup == null or not _popup.visible:
		return
	_popup.visible = false
	_next_button.visible = _page_index < _pages.size() - 1
	_shift_map(false, animate)


# 팝업이 열리면 지도(타일 + 파티)를 왼쪽으로 밀어 팝업에 가리지 않게 한다.
# 타일 배치는 그대로 두고 두 층을 같은 거리만큼 옮긴다 — 걷는 중인 파티의 길도 그대로 맞는다.
func _shift_map(open: bool, animate: bool = true) -> void:
	var dx := -(POPUP_W + POPUP_MARGIN) * 0.5 if open else 0.0
	if _shift_tween != null and _shift_tween.is_valid():
		_shift_tween.kill()
	if not animate:
		_map.position.x = dx
		_party_root.position.x = dx
		return
	_shift_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_shift_tween.tween_property(_map, "position:x", dx, 0.3)
	_shift_tween.tween_property(_party_root, "position:x", dx, 0.3)


# 저작된 스테이지가 없을 때의 출격. 현재 전장을 그대로 드러낸다.
# 이때도 파티는 고르게 한다 — 고를 스테이지가 없을 뿐 파티는 고를 수 있다.
func _on_launch_pressed() -> void:
	_open_party_select(&"")


# 파티 선택 화면을 출격 모드로 띄운다. 팝업의 출격(또는 고른 타일을 한 번 더 누름)이
# 여기로 온다 — 출격 전에 **파티를 먼저 고른다**(#243).
#
# 여기서 스테이지를 시작하지 않는 이유: 파티 선택 화면에서 뒤로 돌아올 수 있어야 하고,
# 그때 이미 전투가 시작되어 있으면 안 된다. 실제 시작은 편성 화면이 확정할 때 한다.
#
# 어떤 스테이지를 플레이 중인지는 StageSystem 이 안다. 이 화면은 id 만 넘기고,
# 전장을 그 배치로 다시 만드는 일은 Stage 노드가 한다(화면은 전장을 모른다).
#
# 새 화면을 만들지 않고 편성 화면(FormationScreen)을 재사용한다 — 로스터·파티·시너지를
# 읽는 UI 를 두 벌 두면 한쪽만 고쳐지는 일이 생긴다(CLAUDE.md 기초 시스템).
func _open_party_select(stage_id: StringName) -> void:
	var scene := load(FORMATION_SCREEN_PATH) as PackedScene
	if scene == null:
		push_warning("StageSelectScreen: 편성 화면을 불러올 수 없습니다: " + FORMATION_SCREEN_PATH)
		# 파티를 고를 수 없더라도 출격 자체는 막지 않는다(기존 편성으로 나간다).
		if not String(stage_id).is_empty():
			StageSystem.request_stage(stage_id)
		ScreenManager.close_all()
		return

	var screen := ScreenManager.push(scene)
	if screen == null:
		return
	screen.set_sortie(stage_id)
