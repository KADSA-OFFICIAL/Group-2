extends Control

# 스테이지 리스트의 마름모 타일 하나 (#555).
#
# 아이소메트릭 블록(윗면 + 왼쪽·오른쪽 옆면)을 _draw 로 그리고, 번호 알약·이름·NEW·
# 파티 캐릭터는 자식 노드로 얹는다. 그림 에셋이 없어도 서도록 모양은 전부 코드로 그린다.
#
# 이 타일은 **보여 주기만** 한다. 어떤 스테이지인지·잠겼는지·현재인지는 화면
# (stage_select_screen.gd)이 StageDatabase / StageProgress 에서 읽어 넘겨 준다.
#
# 자물쇠는 그림뿐이다 — 잠긴 타일도 누르면 pressed 가 나간다(해금 규칙은 #541 범위).

signal pressed()

# 윗면 마름모의 반폭·반높이와 옆면 두께(px). 화면이 배치 간격을 이 값에서 잡는다.
const HALF_W: float = 150.0
const HALF_H: float = 86.0
const DEPTH: float = 30.0

# 타일 위아래 여유. 위는 파티 캐릭터 머리, 아래는 이름 글자가 들어갈 자리다.
const HEAD_ROOM: float = 70.0
const FOOT_ROOM: float = 34.0

const TILE_SIZE := Vector2(HALF_W * 2.0, HEAD_ROOM + HALF_H * 2.0 + DEPTH + FOOT_ROOM)

# 마우스를 올리면 블록이 이만큼 떠오른다.
const HOVER_LIFT: float = 6.0

const OUTLINE_WIDTH: float = 3.0

var _base: Color = UITheme.SAGE
var _boss := false
var _locked := false
var _hover := false
var _down := false

# 윗면 위에 얹는 자식(알약·캐릭터)을 담는 판. 떠오를 때 블록과 함께 움직인다.
var _overlay: Control


func _init() -> void:
	custom_minimum_size = TILE_SIZE
	size = TILE_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset = TILE_SIZE * 0.5

	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.size = TILE_SIZE
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

	mouse_entered.connect(func():
		_hover = true
		_sync_lift())
	mouse_exited.connect(func():
		_hover = false
		_down = false
		_sync_lift())


# ===== 설정 (화면이 부른다) =====

# number_text: 알약 글자("1-1"). name_text: 그 아래 이름. 비어 있으면 줄을 만들지 않는다.
# party: 이 타일 위에 세울 캐릭터(CharacterData). 현재 스테이지에만 넘긴다.
# 알약 크기를 재야 하므로 **트리에 붙인 뒤에** 부른다.
func setup(base: Color, number_text: String, name_text: String, boss: bool, locked: bool,
		is_new: bool, party: Array) -> void:
	_base = _vivid(base)
	_boss = boss
	_locked = locked

	if not party.is_empty():
		_overlay.add_child(_make_party(party))

	var plate := VBoxContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.alignment = BoxContainer.ALIGNMENT_CENTER
	plate.add_theme_constant_override("separation", 2)
	_overlay.add_child(plate)

	var pill_row := Control.new()
	pill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(pill_row)
	var pill := _make_pill(number_text)
	pill_row.add_child(pill)

	if not name_text.is_empty():
		plate.add_child(_outlined_label(name_text, 17))

	# 알약은 윗면 앞쪽 절반에 앉힌다(레퍼런스와 같은 자리). 크기가 정해진 뒤에 맞춘다.
	var top_center := _top_center()
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	var pill_size := pill.get_combined_minimum_size()
	pill.size = pill_size
	pill_row.custom_minimum_size = pill_size
	var plate_size := plate.get_combined_minimum_size()
	plate.size = Vector2(TILE_SIZE.x, plate_size.y)
	plate.position = Vector2(0.0, top_center.y + HALF_H * 0.42 - pill_size.y * 0.5)
	pill.position = Vector2((TILE_SIZE.x - pill_size.x) * 0.5, 0.0)

	if is_new:
		var badge := _make_new_badge()
		pill_row.add_child(badge)
		var badge_size := badge.get_combined_minimum_size()
		badge.size = badge_size
		badge.position = Vector2(pill.position.x + pill_size.x - badge_size.x * 0.45,
				-badge_size.y * 0.55)
		badge.rotation_degrees = 8.0


# ===== 그리기 =====

# 팔레트 색(UITheme)은 패널용이라 배경 그림 위에서는 흐릿하게 묻힌다.
# 색상은 그대로 두고 채도·명도만 올려 블록이 그림 앞으로 나오게 한다.
static func _vivid(c: Color) -> Color:
	return Color.from_hsv(c.h, minf(c.s * 1.45, 1.0), minf(c.v * 1.08, 1.0), c.a)


func _top_center() -> Vector2:
	return Vector2(HALF_W, HEAD_ROOM + HALF_H)


