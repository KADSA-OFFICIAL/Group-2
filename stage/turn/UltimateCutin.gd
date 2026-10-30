extends Control
class_name UltimateCutin

# 오의 컷인 판 (#544, 풀 연출은 #576 에서 재설계). 전투 화면(`TurnBattle`)이 한 번 만들어 두고,
# 오의마다 그림과 글자만 갈아 끼워 재생한다.
#
# ## 풀 연출 — "정확히 조준하고, 짧은 정적 뒤 한 발로 타격한다" (기본 약 2.2초)
#
# 캐릭터 소개 배너가 아니라 **행동**을 보여 준다. 전신 대신 얼굴·상체·무기를 크롭하고,
# 사선 판·속도선·거대한 글자를 없앴다. 시간은 컷인(이 파일)과 필드(`TurnBattle._play_ult_field`)가 나눠 갖는다.
# 단계마다 구도가 달라야 읽힌다 — 클로즈업(머리~허벅지) → 조준(얼굴·손·석궁으로 밀려 듦) → 정적(멈춤)
# → 발사(반동·섬광) → 그림을 빨리 걷고 전장의 실제 대상이 맞는다.
#
#   0.00~0.15  암전          필드가 짙은 남색으로 가라앉는다 (전투 UI·떠 있던 숫자는 `TurnBattle` 이 치운다)
#   0.15~0.55  클로즈업      머리~허벅지 구도로 발사 반대쪽에서 들어온다. 반투명은 처음 0.08초뿐
#                            들어오면서부터 조준 끝까지 원화를 넘겨 인물이 공격 자세를 잡는다(LEAD_FRAMES)
#   0.55~0.95  조준          총구를 축으로 얼굴·손·석궁까지 밀려 든다. 조준 고리가 발사 방향의 조준점으로 모이고
#                            작은 전기가 총구로 빨려 든다. 이름·기술명이 한 묶음으로 뜬다
#   0.95~1.10  정적          모든 움직임이 멈춘다 — 발사 직전의 긴장. 글자는 여기서 읽힌다
#   1.10~1.28  발사          공격 정점 장 + 발사 반대쪽으로 짧은 반동 + 발사 방향으로 짧은 섬광. 고리는 바로 꺼진다
#   1.28~1.40  걷기          그림·글자를 걷고 남색 막이 빠르게 걷힌다 (여기까지가 이 파일 `play_full`)
#   이후       피격          필드에서 번개가 캐스터에서 실제 대상으로 이어진다. 피해 숫자는 그 피격 순간에 뜬다 (`TurnBattle`)
#   마지막     UI 복구       전투 UI 가 돌아온다 (`TurnBattle`)
#
# **발사 방향**: 원화는 왼쪽을 겨눈다. 전장에서 아군은 오른쪽(적)을 쏘므로 그림을 좌우로 뒤집어
# 컷인에서 쏜 방향과 전장에서 맞는 방향을 잇는다(`MIRROR_TO_FIELD`). 글자는 발사 쪽 여백에 선다.
#
# 밝은 전면 플래시와 지속 흔들림은 쓰지 않는다. 빛은 조준점·총구 섬광·잔 전기에만 모은다.
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
const T_FIRE: float = 0.18          # 1.10 -> 1.28
const T_EXIT: float = 0.12          # 1.28 -> 1.40  그림·글자를 걷는다
const T_FADE_TAIL: float = 0.22     # 남색 막이 걷히는 시간(필드 피격과 겹친다)
## 그림이 반투명한 시간. 짧게 둬 조준 전에 완전히 불투명해진다.
const T_ART_FADE_IN: float = 0.08

