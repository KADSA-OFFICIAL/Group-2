extends Control
class_name UltimateCutin

# 오의 컷인 판 (#544). 전투 화면(`TurnBattle`)이 한 번 만들어 두고, 오의마다 그림과 글자만
# 갈아 끼워 재생한다.
#
# ## 풀 연출 (약 2초 + 필드 연출) — 스타레일식
#
#   0.00  정지·암전         필드가 어두워진다
#   0.10  스피드라인        원소색 사선이 화면을 쓸고, 원소색 사선 판이 오른쪽에서 갈라져 들어온다
#   0.25  캐릭터 등장       잔상 둘을 끌며 오른쪽에서 들어온다. 실루엣 → 흰 번쩍 → 컬러
#   0.45  이름·ULTIMATE     캐릭터 이름과 "ULTIMATE", 원소 문양이 왼쪽에서 들어온다
#   0.55  기술명 타이포     기술명이 한 글자씩 크게 튀어 들어와 박힌다(키네틱 타이포그래피)
#   ~1.60 홀드              그림이 천천히 밀려 들어오고, 판 위 큰 기술명 외곽선이 흐른다
#   1.60  흰 번쩍           판이 사라지고 필드로 돌아온다
#   (이후 `TurnBattle` 이 캐스터 줌인 · 더치 앵글 · 원소 폭발을 이어 재생한다)
#
#   LD 공격 애니메이션이 있으면 0.25 부터 원화 24장(1배속 3초)이 넘어가고, 기술명은 공격 정점 장에서
#   박힌다(`_play_full_anim`). 전체 약 3.4초.
#
# ## 짧게 (약 0.9초)
#   화면 가운데 사선 띠에 캐릭터 상반신과 기술명만 지나간다.
#
# ## 그림
#   `setup()` 이 받는 그림은 셋 중 하나다(고르는 것은 `TurnBattle`):
#     - LD 공격 애니메이션(#549) — 독립 원화 24장 `SpriteFrames`. 풀 연출은 이것을 재생하고,
#       짧게 모드는 마지막 장(결정 포즈)을 쓴다. 만드는 법: tools/build_ultimate_frames.py
#     - 오의 전용 정지 일러스트(`UITheme.ultimate_cutin_path()`) — 사양: docs/ultimate-cutin-art-spec.md
#     - 없으면 전투 스프라이트의 공격 프레임 — 게임 그림체와 같다. 크게 키우면 조금 무르므로
#       원소색 테두리(잔상)로 감싼다.
#
# **조명을 그림에 굽지 않는다.** 원소색은 여기서 잔상·판·글자에 입힌다 — 속성이 바뀌어도
# 다시 그릴 필요가 없다(캐릭터 아트 가이드 §4.2).
#
# ## 시간
#   모든 길이는 `scaled` 콜백(배속 반영)을 거친다. 재시작 등으로 `reset()` 이 불리면
#   토큰이 바뀌고, 재생 중이던 코루틴은 다음 대기에서 깨어나 조용히 빠진다.

## 길이(초) -> 배속이 반영된 길이. `TurnBattle._scaled` 를 넣는다.
var scaled: Callable = Callable()

# ===== LD 공격 애니메이션 (#549) =====
# 원화 24장을 장마다 정해진 길이(SpriteFrames 의 duration, 1/24초 단위)로 넘긴다.
# 공격이 정점에 닿는 장(metadata/strike_frame)에서 기술명 타이포가 박힌다 — 캐릭터마다 다르다.
# 예전 영상판(#546)은 정점이 6명 공통 상수(1.15초)였고, 첫 재생 때 디코딩이 늦게 시작했다.
const ANIM_NAME := &"ult"
## 애니메이션이 끝나기 이만큼(초, 원화 시간) 전에 흰 번쩍으로 빠진다.
const ANIM_EXIT_LEAD: float = 0.1
## 애니메이션 인물 높이(화면 높이 비). 24장 합집합으로 자른 그림이라 무기를 머리 위로 든 장까지
## 들어 있다 — 화면보다 조금 크게 세워 정강이 아래를 잘라야 인물이 화면을 채운다(전신을 다 넣으면
## 화면 높이의 약 70% 로 작게 보였다).
const ANIM_HEIGHT: float = 1.18
## 정점 장에서 판이 번쩍이는 세기(흰색 알파).
const STRIKE_FLASH: float = 0.35

