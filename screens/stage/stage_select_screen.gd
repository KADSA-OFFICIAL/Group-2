extends Control

# 스테이지 선택 화면 (메타 UI) — "스테이지 리스트".
#
# 책임: 저작된 스테이지를 챕터별 맵으로 보여 주고, 고른 스테이지로 출격한다.
#
# 데이터 출처 (단일 출처 원칙 — 여기서 재정의하지 않는다):
#   스테이지 목록/정의 -> StageDatabase / StageData
#   챕터·컨셉          -> StageData.chapter_to_display_name() (#408)
#   클리어 기록        -> StageProgress
#   파티               -> PartySystem
#   주요 재화          -> CurrencySystem.get_primary_currencies()
#   컨셉 배경 그림     -> TurnBattle.CONCEPT_BACKDROP (#505, 전투와 같은 그림)
#   색·조각            -> UITheme / HUDKit
#
# 레이아웃 (#555): 챕터 한 장 = 맵 한 장. 스테이지는 지그재그로 놓인 마름모 타일이고
# (screens/stage/stage_tile.gd), 좌우 화살표로 챕터를 넘긴다. 챕터에 속하지 않는
# 스테이지(테스트)는 마지막 장에 모인다.
#
# 진행 표시는 StageProgress 기록에서 도출한다:
#   - 챕터 순서로 처음 만나는 "안 깬" 스테이지 = 현재 스테이지 -> NEW + 파티가 그 위에 선다.
#   - 그 뒤 스테이지 -> 자물쇠 **그림만** 그린다. 눌러도 출격된다(해금 규칙은 #541 범위).
#
# 타일을 누르면 바로 캐릭터 선택(편성 화면 출격 모드)으로 넘어간다 — 카드 안의
# "출격" 버튼을 찾을 필요가 없다. StageData.description 은 개발 메모라 화면에 띄우지 않는다.
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

# 배경 그림의 출처는 전투 화면이다. 표를 여기 다시 적지 않고 그쪽 상수를 읽는다.
# preload 하지 않는 이유: 화면 하나를 열 때 전투 스크립트 의존성까지 끌어오지 않으려고.
const BATTLE_SCRIPT_PATH := "res://stage/turn/TurnBattle.gd"

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


func _ready() -> void:
	_build()
	_collect_pages()
	_page_index = _initial_page()
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

	add_child(_edge_shade(true))
	add_child(_edge_shade(false))

	_map = Control.new()
	_map.name = "Map"
	_map.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map)

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


# 위(또는 아래) 가장자리를 어둡게 덮는 띠. 배경이 밝아도 상단 글자가 읽히게 한다.
func _edge_shade(top: bool) -> Control:
	var gradient := Gradient.new()
	var dark := Color(UITheme.BG, 0.55)
	var clear := Color(UITheme.BG, 0.0)
	gradient.set_color(0, dark if top else clear)
	gradient.set_color(1, clear if top else dark)

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 4
	texture.height = 64

	var rect := TextureRect.new()
	rect.texture = texture
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
	if top:
		rect.offset_bottom = 150.0
	else:
		rect.offset_top = -110.0
	return rect


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
	var title := _outlined("스테이지 리스트", 30, 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	titles.add_child(title)
	_chapter_label = _outlined("", 16, 6)
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

	box.add_child(_outlined(caption, 15, 6))
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
	var current := _current_stage_id()
	var last_chapter_page := 0
	for i in _pages.size():
		if _pages[i].chapter == StageData.NO_CHAPTER:
			continue
		last_chapter_page = i
		if _pages[i].ids.has(current):
			return i
	return last_chapter_page


# 챕터 순서로 처음 만나는 안 깬 스테이지. 없으면 빈 id.
# 챕터 밖(테스트) 스테이지는 진행 경로가 아니므로 보지 않는다.
func _current_stage_id() -> StringName:
	for chapter in StageDatabase.get_authored_chapters():
		for id in StageDatabase.get_ids_by_chapter(chapter):
			if not StageProgress.is_cleared(id):
				return id
	return &""


func _turn_page(step: int) -> void:
	var target := clampi(_page_index + step, 0, maxi(_pages.size() - 1, 0))
	if target == _page_index:
		return
	_page_index = target
	_show_page(true, step)


func _on_progress_changed() -> void:
	_show_page(false)


func _show_page(animate: bool, step: int = 0) -> void:
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
	_art.texture = _backdrop_for(page.chapter)

	var current := _current_stage_id()
	var locked_ids := _locked_ids(current)
	var party := PartySystem.get_members()
	var setups: Array = []

	for id in page.ids:
		var stage := StageDatabase.get_stage(id)
		var is_current: bool = id == current
		var number := stage.get_stage_number_text() if stage != null else ""

		var tile := StageTile.new()
		tile.name = "Tile_" + String(id)
		tile.set_meta("stage_id", id)
		tile.pressed.connect(_on_stage_launch_pressed.bind(id))
		_tiles.append(tile)
		setups.append([
			_tile_color(stage, page.chapter),
			number if not number.is_empty() else "EX",
			_short_name(stage, number, id),
			_is_boss(stage),
			locked_ids.has(id),
			is_current,
			party if is_current else [],
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


# 챕터의 컨셉 배경. 챕터 밖이면 육지 그림을 쓴다. 그림이 없으면 null(단색 바닥이 보인다).
func _backdrop_for(chapter: int) -> Texture2D:
	var battle := load(BATTLE_SCRIPT_PATH) as GDScript
	if battle == null:
		return null
	var constants := battle.get_script_constant_map()
	var table: Dictionary = constants.get("CONCEPT_BACKDROP", {})
	var dir: String = constants.get("BACKDROP_DIR", "")
	var concept := StageData.chapter_to_concept(chapter)
	if concept < 0:
		concept = StageData.Concept.LAND
	var file_name: String = table.get(concept, "")
	if file_name.is_empty() or dir.is_empty():
		return null
	var path := dir.path_join(file_name + ".png")
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


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


# ===== 조작 =====

# 타일을 누르면 그 스테이지로 출격한다 — **파티를 먼저 고른다**(#243).
#
# 여기서 스테이지를 시작하지 않는 이유: 파티 선택 화면에서 뒤로 돌아올 수 있어야 하고,
# 그때 이미 전투가 시작되어 있으면 안 된다. 실제 시작은 편성 화면이 확정할 때 한다.
#
# 어떤 스테이지를 플레이 중인지는 StageSystem 이 안다. 이 화면은 id 만 넘기고,
# 전장을 그 배치로 다시 만드는 일은 Stage 노드가 한다(화면은 전장을 모른다).
func _on_stage_launch_pressed(id: StringName) -> void:
	_open_party_select(id)


# 저작된 스테이지가 없을 때의 출격. 현재 전장을 그대로 드러낸다.
# 이때도 파티는 고르게 한다 — 고를 스테이지가 없을 뿐 파티는 고를 수 있다.
func _on_launch_pressed() -> void:
	_open_party_select(&"")


# 파티 선택 화면을 출격 모드로 띄운다.
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


# ===== 공용 조각 =====

# 배경 그림 위 글자. 밝은 글자 + 진한 윤곽선(레퍼런스의 제목 글자).
func _outlined(text: String, font_size: int, outline: int) -> Label:
	var label := HUDKit.label(text, font_size, UITheme.CREAM, 700)
	label.add_theme_color_override("font_outline_color", UITheme.INK)
	label.add_theme_constant_override("outline_size", outline)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
