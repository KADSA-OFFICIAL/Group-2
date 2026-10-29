extends Control
class_name UltimateCutin

# 오의 컷인 판 (#544, 풀 연출은 #576 에서 재설계). 전투 화면(`TurnBattle`)이 한 번 만들어 두고,
# 오의마다 그림과 글자만 갈아 끼워 재생한다.
#
# ## 풀 연출 — "정확히 조준하고, 짧은 정적 뒤 한 발로 타격한다" (기본 약 2.2초)
#
# 캐릭터 소개 배너가 아니라 **행동**을 보여 준다. 전신 대신 얼굴·상체·무기를 크롭하고,
# 사선 판·속도선·거대한 글자를 없앴다. 시간은 컷인(이 파일)과 필드(`TurnBattle._play_ult_field`)가 나눠 갖는다.
#
#   0.00~0.15  암전          필드가 짙은 남색으로 가라앉는다 (전투 UI 는 `TurnBattle` 이 내린다)
#   0.15~0.55  클로즈업      얼굴·조준하는 눈·무기가 오른쪽에서 들어오며 천천히 밀려 든다. 이름이 뜬다
#   0.55~0.95  조준          조준 고리가 발사 방향의 한 점으로 모이고, 작은 전기는 총구로 빨려 든다. 기술명이 뜬다
#   0.95~1.10  정적          모든 움직임이 멈춘다 — 발사 직전의 긴장
#   1.10~1.35  발사          발사 방향(왼쪽)으로 가는 가는 번개 한 줄 + 짧은 반동
#   ~1.45      컷인 퇴장     (여기까지가 이 파일 `play_full`)
#   이후       피격          필드에서 번개가 실제 대상에게 이어지고 피격 효과가 난다 (`TurnBattle`)
#   마지막     UI 복구       잔광을 정리하고 전투 UI 가 돌아온다 (`TurnBattle`)
#
# 밝은 전면 플래시와 지속 흔들림은 쓰지 않는다. 빛은 조준점·번개·잔 전기에만 모은다.
# 시간·크기·색은 아래 상수로 조정한다. 모든 길이는 `scaled` 콜백(배속 반영)을 거친다.
#
# ## 짧게 (약 0.9초)
#   화면 가운데 사선 띠에 캐릭터 상반신과 기술명만 지나간다.
#
# ## 그림
#   `setup()` 이 받는 그림은 셋 중 하나다(고르는 것은 `TurnBattle`):
#     - LD 공격 애니메이션(#549) — 독립 원화 24장 `SpriteFrames`. 풀 연출은 조준 장(정점 3장 앞)과
#       정점 장·반동 장만 쓴다. 짧게 모드는 마지막 장(결정 포즈)을 쓴다. 만드는 법: tools/build_ultimate_frames.py
#     - 오의 전용 정지 일러스트(`UITheme.ultimate_cutin_path()`) — 사양: docs/ultimate-cutin-art-spec.md
#     - 없으면 전투 스프라이트의 공격 프레임 — 크게 키우면 무르므로 크롭을 덜 하고 작게 쓴다.
#
# 총구 위치는 SpriteFrames 의 `metadata/muzzle`(원화 픽셀 좌표)이다. 없으면 원화 크기에서 추정한다.
# **조명을 그림에 굽지 않는다.** 원소색은 여기서 조준선·번개·밑줄에만 입힌다.
#
# ## 시간
#   재시작 등으로 `reset()` 이 불리면 토큰이 바뀌고, 재생 중이던 코루틴은 다음 대기에서 깨어나 조용히 빠진다.

## 효과음 자리. 조준이 시작될 때 `ult_charge`, 발사 순간 `ult_fire` 를 보낸다(재생은 `TurnBattle`).
signal cue(sound: StringName)

## 길이(초) -> 배속이 반영된 길이. `TurnBattle._scaled` 를 넣는다.
var scaled: Callable = Callable()