## 인물의 머리부터 이만큼(인물 높이 비)이 화면 높이를 채운다 — 얼굴·상체·무기. 나머지는 화면 아래로 나간다.
## 인물 높이는 원화 칸이 아니라 실제로 그려진 영역(`_figure_rect`)이다. 전투 스프라이트(저해상도)는 덜 자른다.
const CROP_FRAC: float = 0.85
const CROP_FRAC_SPRITE: float = 0.9
## 인물이 화면 폭에서 차지할 수 있는 최대 비. 넘으면 그림을 줄인다.
const CROP_MAX_WIDTH: float = 0.6
## 가장 밀려 든(ZOOM_TIGHT) 순간에도 머리 위에 남기는 여백(화면 높이 비).
const HEAD_ROOM: float = 0.03
## 구도: 클로즈업은 머리~허벅지(ZOOM_START), 조준 동안 총구를 축으로 얼굴·손·석궁까지 밀려 든다(ZOOM_TIGHT).
## 인물이 화면 안에 잘리지 않고 들어오도록 밀려 드는 폭을 작게 둔다(1.15배).
const ZOOM_START: float = 1.0
const ZOOM_TIGHT: float = 1.15
## 들어올 때·걷을 때 발사 반대쪽으로 움직이는 거리(px).
const ENTER_SLIDE: float = 60.0
const EXIT_SLIDE: float = 48.0
## 발사 반동: 발사 반대쪽으로 RECOIL, 아래로 RECOIL_DROP 만큼 밀렸다 돌아온다(px).
const RECOIL: float = 16.0
const RECOIL_DROP: float = 4.0
## 반동 장을 넘기는 간격(초, 배속 적용 전). 정점 장 뒤로 몇 장 더 보여 준다.
const RECOIL_FRAME_STEP: float = 0.05
const RECOIL_FRAMES: int = 4
## 클로즈업·조준 동안 원화를 넘긴다: 조준 장보다 이만큼 앞 장에서 시작해 정점 바로 앞 장까지.
## 카메라가 밀려 드는 동안 인물도 공격 자세를 잡는다. 너무 앞(서 있는 장)에서 시작하면 머리가 높아
## 조준 자세 기준 구도에서 화면 위로 나간다.
const LEAD_FRAMES: int = 5

## 원화를 좌우로 뒤집어 전장의 발사 방향(오른쪽)과 맞춘다. false 면 원화 그대로(왼쪽으로 쏜다).
const MIRROR_TO_FIELD: bool = true

## 막 색: 원소색 색조를 지키되 아주 어둡게 — 남보라 계열의 깊이. (안쪽, 바깥)
const DEEP_VALUE_INNER: float = 0.30
const DEEP_VALUE_OUTER: float = 0.07
const DEEP_ALPHA_INNER: float = 0.62
const DEEP_ALPHA_OUTER: float = 0.93

## 조준점: 총구에서 발사 방향으로 이만큼(화면 폭 비). 고리는 시작 반지름(화면 높이 비)에서 RETICLE_END(px)로 모인다.
const AIM_DISTANCE: float = 0.22
const RETICLE_START: float = 0.16
const RETICLE_END: float = 12.0
## 발사 섬광: 총구에서 발사 방향으로 짧게(화면 폭 비) 뻗었다가 곧 사라진다. 화면을 가로지르지 않는다.
const FLASH_LENGTH: float = 0.12
const FLASH_TIME: float = 0.10
## 총구 위치를 모를 때: 인물의 발사 쪽 가장자리, 인물 머리에서 이만큼(인물 높이 비) 아래.
const MUZZLE_DEFAULT_HEIGHT: float = 0.22
## 이름·기술명 글자 크기(화면 높이 비). 기술명은 #576 1차(0.066)의 약 1.6배.
const NAME_SIZE: float = 0.036
const SKILL_SIZE: float = 0.105
const SKILL_SIZE_MIN: int = 36
## 글자 묶음: 발사 쪽 여백, 화면 중앙보다 조금 아래(위쪽 가장자리, 화면 높이 비). 들여쓰기(화면 폭 비).
const TYPE_TOP: float = 0.58
## 대상이 화면 아래쪽이어도 글자 묶음이 이보다 내려가지 않는다(화면 높이 비).
const TYPE_BOTTOM: float = 0.70
const TYPE_INSET: float = 0.05
## 기술명은 따뜻한 아이보리, 이름은 차분한 연회색. 원소색은 기호와 짧은 포인트 선에만.
const SKILL_COLOR := Color("F4EEDC")
const NAME_COLOR := Color(0.86, 0.85, 0.92)
const ACCENT_WIDTH: float = 44.0