var _token: int = 0
var _color: Color = Color.WHITE
var _dedicated: bool = false

# 풀 연출
var _dim: ColorRect
var _speed: ColorRect
var _slash: Slash
var _watermark: Label
var _art_root: Control
var _ghosts: Array[TextureRect] = []
var _art: TextureRect
var _anim: SpriteFrames = null
var _anim_speed: float = 1.0
var _anim_tween: Tween = null
var _anim_starts: PackedFloat32Array = PackedFloat32Array()   # 장마다 시작 시각(초, 원화 시간)
var _anim_length: float = 0.0
var _anim_strike: int = -1
var _anim_frame: int = -1
var _anim_struck: bool = false
var _emblem: TextureRect
var _type_root: Control
var _caption: Label
var _glyph: TextureRect
var _name: Label
var _skill_row: HBoxContainer
var _underline: ColorRect
var _white: ColorRect

# 짧게
var _strip: Control
var _strip_bg: Slash
var _strip_art: TextureRect
var _strip_name: Label
var _strip_skill: Label
var _strip_lines: Array[ColorRect] = []

var _skill_text: String = ""


# 사선 판. reveal(0..1)만큼 오른쪽에서 밀려 들어온다.
class Slash:
	extends Control

	var fill: Color = Color.WHITE
	var edge: Color = Color(1, 1, 1, 0)
	var left_ratio: float = 0.38      # 판의 왼쪽 끝(화면 폭 비율)
	var slant: float = 180.0          # 위쪽이 아래쪽보다 오른쪽으로 이만큼 기운다
	var reveal: float = 1.0:
		set(value):
			reveal = value
			queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var x0 := lerpf(w + slant, w * left_ratio, reveal)
		var poly := PackedVector2Array([
			Vector2(x0 + slant, 0), Vector2(w + slant + 40, 0), Vector2(w + 40, h), Vector2(x0, h)])
		draw_colored_polygon(poly, fill)
		# 판 안의 결: 왼쪽 가장자리를 따라 밝은 띠, 오른쪽으로 갈수록 어둡게, 가는 평행선 몇 줄.
		var bands := [[0.0, 90.0, Color(1, 1, 1, 0.10)], [90.0, 150.0, Color(1, 1, 1, 0.04)],
			[w * 0.42, w * 0.42 + 260.0, Color(0, 0, 0, 0.10)], [w * 0.52, w * 0.9, Color(0, 0, 0, 0.14)]]
		for b in bands:
			var a0: float = x0 + float(b[0])
			var a1: float = x0 + float(b[1])
			draw_colored_polygon(PackedVector2Array([
				Vector2(a0 + slant, 0), Vector2(a1 + slant, 0), Vector2(a1, h), Vector2(a0, h)]), b[2])
		for i in 6:
			var lx := x0 + 210.0 + float(i) * 34.0
			draw_line(Vector2(lx + slant, 0), Vector2(lx, h), Color(1, 1, 1, 0.05), 2.0, true)
		if edge.a > 0.0:
			draw_line(Vector2(x0 + slant, 0), Vector2(x0, h), edge, 6.0, true)
			draw_line(Vector2(x0 + slant - 22, 0), Vector2(x0 - 22, h), Color(edge, edge.a * 0.45), 2.0, true)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()
	resized.connect(_layout)


# ===== 구성 =====