# ===== 연출 상수 (#576) — 타이밍은 위 표와 같다. 값을 바꾸면 이 파일의 호출부 기준이 같이 움직인다. =====
const ANIM_NAME := &"ult"
## 시점(초, 배속 적용 전).
const T_DIM: float = 0.15
const T_CLOSEUP: float = 0.40       # 0.15 -> 0.55
const T_AIM: float = 0.40           # 0.55 -> 0.95
const T_FREEZE: float = 0.15        # 0.95 -> 1.10
const T_FIRE: float = 0.25          # 1.10 -> 1.35
const T_EXIT: float = 0.10          # 컷인을 걷는 데 쓰는 시간
const T_FADE_TAIL: float = 0.40     # 남색 막이 필드 위에서 걷히는 시간(필드 연출과 겹친다)

## 그림을 위에서부터 이만큼(원화 높이 비)만 보인다 — 얼굴·상체·무기. 전투 스프라이트(저해상도)는 덜 자른다.
const CROP_FRAC: float = 0.56
const CROP_FRAC_SPRITE: float = 0.80
## 크롭 상자가 화면 폭에서 차지할 수 있는 최대 비.
const CROP_MAX_WIDTH: float = 0.70
## 클로즈업: 시작 배율 -> 정적 때의 배율, 들어오는 거리(px).
const ZOOM_START: float = 1.0
const ZOOM_END: float = 1.10
const ENTER_SLIDE: float = 60.0
## 발사 반동(px). 오른쪽·아래로 살짝 밀렸다 돌아온다.
const RECOIL: Vector2 = Vector2(14.0, 4.0)
## 반동 장을 넘기는 간격(초, 배속 적용 전). 정점 장 뒤로 몇 장 더 보여 준다.
const RECOIL_FRAME_STEP: float = 0.05
const RECOIL_FRAMES: int = 4

## 막 색: 원소색 색조를 지키되 아주 어둡게 — 남보라 계열의 깊이. (안쪽, 바깥)
const DEEP_VALUE_INNER: float = 0.30
const DEEP_VALUE_OUTER: float = 0.07
const DEEP_ALPHA_INNER: float = 0.62
const DEEP_ALPHA_OUTER: float = 0.93

## 조준점의 가로 위치(화면 폭 비)와 조준 고리의 시작 반지름(화면 높이 비).
## 고리는 이 반지름에서 한 점으로 오므라든다 — 아래 이름·기술명에 닿지 않을 만큼만 크게 둔다.
const AIM_POINT_X: float = 0.24
const RETICLE_START: float = 0.20
## 총구 위치를 모를 때 원화 크기에 곱하는 기본값.
const MUZZLE_DEFAULT := Vector2(0.085, 0.205)
## 이름·기술명 글자 크기(화면 높이 비)와 기술명이 쓸 수 있는 폭(화면 폭 비).
const NAME_SIZE: float = 0.034
const SKILL_SIZE: float = 0.066
const SKILL_MAX_WIDTH: float = 0.34
const SKILL_SIZE_MIN: int = 28

var _token: int = 0
var _color: Color = Color.WHITE
var _dedicated: bool = false

# 풀 연출
var _dim: ColorRect
var _deep: TextureRect
var _crop: Control
var _art: TextureRect
var _aim_line: TextureRect
var _reticle: Reticle
var _fx: Control
var _type_root: Control
var _name_row: Control
var _glyph: TextureRect
var _name: Label
var _skill: Label
var _underline: ColorRect
var _white: ColorRect

var _anim: SpriteFrames = null
var _anim_speed: float = 1.0
var _anim_starts: PackedFloat32Array = PackedFloat32Array()   # 장마다 시작 시각(초, 원화 시간)
var _anim_length: float = 0.0
var _anim_strike: int = -1
var _anim_frame: int = -1
var _anim_struck: bool = false
var _muzzle: Vector2 = Vector2.ZERO      # 원화 픽셀 좌표
var _frame_size: Vector2 = Vector2(716.0, 1152.0)
## 화면에서 총구가 놓이는 점. `_layout()` 이 정한다(정적 때의 확대 배율 기준).
var _muzzle_screen: Vector2 = Vector2.ZERO
## 조준 고리가 모이는 점(발사 방향 여백 위).
var _aim_point: Vector2 = Vector2.ZERO
var _home_art: Vector2 = Vector2.ZERO