var _token: int = 0
var _color: Color = Color.WHITE
var _dedicated: bool = false

# 풀 연출
var _dim: ColorRect
var _deep: TextureRect
var _crop: Control
var _art: TextureRect
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
## 그림(SpriteFrames 또는 정지 그림)마다 인물이 그려진 영역(원화 픽셀, 뒤집기 전). `_figure_rect` 가 채운다.
var _figure_cache: Dictionary = {}
## 화면에서 총구가 놓이는 점. `_layout()` 이 정한다(정적 때의 확대 배율 기준).
var _muzzle_screen: Vector2 = Vector2.ZERO
## 조준 고리가 모이는 점. 대상이 있으면 그 대상, 없으면 발사 방향 여백 위.
var _aim_point: Vector2 = Vector2.ZERO
## 실제로 맞을 대상의 화면 좌표(이 판 기준). 없으면 Vector2.INF. `set_aim_target()` 이 정한다.
var _aim_target: Vector2 = Vector2.INF
var _home_art: Vector2 = Vector2.ZERO
## 그림을 뒤집었는가, 발사 방향, 글자 묶음이 쓸 수 있는 폭. `_layout()` 이 정한다.
var _mirror: bool = false
var _fire_dir: Vector2 = Vector2.LEFT
var _type_width: float = 0.0

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

	# 그림 판: 화면 전체. 자르지 않는다 — 상자 가장자리가 그림을 끊으면 인물이 잘려 보인다.
	# 하체는 크기·위치로 화면 아래 밖에 둔다(`_layout`).
	_crop = Control.new()
	_crop.clip_contents = false
	_crop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crop)
	_art = _texture_rect()
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_crop.add_child(_art)

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

	# 인물(원화에서 실제로 그려진 영역)의 머리~허벅지가 화면 높이를 채우고, 발사 반대쪽 화면 가장자리에 붙는다.
	# 반대편은 발사 방향의 여백이다. 원화 칸의 빈 여백은 캐릭터마다 달라 칸 기준으로 자르면 인물이 밀려난다.
	var tex := _art.texture
	if _anim != null:
		tex = _anim.get_frame_texture(ANIM_NAME, 0)
	_frame_size = tex.get_size() if tex != null else Vector2(716.0, 1152.0)
	_fire_dir = Vector2.RIGHT if _mirror else Vector2.LEFT
	_crop.position = Vector2.ZERO
	_crop.size = c

	var figure := _figure_rect()
	var crop_frac := CROP_FRAC if _dedicated else CROP_FRAC_SPRITE

	# 총구(원화 좌표, 뒤집기 전). 모르면 인물의 발사 쪽(원화는 왼쪽을 겨눈다) 가장자리, 상체 높이.
	var muzzle_px := _muzzle if _muzzle != Vector2.ZERO \
		else Vector2(figure.position.x, figure.position.y + figure.size.y * MUZZLE_DEFAULT_HEIGHT)

	# 확대는 **총구를 축으로** 한다 — 밀려 들어도 총구·조준점·전기가 제자리에 있다. 머리는 축보다 위라
	# 밀려 들수록 올라가므로, 가장 밀려 든 순간에 머리 위 여백이 HEAD_ROOM 이 되게 처음부터 그만큼 내려 둔다.
	# 배율은 그 여백까지 더해 인물의 crop_frac 이 화면 바닥에 딱 닿게 정한다.
	var above_px := maxf(muzzle_px.y - figure.position.y, 0.0)
	var art_scale := c.y * (1.0 - HEAD_ROOM) \
		/ maxf(figure.size.y * crop_frac + above_px * (ZOOM_TIGHT - 1.0), 1.0)
	if figure.size.x * art_scale > c.x * CROP_MAX_WIDTH:
		art_scale = c.x * CROP_MAX_WIDTH / figure.size.x

	if _mirror:
		muzzle_px.x = _frame_size.x - muzzle_px.x
		figure.position.x = _frame_size.x - figure.end.x
	var above := above_px * art_scale
	var figure_top := c.y * HEAD_ROOM + above * (ZOOM_TIGHT - 1.0)
	var figure_x := 0.0 if _mirror else c.x - figure.size.x * art_scale
	_art.size = _frame_size * art_scale
	_art.position = Vector2(figure_x - figure.position.x * art_scale, figure_top - figure.position.y * art_scale)
	_home_art = _art.position

	var m := muzzle_px * art_scale
	_art.pivot_offset = m
	_muzzle_screen = _art.position + m

	# 인물의 발사 쪽 가장자리(화면 x). 밀려 든 뒤에도 글자 여백을 넘지 않게 두 배율 중 바깥쪽을 쓴다.
	var inner := _art.position.x + (figure.end.x if _mirror else figure.position.x) * art_scale
	var inner_tight := _muzzle_screen.x + (inner - _muzzle_screen.x) * ZOOM_TIGHT
	inner = maxf(inner, inner_tight) if _mirror else minf(inner, inner_tight)

	# 조준점: 전장에서 실제로 맞을 대상. 고리는 여기서 한 점으로 모이고, 필드 번개가 같은 자리에 꽂힌다.
	# 대상을 모르면(검증 장면 등) 총구 높이에서 발사 방향 여백 위.
	if _aim_target.is_finite():
		_aim_point = _aim_target
	else:
		_aim_point = _muzzle_screen + _fire_dir * (c.x * AIM_DISTANCE)
		_aim_point.x = clampf(_aim_point.x, c.x * 0.08, c.x * 0.92)
	var reticle_box := c.y * RETICLE_START * 2.0 + 40.0
	_reticle.size = Vector2(reticle_box, reticle_box)
	_reticle.position = _aim_point - _reticle.size * 0.5

	# 글자 묶음: 발사 쪽 여백, 화면 중앙보다 조금 아래. 조준 고리(위)와 그림(옆)을 피한다.
	var margin_from := clampf(inner, 0.0, c.x) if _mirror else 0.0
	var margin_to := c.x if _mirror else clampf(inner, 0.0, c.x)
	_type_width = margin_to - margin_from - c.x * TYPE_INSET * 2.0
	_type_root.position = Vector2(margin_from + c.x * TYPE_INSET,
		clampf(_aim_point.y + c.y * RETICLE_START + 12.0, c.y * TYPE_TOP, c.y * TYPE_BOTTOM))
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