func _build() -> void:
	_dim = _rect(Color(0, 0, 0, 0))
	add_child(_dim)

	_speed = _rect(Color(1, 1, 1, 1))
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(1.0);
uniform float flow = 1.0;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void fragment() {
	// 기울인 좌표에서 촘촘한 줄마다 길이·속도가 다른 선분이 오른쪽에서 왼쪽으로 흐른다.
	vec2 p = FRAGCOORD.xy;
	float row = floor((p.y - p.x * 0.42) / 7.0);
	float speed = 1500.0 + hash(row) * 2600.0;
	float len = 60.0 + hash(row + 7.0) * 420.0;
	float x = mod(p.x + TIME * speed * flow + hash(row + 3.0) * 3000.0, 1800.0);
	float on = step(x, len) * step(0.62, hash(row + 11.0));
	float fade = 1.0 - x / max(len, 1.0);
	COLOR = vec4(tint.rgb, tint.a * on * fade);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_speed.material = mat
	_speed.modulate.a = 0.0
	add_child(_speed)

	_slash = Slash.new()
	_slash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slash)

	# 판 위의 커다란 외곽선 글자(기술명). 홀드 동안 천천히 흐른다.
	_watermark = _label(230, 1.4)
	_watermark.add_theme_color_override("font_color", Color(0, 0, 0, 0))
	_watermark.add_theme_constant_override("outline_size", 6)
	_watermark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_watermark.rotation = deg_to_rad(-8.0)
	add_child(_watermark)

	_emblem = TextureRect.new()
	_emblem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_emblem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_emblem)

	_art_root = Control.new()
	_art_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_root)
	for i in 2:
		var ghost := _texture_rect()
		_art_root.add_child(ghost)
		_ghosts.append(ghost)
	_art = _texture_rect()
	_art_root.add_child(_art)


	_type_root = Control.new()
	_type_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_root.rotation = deg_to_rad(-8.0)
	add_child(_type_root)

	_glyph = _texture_rect()
	_glyph.size = Vector2(34, 34)
	_glyph.position = Vector2(0, -6)
	_type_root.add_child(_glyph)

	_caption = _label(18, 0.7)
	# 영문 캡션("U L T I M A T E")만 BREAK! 와 같은 디스플레이 폰트를 쓴다(#559).
	# 이름·기술명은 한글이라 지금의 기울인 굵은 글꼴을 그대로 둔다.
	_caption.add_theme_font_override("font", HUDKit.display_font())
	_caption.add_theme_font_size_override("font_size", 22)
	_caption.position = Vector2(44, 0)
	_type_root.add_child(_caption)

	_name = _label(30, 0.9)
	_name.position = Vector2(0, 36)
	_type_root.add_child(_name)

	_skill_row = HBoxContainer.new()
	_skill_row.add_theme_constant_override("separation", 0)
	_skill_row.position = Vector2(-6, 80)
	_skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_root.add_child(_skill_row)

	_underline = ColorRect.new()
	_underline.position = Vector2(0, 182)
	_underline.size = Vector2(0, 6)
	_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_root.add_child(_underline)

	# 짧게 — 가운데 사선 띠.
	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip.clip_contents = true
	add_child(_strip)
	_strip_bg = Slash.new()
	_strip_bg.left_ratio = 0.0
	_strip_bg.slant = 60.0
	_strip_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_strip_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_strip.add_child(_strip_bg)
	_strip_art = _texture_rect()
	_strip.add_child(_strip_art)
	for i in 2:
		var line := ColorRect.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_strip.add_child(line)
		_strip_lines.append(line)
	_strip_name = _label(20, 0.7)
	_strip.add_child(_strip_name)
	_strip_skill = _label(52, 1.2)
	_strip.add_child(_strip_skill)

	_white = _rect(Color(1, 1, 1, 0))
	add_child(_white)