# 짧게
var _strip: Control
var _strip_bg: Slash
var _strip_art: TextureRect
var _strip_name: Label
var _strip_skill: Label
var _strip_lines: Array[ColorRect] = []

var _skill_text: String = ""


# 사선 판. reveal(0..1)만큼 오른쪽에서 밀려 들어온다. (짧게 모드의 띠)
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


# 조준선: 고리 하나와 십자 눈금 넷. 고리가 한 점으로 오므라든다. `radius` 와 알파는 트윈이 움직인다.
class Reticle:
	extends Control

	var color: Color = Color.WHITE
	var radius: float = 200.0:
		set(value):
			radius = value
			queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		draw_arc(center, radius, 0.0, TAU, 48, color, 2.0, true)
		var tick := 16.0
		for dir in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			draw_line(center + dir * (radius - tick), center + dir * (radius + tick * 0.5), color, 2.0, true)
		draw_circle(center, 2.5, color)


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

	# 짙은 남보라 막. 가운데가 조금 밝고 바깥이 어둡다 — 깊이는 여기서 만든다.
	_deep = TextureRect.new()
	_deep.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_deep.stretch_mode = TextureRect.STRETCH_SCALE
	_deep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_deep.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deep.modulate.a = 0.0
	add_child(_deep)

	# 크롭: 얼굴·상체·무기만 보이게 자른 창. 그림은 이 안에서 움직인다.
	_crop = Control.new()
	_crop.clip_contents = true
	_crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crop)
	_art = _texture_rect()
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_crop.add_child(_art)

	# 발사 방향으로 뻗는 조준선(총구에서 왼쪽 가장자리까지, 끝으로 갈수록 옅다).
	_aim_line = TextureRect.new()
	_aim_line.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_aim_line.stretch_mode = TextureRect.STRETCH_SCALE
	_aim_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_aim_line)

	_reticle = Reticle.new()
	_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reticle)

	_fx = Control.new()
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_fx)

	# 글자: 수평 조판, 한 계열(HUDKit.notice_font). 이름은 작게, 기술명은 그보다 크게.
	_type_root = Control.new()
	_type_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_type_root)

	_name_row = Control.new()
	_name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_type_root.add_child(_name_row)
	_glyph = _texture_rect()
	_name_row.add_child(_glyph)
	_name = _plain_label()
	_name_row.add_child(_name)
	_skill = _plain_label()
	_type_root.add_child(_skill)
	_underline = ColorRect.new()
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
	_strip_name = _plain_label()
	_strip_name.add_theme_font_size_override("font_size", 22)
	_strip.add_child(_strip_name)
	_strip_skill = _plain_label()
	_strip_skill.add_theme_font_size_override("font_size", 52)
	_strip.add_child(_strip_skill)

	_white = _rect(Color(1, 1, 1, 0))
	add_child(_white)


