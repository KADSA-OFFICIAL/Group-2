extends Control

# 약점 격파 7단계 "BREAK!" 타이포그래피 (#559).
#
# 예전에는 다른 배너(WAVE · VICTORY · 스킬 이름)와 같은 Label 하나를 재사용했다.
# 기본 폰트 글자에 원소 색을 modulate 로 입혀 0.4초 페이드할 뿐이라, 전투에서 가장 큰
# 순간인데도 이펙트 위에서 글자가 묻혔다. 격파만 전용 연출을 둔다.
#
# 구성 (뒤에서 앞으로):
#   1. 집중선     — 화면 가운데로 모이는 방사형 선. 박히는 순간 번쩍인다.
#   2. 사선 띠    — 원소 색 띠가 글자 뒤를 왼쪽에서 오른쪽으로 긋는다.
#   3. 충격파 링  — 박히는 순간 퍼져 나간다.
#   4. 잔상       — 원소 색 글자 두 장이 좌우로 밀려나며 사라진다.
#   5. 글자       — Bangers(HUDKit.display_font, 파일이 없으면 기본 폰트). 흰 글자 + 진한 윤곽 + 원소 색 바깥 윤곽(이중 테두리) + 그림자.
#   6. 불꽃 조각  — 박히는 순간 사방으로 튄다.
#
# 시간 규격(PresentationQueue.break_steps 7단계 0.40초)은 그대로 지킨다:
# play() 는 hold 만큼만 기다리고 돌아간다. 퇴장(가로로 늘어나며 사라짐)은 그 뒤 8단계와
# 겹쳐 재생되고, 끝나면 스스로 지운다. 매번 새 노드를 만들고 지우므로 연달아 불려도 꼬이지 않는다.
#
# 기울기 -9°는 설계서 §4.10.4 타이포그래피 규격(-8° ~ -12°)이다.

const TEXT := "BREAK!"
const FONT_SIZE := 148
const TILT_DEG := -9.0

