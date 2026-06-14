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

# ── Theme 본체 ─────────────────────────────────────────
static func build(default_font: Font = null) -> Theme:
	var t := Theme.new()
	if default_font:
		t.default_font = default_font
	t.default_font_size = 18

	t.set_color("font_color", "Label", C_INK)

	t.set_stylebox("normal", "Button", glass_panel(false, 18))
	t.set_stylebox("hover",  "Button", glass_panel(true, 18))
	t.set_stylebox("pressed","Button", glass_panel(true, 18))
	t.set_color("font_color", "Button", C_INK)
	t.set_color("font_hover_color", "Button", C_CYAN)

	t.set_stylebox("panel", "PanelContainer", glass_panel(false, 22))

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