func _layout() -> void:
	var c := size
	if c.x <= 0.0 or c.y <= 0.0:
		return

	# 크롭 상자: 화면 높이를 꽉 채우고 오른쪽에 붙인다. 왼쪽은 발사 방향의 여백이다.
	var tex := _art.texture
	if _anim != null:
		tex = _anim.get_frame_texture(ANIM_NAME, 0)
	_frame_size = tex.get_size() if tex != null else Vector2(716.0, 1152.0)
	var crop_frac := CROP_FRAC if _dedicated else CROP_FRAC_SPRITE
	var crop_aspect := _frame_size.x / maxf(_frame_size.y * crop_frac, 1.0)
	var box_h := c.y
	var box_w := box_h * crop_aspect
	if box_w > c.x * CROP_MAX_WIDTH:
		box_w = c.x * CROP_MAX_WIDTH
		box_h = box_w / crop_aspect
	_crop.size = Vector2(box_w, box_h)
	_crop.position = Vector2(c.x - box_w, 0.0)

	# 그림은 상자 폭에 맞추고 위쪽에 붙인다. 아래(하체)는 창 밖으로 잘린다.
	var art_scale := box_w / _frame_size.x
	_art.size = _frame_size * art_scale
	_art.position = Vector2.ZERO
	_home_art = _art.position
	# 확대는 얼굴 쪽(위쪽, 가운데보다 오른쪽)을 중심으로 한다 — 총구가 크게 밀려나지 않게.
	_art.pivot_offset = Vector2(box_w * 0.55, box_h * 0.22)

	# 총구의 화면 좌표(정적 때의 확대 배율 기준). 조준선·번개가 여기서 나간다.
	var muzzle_px := _muzzle if _muzzle != Vector2.ZERO else _frame_size * MUZZLE_DEFAULT
	var m := muzzle_px * art_scale
	var zoomed := _art.pivot_offset + (m - _art.pivot_offset) * ZOOM_END
	_muzzle_screen = _crop.position + zoomed

	# 조준선: 총구에서 왼쪽 가장자리까지.
	_aim_line.position = Vector2(0.0, _muzzle_screen.y - 1.0)
	_aim_line.size = Vector2(maxf(_muzzle_screen.x, 1.0), 2.0)
	_aim_line.pivot_offset = Vector2(_aim_line.size.x, 1.0)

	# 조준점: 총구에서 발사 방향(왼쪽)으로 뻗은 조준선 위. 고리는 여기서 한 점으로 모인다.
	_aim_point = Vector2(c.x * AIM_POINT_X, _muzzle_screen.y)
	var reticle_box := c.y * RETICLE_START * 2.0 + 40.0
	_reticle.size = Vector2(reticle_box, reticle_box)
	_reticle.position = _aim_point - _reticle.size * 0.5

	# 글자: 왼쪽 아래 여백. 조준선(위쪽)과 그림(오른쪽)을 피한다.
	_type_root.position = Vector2(c.x * 0.06, maxf(_muzzle_screen.y + c.y * 0.2, c.y * 0.64))
	_fit_text()

	var strip_h := minf(210.0, c.y * 0.3)
	_strip.position = Vector2(0, c.y * 0.5 - strip_h * 0.5)
	_strip.size = Vector2(c.x, strip_h)
	# 띠 안의 그림은 상반신만: 그림 높이를 띠의 2.4배로 두고 머리가 띠 위쪽에 오게 한다.
	var sh := strip_h * 2.4
	var still_aspect := _frame_size.x / maxf(_frame_size.y, 1.0)
	var still_tex := _strip_art.texture
	if still_tex != null and still_tex.get_height() > 0:
		still_aspect = float(still_tex.get_width()) / float(still_tex.get_height())
	var sw := sh * still_aspect
	_strip_art.size = Vector2(sw, sh)
	# 전투 프레임은 칸 위쪽에 여백이 있어 머리가 30% 아래에 온다 — 얼굴이 띠 위쪽에 오게 올린다.
	# LD 정지 그림(전용)은 여백 없이 잘려 있어 머리가 맨 위에 온다.
	_strip_art.position = Vector2(c.x * 0.70 - sw * 0.5, -strip_h * (0.08 if _dedicated else 0.6))
	_strip_lines[0].position = Vector2(0, 0)
	_strip_lines[0].size = Vector2(c.x, 5)
	_strip_lines[1].position = Vector2(0, strip_h - 5)
	_strip_lines[1].size = Vector2(c.x, 5)
	_strip_name.position = Vector2(c.x * 0.12, strip_h * 0.16)
	_strip_skill.position = Vector2(c.x * 0.11, strip_h * 0.34)