# 이름·기술명 글자 크기를 화면 높이에 맞추고, 기술명이 여백 폭을 넘으면 줄인다.
func _fit_text() -> void:
	var c := size
	var font := HUDKit.notice_font()
	var name_px := maxi(int(c.y * NAME_SIZE), 14)
	var skill_px := maxi(int(c.y * SKILL_SIZE), SKILL_SIZE_MIN)
	var avail := maxf(_type_width, 120.0)
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
	_skill.position = Vector2(0.0, glyph_px + 2.0)
	# 기술명 아래 짧은 원소색 포인트 선(긴 밑줄이 아니다).
	_underline.position = Vector2(2.0, glyph_px + 2.0 + float(skill_px) * 1.18)
	_underline.size = Vector2(ACCENT_WIDTH, 2.0)


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
	_name.add_theme_color_override("font_color", NAME_COLOR)
	_skill.text = skill_name
	_skill.add_theme_color_override("font_color", SKILL_COLOR)
	_underline.color = color.lerp(Color.WHITE, 0.45)
	_mirror = MIRROR_TO_FIELD
	_art.flip_h = _mirror
	_aim_target = Vector2.INF

	# 막: 원소색 색조를 지키며 아주 어둡게. 노랑이 올리브로 탁해지지 않게 채도는 남긴다.
	_deep.texture = _make_deep_texture(color)
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


# 조준 고리가 모일 대상의 화면 좌표(이 판 기준). `setup()` 뒤에 부른다 — `setup()` 은 대상을 지운다.
func set_aim_target(point: Vector2) -> void:
	_aim_target = point
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


