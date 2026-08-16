class_name HUDKit
extends RefCounted

# 서브컬쳐 수집형 RPG UI 문법을 이 프로젝트에 적용하는 공용 조각 모음.
#
# 왜 UITheme 과 나누는가:
#   UITheme = **색·치수·StyleBox** 의 단일 출처(팔레트 도메인).
#   HUDKit  = 그 위에서 **화면 구조와 상투구**(헤더/패널/브래킷/델타/스테퍼)를 만든다.
#   여섯 화면이 같은 조각을 각자 만들면 화면마다 미묘하게 어긋난다.
#
# 적용한 장르 문법(참고: 팀이 정리한 서브컬쳐 UI 킷):
#   1) UI 를 가장자리로 밀고 가운데는 프리뷰용으로 비운다 (좌 리스트 / 중앙 / 우 상세)
#   2) 한글 라벨 옆·아래에 작은 영문 라벨을 병기한다  <- 이 장르의 가장 강한 시그니처
#   3) 모서리는 둥글리지 않는다. 45도 챔퍼(코너 컷)를 쓴다
#   4) 선택 표시 = 액센트 아웃라인 + 네 모서리 L자 브래킷
#   5) 증감은 색 + 삼각형 (상승 초록 ▲ / 하락 빨강 ▼)
#   6) 주 CTA 는 우하단에 하나. 보조는 그 왼쪽에 아웃라인
#   7) 정보 밀도를 높게. 라벨은 작고 흐리고 자간 넓게, 수치는 크고 굵게
#
# 아트 디렉션은 킷의 A(테크니컬 HUD)를 따르되 **액센트는 이 게임의 앰버 1색**이다.
# 킷이 제시한 형광 라임으로 바꾸면 이미 저작된 아이콘(베이지/스톤)과 전부 어긋난다.
# "액센트는 정확히 1개" 라는 규칙 자체는 그대로 지킨다.

# ===== 치수 =====
const CHAMFER: int = 12          # 코너 컷 크기
const HAIRLINE: int = 1          # 헤어라인 두께
const BRACKET_LEN: int = 10      # 선택 표시 L자 브래킷 길이
const BRACKET_WIDTH: int = 2

const RAIL_WIDTH: int = 300      # 좌측 리스트 폭
const DETAIL_WIDTH: int = 380    # 우측 상세 폭

# ===== 색 (UITheme 팔레트를 이 문법에 매핑) =====
# 값의 출처는 UITheme 이다. 여기서 새 색을 만들지 않는다.
static func void_bg() -> Color:
	return Color(0.055, 0.049, 0.039, 1.0)   # UITheme.BG 보다 한 단계 깊은 바닥


static func panel_fill() -> Color:
	return _alpha(UITheme.BG, 0.86)


static func card_fill() -> Color:
	return _alpha(UITheme.STONE_DARK, 0.34)


static func line() -> Color:
	return _alpha(UITheme.CREAM, 0.12)


static func line_hi() -> Color:
	return _alpha(UITheme.CREAM, 0.26)


static func text_1() -> Color:
	return UITheme.CREAM


static func text_2() -> Color:
	return _alpha(UITheme.CREAM, 0.62)


static func text_3() -> Color:
	return _alpha(UITheme.CREAM, 0.34)


static func up_color() -> Color:
	return UITheme.SAGE


static func down_color() -> Color:
	return Color("D9736A")


static func _alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


# ===== StyleBox =====
# 모서리를 둥글리지 않는다. Godot 의 StyleBoxFlat 은 챔퍼를 직접 못 그리므로
# corner_radius 0 + 헤어라인으로 각진 느낌을 만들고, 챔퍼가 필요한 곳은
# chamfer_overlay() 로 모서리에 삼각형을 덧그린다.

static func panel(pad: int = 12) -> StyleBoxFlat:
	return _box(panel_fill(), line(), HAIRLINE, pad)


static func card(selected: bool = false) -> StyleBoxFlat:
	if selected:
		return _box(_alpha(UITheme.ACCENT, 0.16), UITheme.ACCENT, HAIRLINE, 8)
	return _box(card_fill(), line(), HAIRLINE, 8)