# 이름·기술명 글자 크기를 화면 높이에 맞추고, 기술명이 쓸 폭을 넘으면 줄인다.
func _fit_text() -> void:
	var c := size
	var font := HUDKit.notice_font()
	var name_px := maxi(int(c.y * NAME_SIZE), 14)
	var skill_px := maxi(int(c.y * SKILL_SIZE), SKILL_SIZE_MIN)
	var avail := c.x * SKILL_MAX_WIDTH
	while skill_px > SKILL_SIZE_MIN \
			and font.get_string_size(_skill.text, HORIZONTAL_ALIGNMENT_LEFT, -1, skill_px).x > avail:
		skill_px -= 2
	_name.add_theme_font_size_override("font_size", name_px)
	_skill.add_theme_font_size_override("font_size", skill_px)

	var glyph_px := float(name_px) * 1.1
	_glyph.size = Vector2(glyph_px, glyph_px)
	_glyph.position = Vector2(0.0, 0.0)
	_name.position = Vector2(glyph_px + 8.0 if _glyph.texture != null else 0.0, -2.0)
	_name_row.size = Vector2(avail, glyph_px)
	_skill.position = Vector2(0.0, glyph_px + 6.0)
	var skill_w := font.get_string_size(_skill.text, HORIZONTAL_ALIGNMENT_LEFT, -1, skill_px).x
	_underline.position = Vector2(0.0, glyph_px + 6.0 + float(skill_px) * 1.3)
	_underline.size = Vector2(0.0, 2.0)
	_underline.set_meta(&"full_width", maxf(skill_w, 80.0))


# ===== 준비 =====

# art: 정지 그림(짧게 모드·애니메이션이 없을 때). anim: LD 공격 애니메이션(없으면 null).
# anim_speed: 배속 배수. emblem 은 예전 사선 판 연출의 장식이라 더는 쓰지 않는다(호출부 호환을 위해 둔다).
func setup(art: Texture2D, dedicated: bool, char_name: String, skill_name: String, color: Color,
		_emblem: Texture2D = null, glyph: Texture2D = null, anim: SpriteFrames = null,
		anim_speed: float = 1.0) -> void:
	_color = color
	_dedicated = dedicated
	_skill_text = skill_name
	_anim = anim if anim != null and anim.has_animation(ANIM_NAME) \
		and anim.get_frame_count(ANIM_NAME) > 0 else null
	_anim_speed = maxf(anim_speed, 0.1)
	_index_anim()
	_muzzle = Vector2.ZERO
	# get_meta 의 기본값이 null 이면 "기본값 없음"으로 취급돼 에러가 난다 — has_meta 로 먼저 본다.
	if _anim != null and _anim.has_meta(&"muzzle"):
		var muzzle_meta: Variant = _anim.get_meta(&"muzzle")
		if muzzle_meta is Vector2:
			_muzzle = muzzle_meta

	# 풀 연출은 조준 장에서 시작한다(정점 3장 앞). 애니메이션이 없으면 정지 그림 한 장이다.
	var entry := _anim.get_frame_texture(ANIM_NAME, _aim_frame()) if _anim != null else art
	_art.texture = entry
	_strip_art.texture = art

	_glyph.texture = glyph
	_glyph.modulate = color.lightened(0.35)
	_name.text = char_name
	_name.add_theme_color_override("font_color", Color(0.86, 0.88, 1.0))
	_skill.text = skill_name
	_skill.add_theme_color_override("font_color", Color(0.97, 0.97, 1.0))
	_underline.color = color.lightened(0.45)

	# 막: 원소색 색조를 지키며 아주 어둡게. 노랑이 올리브로 탁해지지 않게 채도는 남긴다.
	_deep.texture = _make_deep_texture(color)
	_aim_line.texture = _make_aim_texture(color)
	_reticle.color = color.lightened(0.5)

	_strip_bg.fill = Color(0.09, 0.08, 0.07, 0.95)
	_strip_bg.edge = color
	_strip_name.text = char_name
	_strip_name.add_theme_color_override("font_color", color.lightened(0.3))
	_strip_skill.text = skill_name
	_strip_skill.add_theme_color_override("font_color", UITheme.CREAM)
	for line in _strip_lines:
		line.color = color
	_layout()


# 재생 중이던 연출을 끊고 처음 상태로 되돌린다(전투 재시작 등).
func reset() -> void:
	_token += 1
	visible = false
	modulate = Color.WHITE
	_dim.color.a = 0.0
	_white.color.a = 0.0
	_strip.visible = false
	_clear_fx()
	_hide_full()