func _layout() -> void:
	var c := size
	if c.x <= 0.0 or c.y <= 0.0:
		return
	# 그림: 오른쪽 55~65%. 전용 일러스트는 화면보다 조금 크게(잘려 나가도 된다),
	# 전투 스프라이트는 너무 키우면 무르므로 화면 높이의 90% 정도로 둔다.
	var tex := _art.texture
	if _anim != null:
		tex = _anim.get_frame_texture(ANIM_NAME, 0)
	var aspect := 0.66
	if tex != null and tex.get_height() > 0:
		aspect = float(tex.get_width()) / float(tex.get_height())
	var h := c.y * (ANIM_HEIGHT if _anim != null else (1.10 if _dedicated else 1.02))
	var w := h * aspect
	var center_x := c.x * (0.66 if _dedicated else 0.70)
	_art_root.size = Vector2(w, h)
	if _anim != null:
		# 합집합 상자의 위쪽(머리 위로 든 무기)을 화면 위에 붙이고, 아래(정강이·발)를 잘라 낸다.
		_art_root.position = Vector2(center_x - w * 0.5, c.y * 0.01)
	else:
		_art_root.position = Vector2(center_x - w * 0.5, c.y - h * (0.96 if _dedicated else 0.95))
	_art_root.pivot_offset = Vector2(w * 0.5, h * 0.6)
	for node in [_art] + _ghosts:
		node.position = Vector2.ZERO
		node.size = Vector2(w, h)
		node.pivot_offset = Vector2(w * 0.5, h * 0.6)

	_watermark.position = Vector2(c.x * 0.40, c.y * 0.20)

	_emblem.size = Vector2(c.y * 0.62, c.y * 0.62)
	_emblem.position = Vector2(c.x * 0.06, c.y * 0.18)

	_type_root.position = Vector2(c.x * 0.075, c.y * 0.36)

	var strip_h := minf(210.0, c.y * 0.3)
	_strip.position = Vector2(0, c.y * 0.5 - strip_h * 0.5)
	_strip.size = Vector2(c.x, strip_h)
	# 띠 안의 그림은 상반신만: 그림 높이를 띠의 2.4배로 두고 머리가 띠 위쪽에 오게 한다.
	var sh := strip_h * 2.4
	var still_aspect := aspect
	var still_tex := _strip_art.texture
	if still_tex != null and still_tex.get_height() > 0:
		still_aspect = float(still_tex.get_width()) / float(still_tex.get_height())
	var sw := sh * still_aspect
	_strip_art.size = Vector2(sw, sh)
	# 전투 프레임은 칸 위쪽에 여백이 있어 머리가 30% 아래에 온다 — 얼굴이 띠 위쪽에 오게 올린다.
	# LD 정지 그림(전용)은 여백 없이 잘려 있어 머리가 맨 위에 온다. SD 전투 프레임은 칸 위쪽에
	# 여백이 있어 머리가 30% 아래에 온다 — 둘 다 얼굴이 띠 위쪽에 오게 맞춘다.
	_strip_art.position = Vector2(c.x * 0.70 - sw * 0.5, -strip_h * (0.08 if _dedicated else 0.6))
	_strip_lines[0].position = Vector2(0, 0)
	_strip_lines[0].size = Vector2(c.x, 5)
	_strip_lines[1].position = Vector2(0, strip_h - 5)
	_strip_lines[1].size = Vector2(c.x, 5)
	_strip_name.position = Vector2(c.x * 0.12, strip_h * 0.16)
	_strip_skill.position = Vector2(c.x * 0.11, strip_h * 0.34)


# ===== 준비 =====

# art: 정지 그림(짧게 모드·애니메이션이 없을 때). anim: LD 공격 애니메이션(없으면 null).
# anim_speed: 배속 배수 — 애니메이션은 이 배수로 넘긴다.
func setup(art: Texture2D, dedicated: bool, char_name: String, skill_name: String, color: Color,
		emblem: Texture2D = null, glyph: Texture2D = null, anim: SpriteFrames = null,
		anim_speed: float = 1.0) -> void:
	_color = color
	_dedicated = dedicated
	_skill_text = skill_name
	_stop_anim()
	_anim = anim if anim != null and anim.has_animation(ANIM_NAME) \
		and anim.get_frame_count(ANIM_NAME) > 0 else null
	_anim_speed = maxf(anim_speed, 0.1)
	_index_anim()

	# 애니메이션이면 첫 장으로 등장한다(잔상도 첫 장). 정지 그림은 짧게 띠에만 쓴다.
	var entry := _anim.get_frame_texture(ANIM_NAME, 0) if _anim != null else art
	_art.texture = entry
	_strip_art.texture = art
	for ghost in _ghosts:
		ghost.texture = entry
		ghost.modulate = Color(color.r, color.g, color.b, 0.0)

	_emblem.texture = emblem
	_emblem.modulate = Color(color.r, color.g, color.b, 0.16)
	_glyph.texture = glyph
	_glyph.modulate = color.lightened(0.2)

	_caption.text = "U L T I M A T E"
	_caption.add_theme_color_override("font_color", color.lightened(0.25))
	_name.text = char_name
	_name.add_theme_color_override("font_color", UITheme.CREAM)

	for child in _skill_row.get_children():
		_skill_row.remove_child(child)
		child.queue_free()
	for ch in skill_name:
		var l := _label(76, 1.3)
		l.text = ch
		l.add_theme_color_override("font_color", UITheme.CREAM)
		l.add_theme_color_override("font_outline_color", color.darkened(0.55))
		l.add_theme_constant_override("outline_size", 10)
		l.modulate.a = 0.0
		_skill_row.add_child(l)

	_underline.color = color
	_watermark.text = skill_name
	_watermark.add_theme_color_override("font_outline_color", Color(color.lightened(0.45), 0.16))
	for line in _strip_lines:
		line.color = color

	_slash.fill = Color(color.darkened(0.35), 0.92)
	_slash.edge = color.lightened(0.35)
	_speed.material.set_shader_parameter("tint", Color(color.lightened(0.5), 0.55))

	_strip_bg.fill = Color(0.09, 0.08, 0.07, 0.95)
	_strip_bg.edge = color
	_strip_name.text = char_name
	_strip_name.add_theme_color_override("font_color", color.lightened(0.3))
	_strip_skill.text = skill_name
	_strip_skill.add_theme_color_override("font_color", UITheme.CREAM)
	_strip_skill.add_theme_color_override("font_outline_color", color.darkened(0.5))
	_strip_skill.add_theme_constant_override("outline_size", 8)
	_layout()


