## res://ui/theme_factory.gd
##
## 글래스 룩 StyleBox / Theme 를 코드로 빌드한다.
## 에디터에서 .tres 로 만들고 싶으면 아래 상수/값을 그대로 입력하면 동일하게 나온다.

class_name ThemeFactory
extends RefCounted

# ── 색상 (HTML 변수와 동일) ──────────────────────────────
const C_BG0          := Color("140f26")
const C_BG1          := Color("241742")
const C_BG2          := Color("3a1f5e")
const C_INK          := Color("f4efff")
const C_INK_DIM      := Color("bda9e6")
const C_INK_FAINT    := Color("8c7bb5")
const C_CYAN         := Color("41e0e6")
const C_PINK         := Color("ff6fb5")
const C_AMBER        := Color("ffc24d")
const C_GOLD         := Color("ffd86b")
const C_GOOD         := Color("7df0a8")
const C_BAD          := Color("ff7a7a")
const C_CTA1         := Color("ff8a3d")
const C_CTA2         := Color("ff4d8d")
const C_LINE         := Color(0.745, 0.667, 1.0, 0.22)
const C_GLASS        := Color(1, 1, 1, 0.07)
const C_GLASS_STRONG := Color(1, 1, 1, 0.12)
const C_SHADOW       := Color(0, 0, 0, 0.45)

# ── 글래스 패널 StyleBox ────────────────────────────────
static func glass_panel(strong: bool = false, radius: int = 22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_GLASS_STRONG if strong else C_GLASS
	sb.set_corner_radius_all(radius)
	sb.border_color = C_LINE
	sb.set_border_width_all(2)
	sb.shadow_color = C_SHADOW
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	return sb

# 둥근 알약(재화/뱃지)용
static func pill(bg: Color = C_GLASS, radius: int = 40) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = C_LINE
	sb.set_border_width_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb

# ── 그라데이션 (CTA 버튼 등) ────────────────────────────
static func gradient_tex(a: Color, b: Color, angle_deg: float = 120.0) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_LINEAR
	var rad := deg_to_rad(angle_deg)
	var dir := Vector2(cos(rad), sin(rad)) * 0.5
	tex.fill_from = Vector2(0.5, 0.5) - dir
	tex.fill_to   = Vector2(0.5, 0.5) + dir
	return tex

static func texture_box(tex: Texture2D, _radius: int = 20) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb

# ── 버튼 StyleBox (둥근 글래스) ─────────────────────────
static func button_box(bg: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.anti_aliasing = true
	return sb

# ── Theme 본체 ─────────────────────────────────────────
static func build(default_font: Font = null) -> Theme:
	var t := Theme.new()
	if default_font:
		t.default_font = default_font
	t.default_font_size = 16

	t.set_color("font_color", "Label", C_INK)

	# 버튼 — 둥근 글래스, 상태별 색
	t.set_stylebox("normal",   "Button", button_box(C_GLASS, C_LINE, 12))
	t.set_stylebox("hover",    "Button", button_box(C_GLASS_STRONG, C_CYAN, 12))
	t.set_stylebox("pressed",  "Button", button_box(Color(C_CYAN, 0.22), C_CYAN, 12))
	t.set_stylebox("disabled", "Button", button_box(Color(0.5, 0.5, 0.6, 0.10), Color(C_LINE, 0.4), 12))
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.set_corner_radius_all(12)
	focus.border_color = Color(C_CYAN, 0.0)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color",          "Button", C_INK)
	t.set_color("font_hover_color",    "Button", C_CYAN)
	t.set_color("font_pressed_color",  "Button", C_CYAN)
	t.set_color("font_disabled_color", "Button", C_INK_FAINT)
	t.set_font_size("font_size", "Button", 15)

	# 패널
	t.set_stylebox("panel", "PanelContainer", glass_panel(false, 18))
	t.set_stylebox("panel", "Panel", glass_panel(false, 18))

	# 프로그레스바 — 둥근 트랙/필
	var pb_bg := round_box(Color(0, 0, 0, 0.32), 8)
	var pb_fg := round_box(C_CYAN, 8)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fg)
	t.set_color("font_color", "ProgressBar", C_INK)

	# 라인에딧 (설정 이름 입력)
	var le := round_box(Color(0, 0, 0, 0.32), 10, C_LINE, 2, 0, 8)
	var le_focus := round_box(Color(0, 0, 0, 0.32), 10, C_CYAN, 2, 0, 8)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", C_INK)
	t.set_color("caret_color", "LineEdit", C_CYAN)

	return t

# ── 분위기 배경 (셰이더) ─────────────────────────────────
const BG_SHADER_PATH := "res://ui/bg_atmosphere.gdshader"
static func make_background() -> ColorRect:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh: Shader = load(BG_SHADER_PATH)
	if sh:
		var mat := ShaderMaterial.new()
		mat.shader = sh
		bg.material = mat
	else:
		bg.color = C_BG0
	return bg

# ── 원형 글로우 텍스처 ──────────────────────────────────
static func radial_glow_tex(c: Color, strength: float = 0.55) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, strength))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 256
	tex.height = 256
	return tex