# 조준 장: 정점 3장 앞(조준을 마친 자세). 범위를 넘지 않게 자른다.
func _aim_frame() -> int:
	if _anim == null:
		return 0
	return maxi(_anim_strike - 3, 0)


func _make_deep_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.from_hsv(color.h, 0.55, DEEP_VALUE_INNER, DEEP_ALPHA_INNER))
	gradient.set_color(1, Color.from_hsv(color.h, 0.60, DEEP_VALUE_OUTER, DEEP_ALPHA_OUTER))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.62, 0.38)
	texture.fill_to = Vector2(1.25, 0.38)
	texture.width = 256
	texture.height = 256
	return texture


# 왼쪽 끝은 투명, 총구 쪽은 선명한 가로 그라데이션 한 줄.
func _make_aim_texture(color: Color) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(color.lightened(0.5), 0.0))
	gradient.set_color(1, Color(color.lightened(0.6), 0.85))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 2
	return texture


# ===== 풀 연출 =====

# 컷인 부분(약 1.45초)을 재생한다. 끝나면 **남색 막이 필드 위에서 걷히는 중**이므로
# 호출부(`TurnBattle`)는 곧바로 필드 연출을 이어 붙인다.
func play_full() -> void:
	_token += 1
	var token := _token
	_prepare_full()
	var c := size

	# 0.00~0.15 암전
	var t := _tween()
	t.tween_property(_deep, "modulate:a", 1.0, _s(T_DIM))
	if not await _hold(T_DIM, token):
		return

	# 0.15~0.55 클로즈업 — 들어오면서 천천히 밀려 든다. 밀려 드는 것은 정적(0.95)까지 이어진다.
	_art.position = _home_art + Vector2(ENTER_SLIDE, 0.0)
	_art.scale = Vector2.ONE * ZOOM_START
	var name_home := _name_row.position
	_name_row.position = name_home + Vector2(-14.0, 0.0)
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_crop, "modulate:a", 1.0, _s(0.20))
	t.tween_property(_art, "position", _home_art, _s(T_CLOSEUP)) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(_art, "scale", Vector2.ONE * ZOOM_END, _s(T_CLOSEUP + T_AIM)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(_name_row, "modulate:a", 1.0, _s(0.18)).set_delay(_s(0.15))
	t.tween_property(_name_row, "position", name_home, _s(0.25)).set_delay(_s(0.15)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not await _hold(T_CLOSEUP, token):
		return

	# 0.55~0.95 조준 — 조준선이 한 점으로 모이고 전기가 빨려 든다. 기술명이 뜬다.
	var skill_home := _skill.position
	_skill.position = skill_home + Vector2(-14.0, 0.0)
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_reticle, "modulate:a", 1.0, _s(0.12))
	t.tween_property(_reticle, "radius", 14.0, _s(T_AIM)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_aim_line, "scale:x", 1.0, _s(T_AIM)) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(_aim_line, "modulate:a", 1.0, _s(0.12))
	t.tween_property(_skill, "modulate:a", 1.0, _s(0.16))
	t.tween_property(_skill, "position", skill_home, _s(0.24)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_underline, "size:x", float(_underline.get_meta(&"full_width", 120.0)), _s(0.30)) \
		.set_delay(_s(0.10)).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_spawn_converging_arcs(token)
	cue.emit(&"ult_charge")
	if not await _hold(T_AIM, token):
		return

	# 0.95~1.10 정적 — 움직임이 멈춘다. 확대는 이미 끝났고, 고리는 한 점이며, 막만 한 번 더 가라앉는다.
	_art.scale = Vector2.ONE * ZOOM_END
	t = _tween()
	t.tween_property(_deep, "modulate", Color(0.82, 0.82, 0.9, 1.0), _s(T_FREEZE))
	if not await _hold(T_FREEZE, token):
		return

	# 1.10~1.35 발사
	_fire()
	if not await _hold(T_FIRE, token):
		return

	# 컷인을 걷는다. 남색 막은 필드 연출 아래에서 천천히 걷힌다.
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_crop, "modulate:a", 0.0, _s(T_EXIT))
	t.tween_property(_type_root, "modulate:a", 0.0, _s(T_EXIT))
	t.tween_property(_aim_line, "modulate:a", 0.0, _s(T_EXIT))
	t.tween_property(_reticle, "modulate:a", 0.0, _s(T_EXIT))
	var tail := _tween()
	tail.tween_property(_deep, "modulate:a", 0.0, _s(T_FADE_TAIL))
	tail.tween_callback(_finish.bind(token))
	if not await _hold(T_EXIT, token):
		return