func _lift() -> float:
	if _down:
		return 0.0
	return -HOVER_LIFT if _hover else 0.0


func _sync_lift() -> void:
	_overlay.position.y = _lift()
	queue_redraw()


func _draw() -> void:
	var c := _top_center() + Vector2(0.0, _lift())
	var top := c + Vector2(0.0, -HALF_H)
	var right := c + Vector2(HALF_W, 0.0)
	var bottom := c + Vector2(0.0, HALF_H)
	var left := c + Vector2(-HALF_W, 0.0)
	var d := Vector2(0.0, DEPTH)

	# 바닥 그림자. 떠오르면 살짝 옅어진다.
	var shadow_c := _top_center() + Vector2(0.0, DEPTH + 10.0)
	var shadow := PackedVector2Array([
		shadow_c + Vector2(0.0, -HALF_H), shadow_c + Vector2(HALF_W, 0.0),
		shadow_c + Vector2(0.0, HALF_H), shadow_c + Vector2(-HALF_W, 0.0)])
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.16 if _hover else 0.24))

	var face := _base
	if _hover:
		face = face.lightened(0.08)

	var outline := face.darkened(0.72)

	# 옆면 둘. 왼쪽이 오른쪽보다 밝다(빛이 왼쪽 위에서 온다).
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + d, left + d]), face.darkened(0.30))
	draw_colored_polygon(PackedVector2Array([bottom, right, right + d, bottom + d]), face.darkened(0.45))

	# 윗면: 2x2 체크무늬. 마름모를 네 칸으로 나눠 대각 칸끼리 같은 색을 쓴다.
	var mid_tl := (top + left) * 0.5
	var mid_tr := (top + right) * 0.5
	var mid_bl := (bottom + left) * 0.5
	var mid_br := (bottom + right) * 0.5
	var light := face.lightened(0.10)
	var dark := face.darkened(0.06)
	draw_colored_polygon(PackedVector2Array([top, mid_tr, c, mid_tl]), light)
	draw_colored_polygon(PackedVector2Array([mid_tr, right, mid_br, c]), dark)
	draw_colored_polygon(PackedVector2Array([c, mid_br, bottom, mid_bl]), light)
	draw_colored_polygon(PackedVector2Array([mid_tl, c, mid_bl, left]), dark)

	# 윗면 안쪽 테두리의 밝은 선. 블록 모서리가 배경과 떨어져 보이게 한다.
	var rim := 0.93
	draw_polyline(PackedVector2Array([
		c + (top - c) * rim, c + (right - c) * rim, c + (bottom - c) * rim,
		c + (left - c) * rim, c + (top - c) * rim]), Color(1, 1, 1, 0.35), 2.0, true)

	if _boss:
		_draw_boss_lights(c)

	# 윤곽선. 윗면 테두리 + 옆면 바깥선.
	draw_polyline(PackedVector2Array([top, right, bottom, left, top]), outline, OUTLINE_WIDTH, true)
	draw_polyline(PackedVector2Array([left, left + d, bottom + d, right + d, right]), outline, OUTLINE_WIDTH, true)
	draw_line(bottom, bottom + d, outline, OUTLINE_WIDTH, true)

	if _locked:
		_draw_lock(c + Vector2(0.0, -HALF_H * 0.30))


# 보스 타일 둘레의 전구. 윗면 안쪽 마름모를 따라 점을 찍는다.
func _draw_boss_lights(c: Vector2) -> void:
	var inset := 0.80
	var corners := [
		c + Vector2(0.0, -HALF_H * inset), c + Vector2(HALF_W * inset, 0.0),
		c + Vector2(0.0, HALF_H * inset), c + Vector2(-HALF_W * inset, 0.0)]
	var per_edge := 5
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		for k in per_edge:
			var p := a.lerp(b, float(k) / per_edge)
			draw_circle(p, 5.0, UITheme.CREAM)
			draw_circle(p, 3.0, UITheme.AMBER.lightened(0.3))


# 자물쇠. 고리(호) + 몸통(둥근 사각) + 열쇠 구멍. 에셋 없이 그린다.
func _draw_lock(at: Vector2) -> void:
	var body_size := Vector2(46.0, 38.0)
	var body := Rect2(at - Vector2(body_size.x * 0.5, 0.0), body_size)
	var ink := UITheme.OUTLINE.darkened(0.3)
	var gold := UITheme.AMBER.lightened(0.15)

	# 고리: 굵은 윤곽 위에 금색을 한 번 더 긋는다.
	var shackle_c := at + Vector2(0.0, 2.0)
	draw_arc(shackle_c, 15.0, PI, TAU, 24, ink, 11.0, true)
	draw_arc(shackle_c, 15.0, PI, TAU, 24, UITheme.CREAM.darkened(0.08), 6.0, true)

	var outer := StyleBoxFlat.new()
	outer.bg_color = gold
	outer.border_color = ink
	outer.set_border_width_all(3)
	outer.set_corner_radius_all(9)
	draw_style_box(outer, body)

	# 윗부분 하이라이트.
	draw_rect(Rect2(body.position + Vector2(8.0, 6.0), Vector2(body_size.x - 16.0, 5.0)),
			gold.lightened(0.35), true)

	# 열쇠 구멍.
	var hole := at + Vector2(0.0, body_size.y * 0.48)
	draw_circle(hole, 5.0, ink)
	draw_rect(Rect2(hole + Vector2(-2.0, 2.0), Vector2(4.0, 9.0)), ink, true)