# ── 메인 CTA(정복/출격): 선명한 색 + 핑크 글로우 + 큰 라운드 ──
static func cta_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("ff5e6e")
	sb.set_corner_radius_all(28)
	sb.anti_aliasing = true
	sb.shadow_color = Color(1.0, 0.30, 0.45, 0.45)
	sb.shadow_size = 26
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb

# ── 활성 탭/선택 강조 (시안) ─────────────────────────────
static func accent_box(radius: int = 16) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CYAN
	sb.set_corner_radius_all(radius)
	sb.border_color = Color(1, 1, 1, 0.45)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	return sb

# ════════════════════════════════════════════════════════
#  범용 헬퍼 (블루아카이브/트릭컬 스타일 메인 재설계용)
# ════════════════════════════════════════════════════════

const C_VIOLET := Color("c6a8ff")

# 완전한 원형 배지/아이콘
static func circle_box(bg: Color, border: Color = Color(0, 0, 0, 0),
		bw: int = 0, pad: int = 6) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(999)
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb

# 둥근 사각 (네비 박스/패널)
static func round_box(bg: Color, radius: int = 16, border: Color = Color(0, 0, 0, 0),
		bw: int = 0, shadow: int = 0, pad: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(bw)
	if shadow > 0:
		sb.shadow_color = C_SHADOW
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, 4)
	if pad > 0:
		sb.set_content_margin_all(pad)
	sb.anti_aliasing = true
	return sb

# 그라데이션 둥근 박스 (배너/CTA) — StyleBoxTexture 라운드
static func gradient_round_box(a: Color, b: Color, angle_deg: float = 120.0,
		radius: int = 18) -> StyleBoxFlat:
	# StyleBoxTexture 는 코너 라운드가 약해, 중간색 단색 + 보더로 근사
	var mix := a.lerp(b, 0.5)
	var sb := StyleBoxFlat.new()
	sb.bg_color = mix
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb

# 재화 종류별 대표 색
static func currency_color(kind: String) -> Color:
	match kind:
		"stamina": return C_CYAN
		"gold":    return C_GOLD
		"gems":    return C_PINK
		"token":   return C_VIOLET
	return C_INK

# ── 공용 뒤로가기 버튼 ──────────────────────────────────
static func back_button(on_back: Callable) -> Button:
	var b := Button.new()
	b.text = "← 뒤로"
	b.add_theme_font_size_override("font_size", 15)
	b.custom_minimum_size = Vector2(0, 38)
	b.add_theme_stylebox_override("normal",  button_box(C_GLASS, C_LINE, 999))
	b.add_theme_stylebox_override("hover",   button_box(C_GLASS_STRONG, C_CYAN, 999))
	b.add_theme_stylebox_override("pressed", button_box(Color(C_CYAN, 0.22), C_CYAN, 999))
	if on_back.is_valid():
		b.pressed.connect(on_back)
	return b

# ── 공용 상단바 (뒤로 + 제목 + 우측 영역) ───────────────
# 반환: { "bar": MarginContainer, "row": HBoxContainer, "title": Label }
static func make_top_bar(title_text: String, on_back: Callable) -> Dictionary:
	var bar := MarginContainer.new()
	bar.add_theme_constant_override("margin_left", 14)
	bar.add_theme_constant_override("margin_right", 14)
	bar.add_theme_constant_override("margin_top", 12)
	bar.add_theme_constant_override("margin_bottom", 8)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	row.add_child(back_button(on_back))

	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", C_CYAN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	return {"bar": bar, "row": row, "title": title}

# ── 섹션 헤더 라벨 ──────────────────────────────────────
static func section_label(text: String, accent: Color = C_CYAN) -> Label:
	var lb := Label.new()
	lb.text = text
	lb.add_theme_font_size_override("font_size", 18)
	lb.add_theme_color_override("font_color", accent)
	return lb