# 1280x720 기준 자리. 예전 배너와 같은 화면 가운데다.
const BAND_HEIGHT := 128.0

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# color: 원소 색. hold: 7단계가 막는 시간(배속 적용 후, 초).
# k: 연출 내부 시간 배율(배속 적용 — 2배속이면 0.5). 퇴장 꼬리도 이 배율을 따른다.
func play(color: Color, hold: float, k: float) -> void:
	var canvas := get_viewport().get_visible_rect().size
	var root := Control.new()
	root.name = "BreakBurst"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.position = canvas * 0.5
	add_child(root)

	# 기울인 무대. 띠·글자·잔상이 같은 기울기를 쓴다. 집중선·링은 기울이지 않는다.
	var tilted := Control.new()
	tilted.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tilted.rotation = deg_to_rad(TILT_DEG)

	var lines := _make_speed_lines(color, canvas)
	root.add_child(lines)
	root.add_child(tilted)

	var band := _make_band(color, canvas.x * 1.5)
	tilted.add_child(band)

	var ring := _make_ring(color)
	root.add_child(ring)

	var ghosts: Array[Label] = []
	for i in 2:
		var ghost := _make_text(Color(color, 0.55), 0, Color.TRANSPARENT)
		ghost.modulate.a = 0.0
		tilted.add_child(ghost)
		_center(ghost)
		ghosts.append(ghost)

	# 이중 테두리: 뒤에 원소 색 굵은 윤곽 글자, 앞에 흰 글자 + 진한 윤곽.
	var back := _make_text(color.darkened(0.15), 40, color.darkened(0.15))
	back.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
	back.add_theme_constant_override("shadow_offset_x", 8)
	back.add_theme_constant_override("shadow_offset_y", 10)
	back.add_theme_constant_override("shadow_outline_size", 40)
	tilted.add_child(back)
	_center(back)
	var front := _make_text(Color.WHITE, 18, UITheme.INK)
	tilted.add_child(front)
	_center(front)

	var sparks := Control.new()
	sparks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sparks)

	# ── 등장: 크게 -> 제자리로 쾅 ──
	var slam := 0.10 * k
	var settle := 0.08 * k
	for label in [back, front]:
		label.scale = Vector2(2.6, 2.6)
		label.modulate.a = 0.0
		var t: Tween = label.create_tween().set_parallel(true)
		t.tween_property(label, "modulate:a", 1.0, slam * 0.5)
		t.tween_property(label, "scale", Vector2(0.9, 0.9), slam).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.chain().tween_property(label, "scale", Vector2.ONE, settle).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 띠는 글자보다 조금 먼저 왼쪽에서 긋는다.
	band.scale = Vector2(0.0, 1.0)
	var bt := band.create_tween()
	bt.tween_property(band, "scale:x", 1.0, 0.12 * k).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(slam).timeout
	if not is_instance_valid(root):
		return

	# ── 박히는 순간: 링 · 집중선 · 잔상 · 불꽃 · 떨림 ──
	_burst_ring(ring, k)
	_flash_lines(lines, k)
	_spread_ghosts(ghosts, k)
	_spawn_sparks(sparks, color, k)
	_jolt(tilted, k)

	var rest := hold - slam
	if rest > 0.0:
		await get_tree().create_timer(rest).timeout
	if not is_instance_valid(root):
		return

	# ── 퇴장: 기다리지 않는다. 다음 단계와 겹쳐 재생되고 스스로 지운다 ──
	var out := 0.20 * k
	var exit := root.create_tween().set_parallel(true)
	for label in [back, front]:
		exit.tween_property(label, "scale", Vector2(1.45, 0.65), out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		exit.tween_property(label, "modulate:a", 0.0, out)
	exit.tween_property(band, "scale:y", 0.0, out).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	exit.tween_property(lines, "modulate:a", 0.0, out)
	exit.chain().tween_callback(root.queue_free)


# ===== 조각 =====

# 글자 하나. 가운데를 기준으로 서도록 크기를 재서 자리를 잡는다.
func _make_text(fill: Color, outline: int, outline_color: Color) -> Label:
	var label := Label.new()
	label.text = TEXT
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", HUDKit.display_font())
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", fill)
	if outline > 0:
		label.add_theme_constant_override("outline_size", outline)
		label.add_theme_color_override("font_outline_color", outline_color)
	return label


# 글자를 가운데 기준으로 세운다. 트리에 붙기 전에는 크기를 잴 수 없어(0 이 나온다)
# 붙인 **뒤에** 부른다.
func _center(label: Label) -> void:
	label.size = label.get_minimum_size()
	label.position = -label.size * 0.5
	label.pivot_offset = label.size * 0.5


# 글자 뒤 사선 띠. 원소 색 면 + 위아래 흰 선. 왼쪽 끝을 기준으로 늘어난다.
func _make_band(color: Color, width: float) -> Control:
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = Vector2(-width * 0.5, -BAND_HEIGHT * 0.5)
	band.size = Vector2(width, BAND_HEIGHT)
	band.pivot_offset = Vector2(0.0, BAND_HEIGHT * 0.5)
	band.draw.connect(func():
		var h := BAND_HEIGHT
		var skew := 40.0
		var body := PackedVector2Array([
			Vector2(skew, 0.0), Vector2(width, 0.0), Vector2(width - skew, h), Vector2(0.0, h)])
		band.draw_colored_polygon(body, Color(color.darkened(0.25), 0.82))
		# 가운데 밝은 줄무늬로 속도감.
		var inner := PackedVector2Array([
			Vector2(skew * 0.7, h * 0.30), Vector2(width, h * 0.30),
			Vector2(width - skew * 0.4, h * 0.42), Vector2(skew * 0.5, h * 0.42)])
		band.draw_colored_polygon(inner, Color(1, 1, 1, 0.18))
		band.draw_line(Vector2(skew, 0.0), Vector2(width, 0.0), Color(1, 1, 1, 0.9), 4.0, true)
		band.draw_line(Vector2(0.0, h), Vector2(width - skew, h), Color(1, 1, 1, 0.9), 4.0, true))
	return band


# 방사형 집중선. 안쪽은 비워 두고(글자 자리) 바깥으로 갈수록 굵어지는 가는 삼각형들.
func _make_speed_lines(color: Color, canvas: Vector2) -> Control:
	var lines := Control.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.modulate.a = 0.0
	var reach := canvas.length() * 0.6
	var seeds: Array = []
	for i in 46:
		seeds.append([TAU * i / 46.0 + randf_range(-0.05, 0.05), randf_range(0.0, 1.0)])
	lines.draw.connect(func():
		for s in seeds:
			var a: float = s[0]
			var inner := 230.0 + 140.0 * float(s[1])
			var dir := Vector2(cos(a), sin(a))
			var side := Vector2(-dir.y, dir.x) * (5.0 + 7.0 * float(s[1]))
			var tip := dir * inner
			var far := dir * reach
			lines.draw_colored_polygon(PackedVector2Array([tip, far + side, far - side]),
				Color(1, 1, 1, 0.75) if int(s[1] * 10.0) % 3 != 0 else Color(color.lightened(0.4), 0.8)))
	return lines


func _flash_lines(lines: Control, k: float) -> void:
	lines.scale = Vector2(1.15, 1.15)
	var t := lines.create_tween().set_parallel(true)
	t.tween_property(lines, "modulate:a", 1.0, 0.03 * k)
	t.tween_property(lines, "scale", Vector2.ONE, 0.25 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(lines, "modulate:a", 0.35, 0.22 * k)


# 충격파 링. 반지름·두께는 그릴 때 메타 값에서 읽는다(트윈이 메타를 바꾼다).
func _make_ring(color: Color) -> Control:
	var ring := Control.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_meta("r", 40.0)
	ring.set_meta("w", 26.0)
	ring.modulate.a = 0.0
	ring.draw.connect(func():
		var r: float = ring.get_meta("r")
		var w: float = ring.get_meta("w")
		ring.draw_arc(Vector2.ZERO, r, 0.0, TAU, 72, Color(color.lightened(0.3), 0.9), w, true)
		ring.draw_arc(Vector2.ZERO, r - w * 0.35, 0.0, TAU, 72, Color(1, 1, 1, 0.9), maxf(w * 0.25, 1.5), true))
	return ring


func _burst_ring(ring: Control, k: float) -> void:
	ring.modulate.a = 1.0
	var t := ring.create_tween().set_parallel(true)
	t.tween_method(func(v: float):
		ring.set_meta("r", lerpf(40.0, 470.0, v))
		ring.set_meta("w", lerpf(26.0, 2.0, v))
		ring.queue_redraw(), 0.0, 1.0, 0.42 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.42 * k).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


# 잔상 두 장이 좌우로 밀려나며 사라진다(색수차 느낌).
func _spread_ghosts(ghosts: Array[Label], k: float) -> void:
	for i in ghosts.size():
		var ghost := ghosts[i]
		var dir := -1.0 if i == 0 else 1.0
		var rest := ghost.position
		ghost.modulate.a = 0.85
		ghost.scale = Vector2(1.05, 1.05)
		var t := ghost.create_tween().set_parallel(true)
		t.tween_property(ghost, "position", rest + Vector2(70.0 * dir, 6.0 * dir), 0.32 * k).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(ghost, "scale", Vector2(1.25, 1.25), 0.32 * k)
		t.tween_property(ghost, "modulate:a", 0.0, 0.32 * k)


# 불꽃 조각: 원소 색·흰색 마름모가 사방으로 튀고 떨어지며 사라진다.
func _spawn_sparks(holder: Control, color: Color, k: float) -> void:
	for i in 22:
		var spark := Polygon2D.new()
		var r := randf_range(5.0, 11.0)
		spark.polygon = PackedVector2Array([
			Vector2(0, -r * 1.8), Vector2(r * 0.6, 0), Vector2(0, r * 1.8), Vector2(-r * 0.6, 0)])
		spark.color = Color.WHITE if i % 3 == 0 else color.lightened(0.25)
		var angle := TAU * i / 22.0 + randf_range(-0.15, 0.15)
		var dir := Vector2(cos(angle), sin(angle))
		spark.rotation = angle + PI * 0.5
		spark.position = dir * randf_range(70.0, 120.0)
		holder.add_child(spark)

		var dist := randf_range(180.0, 360.0)
		var life := randf_range(0.35, 0.55) * k
		var t := spark.create_tween().set_parallel(true)
		t.tween_property(spark, "position", spark.position + dir * dist + Vector2(0, 60.0), life).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "scale", Vector2(0.2, 0.2), life)
		t.tween_property(spark, "modulate:a", 0.0, life).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.chain().tween_callback(spark.queue_free)


# 박히는 순간 무대가 짧게 덜컥인다.
func _jolt(node: Control, k: float) -> void:
	var rest := node.position
	var t := node.create_tween()
	for offset in [Vector2(10, -6), Vector2(-8, 5), Vector2(5, -3), Vector2.ZERO]:
		t.tween_property(node, "position", rest + offset, 0.025 * k)