# ===== 입력 =====

# 마름모 바깥(타일 사이 빈 칸)을 누르면 옆 타일이 받도록, 블록과 이름판 자리만 맞은 것으로 친다.
func _has_point(point: Vector2) -> bool:
	var c := _top_center()
	var rel := point - c
	# 윗면 + 옆면: 마름모를 옆면 두께만큼 아래로 늘린 모양.
	var dy := rel.y
	if dy > 0.0:
		dy = maxf(0.0, dy - DEPTH)
	if absf(rel.x) / HALF_W + absf(dy) / HALF_H <= 1.0:
		return true
	# 이름판(블록 아래).
	return absf(rel.x) < HALF_W * 0.55 and rel.y > 0.0 and rel.y < HALF_H + DEPTH + FOOT_ROOM


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_sync_lift()
		elif _down:
			_down = false
			_sync_lift()
			pressed.emit()
		accept_event()


# ===== 조각 =====

func _make_pill(text: String) -> PanelContainer:
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = _base.darkened(0.55)
	box.border_color = UITheme.CREAM
	box.set_border_width_all(3)
	box.set_corner_radius_all(999)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 3
	box.content_margin_bottom = 4
	pill.add_theme_stylebox_override("panel", box)

	var label := HUDKit.label(text, 22, UITheme.CREAM, 700)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pill.add_child(label)
	return pill


func _make_new_badge() -> PanelContainer:
	var badge := PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = UITheme.SKY.darkened(0.15)
	box.border_color = UITheme.CREAM
	box.set_border_width_all(2)
	box.set_corner_radius_all(6)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 0
	box.content_margin_bottom = 1
	badge.add_theme_stylebox_override("panel", box)
	badge.add_child(HUDKit.label("NEW", 13, UITheme.CREAM, 700))
	return badge


func _outlined_label(text: String, font_size: int) -> Label:
	var label := HUDKit.label(text, font_size, UITheme.CREAM, 700)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_outline_color", UITheme.INK)
	label.add_theme_constant_override("outline_size", 7)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# 현재 스테이지 위에 선 파티. 전투 스프라이트를 같은 키로 맞춰 두 줄로 세운다.
const PARTY_HEIGHT: float = 104.0

func _make_party(party: Array) -> Control:
	var holder := Control.new()
	holder.name = "Party"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var c := _top_center()
	# 뒷줄 둘, 앞줄 둘. 넷을 넘으면 넷까지만 세운다(파티 정원이 넷이다).
	var spots := [
		Vector2(-34.0, -22.0), Vector2(34.0, -22.0),
		Vector2(-62.0, 4.0), Vector2(62.0, 4.0)]
	if party.size() <= 2:
		spots = [Vector2(-30.0, -6.0), Vector2(30.0, -6.0)]
	elif party.size() == 3:
		spots = [Vector2(0.0, -26.0), Vector2(-52.0, 0.0), Vector2(52.0, 0.0)]

	for i in mini(party.size(), spots.size()):
		var character: CharacterData = party[i]
		var texture := HUDKit.trimmed_texture(character.battle_sprite) if character.battle_sprite != null else null
		if texture == null:
			continue
		var tex_size := texture.get_size()
		var scale_k := PARTY_HEIGHT / maxf(tex_size.y, 1.0)
		var draw_size := tex_size * scale_k

		var feet: Vector2 = c + spots[i] + Vector2(0.0, -HALF_H * 0.18)

		var shadow := _ellipse(Vector2(draw_size.x * 0.42, 7.0), Color(0, 0, 0, 0.22))
		shadow.position = feet - shadow.size * 0.5
		holder.add_child(shadow)

		var rect := TextureRect.new()
		rect.texture = texture
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		rect.size = draw_size
		rect.position = feet - Vector2(draw_size.x * 0.5, draw_size.y)
		holder.add_child(rect)
	return holder


func _ellipse(radii: Vector2, color: Color) -> Control:
	var e := Panel.new()
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(maxf(radii.x, radii.y)))
	e.add_theme_stylebox_override("panel", box)
	e.size = radii * 2.0
	return e