# 클로즈업이 시작하는 장: 조준 장보다 LEAD_FRAMES 앞.
func _lead_frame() -> int:
	return maxi(_aim_frame() - LEAD_FRAMES, 0)


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


# ===== 풀 연출 =====

# 컷인 부분(약 1.4초)을 재생한다. 끝나면 **남색 막이 필드 위에서 걷히는 중**이므로
# 호출부(`TurnBattle`)는 곧바로 필드 피격을 이어 붙인다.
func play_full() -> void:
	_token += 1
	var token := _token
	_prepare_full()

	# 0.00~0.15 암전
	var t := _tween()
	t.tween_property(_deep, "modulate:a", 1.0, _s(T_DIM))
	if not await _hold(T_DIM, token):
		return

	# 0.15~0.55 클로즈업 — 머리~허벅지 구도로 발사 반대쪽에서 들어온다. 반투명은 아주 짧다.
	# 들어오는 순간부터 조준이 끝날 때까지 원화를 넘겨, 밀려 드는 카메라와 함께 인물이 공격 자세를 잡는다.
	_art.position = _home_art - _fire_dir * ENTER_SLIDE
	_art.scale = Vector2.ONE * ZOOM_START
	if _anim != null:
		# 재시작(`reset()`)으로 토큰이 바뀌면 넘기지 않는다 — 트윈은 판이 접혀도 남아 돈다.
		var step := func(v: float) -> void:
			if token == _token:
				_show_anim_frame(int(v))
		var lead := _tween()
		lead.tween_method(step, float(_lead_frame()), float(maxi(_anim_strike - 1, _lead_frame())),
			_s(T_CLOSEUP + T_AIM * 0.85))
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_crop, "modulate:a", 1.0, _s(T_ART_FADE_IN))
	t.tween_property(_art, "position", _home_art, _s(T_CLOSEUP * 0.8)) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	if not await _hold(T_CLOSEUP, token):
		return

	# 0.55~0.95 조준 — 총구를 축으로 얼굴·손·석궁까지 밀려 든다. 고리가 조준점으로 모이고 전기가 총구로 빨려 든다.
	# 이름·기술명은 한 묶음으로 여기서 뜬다 — 정적 구간까지 읽히고, 피격으로 넘어갈 때 걷힌다.
	var type_home := _type_root.position
	_type_root.position = type_home + Vector2(0.0, 10.0)
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_art, "scale", Vector2.ONE * ZOOM_TIGHT, _s(T_AIM * 0.85)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(_reticle, "modulate:a", 1.0, _s(0.10))
	t.tween_property(_reticle, "radius", RETICLE_END, _s(T_AIM * 0.85)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(_type_root, "modulate:a", 1.0, _s(0.14))
	t.tween_property(_type_root, "position", type_home, _s(0.22)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_spawn_converging_arcs(token)
	cue.emit(&"ult_charge")
	if not await _hold(T_AIM, token):
		return

	# 0.95~1.10 정적 — 아무것도 움직이지 않는다. 확대·고리·전기는 조준 구간 안에서 이미 끝났다.
	_art.scale = Vector2.ONE * ZOOM_TIGHT
	_reticle.radius = RETICLE_END
	if not await _hold(T_FREEZE, token):
		return

	# 1.10~1.28 발사
	_fire()
	if not await _hold(T_FIRE, token):
		return

	# 1.28~1.40 걷기 — 큰 그림과 글자를 빨리 치워 전장의 실제 피격 대상이 가려지지 않게 한다.
	t = _tween()
	t.set_parallel(true)
	t.tween_property(_crop, "modulate:a", 0.0, _s(T_EXIT))
	t.tween_property(_art, "position", _home_art - _fire_dir * EXIT_SLIDE, _s(T_EXIT)) \
		.set_ease(Tween.EASE_IN)
	t.tween_property(_type_root, "modulate:a", 0.0, _s(T_EXIT))
	var tail := _tween()
	tail.tween_property(_deep, "modulate:a", 0.0, _s(T_FADE_TAIL))
	tail.tween_callback(_finish.bind(token))
	if not await _hold(T_EXIT, token):
		return


# 발사: 정점 장으로 바꾸고, 발사 반대쪽으로 짧게 반동하며, 총구에서 발사 방향으로 짧은 섬광이 난다.
func _fire() -> void:
	_anim_struck = true
	_show_anim_frame(_anim_strike if _anim != null else 0)
	cue.emit(&"ult_fire")

	# 반동: 발사 반대쪽·아래로 밀렸다 돌아온다.
	var back := -_fire_dir * RECOIL + Vector2(0.0, RECOIL_DROP)
	var kick := _tween()
	kick.tween_property(_art, "position", _home_art + back, _s(0.04)).set_ease(Tween.EASE_OUT)
	kick.tween_property(_art, "position", _home_art, _s(0.14)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# 반동 장: 정점 뒤 몇 장을 짧은 간격으로 넘긴다(애니메이션이 있을 때).
	if _anim != null:
		var last := _anim.get_frame_count(ANIM_NAME) - 1
		var frames := _tween()
		for i in range(1, RECOIL_FRAMES + 1):
			var idx := mini(_anim_strike + i, last)
			frames.tween_interval(_s(RECOIL_FRAME_STEP))
			frames.tween_callback(_show_anim_frame.bind(idx))

	# 조준 고리는 그 자리에서 바로 꺼진다 — 발사 뒤에 고리가 다시 커지거나 강조되지 않는다.
	var ring := _tween()
	ring.tween_property(_reticle, "modulate:a", 0.0, _s(0.06))
	_spawn_muzzle_flash()
	_spawn_sparks(_muzzle_screen, 8)


# 총구에서 조준점으로 향하는 방향. 조준점이 총구와 겹치면 발사 방향.
func _shot_dir() -> Vector2:
	var to_aim := _aim_point - _muzzle_screen
	return to_aim.normalized() if to_aim.length() > 1.0 else _fire_dir


# 발사 섬광: 총구에서 조준점 쪽으로 짧게 뻗어 끝으로 가늘어지는 빛(흰 심지 + 원소색 후광). 곧 사라진다.
func _spawn_muzzle_flash() -> void:
	var end := _muzzle_screen + _shot_dir() * (size.x * FLASH_LENGTH)
	var taper := Curve.new()
	taper.add_point(Vector2(0.0, 1.0))
	taper.add_point(Vector2(1.0, 0.0))
	for spec in [[18.0, Color(_color.lightened(0.3), 0.55)], [6.0, Color(1, 1, 1, 0.95)]]:
		var line := Line2D.new()
		line.points = PackedVector2Array([_muzzle_screen, end])
		line.width = float(spec[0])
		line.width_curve = taper
		line.default_color = spec[1]
		line.material = additive()
		_fx.add_child(line)
		var t := line.create_tween()
		t.tween_property(line, "modulate:a", 0.0, _s(FLASH_TIME)).set_ease(Tween.EASE_IN)
		t.tween_callback(line.queue_free)


# 총구로 빨려 드는 작은 전기: 둘레에서 짧은 꺾은선이 한 점을 향해 모이며 사라진다.
# 조준 구간 안에서 끝난다 — 정적 구간에는 움직이는 것이 없어야 한다.
func _spawn_converging_arcs(token: int) -> void:
	var count := 9
	for i in count:
		var angle := TAU * float(i) / float(count) + randf_range(-0.3, 0.3)
		var dist := randf_range(0.14, 0.24) * size.y
		var arc := Line2D.new()
		arc.width = 2.0
		arc.default_color = _color.lightened(0.6)
		arc.material = additive()
		arc.points = jagged(Vector2.ZERO, Vector2.RIGHT.rotated(angle + PI) * randf_range(26.0, 42.0), 5.0, 12.0)
		arc.position = _muzzle_screen + Vector2.RIGHT.rotated(angle) * dist
		arc.modulate.a = 0.0
		_fx.add_child(arc)
		var delay := T_AIM * 0.45 * float(i) / float(count)
		var life := T_AIM * 0.40
		var t := arc.create_tween()
		t.set_parallel(true)
		t.tween_property(arc, "modulate:a", 0.9, _s(0.06)).set_delay(_s(delay))
		t.tween_property(arc, "position", _muzzle_screen, _s(life)).set_delay(_s(delay)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.chain().tween_property(arc, "modulate:a", 0.0, _s(0.05))
		t.chain().tween_callback(arc.queue_free)


# 총구에서 튀는 잔 불꽃. 방향은 발사 방향 쪽으로 치우친다.
func _spawn_sparks(at: Vector2, count: int) -> void:
	for i in count:
		var spark := Line2D.new()
		spark.width = 2.0
		spark.default_color = _color.lightened(0.6)
		spark.material = additive()
		var dir := _shot_dir().rotated(randf_range(-0.9, 0.9))
		spark.points = PackedVector2Array([Vector2.ZERO, dir * randf_range(8.0, 18.0)])
		spark.position = at
		_fx.add_child(spark)
		var t := spark.create_tween()
		t.set_parallel(true)
		t.tween_property(spark, "position", at + dir * randf_range(50.0, 130.0), _s(0.24)) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(spark, "modulate:a", 0.0, _s(0.24))
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
	for node in [_crop, _reticle, _type_root]:
		node.visible = true
		node.modulate = Color.WHITE
	_deep.visible = true
	_deep.modulate = Color(1, 1, 1, 0)
	_crop.modulate.a = 0.0
	_reticle.modulate.a = 0.0
	_reticle.radius = size.y * RETICLE_START
	_type_root.modulate.a = 0.0
	_name_row.modulate.a = 1.0
	_skill.modulate.a = 1.0
	_art.flip_h = _mirror
	_art.scale = Vector2.ONE
	_anim_frame = -1
	_show_anim_frame(_lead_frame())
	_dim.color.a = 0.0
	_white.color.a = 0.0
	_layout()


func _hide_full() -> void:
	for node in [_crop, _reticle, _type_root, _deep]:
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


# 인물이 실제로 그려진 영역(원화 픽셀, 뒤집기 전). 그림마다 한 번만 센다. 셀 수 없으면 원화 칸 전체.
# 위아래는 카메라가 밀려 드는 동안 보이는 장(시작 장 ~ 조준 장)의 불투명 영역이다 — 발사 장에서 무기를
# 높이 치켜드는 캐릭터(태희)까지 합치면 머리 위가 텅 비어 얼굴이 화면 아래로 밀린다. 좌우는 풀 연출이
# 보여 주는 장(시작 장 ~ 마지막 반동 장)을 모두 합쳐, 인물이 글자 여백으로 넘어가지 않게 한다.
func _figure_rect() -> Rect2:
	var key: Resource = _anim if _anim != null else _art.texture
	if key == null:
		return Rect2(Vector2.ZERO, _frame_size)
	if _figure_cache.has(key):
		return _figure_cache[key]
	var textures: Array[Texture2D] = []
	var lead_count := 1
	if _anim != null:
		var last := _anim.get_frame_count(ANIM_NAME) - 1
		for i in range(_lead_frame(), mini(_anim_strike + RECOIL_FRAMES, last) + 1):
			textures.append(_anim.get_frame_texture(ANIM_NAME, i))
		lead_count = _aim_frame() - _lead_frame() + 1
	else:
		textures.append(_art.texture)
	var entry := Rect2()
	var across := Rect2()
	for i in textures.size():
		var used := _used_rect(textures[i])
		if not used.has_area():
			continue
		if i < lead_count:
			entry = used if not entry.has_area() else entry.merge(used)
		across = used if not across.has_area() else across.merge(used)
	var rect := Rect2(Vector2.ZERO, _frame_size)
	if entry.has_area():
		rect = Rect2(across.position.x, entry.position.y, across.size.x, entry.size.y)
	_figure_cache[key] = rect
	return rect


static func _used_rect(texture: Texture2D) -> Rect2:
	var image := texture.get_image() if texture != null else null
	if image == null:
		return Rect2()
	if image.is_compressed():
		image.decompress()
	return Rect2(image.get_used_rect())


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
