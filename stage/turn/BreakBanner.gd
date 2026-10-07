extends Control

# 약점 격파 7단계 "BREAK" 타이포그래피 (#559) — 현세대 서브컬처 게임풍.
#
# 예전에는 다른 배너(WAVE · VICTORY · 스킬 이름)와 같은 Label 하나를 재사용했다.
# 기본 폰트 글자에 원소 색을 modulate 로 입혀 0.4초 페이드할 뿐이라, 전투에서 가장 큰
# 순간인데도 이펙트 위에서 글자가 묻혔다.
#
# 시안 기록: 집중선·원형 링·반투명 띠(1차)는 산만했고, 만화 폭발 말풍선(2차)은 게임
# 톤과 맞지 않았다. 지금 것은 요즘 서브컬처 액션 RPG 의 격파 연출 문법을 따른다 —
# 검은 테두리·만화 도형 대신 **빛(가산 혼합)과 날카로운 선**으로 만든다.
#
#   1. 화면 어둡힘 — 아주 짧게 화면을 눌러 이 순간에 시선을 모은다.
#   2. 슬래시      — 흰 칼선이 화면을 가로로 가르고, 그 자리에 원소 색 발광 띠가 벌어진다.
#   3. 후광        — 글자 뒤 원소 색 타원 빛.
#   4. 글자        — Barlow Condensed Black Italic(HUDKit.display_font). 흰 글자 + 원소 색
#                    발광 윤곽. 처음엔 하얗게 타오르다(플래시) 식는다. 왼쪽에서 미끄러져 박힌다.
#   5. 보조 문구   — 위에 작은 자간 넓은 "WEAKNESS" + 양옆 가는 선.
#   6. 유리 조각   — 빛나는 삼각 파편이 칼선을 따라 흩어진다.
#   7. 빛줄기      — 가는 가로 선 몇 개가 빠르게 스쳐 지나간다(속도감).
#
# 시간 규격(PresentationQueue.break_steps 7단계 0.40초)은 그대로 지킨다:
# play() 는 hold 만큼만 기다리고 돌아간다. 퇴장(오른쪽으로 흘러가며 사라짐)은 그 뒤
# 8단계와 겹쳐 재생되고, 끝나면 스스로 지운다. 매번 새 노드를 만들고 지우므로 연달아 불려도 꼬이지 않는다.
#
# 기울기 -8°는 설계서 §4.10.4 타이포그래피 규격(-8° ~ -12°)의 가장 얕은 값이다.
# 폰트 자체가 기울임체라 더 기울이면 글자가 눕는다.

const TEXT := "BREAK"
const SUBTEXT := "WEAKNESS"
const FONT_SIZE := 168
const SUB_SIZE := 30
const TILT_DEG := -8.0

const BAND_HEIGHT := 150.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