static func inset(pad: int = 8) -> StyleBoxFlat:
	return _box(_alpha(UITheme.BG, 0.55), line(), HAIRLINE, pad)


# 주 CTA. 액센트로 꽉 채운다. 화면당 하나만 쓴다.
static func cta() -> StyleBoxFlat:
	return _box(UITheme.ACCENT, _alpha(UITheme.CREAM, 0.35), HAIRLINE, 12)


# 보조 버튼. 아웃라인만.
static func ghost() -> StyleBoxFlat:
	return _box(_alpha(UITheme.CREAM, 0.04), line_hi(), HAIRLINE, 10)


static func ghost_hover() -> StyleBoxFlat:
	return _box(_alpha(UITheme.CREAM, 0.10), UITheme.ACCENT, HAIRLINE, 10)


static func _box(fill: Color, border: Color, width: int, pad: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(0)
	box.set_border_width_all(width)
	box.border_color = border
	box.set_content_margin_all(pad)
	return box


# ===== 화면 뼈대 =====

# 화면 바닥. 스캔라인을 아주 옅게 깐다(장르 시그니처, opacity 0.03 수준).
static func make_backdrop() -> Control:
	var root := Control.new()
	root.name = "Backdrop"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base := ColorRect.new()
	base.color = void_bg()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)

	var scan := ColorRect.new()
	scan.name = "Scanlines"
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.color = _alpha(UITheme.CREAM, 0.022)
	# 셰이더 없이 4px 간격 줄무늬를 만든다.
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 line_color : source_color = vec4(1.0);
void fragment() {
	float y = mod(FRAGCOORD.y, 4.0);
	COLOR = vec4(line_color.rgb, y < 1.0 ? line_color.a : 0.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("line_color", _alpha(UITheme.CREAM, 0.03))
	scan.material = mat
	root.add_child(scan)
	return root


# 좌상단 고정 헤더: 뒤로 + 제목(한/영 2단).
# on_back 이 비어 있으면 ScreenManager.pop() 을 부른다.
static func make_header(title_ko: String, title_en: String, icon_name: String = "", on_back: Callable = Callable()) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var back := Button.new()
	back.text = "←"
	back.custom_minimum_size = Vector2(40, 40)
	back.add_theme_font_size_override("font_size", 18)
	back.add_theme_color_override("font_color", text_1())
	back.add_theme_stylebox_override("normal", ghost())
	back.add_theme_stylebox_override("hover", ghost_hover())
	back.add_theme_stylebox_override("pressed", ghost())
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if on_back.is_valid():
		back.pressed.connect(on_back)
	else:
		back.pressed.connect(func(): ScreenManager.pop())
	row.add_child(back)

	if not icon_name.is_empty():
		var icon := make_icon(icon_name, 26)
		if icon != null:
			row.add_child(icon)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)

	box.add_child(label(title_ko, 24, text_1(), 700))
	# 영문 병기 — 이 장르의 가장 강한 시각 시그니처다.
	box.add_child(caption(title_en))
	return row


# 섹션 라벨. 작고 흐리고 자간 넓은 영문 대문자.
static func caption(text_en: String) -> Label:
	var l := Label.new()
	l.text = text_en.to_upper()
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", text_3())
	l.add_theme_constant_override("line_spacing", 0)
	return l


# 한글 섹션 제목 + 영문 병기를 한 줄로.
static func section(title_ko: String, title_en: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.add_child(label(title_ko, 13, text_2(), 600))
	box.add_child(caption(title_en))
	return box


static func label(text: String, size: int, color: Color, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if weight >= 700:
		l.add_theme_constant_override("outline_size", 0)
	return l


# 수치. 크고 굵게.
static func value(text: String, size: int = 20) -> Label:
	return label(text, size, text_1(), 700)


# 라벨(좌) + 값(우) 한 행. 정보 밀도의 기본 단위다.
static func stat_row(label_ko: String, label_en: String, value_text: String, bonus_text: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 26)

	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(label(label_ko, 12, text_2()))
	left.add_child(caption(label_en))
	row.add_child(left)

	row.add_child(label(value_text, 14, text_1(), 700))
	# 장비 보정분은 액센트로. (+320) 형태.
	if not bonus_text.is_empty():
		row.add_child(label(bonus_text, 12, UITheme.ACCENT, 700))
	return row


# 증감 표시. 상승 ▲ 초록 / 하락 ▼ 빨강 / 0 은 회색.
static func delta(amount: int, suffix: String = "") -> Label:
	if amount > 0:
		return label("▲ +%d%s" % [amount, suffix], 12, up_color(), 700)
	if amount < 0:
		return label("▼ %d%s" % [amount, suffix], 12, down_color(), 700)
	return label("- 0%s" % suffix, 12, text_3())


# 선택 표시용 L자 브래킷 네 모서리. 패널 위에 겹쳐 놓는다.
static func make_brackets() -> Control:
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for corner in 4:
		for axis in 2:
			var bar := ColorRect.new()
			bar.color = UITheme.ACCENT
			bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var horizontal := axis == 0
			bar.custom_minimum_size = Vector2(
				BRACKET_LEN if horizontal else BRACKET_WIDTH,
				BRACKET_WIDTH if horizontal else BRACKET_LEN)
			var preset: int = [Control.PRESET_TOP_LEFT, Control.PRESET_TOP_RIGHT,
				Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT][corner]
			bar.set_anchors_preset(preset)
			bar.size = bar.custom_minimum_size
			holder.add_child(bar)
	return holder


# 분위기용 더미 텍스트. 데이터가 없는 여백에 좌표·시리얼을 아주 흐리게 깐다.
# 장르 문법이며 정보가 아니다(읽으라고 두는 것이 아니다).
static func make_serial(text: String) -> Label:
	var l := label(text, 10, _alpha(UITheme.CREAM, 0.20))
	return l


static func make_icon(icon_name: String, size: int) -> TextureRect:
	var path := UITheme.icon_path(icon_name)
	if path.is_empty():
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# 주 CTA 버튼(우하단 하나). 큰 액센트 채움.
static func make_cta(text_ko: String, text_en: String) -> Button:
	var b := Button.new()
	b.text = "%s  %s" % [text_ko, text_en.to_upper()]
	b.custom_minimum_size = Vector2(180, 52)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", UITheme.INK)
	b.add_theme_color_override("font_hover_color", UITheme.INK)
	b.add_theme_stylebox_override("normal", cta())
	b.add_theme_stylebox_override("hover", cta())
	b.add_theme_stylebox_override("pressed", ghost())
	b.add_theme_stylebox_override("disabled", ghost())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


# 보조 버튼. 아웃라인.
static func make_ghost(text_ko: String, min_width: int = 110) -> Button:
	var b := Button.new()
	b.text = text_ko
	b.custom_minimum_size = Vector2(min_width, 40)
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", text_1())
	b.add_theme_color_override("font_hover_color", UITheme.ACCENT)
	b.add_theme_stylebox_override("normal", ghost())
	b.add_theme_stylebox_override("hover", ghost_hover())
	b.add_theme_stylebox_override("pressed", ghost())
	b.add_theme_stylebox_override("disabled", ghost())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


# 패널 하나. 제목(한/영)과 내용 칸을 함께 만든다.
# 반환값의 meta "body" 에 내용 컨테이너가 들어 있다.
static func make_panel(title_ko: String, title_en: String, pad: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel(pad))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	p.add_child(box)

	if not title_ko.is_empty():
		box.add_child(section(title_ko, title_en))
		var rule := ColorRect.new()
		rule.color = line()
		rule.custom_minimum_size = Vector2(0, HAIRLINE)
		box.add_child(rule)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 6)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	p.set_meta("body", body)
	return p


# make_panel 이 만든 패널의 내용 칸.
static func body_of(panel_node: PanelContainer) -> VBoxContainer:
	return panel_node.get_meta("body") as VBoxContainer