# 재생 중이던 연출을 끊고 처음 상태로 되돌린다(전투 재시작 등).
func reset() -> void:
	_token += 1
	_stop_anim()
	visible = false
	modulate = Color.WHITE
	_dim.color.a = 0.0
	_white.color.a = 0.0
	_speed.modulate.a = 0.0
	_strip.visible = false


# ===== 풀 연출 =====

func play_full() -> void:
	_token += 1
	var token := _token
	_prepare_full()
	var c := size

	# 0.00 정지·암전
	var t := _tween()
	t.tween_property(_dim, "color:a", 0.78, _s(0.12))
	if not await _hold(0.10, token):
		return

	# 0.10 스피드라인 + 사선 판
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_speed, "modulate:a", 1.0, _s(0.15))
	t.tween_property(_slash, "reveal", 1.0, _s(0.24)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(_watermark, "modulate:a", 1.0, _s(0.3)).set_delay(_s(0.1))
	if not await _hold(0.15, token):
		return

	if _anim != null:
		await _play_full_anim(token)
		return

	# 0.25 캐릭터 등장 — 잔상을 끌며 들어온다. 실루엣 → 흰 번쩍 → 컬러.
	var home := _art_root.position
	_art_root.position = home + Vector2(c.x * 0.22, 0)
	_art_root.modulate.a = 1.0
	_art.modulate = Color(0, 0, 0, 1)
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_art_root, "position", home, _s(0.30)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for i in _ghosts.size():
		var ghost := _ghosts[i]
		var lag := 0.05 * float(i + 1)
		ghost.position = Vector2(c.x * 0.06 * float(i + 1), 0)
		ghost.modulate.a = 0.5 - 0.15 * float(i)
		t.tween_property(ghost, "position", Vector2(18.0 * float(i + 1), -6.0 * float(i + 1)), _s(0.30 + lag)) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ghost, "modulate:a", 0.22 - 0.07 * float(i), _s(0.5)).set_delay(_s(0.25))
	t.tween_property(_art, "modulate", Color(4, 4, 4, 1), _s(0.12)).set_delay(_s(0.10))
	t.chain().tween_property(_art, "modulate", Color.WHITE, _s(0.22))
	if not await _hold(0.20, token):
		return

	# 0.45 이름 · ULTIMATE · 원소 문양
	var type_home := _type_root.position
	_type_root.position = type_home + Vector2(-80, 0)
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_type_root, "position", type_home, _s(0.25)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_caption, "modulate:a", 1.0, _s(0.18))
	t.tween_property(_glyph, "modulate:a", 1.0, _s(0.18))
	t.tween_property(_name, "modulate:a", 1.0, _s(0.18)).set_delay(_s(0.05))
	t.tween_property(_emblem, "modulate:a", 0.16, _s(0.3))
	if not await _hold(0.10, token):
		return

	# 0.55 기술명 — 한 글자씩 크게 튀어 들어와 박힌다.
	_pop_skill_letters()

	# 홀드 — 그림이 천천히 밀려 들어오고, 판 위 큰 글자가 흐른다.
	var push := _tween()
	push.set_parallel(true)
	push.tween_property(_art_root, "scale", Vector2(1.06, 1.06), _s(1.05))
	push.tween_property(_watermark, "position:x", _watermark.position.x - 70.0, _s(1.05))
	if not await _hold(1.05, token):
		return

	# 1.60 흰 번쩍 → 판을 걷는다.
	t = _tween()
	t.tween_property(_white, "color:a", 0.95, _s(0.06))
	if not await _hold(0.06, token):
		return
	_hide_full()
	t = _tween()
	t.tween_property(_white, "color:a", 0.0, _s(0.25))
	if not await _hold(0.10, token):
		return