# color: 원소 색. hold: 7단계가 막는 시간(배속 적용 후, 초).
# k: 연출 내부 시간 배율(배속 적용 — 2배속이면 0.5). 퇴장 꼬리도 이 배율을 따른다.
func play(color: Color, hold: float, k: float) -> void:
	var canvas := get_viewport().get_visible_rect().size
	# 원소 색을 빛 색으로 쓴다. 팔레트 색은 탁해서 가산 혼합에서 회색빛이 돈다.
	var glow := Color.from_hsv(color.h, minf(color.s * 1.2 + 0.1, 1.0), 1.0)

	var holder := Control.new()
	holder.name = "BreakBurst"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(holder)

	# 1. 화면 어둡힘 (기울이지 않는다)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(dim)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = canvas * 0.5
	root.rotation = deg_to_rad(TILT_DEG)
	holder.add_child(root)

	var span := canvas.length() * 1.2

	# 2. 슬래시: 발광 띠 + 흰 칼선
	var band := _make_band(glow, span)
	root.add_child(band)
	var cut := ColorRect.new()
	cut.color = Color.WHITE
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cut.size = Vector2(span, 4.0)
	cut.position = Vector2(-span * 0.5, -2.0)
	cut.pivot_offset = Vector2(0.0, 2.0)
	cut.material = _additive()
	root.add_child(cut)

	# 3. 후광
	var halo := _make_halo(glow)
	root.add_child(halo)

	# 7. 빛줄기 (글자 뒤를 스친다)
	var streaks := Control.new()
	streaks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(streaks)

	# 4. 글자: 발광 윤곽(가산) -> 본 글자 -> 플래시(가산, 흰색이 식는다)
	var aura := _make_text(TEXT, FONT_SIZE, Color(glow, 0.0), 30, Color(glow, 0.55))
	aura.material = _additive()
	root.add_child(aura)
	var main := _make_text(TEXT, FONT_SIZE, Color.WHITE, 5, glow.darkened(0.55))
	main.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	main.add_theme_constant_override("shadow_offset_x", 5)
	main.add_theme_constant_override("shadow_offset_y", 7)
	root.add_child(main)
	var flash := _make_text(TEXT, FONT_SIZE, Color.WHITE, 12, Color.WHITE)
	flash.material = _additive()
	root.add_child(flash)
	for l in [aura, main, flash]:
		_center(l, Vector2(0.0, 8.0))

	# 5. 보조 문구 "WEAKNESS" + 양옆 선
	var sub := _make_subtitle(glow)
	root.add_child(sub)

	# 6. 유리 조각
	var shards := Control.new()
	shards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shards)

	# ── 등장 ──
	var dt := dim.create_tween()
	dt.tween_property(dim, "color:a", 0.38, 0.06 * k)

	cut.scale = Vector2(0.0, 1.0)
	var ct := cut.create_tween()
	ct.tween_property(cut, "scale:x", 1.0, 0.07 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	ct.tween_property(cut, "modulate:a", 0.0, 0.18 * k)

	band.scale = Vector2(1.0, 0.0)
	var bt := band.create_tween()
	bt.tween_interval(0.04 * k)
	bt.tween_property(band, "scale:y", 1.0, 0.1 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	halo.modulate.a = 0.0
	halo.scale = Vector2(0.6, 0.6)
	var ht := halo.create_tween().set_parallel(true)
	ht.tween_property(halo, "modulate:a", 1.0, 0.1 * k).set_delay(0.05 * k)
	ht.tween_property(halo, "scale", Vector2.ONE, 0.18 * k).set_delay(0.05 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# 글자는 왼쪽에서 가로로 늘어난 채 미끄러져 들어와 박힌다.
	for l in [aura, main, flash]:
		var rest: Vector2 = l.position
		l.position = rest + Vector2(-140.0, 0.0)
		l.scale = Vector2(1.6, 0.85)
		l.modulate.a = 0.0
		var lt: Tween = l.create_tween().set_parallel(true)
		lt.tween_property(l, "modulate:a", 1.0, 0.05 * k).set_delay(0.05 * k)
		lt.tween_property(l, "position", rest, 0.12 * k).set_delay(0.05 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		lt.tween_property(l, "scale", Vector2.ONE, 0.12 * k).set_delay(0.05 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# 플래시는 박힌 뒤 식어 사라진다(흰 글자가 원소 색 윤곽으로 가라앉는다).
	var ft := flash.create_tween()
	ft.tween_interval(0.17 * k)
	ft.tween_property(flash, "modulate:a", 0.0, 0.2 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	sub.modulate.a = 0.0
	var sub_rest := sub.position
	sub.position = sub_rest + Vector2(60.0, 0.0)
	var st := sub.create_tween().set_parallel(true)
	st.tween_property(sub, "modulate:a", 1.0, 0.1 * k).set_delay(0.12 * k)
	st.tween_property(sub, "position", sub_rest, 0.16 * k).set_delay(0.12 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	var impact := 0.15 * k
	await get_tree().create_timer(impact).timeout
	if not is_instance_valid(holder):
		return

	# ── 박히는 순간: 유리 조각 · 빛줄기 · 화면 덜컥 ──
	_spawn_shards(shards, glow, span, k)
	_spawn_streaks(streaks, glow, k)
	_jolt(root, k)

	var rest_time := hold - impact
	if rest_time > 0.0:
		await get_tree().create_timer(rest_time).timeout
	if not is_instance_valid(holder):
		return

	# ── 퇴장: 기다리지 않는다. 다음 단계와 겹쳐 재생되고 스스로 지운다 ──
	var out := 0.18 * k
	var exit := holder.create_tween().set_parallel(true)
	for l in [aura, main, sub]:
		exit.tween_property(l, "position:x", l.position.x + 110.0, out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		exit.tween_property(l, "modulate:a", 0.0, out).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	exit.tween_property(main, "scale", Vector2(1.25, 0.9), out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit.tween_property(band, "scale:y", 0.0, out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit.tween_property(halo, "modulate:a", 0.0, out)
	exit.tween_property(dim, "color:a", 0.0, out)
	exit.chain().tween_callback(holder.queue_free)


# ===== 조각 =====

func _make_text(text: String, font_size: int, fill: Color, outline: int, outline_color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", HUDKit.display_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", fill)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", outline_color)
	return l


# 가운데 기준으로 세운다. 트리에 붙기 전에는 크기를 잴 수 없어(0 이 나온다) 붙인 **뒤에** 부른다.
func _center(l: Control, offset: Vector2 = Vector2.ZERO) -> void:
	l.size = l.get_combined_minimum_size()
	l.position = -l.size * 0.5 + offset
	l.pivot_offset = l.size * 0.5


# 발광 띠: 가운데가 밝고 위아래로 사라지는 원소 색 그라데이션(가산 혼합).
func _make_band(glow: Color, span: float) -> Control:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.42, 0.5, 0.58, 1.0])
	gradient.colors = PackedColorArray([
		Color(glow, 0.0), Color(glow, 0.45), Color(glow.lightened(0.6), 0.85), Color(glow, 0.45), Color(glow, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.5, 0.0)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 4
	texture.height = 128

	var band := TextureRect.new()
	band.texture = texture
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.size = Vector2(span, BAND_HEIGHT)
	band.position = Vector2(-span * 0.5, -BAND_HEIGHT * 0.5)
	band.pivot_offset = Vector2(span * 0.5, BAND_HEIGHT * 0.5)
	band.material = _additive()
	return band


# 글자 뒤 타원 후광(가산 혼합).
func _make_halo(glow: Color) -> Control:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(glow.lightened(0.3), 0.75))
	gradient.set_color(1, Color(glow, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128

	var halo := TextureRect.new()
	halo.texture = texture
	halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.stretch_mode = TextureRect.STRETCH_SCALE
	halo.size = Vector2(760.0, 300.0)
	halo.position = -halo.size * 0.5
	halo.pivot_offset = halo.size * 0.5
	halo.material = _additive()
	return halo


# "WEAKNESS" — 자간을 넓힌 작은 영문 + 양옆 가는 선. 글자 위에 앉는다.
func _make_subtitle(glow: Color) -> Control:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var spaced := FontVariation.new()
	spaced.base_font = HUDKit.display_font()
	spaced.spacing_glyph = 9

	var label := Label.new()
	label.text = SUBTEXT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", spaced)
	label.add_theme_font_size_override("font_size", SUB_SIZE)
	label.add_theme_color_override("font_color", glow.lightened(0.55))
	label.add_theme_constant_override("outline_size", 4)
	label.add_theme_color_override("font_outline_color", glow.darkened(0.6))
	box.add_child(label)
	_center(label)

	var line_w := 120.0
	var gap := label.size.x * 0.5 + 34.0
	for side in [-1.0, 1.0]:
		var line := ColorRect.new()
		line.color = glow.lightened(0.4)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.size = Vector2(line_w, 3.0)
		line.position = Vector2(gap if side > 0.0 else -gap - line_w, -1.5)
		line.material = _additive()
		box.add_child(line)

	box.position = Vector2(-18.0, -FONT_SIZE * 0.5 - 6.0)
	return box


# 유리 조각: 흰 꼭짓점에서 원소 색으로 번지는 삼각 파편(가산 혼합).
# 칼선을 따라 좌우로 흩어지고 조금 위아래로 퍼진다.
func _spawn_shards(holder: Control, glow: Color, span: float, k: float) -> void:
	for i in 16:
		var shard := Polygon2D.new()
		var s := randf_range(10.0, 26.0)
		shard.polygon = PackedVector2Array([
			Vector2(0, -s), Vector2(s * randf_range(0.35, 0.7), s * 0.6), Vector2(-s * randf_range(0.2, 0.5), s * 0.4)])
		shard.vertex_colors = PackedColorArray([Color.WHITE, Color(glow, 0.9), Color(glow.darkened(0.2), 0.7)])
		shard.material = _additive()
		var side := -1.0 if i % 2 == 0 else 1.0
		shard.position = Vector2(randf_range(40.0, 220.0) * side, randf_range(-30.0, 30.0))
		shard.rotation = randf_range(0.0, TAU)
		holder.add_child(shard)

		var target := shard.position + Vector2(randf_range(180.0, span * 0.32) * side, randf_range(-160.0, 160.0))
		var life := randf_range(0.35, 0.6) * k
		var t := shard.create_tween().set_parallel(true)
		t.tween_property(shard, "position", target, life).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(shard, "rotation", shard.rotation + randf_range(-3.0, 3.0), life)
		t.tween_property(shard, "modulate:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(shard.queue_free)


# 빛줄기: 가는 가로 선 몇 개가 글자 뒤를 빠르게 스친다.
func _spawn_streaks(holder: Control, glow: Color, k: float) -> void:
	for i in 5:
		var line := ColorRect.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.color = Color.WHITE if i % 2 == 0 else glow.lightened(0.35)
		var w := randf_range(160.0, 360.0)
		line.size = Vector2(w, randf_range(2.0, 4.0))
		var y := randf_range(-110.0, 110.0)
		line.position = Vector2(-520.0 - w, y)
		line.material = _additive()
		holder.add_child(line)

		var life := randf_range(0.16, 0.26) * k
		var t := line.create_tween().set_parallel(true)
		t.tween_property(line, "position:x", 520.0, life).set_delay(randf_range(0.0, 0.06) * k).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		t.chain().tween_callback(line.queue_free)


# 박히는 순간 판이 짧게 덜컥인다. 만화식 큰 흔들림이 아니라 짧고 작게.
func _jolt(node: Control, k: float) -> void:
	var rest := node.position
	var t := node.create_tween()
	for offset in [Vector2(7, -3), Vector2(-5, 2), Vector2.ZERO]:
		t.tween_property(node, "position", rest + offset, 0.022 * k)