# 발사: 정점 장으로 바꾸고, 총구에서 왼쪽 가장자리로 번개 한 줄이 나간다. 그림이 짧게 반동한다.
func _fire() -> void:
	_anim_struck = true
	_show_anim_frame(_anim_strike if _anim != null else 0)
	cue.emit(&"ult_fire")

	# 반동: 오른쪽·아래로 밀렸다 돌아온다.
	var kick := _tween()
	kick.tween_property(_art, "position", _home_art + RECOIL, _s(0.04)).set_ease(Tween.EASE_OUT)
	kick.tween_property(_art, "position", _home_art, _s(0.18)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 반동 장: 정점 뒤 몇 장을 짧은 간격으로 넘긴다(애니메이션이 있을 때).
	if _anim != null:
		var last := _anim.get_frame_count(ANIM_NAME) - 1
		var frames := _tween()
		for i in range(1, RECOIL_FRAMES + 1):
			var idx := mini(_anim_strike + i, last)
			frames.tween_interval(_s(RECOIL_FRAME_STEP))
			frames.tween_callback(_show_anim_frame.bind(idx))

	# 조준 고리는 터지듯 사라지고, 번개가 나간다.
	var ring := _tween()
	ring.set_parallel(true)
	ring.tween_property(_reticle, "radius", 90.0, _s(0.14)).set_ease(Tween.EASE_OUT)
	ring.tween_property(_reticle, "modulate:a", 0.0, _s(0.14))
	_spawn_bolt(_muzzle_screen, Vector2(-24.0, _muzzle_screen.y + 2.0), 0.26, 1.0)
	_spawn_sparks(_muzzle_screen, 10)
	_spawn_sparks(_aim_point, 6)


# 총구로 빨려 드는 작은 전기: 둘레에서 짧은 꺾은선이 한 점을 향해 모이며 사라진다.
func _spawn_converging_arcs(token: int) -> void:
	var count := 9
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var dist := randf_range(0.18, 0.30) * size.y
		var arc := Line2D.new()
		arc.width = 2.0
		arc.default_color = _color.lightened(0.6)
		arc.material = additive()
		arc.points = jagged(Vector2.ZERO, Vector2.RIGHT.rotated(angle + PI) * randf_range(26.0, 42.0), 5.0, 12.0)
		arc.position = _muzzle_screen + Vector2.RIGHT.rotated(angle) * dist
		arc.modulate.a = 0.0
		_fx.add_child(arc)
		var delay := T_AIM * 0.9 * float(i) / float(count)
		var life := T_AIM * 0.55
		var t := arc.create_tween()
		t.set_parallel(true)
		t.tween_property(arc, "modulate:a", 0.9, _s(0.06)).set_delay(_s(delay))
		t.tween_property(arc, "position", _muzzle_screen, _s(life)).set_delay(_s(delay)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.chain().tween_property(arc, "modulate:a", 0.0, _s(0.05))
		t.chain().tween_callback(arc.queue_free)


# 번개 한 줄: 꺾은선 두 겹(굵은 원소색 후광 + 가는 흰 심지). 오래 두지 않고 곧 걷는다.
func _spawn_bolt(from: Vector2, to: Vector2, life: float, power: float) -> void:
	var points := jagged(from, to, 9.0 * power, 46.0)
	var glow := Line2D.new()
	glow.width = 14.0 * power
	glow.default_color = Color(_color.lightened(0.2), 0.40)
	glow.points = points
	glow.material = additive()
	_fx.add_child(glow)
	var core := Line2D.new()
	core.width = 4.0 * power
	core.default_color = Color(1, 1, 1, 0.95)
	core.points = points
	core.material = additive()
	_fx.add_child(core)
	for line in [glow, core]:
		var t: Tween = line.create_tween()
		t.set_parallel(true)
		t.tween_property(line, "modulate:a", 0.0, _s(life)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(line, "width", line.width * 0.3, _s(life))
		t.chain().tween_callback(line.queue_free)


# 총구에서 튀는 잔 불꽃. 방향은 발사 방향(왼쪽) 쪽으로 치우친다.
func _spawn_sparks(at: Vector2, count: int) -> void:
	for i in count:
		var spark := Line2D.new()
		spark.width = 2.0
		spark.default_color = _color.lightened(0.6)
		spark.material = additive()
		var dir := Vector2.LEFT.rotated(randf_range(-0.9, 0.9))
		spark.points = PackedVector2Array([Vector2.ZERO, dir * randf_range(8.0, 18.0)])
		spark.position = at
		_fx.add_child(spark)
		var t := spark.create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "position", at + dir * randf_range(50.0, 130.0), _s(0.28)) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "modulate:a", 0.0, _s(0.28))
		t.chain().tween_callback(spark.queue_free)


# 꺾은선: from 에서 to 로 가며 수직으로 흔들린다. 양 끝은 고정한다.
static func jagged(from: Vector2, to: Vector2, amp: float, step: float) -> PackedVector2Array:
	var points := PackedVector2Array([from])
	var length := from.distance_to(to)
	var count := maxi(int(length / step), 1)
	var dir := (to - from).normalized()
	var normal := Vector2(-dir.y, dir.x)
	for i in range(1, count):
		var along := from.lerp(to, float(i) / float(count))
		points.append(along + normal * randf_range(-amp, amp))
	points.append(to)
	return points


static func additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _prepare_full() -> void:
	visible = true
	modulate = Color.WHITE
	_strip.visible = false
	_anim_struck = false
	_clear_fx()
	for node in [_crop, _aim_line, _reticle, _type_root]:
		node.visible = true
		node.modulate = Color.WHITE
	_deep.visible = true
	_deep.modulate = Color(1, 1, 1, 0)
	_crop.modulate.a = 0.0
	_aim_line.modulate.a = 0.0
	_aim_line.scale = Vector2(0.0, 1.0)
	_reticle.modulate.a = 0.0
	_reticle.radius = size.y * RETICLE_START
	_name_row.modulate.a = 0.0
	_skill.modulate.a = 0.0
	_underline.size.x = 0.0
	_art.scale = Vector2.ONE
	_anim_frame = -1
	_show_anim_frame(_aim_frame())
	_dim.color.a = 0.0
	_white.color.a = 0.0
	_layout()


func _hide_full() -> void:
	for node in [_crop, _aim_line, _reticle, _type_root, _deep]:
		node.visible = false


# 막이 다 걷히면 판을 접는다. 그 사이 새 재생이 시작됐으면(토큰이 바뀌었으면) 건드리지 않는다.
func _finish(token: int) -> void:
	if token != _token:
		return
	_hide_full()
	_clear_fx()
	visible = false


func _clear_fx() -> void:
	for child in _fx.get_children():
		_fx.remove_child(child)
		child.queue_free()


# ===== 원화 =====

# 원화 한 장을 보인다. 같은 장이면 건너뛴다.
func _show_anim_frame(idx: int) -> void:
	if _anim == null or idx == _anim_frame:
		return
	_anim_frame = idx
	_art.texture = _anim.get_frame_texture(ANIM_NAME, idx)


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


# ===== 짧게 =====

func play_short() -> void:
	_token += 1
	var token := _token
	visible = true
	modulate = Color.WHITE
	_hide_full()
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


# 풀 연출 글자: 기울이지 않고 얇은 그림자만 둔다. 한글 알림 폰트 한 계열.
func _plain_label() -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", HUDKit.notice_font())
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