# 애니메이션판 (#549): 0.25 에서 LD 캐릭터가 잔상을 끌고 들어오며 원화 24장이 넘어가기 시작하고,
# 기술명 타이포는 공격이 정점에 닿는 장에서 박힌다. 결정 포즈가 유지되는 동안 홀드하고,
# 마지막 장 끝에서 흰 번쩍으로 빠진다.
# 원화 시간은 배속 배수(`_anim_speed`)로 나눈다 — 기준 속도 0.7 로 늦추지 않는다.
func _play_full_anim(token: int) -> void:
	var c := size
	var home := _art_root.position
	_art_root.position = home + Vector2(c.x * 0.18, 0)
	_art_root.modulate.a = 1.0
	_art.modulate = Color(0, 0, 0, 1)
	_show_anim_frame(0)
	_anim_struck = false

	var t := _tween()
	t.set_parallel(true)
	t.tween_property(_art_root, "position", home, _s(0.28)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# 잔상 — 첫 장의 원소색 실루엣 둘이 뒤따라 들어와 흩어진다(영상판에서는 빠져 있었다).
	for i in _ghosts.size():
		var ghost := _ghosts[i]
		ghost.position = Vector2(c.x * 0.06 * float(i + 1), 0)
		ghost.modulate.a = 0.5 - 0.15 * float(i)
		t.tween_property(ghost, "position", Vector2(18.0 * float(i + 1), -6.0 * float(i + 1)),
			_s(0.28 + 0.05 * float(i + 1))).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ghost, "modulate:a", 0.0, _s(0.35)).set_delay(_s(0.2))
	# 실루엣 → 흰 번쩍 → 컬러를 짧게 — 길면 첫 동작(무기를 드는 순간)을 가린다.
	var flash := _tween()
	flash.tween_property(_art, "modulate", Color(4, 4, 4, 1), _s(0.07)).set_delay(_s(0.04))
	flash.tween_property(_art, "modulate", Color.WHITE, _s(0.14))

	# 이름 · ULTIMATE · 원소 문양
	var type_home := _type_root.position
	_type_root.position = type_home + Vector2(-80, 0)
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_type_root, "position", type_home, _s(0.25)).set_delay(_s(0.2)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_caption, "modulate:a", 1.0, _s(0.18)).set_delay(_s(0.2))
	t.tween_property(_glyph, "modulate:a", 1.0, _s(0.18)).set_delay(_s(0.2))
	t.tween_property(_name, "modulate:a", 1.0, _s(0.18)).set_delay(_s(0.25))
	t.tween_property(_emblem, "modulate:a", 0.16, _s(0.3)).set_delay(_s(0.2))

	# 원화를 넘긴다. 정점 장에 닿으면 `_seek_anim` 이 기술명을 박는다.
	var real_length := _anim_length / _anim_speed
	_anim_tween = create_tween()
	_anim_tween.tween_method(_seek_anim, 0.0, _anim_length, real_length)
	var push := _tween()
	push.set_parallel(true)
	push.tween_property(_art_root, "scale", Vector2(1.04, 1.04), real_length)
	push.tween_property(_watermark, "position:x", _watermark.position.x - 70.0, real_length)

	# 결정 포즈 홀드 — 마지막 장이 끝나기 직전까지.
	if not await _hold_real(real_length - ANIM_EXIT_LEAD / _anim_speed, token):
		return

	t = _tween()
	t.tween_property(_white, "color:a", 0.95, _s(0.06))
	if not await _hold(0.06, token):
		return
	_stop_anim()
	_hide_full()
	t = _tween()
	t.tween_property(_white, "color:a", 0.0, _s(0.25))
	await _hold(0.10, token)


# 원화 시간 seconds 에 해당하는 장을 보인다. 정점 장을 처음 넘을 때 기술명을 박는다.
func _seek_anim(seconds: float) -> void:
	var idx := 0
	while idx + 1 < _anim_starts.size() and _anim_starts[idx + 1] <= seconds:
		idx += 1
	_show_anim_frame(idx)
	if not _anim_struck and idx >= _anim_strike:
		_anim_struck = true
		_on_strike()


func _show_anim_frame(idx: int) -> void:
	if _anim == null or idx == _anim_frame:
		return
	_anim_frame = idx
	_art.texture = _anim.get_frame_texture(ANIM_NAME, idx)


# 공격 정점: 기술명이 박히고, 판이 한 번 번쩍이며 그림이 살짝 튄다.
func _on_strike() -> void:
	_pop_skill_letters()
	var t := _tween()
	t.tween_property(_white, "color:a", STRIKE_FLASH, _s(0.03))
	t.tween_property(_white, "color:a", 0.0, _s(0.16))
	var kick := _tween()
	kick.tween_property(_art, "scale", Vector2(1.03, 1.03), _s(0.04))
	kick.tween_property(_art, "scale", Vector2.ONE, _s(0.12))


# 장마다 시작 시각을 미리 세어 둔다. 길이 = SpriteFrames 의 duration(장 단위) / speed(fps).
func _index_anim() -> void:
	_anim_starts = PackedFloat32Array()
	_anim_length = 0.0
	_anim_frame = -1
	_anim_strike = -1
	if _anim == null:
		return
	var fps := maxf(_anim.get_animation_speed(ANIM_NAME), 1.0)
	var count := _anim.get_frame_count(ANIM_NAME)
	for i in count:
		_anim_starts.append(_anim_length)
		_anim_length += _anim.get_frame_duration(ANIM_NAME, i) / fps
	_anim_strike = clampi(int(_anim.get_meta(&"strike_frame", count / 2)), 0, count - 1)


func _stop_anim() -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()
	_anim_tween = null


# 애니메이션의 마지막 장(결정 포즈)을 인물 상자만큼 잘라 정지 그림으로 쓴다(짧게 모드).
# 상자는 빌드 도구가 metadata/final_rect 에 적어 둔다. 없으면 장 전체.
static func final_pose_of(frames: SpriteFrames) -> Texture2D:
	if frames == null or not frames.has_animation(ANIM_NAME):
		return null
	var count := frames.get_frame_count(ANIM_NAME)
	if count == 0:
		return null
	var last := frames.get_frame_texture(ANIM_NAME, count - 1)
	var rect: Variant = frames.get_meta(&"final_rect", null)
	if last == null or not (rect is Rect2):
		return last
	var region := (rect as Rect2).grow(24.0).intersection(Rect2(Vector2.ZERO, last.get_size()))
	var atlas := AtlasTexture.new()
	atlas.atlas = last
	atlas.region = region
	return atlas


# 기술명: 한 글자씩 크게 튀어 들어와 박히고, 밑줄이 따라 그어진다.
func _pop_skill_letters() -> void:
	var letters := _skill_row.get_children()
	var t := _tween()
	t.set_parallel(true)
	for i in letters.size():
		var l := letters[i] as Label
		l.pivot_offset = Vector2(l.size.x * 0.5, l.size.y * 0.6)
		l.scale = Vector2(2.4, 2.4)
		l.rotation = deg_to_rad(-14.0 if i % 2 == 0 else 10.0)
		var delay := _s(0.035 * float(i))
		t.tween_property(l, "modulate:a", 1.0, _s(0.06)).set_delay(delay)
		t.tween_property(l, "scale", Vector2.ONE, _s(0.16)).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "rotation", 0.0, _s(0.16)).set_delay(delay)
	var row_w: float = maxf(_skill_row.get_combined_minimum_size().x, 200.0)
	t.tween_property(_underline, "size:x", row_w, _s(0.3)).set_delay(_s(0.035 * float(letters.size()))) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _prepare_full() -> void:
	visible = true
	modulate = Color.WHITE
	_strip.visible = false
	for node in [_slash, _art_root, _emblem, _type_root, _watermark]:
		node.visible = true
	_slash.reveal = 0.0
	_art.visible = true
	for ghost in _ghosts:
		ghost.visible = true
	_watermark.modulate.a = 0.0
	_art_root.scale = Vector2.ONE
	_art.scale = Vector2.ONE   # 정점 장의 튀김(`_on_strike`) 도중 끊겼을 수 있다
	_art_root.modulate.a = 0.0
	_emblem.modulate.a = 0.0
	_caption.modulate.a = 0.0
	_glyph.modulate.a = 0.0
	_name.modulate.a = 0.0
	_underline.size.x = 0.0
	for l in _skill_row.get_children():
		(l as Label).modulate.a = 0.0
	_dim.color.a = 0.0
	_white.color.a = 0.0
	_speed.modulate.a = 0.0
	_layout()


func _hide_full() -> void:
	for node in [_slash, _art_root, _emblem, _type_root, _watermark]:
		node.visible = false
	_dim.color.a = 0.0
	_speed.modulate.a = 0.0


# ===== 짧게 =====

func play_short() -> void:
	_token += 1
	var token := _token
	visible = true
	modulate = Color.WHITE
	for node in [_slash, _art_root, _emblem, _type_root, _watermark]:
		node.visible = false
	_layout()
	var c := size
	_strip.visible = true
	_strip_bg.reveal = 0.0
	_strip_art.modulate.a = 0.0
	_strip_name.modulate.a = 0.0
	_strip_skill.modulate.a = 0.0
	var art_home := _strip_art.position
	var skill_home := _strip_skill.position

	var t := _tween()
	t.set_parallel(true)
	t.tween_property(_dim, "color:a", 0.45, _s(0.08))
	t.tween_property(_strip_bg, "reveal", 1.0, _s(0.16)).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_strip_art.position = art_home + Vector2(c.x * 0.15, 0)
	t.tween_property(_strip_art, "position", art_home, _s(0.22)).set_delay(_s(0.06)) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(_strip_art, "modulate:a", 1.0, _s(0.1)).set_delay(_s(0.06))
	_strip_skill.position = skill_home + Vector2(-60, 0)
	t.tween_property(_strip_skill, "position", skill_home, _s(0.2)).set_delay(_s(0.1)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_strip_skill, "modulate:a", 1.0, _s(0.1)).set_delay(_s(0.1))
	t.tween_property(_strip_name, "modulate:a", 1.0, _s(0.1)).set_delay(_s(0.12))
	if not await _hold(0.62, token):
		return

	t = _tween()
	t.set_parallel(true)
	t.tween_property(_strip_art, "position", art_home + Vector2(-c.x * 0.1, 0), _s(0.16))
	t.tween_property(_strip, "modulate:a", 0.0, _s(0.16))
	t.tween_property(_dim, "color:a", 0.0, _s(0.16))
	if not await _hold(0.16, token):
		return
	_strip.visible = false
	_strip.modulate.a = 1.0


# ===== 공용 =====

func _s(d: float) -> float:
	var v := float(scaled.call(d)) if scaled.is_valid() else d
	return maxf(v, 0.0)


func _tween() -> Tween:
	return create_tween()


# 실제 초로 기다린다(영상 시간 기준). 그 사이 `reset()`/새 재생이 있었으면 false.
func _hold_real(seconds: float, token: int) -> bool:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	return token == _token and is_inside_tree()


# 배속을 반영해 기다린다. 그 사이 `reset()`/새 재생이 있었으면 false.
func _hold(d: float, token: int) -> bool:
	var wait := _s(d)
	if wait > 0.0:
		await get_tree().create_timer(wait).timeout
	return token == _token and is_inside_tree()


func _rect(color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _texture_rect() -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _label(size_px: int, embolden: float) -> Label:
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = embolden
	f.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	var l := Label.new()
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
