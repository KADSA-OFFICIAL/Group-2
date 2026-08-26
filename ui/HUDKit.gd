class_name HUDKit
extends RefCounted

# 서브컬쳐 수집형 RPG 메타 UI 문법을 이 프로젝트에 적용하는 공용 조각 모음.
#
# 왜 UITheme 과 나누는가:
#   UITheme = **색·치수** 의 단일 출처(팔레트 도메인).
#   HUDKit  = 그 위에서 **화면 구조와 상투구**(헤더/패널/카드/칩/스테퍼)를 만든다.
#   여섯 화면이 같은 조각을 각자 만들면 화면마다 미묘하게 어긋난다.
#
# ===== 이 킷이 따르는 규칙 (#120) =====
#
# 참고한 것: 블루 아카이브 / 트릭컬 계열의 메타 화면 문법.
# #118 에서 톤만 밝게 바꿨더니 베이지 한 톤의 표처럼 읽혔다. 원인이 넷이었고
# 아래 넷이 그 대응이다.
#
#   1) **대비는 면이 아니라 글자가 만든다.**
#      바닥·패널·카드를 전부 밝게 두는 대신 글자를 거의 검정으로 쓴다.
#      #118 은 반대로 했다 — 면끼리 명도를 비슷하게 두고 글자까지 흐리게 둬서
#      화면 전체가 같은 회색조로 뭉갰다.
#
#   2) **깊이는 그림자가 만든다.**
#      카드는 윤곽선 + 어긋난 그림자로 패널 위에 얹힌 스티커처럼 띄운다.
#      면 색을 바꿔서 띄우려 하면 밝은 톤에서는 쓸 수 있는 명도 폭이 금방 바닥난다.
#
#   3) **위계는 크기 + 굵기가 만든다.**
#      제목 34 / 값 22 / 섹션 15 / 본문 13 / 캡션 10. 크기 차를 크게 벌린다.
#      프로젝트에 폰트 리소스가 없어 굵기를 못 냈으므로 FontVariation 으로 만든다.
#
#   4) **액센트와 분류색을 나눈다.**
#      ACCENT(앰버)는 "주 동작 1개" 전용이다. 역할·태그처럼 서로 구분돼야 하는
#      정보는 UITheme 의 분류색(SKY/CORAL/LEAF)을 쓴다.
#      앰버 하나로 다 칠하면 목록에서 역할이 구분되지 않는다.
#
# 유지한 레이아웃 문법:
#   좌 리스트 / 중앙 프리뷰 / 우 상세, 한글 라벨 옆 영문 병기,
#   높은 정보 밀도, 우하단 주 CTA 1개, 증감 ▲▼.
#
# 버린 것:
#   각진 모서리·헤어라인·스캔라인·L자 브래킷(다크 HUD 시절 잔재).
#   선택 표시는 이제 브래킷이 아니라 **액센트 꽉 채움 + 반전 글자**다.
#   은은한 알파 틴트로 선택을 표시하면 밝은 톤에서 거의 안 보인다.

# ===== 치수 =====
const RADIUS: int = 16           # 패널 모서리. 큼직하게 둥글린다.
const RADIUS_CARD: int = 13      # 카드·버튼
const RADIUS_CHIP: int = 999     # 칩은 완전한 알약
const BORDER: int = UITheme.BORDER_WIDTH   # 두들 아이콘 윤곽선과 같은 두께
const DIVIDER: int = 2           # 패널 안 구분선 두께

# 좌우 기둥 폭.
# 1280 폭 기준으로 좌(280) + 우(340) + 바깥 여백/간격(약 70)을 빼면 중앙에 590 이 남는다.
# 이 합이 1280 을 넘으면 마지막 기둥이 화면 밖으로 밀려 잘린다(실제로 그랬다).
const RAIL_WIDTH: int = 280      # 좌측 리스트 폭
const DETAIL_WIDTH: int = 340    # 우측 상세 폭

# ===== 타이포 =====
# 크기 차를 크게 벌린다. 12~14 사이에 전부 몰려 있으면 위계가 안 생긴다.
const SIZE_TITLE: int = 34
const SIZE_VALUE: int = 22
const SIZE_SECTION: int = 15
const SIZE_BODY: int = 13
const SIZE_CAPTION: int = 10

# 굵기. 프로젝트에 폰트 파일이 없어 기본 폰트를 쓰는데, 기본 폰트에는 볼드 자족이 없다.
# FontVariation.variation_embolden 으로 윤곽을 부풀려 굵기를 만든다.
# 파일을 추가하지 않고 굵기 대비를 얻는 유일한 방법이다(폰트 도입은 라이선스 확인이 필요).
static var _bold_cache: Dictionary = {}


static func weight_font(embolden: float) -> FontVariation:
	if _bold_cache.has(embolden):
		return _bold_cache[embolden]
	var f := FontVariation.new()
	f.base_font = ThemeDB.fallback_font
	f.variation_embolden = embolden
	_bold_cache[embolden] = f
	return f


# ===== 색 (UITheme 팔레트를 이 문법에 매핑) =====
# 값의 출처는 UITheme 이다. 여기서 새 색을 만들지 않는다.
#
# 명도 구성: 바닥(진한 베이지) < 패널(거의 흰색) ≒ 카드(크림).
# 패널과 카드의 **면 색은 일부러 가깝다.** 둘을 명도로 떼어 놓으려 하면
# 밝은 톤에서 금방 탁해진다. 카드는 윤곽선과 그림자로 떼어 놓는다.

# 화면 바닥. 패널을 감싸는 액자 역할이라 확실히 진하다.
static func ground_bg() -> Color:
	return UITheme.TAN_DEEP


# 패널 면. 거의 흰색이라 그 위 글자가 또렷하다.
static func panel_fill() -> Color:
	return UITheme.CREAM.lerp(Color.WHITE, 0.45)


# 카드 면. 패널보다 아주 살짝 따뜻하다. 구분은 윤곽선 + 그림자가 한다.
static func card_fill() -> Color:
	return UITheme.CREAM


# 패널 안에 파인 칸.
static func inset_fill() -> Color:
	return UITheme.TAN.lerp(UITheme.CREAM, 0.45)


static func line() -> Color:
	return _alpha(UITheme.LINE, 0.45)


static func line_hi() -> Color:
	return UITheme.LINE


# 본문. 거의 검정. 이 화면들의 대비는 여기서 나온다.
static func text_1() -> Color:
	return UITheme.INK


# 보조. INK 를 흐리게 한 것이지 갈색이 아니다.
# INK_DIM(갈색 윤곽선색)을 본문에 쓰면 화면 전체가 탁해진다.
static func text_2() -> Color:
	return _alpha(UITheme.INK, 0.75)


# 캡션·비활성 전용. 본문에는 쓰지 않는다.
static func text_3() -> Color:
	return _alpha(UITheme.INK, 0.45)


# 액센트 면 위 글자(앰버 채움 버튼·선택 카드).
static func text_on_accent() -> Color:
	return UITheme.INK


# 분류색 면 위 글자(역할 칩).
static func text_on_category() -> Color:
	return UITheme.CREAM


# 밝은 면 위 액센트 **글자**. 앰버 원본은 크림 위에서 안 읽힌다.
static func accent_text() -> Color:
	return UITheme.ACCENT.darkened(0.45)


static func up_color() -> Color:
	return UITheme.POSITIVE


static func down_color() -> Color:
	return UITheme.NEGATIVE


# 역할 -> 분류색. 역할의 **이름**은 CharacterData.role_to_name() 이 소유하고,
# 여기서는 **색만** 정한다. 이름 문자열을 이 파일에 다시 적지 않는다.
static func role_color(role: int) -> Color:
	match role:
		CharacterData.Role.TANK:
			return UITheme.SKY
		CharacterData.Role.RANGED_DEALER:
			return UITheme.CORAL
		CharacterData.Role.BUFFER:
			return UITheme.LEAF
		_:
			return UITheme.STONE_GRAY


static func _alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


# 임의의 색을 이 게임의 흙 톤 안으로 끌어들인다.
#
# CharacterData.tint 는 전투 스프라이트를 물들이려고 고른 값이라 순색에 가깝다
# (형광 초록·원색 파랑). 그대로 메타 화면에 쓰면 베이지 팔레트와 아이콘을 뚫고 나온다.
# 색상(hue)은 살려서 캐릭터를 구분할 수 있게 두되, 채도와 명도만 팔레트 쪽으로 당긴다.
static func muted(c: Color) -> Color:
	var out := c.lerp(UITheme.TAN, 0.5)
	out.s = min(out.s, 0.38)
	out.a = 1.0
	return out


# ===== StyleBox =====

static func panel(pad: int = 14) -> StyleBoxFlat:
	return _box(panel_fill(), line_hi(), BORDER, pad, RADIUS, UITheme.SHADOW, 5)


# ===== 오버레이 변형 (전장 위에 얹히는 UI) =====
#
# 메타 화면은 화면 전체가 UI 라 패널이 불투명해도 된다.
# 전투 HUD 는 **전장 위에 얹히므로** 불투명하면 뒤가 안 보인다.
# 모양·테두리·그림자는 그대로 두고 면만 비치게 한다 — 같은 UI 언어를 유지하기 위해서다.
#
# 알파를 더 낮추면 전장은 잘 보이지만 글자가 배경에 따라 읽혔다 안 읽혔다 한다.
# 0.78 은 전장의 형태가 비치면서 잉크 글자가 어떤 바닥 위에서도 읽히는 선이다.
const OVERLAY_ALPHA := 0.78

# 배경 그림 위에 덮는 스크림의 불투명도(#287).
# 0.62 는 "그림이 무엇인지는 알아보되 UI 와 같은 층으로는 안 읽히는" 지점이다.
# 더 내리면 밝은 그림(곳간의 하늘, 시장의 물감) 위에서 본문 글자가 흐려지고,
# 더 올리면 그림을 넣은 의미가 없어진다. 화면별로 다르게 두지 않는다 —
# 배경마다 밝기가 달라도 대비가 일정해야 화면들이 한 벌로 읽힌다.
const BACKDROP_SCRIM_ALPHA := 0.62

static func panel_overlay(pad: int = 12) -> StyleBoxFlat:
	return _box(_alpha(panel_fill(), OVERLAY_ALPHA), line_hi(), BORDER, pad, RADIUS,
		UITheme.SHADOW, 5)


static func card_overlay(selected: bool = false) -> StyleBoxFlat:
	if selected:
		return _box(_alpha(UITheme.ACCENT, 0.92), line_hi(), BORDER, 8, RADIUS_CARD,
			UITheme.SHADOW_STRONG, 4)
	return _box(_alpha(card_fill(), OVERLAY_ALPHA), line(), BORDER, 8, RADIUS_CARD,
		UITheme.SHADOW, 3)


# 카드. 선택 시 액센트로 꽉 채운다.
# 알파 틴트가 아니라 꽉 채움인 이유: 밝은 톤에서 옅은 틴트는 배경과 구분되지 않는다.
static func card(selected: bool = false) -> StyleBoxFlat:
	if selected:
		return _box(UITheme.ACCENT, line_hi(), BORDER, 10, RADIUS_CARD, UITheme.SHADOW_STRONG, 5)
	return _box(card_fill(), line(), BORDER, 10, RADIUS_CARD, UITheme.SHADOW, 3)


# 패널 안에 파인 칸. 그림자를 안쪽으로 못 주므로 그림자 없이 면 색으로만 눌린 느낌을 낸다.
static func inset(pad: int = 10) -> StyleBoxFlat:
	return _box(inset_fill(), line(), BORDER, pad, RADIUS_CARD)


# 주 CTA. 액센트로 꽉 채운다. 화면당 하나만 쓴다.
static func cta() -> StyleBoxFlat:
	return _box(UITheme.ACCENT, line_hi(), BORDER, 14, RADIUS, UITheme.SHADOW_STRONG, 6)


# 눌린 CTA. 그림자를 줄이고 면을 어둡게 해서 실제로 눌린 것처럼 보이게 한다.
static func cta_pressed() -> StyleBoxFlat:
	return _box(UITheme.ACCENT.darkened(0.12), line_hi(), BORDER, 14, RADIUS, UITheme.SHADOW, 2)


# 보조 버튼.
static func ghost() -> StyleBoxFlat:
	return _box(card_fill(), line_hi(), BORDER, 12, RADIUS_CARD, UITheme.SHADOW, 3)


static func ghost_hover() -> StyleBoxFlat:
	return _box(UITheme.SURFACE, line_hi(), BORDER, 12, RADIUS_CARD, UITheme.SHADOW, 3)


static func ghost_pressed() -> StyleBoxFlat:
	return _box(UITheme.SURFACE_DEEP, line_hi(), BORDER, 12, RADIUS_CARD)


# 슬라이더. 기본 테마의 슬라이더는 어두운 회색이라 밝은 패널 위에서 이물감이 있다.
# 채워진 구간을 액센트로 칠해 지금 값이 어디인지 한눈에 보이게 한다.
static func style_slider(s: Range) -> void:
	var track := _box(inset_fill(), line(), 2, 0, RADIUS_CHIP)
	track.content_margin_top = 5
	track.content_margin_bottom = 5
	s.add_theme_stylebox_override("slider", track)

	var filled := _box(UITheme.ACCENT, line_hi(), 2, 0, RADIUS_CHIP)
	s.add_theme_stylebox_override("grabber_area", filled)
	s.add_theme_stylebox_override("grabber_area_highlight", filled)


# 칩(역할·태그). 완전한 알약. 테두리는 면색을 어둡게 해서 만든다.
static func chip(fill: Color) -> StyleBoxFlat:
	var box := _box(fill, fill.darkened(0.25), 2, 6, RADIUS_CHIP)
	box.content_margin_left = 9
	box.content_margin_right = 9
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


static func _box(fill: Color, border: Color, width: int, pad: int, radius: int,
		shadow: Color = Color(0, 0, 0, 0), shadow_size: int = 0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(width)
	box.border_color = border
	box.set_content_margin_all(pad)
	if shadow.a > 0.0:
		box.shadow_color = shadow
		box.shadow_size = shadow_size
		# 아래로만 떨어뜨린다. 사방으로 퍼지면 흐릿한 후광이 되어 스티커 느낌이 사라진다.
		box.shadow_offset = Vector2(0, max(2, shadow_size - 1))
	return box


# ===== 기울인 조각 (블루 아카이브 계열 시그니처) =====
# 섹션 제목 왼쪽의 색 막대. 직사각형이 아니라 살짝 기울인 평행사변형이다.
# Control 에는 skew 속성이 없어서 폴리곤으로 직접 그린다.
class SkewBar:
	extends Control

	var bar_color: Color = Color.WHITE
	var slant: float = 4.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_colored_polygon(PackedVector2Array([
			Vector2(slant, 0), Vector2(w, 0),
			Vector2(w - slant, h), Vector2(0, h),
		]), bar_color)


static func accent_bar(color: Color = UITheme.ACCENT, width: int = 6, height: int = 20) -> Control:
	var bar := SkewBar.new()
	bar.bar_color = color
	bar.custom_minimum_size = Vector2(width, height)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return bar


# ===== 화면 뼈대 =====

# 화면 바닥. 진한 베이지 위에 아주 옅은 대각 줄무늬를 깐다.
#
# #118 에서 다크 시절의 가로 스캔라인을 걷어냈는데, 그건 어두운 줄을 밝은 면에
# 얹어서 얼룩으로 읽혔기 때문이다. 여기서는 **밝은 줄을 중간 명도 면에** 45도로
# 얹는다. 같은 "줄무늬"지만 방향·명도·용도가 달라서 직물 질감으로 읽힌다.
#
# art 를 주면 단색 대신 그 그림을 깔고 위에 스크림(반투명 판)을 얹는다(#287).
# 그림이 없는 화면은 인자를 주지 않으면 되고, 그때 결과는 이전과 완전히 같다.
#
# 스크림을 쓰는 이유: 배경이 선명한 채로 있으면 그 위의 패널·글자와 같은 층으로
# 읽혀 화면이 시끄럽다. 스토리 화면이 셰이더로 흐림을 거는 것과 같은 문제인데,
# 여기는 UI 밀도가 훨씬 높아 흐림만으로는 대비가 모자란다. 바닥색을 그대로
# 반투명하게 덮으면 배경이 어느 그림이든 글자 대비가 일정하게 유지된다.
static func make_backdrop(art: Texture2D = null) -> Control:
	var root := Control.new()
	root.name = "Backdrop"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base := ColorRect.new()
	base.color = ground_bg()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)

	if art != null:
		var picture := TextureRect.new()
		picture.name = "Art"
		picture.texture = art
		picture.set_anchors_preset(Control.PRESET_FULL_RECT)
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 배경은 화면을 빈틈없이 덮어야 한다. 비율이 어긋나면 남는 쪽을 자른다.
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		root.add_child(picture)

		var scrim := ColorRect.new()
		scrim.name = "Scrim"
		scrim.color = _alpha(ground_bg(), BACKDROP_SCRIM_ALPHA)
		scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
		scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(scrim)

	var weave := ColorRect.new()
	weave.name = "Weave"
	weave.set_anchors_preset(Control.PRESET_FULL_RECT)
	weave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 stripe : source_color = vec4(1.0);
uniform float period = 16.0;
void fragment() {
	float d = mod(FRAGCOORD.x + FRAGCOORD.y, period);
	COLOR = vec4(stripe.rgb, d < period * 0.5 ? stripe.a : 0.0);
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("stripe", _alpha(UITheme.CREAM, 0.10))
	weave.material = mat
	root.add_child(weave)
	return root


# 좌상단 고정 헤더: 뒤로 + 제목(한/영 2단).
# on_back 이 비어 있으면 ScreenManager.pop() 을 부른다.
static func make_header(title_ko: String, title_en: String, icon_name: String = "", on_back: Callable = Callable()) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)

	var back := Button.new()
	# 아이콘 에셋(icon_back)이 있으면 그것을 쓴다.
	# 문자 화살표는 에셋이 없을 때의 대체물이다 — 폰트마다 굵기·크기가 달라
	# 옆에 붙는 두들 아이콘들과 톤이 어긋난다.
	var back_icon := load_icon("icon_back")
	if back_icon != null:
		back.icon = back_icon
		# 원본이 512px 라 그대로 두면 버튼을 뚫고 나온다.
		# expand_icon 이 스타일박스 여백 안쪽에 맞춰 줄여 준다.
		back.expand_icon = true
		back.add_theme_constant_override("icon_max_width", 26)
	else:
		back.text = "←"
	back.custom_minimum_size = Vector2(52, 52)
	back.add_theme_font_size_override("font_size", 22)
	back.add_theme_font_override("font", weight_font(0.5))
	back.add_theme_color_override("font_color", text_1())
	back.add_theme_color_override("font_hover_color", text_1())
	back.add_theme_stylebox_override("normal", ghost())
	back.add_theme_stylebox_override("hover", ghost_hover())
	back.add_theme_stylebox_override("pressed", ghost_pressed())
	back.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if on_back.is_valid():
		back.pressed.connect(on_back)
	else:
		back.pressed.connect(func(): ScreenManager.pop())
	row.add_child(back)

	# 제목 앞의 기울인 액센트 막대. 이 장르의 헤더 시그니처다.
	row.add_child(accent_bar(UITheme.ACCENT, 7, 40))

	if not icon_name.is_empty():
		var icon := make_icon(icon_name, 36)
		if icon != null:
			row.add_child(icon)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)

	box.add_child(label(title_ko, SIZE_TITLE, text_1(), 700))
	# 영문 병기 — 이 장르의 가장 강한 시각 시그니처다.
	box.add_child(caption(title_en))
	return row


# 섹션 라벨. 작고 흐리고 자간 넓은 영문 대문자.
static func caption(text_en: String) -> Label:
	var l := Label.new()
	l.text = text_en.to_upper()
	l.add_theme_font_size_override("font_size", SIZE_CAPTION)
	l.add_theme_font_override("font", weight_font(0.2))
	l.add_theme_color_override("font_color", text_3())
	l.add_theme_constant_override("line_spacing", 0)
	return l


# 한글 섹션 제목 + 영문 병기. 왼쪽에 기울인 액센트 막대가 붙는다.
# icon_name 을 주면 막대와 제목 사이에 아이콘이 들어간다(헤더와 같은 순서다).
static func section(title_ko: String, title_en: String, bar_color: Color = UITheme.ACCENT,
		icon_name: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(accent_bar(bar_color, 5, 26))

	if not icon_name.is_empty():
		var icon := make_icon(icon_name, 22)
		if icon != null:
			row.add_child(icon)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(box)
	box.add_child(label(title_ko, SIZE_SECTION, text_1(), 700))
	box.add_child(caption(title_en))
	return row


static func label(text: String, size: int, color: Color, weight: int = 400) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	# 굵기를 실제로 적용한다. #118 까지는 이 인자가 아무 효과가 없었다.
	if weight >= 700:
		l.add_theme_font_override("font", weight_font(0.6))
	elif weight >= 600:
		l.add_theme_font_override("font", weight_font(0.35))
	return l


# 수치. 크고 굵게.
static func value(text: String, size: int = SIZE_VALUE) -> Label:
	return label(text, size, text_1(), 700)


# 역할 칩. 아이콘 + 색 + 한글 이름.
# 이름의 출처는 CharacterData, 아이콘 이름의 출처는 UITheme.role_icon_name() 이다.
static func role_chip(role: int) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip(role_color(role)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)

	var icon := make_icon(UITheme.role_icon_name(role), 14)
	if icon != null:
		row.add_child(icon)

	row.add_child(label(CharacterData.role_to_name(role), 11, text_on_category(), 700))
	return p


# 이 크기 이하의 초상 자리는 "썸네일"로 본다(머리 쪽만 자른다).
# 편성 로스터·캐릭터 목록이 44~52px, 파티 슬롯이 150px 라 그 사이에 둔다.
const THUMB_MAX_SIDE: float = 96.0


# 초상을 어떻게 잘라 보여 줄지. **자리마다 필요한 것이 다르다.**
#
# 왜 크기로 추측하지 않고 호출부가 고르는가:
#   예전에는 자리의 짧은 변이 96px 이하면 머리, 아니면 전신으로 정했다.
#   그런데 편성 파티 슬롯은 min_size 를 Vector2(0, 150) 으로 넘긴다(가로는 칸에 맡긴다).
#   짧은 변이 0 이라 "전신"으로 빠지고, 세로로 긴 그림이 가로로 넓은 칸에 들어가
#   양옆이 색 판으로 가득 차고 인물은 손톱만 하게 남았다.
#   자리의 숫자만 봐서는 그 자리가 무엇을 보여 주려는 자리인지 알 수 없다.
enum Framing {
	AUTO,  # 예전 규칙(짧은 변 <= THUMB_MAX_SIDE 면 머리). 지정하지 않은 호출부용.
	HEAD,  # 머리 정사각. 목록 썸네일처럼 "누구인지"만 알면 되는 자리.
	BUST,  # 머리 + 상반신. 카드·슬롯처럼 얼굴이 커야 하고 칸을 채워야 하는 자리.
	FULL,  # 전신 전체. 상세 일러스트·스토리 무대처럼 그림 자체를 보여 주는 자리.
}

# ===== 얼굴 기준 크롭 (Face-anchored crops) =====
#
# 머리 크기를 기준으로 자른다. 저작된 머리 범위(data/portraits/portrait_meta.tres)가
# 있으면 그 값을 쓰고, 없으면 아래 예전 규칙(경계상자 기준)으로 떨어진다.
#
# 왜 머리 기준인가: 같은 자리에 선 인물들의 **얼굴 크기가 같아야** 한 세트로 보인다.
# 경계상자로 자르면 팔을 벌린 포즈만 몸이 많이 들어와 얼굴이 절반 크기가 된다
# (실제로 파티 슬롯에서 그렇게 보였다).

# 머리 정사각 크롭의 한 변 = 머리 높이 x 이 값. 1.0 이면 얼굴이 칸에 꽉 차 답답하다.
const HEAD_CROP_HEADS: float = 1.7

# 머리 정사각의 세로 중심을 머리 범위의 어디에 둘지(0=머리카락 꼭대기, 1=턱).
# 정가운데(0.5)로 두면 머리카락이 절반을 차지해 얼굴이 아래로 밀린다.
const HEAD_CROP_CENTER: float = 0.62

# 상반신 크롭의 세로 = 머리 높이 x 이 값. 대략 머리 + 가슴까지다.
#
# 얼굴이 이 자리의 주인공이다. 3.4(허리까지)로 뒀더니 카드 안에서 얼굴이 다시 작아졌다.
const BUST_CROP_HEADS: float = 2.6

# 상반신 크롭에서 머리 위에 두는 여백 = 머리 높이 x 이 값.
const BUST_TOP_MARGIN_HEADS: float = 0.25


# 상반신 크롭의 가로세로비(가로 / 세로). 1 보다 작으므로 세로로 조금 길다.
# 정사각으로 자르면 어깨에서 끊겨 답답하고, 더 길게 자르면 얼굴이 다시 작아진다.
const BUST_CROP_ASPECT: float = 0.85

# 이 가로세로비 이상이면 **반신(가슴 위) 구도로 저작된 초상**으로 본다.
#
# 저작본 실측: 전신은 인물 경계상자 비율이 0.30 ~ 0.50(팔을 벌려도 0.50)이고,
# 반신은 0.73 이다. 그 사이를 넉넉히 갈랐다.
#
# 왜 구분해야 하는가: 반신은 전신과 나란히 세울 수 없다. 발이 없어 바닥선에 맞출 수
# 없고, 전신에 키를 맞추면 혼자 작은 사람이 된다. 대신 "가까이 있는 인물"로 두고
# 화면 밖으로 잘라 낸다(VN 에서 흔히 쓰는 문법이다).
const BUST_ART_MIN_ASPECT: float = 0.62


# 초상 자리 한 칸.
#
# portrait 가 있으면 그것을 채우고, 없으면 tint 색 판을 둔다(docs §0: 아트 확정 전 플레이스홀더).
# 여섯 화면이 각자 ColorRect 로 만들던 것을 여기로 모은다 — 모서리 반경과 채도가
# 화면마다 달랐다.
#
# 캐릭터와 적이 각자 다른 리소스 타입(CharacterData / EnemyData)이라 텍스처와 색만 받는다.
# 어느 필드에서 꺼내는지는 호출부가 안다.
# fallback: 초상이 없을 때 색 판 위에 얹을 그림(역할 아이콘·전장 도형 등).
#   아트가 아니라 **무엇의 자리인지 알려 주는 표시**다. 색 판만 두면 카드 넉 장이
#   서로 구별되지 않는다(tint 가 비슷한 캐릭터끼리 특히).
# fallback_modulate: 그 그림에 곱할 색. 흰 도형은 어둡게 눌러야 색 판 위에서 읽히고,
#   자기 색이 있는 두들 아이콘은 알파만 낮춘다. 무엇을 넘기는지는 호출부가 안다.
static func portrait_frame(portrait: Texture2D, tint: Color, min_size: Vector2,
		framing: Framing = Framing.AUTO, fallback: Texture2D = null,
		fallback_modulate: Color = Color(1, 1, 1, 0.85)) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(muted(tint), line(), 2, 0, RADIUS_CARD))
	p.custom_minimum_size = min_size
	p.clip_contents = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if portrait != null:
		var mode := resolve_framing(framing, min_size)
		var t := TextureRect.new()
		t.texture = framed_texture(portrait, mode)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# 잘라 둔 그림(머리·상반신)은 칸을 꽉 채우는 편이 낫다 —
		# 무엇을 보여 줄지는 자를 때 이미 정했으므로 여백이 생길 이유가 없다.
		# 전신은 **잘리면 안 된다** — 세로로 긴 그림을 정사각에 가까운 칸에
		# 꽉 채우면 가운데인 몸통만 남고 머리가 잘린다(편성 슬롯에서 실제로 그랬다).
		# 남는 자리는 뒤의 tint 판이 채운다.
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if mode == Framing.FULL else TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(t)
		return p

	if fallback != null:
		p.add_child(_fallback_mark(fallback, fallback_modulate))
	return p


# 초상 대신 얹는 표시. 자리 크기를 따라 커진다 —
# 같은 코드가 44px 썸네일부터 330px 상세까지 쓰이므로 고정 크기를 쓸 수 없다.
static func _fallback_mark(texture: Texture2D, modulate_color: Color) -> Control:
	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mark := TextureRect.new()
	mark.texture = texture
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.modulate = modulate_color
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(mark)

	# 여백은 자리의 짧은 변에 비례한다. 레이아웃이 돌기 전에는 size 가 0이라
	# 지금 계산하면 여백이 없다. 크기가 정해질 때마다 다시 잡는다.
	holder.resized.connect(_fit_fallback_mark.bind(holder))
	_fit_fallback_mark(holder)
	return holder


# 자리의 짧은 변 기준 22% 를 여백으로 둔다(그림은 56% 정도를 차지한다).
# 꽉 채우면 색 판이 사라져 초상이 있는 것처럼 보이고, 너무 작으면 점으로 보인다.
static func _fit_fallback_mark(holder: MarginContainer) -> void:
	if not is_instance_valid(holder):
		return
	var side: float = minf(holder.size.x, holder.size.y)
	var pad: int = maxi(int(side * 0.22), 2)
	for edge in ["left", "right", "top", "bottom"]:
		holder.add_theme_constant_override("margin_" + edge, pad)


# 캐릭터 초상 자리.
#
# 어떤 그림을 쓸지는 PortraitSystem 이 정한다(화면에서 고른 선택 > 저작 기본값).
# 여기서 character.portrait 를 직접 읽지 않는다 — 그러면 화면마다 다른 그림이 뜬다.
#
# 아트가 없으면 그 캐릭터의 주 역할 아이콘을 얹는다. 이름을 읽기 전에 역할이 먼저 보인다.
# framing: 이 자리가 무엇을 보여 주는 자리인지. 호출부가 고른다(Framing 주석 참고).
static func portrait_block(character: CharacterData, min_size: Vector2,
		framing: Framing = Framing.AUTO) -> Control:
	if character == null:
		return portrait_frame(null, UITheme.STONE_GRAY, min_size)

	return portrait_frame(PortraitSystem.get_portrait(character), character.tint, min_size, framing,
		load_icon(UITheme.role_icon_name(character.role)))


# AUTO 를 실제 프레이밍으로 푼다.
#
# 예전 규칙 그대로다: 작은 자리(목록 썸네일)는 머리, 나머지는 전신.
# 전신 일러스트를 44px 칸에 그대로 넣으면 얼굴이 몇 픽셀밖에 안 되어 누구인지 알 수 없다.
# 자리의 짧은 변이 0 이면(가로를 칸에 맡긴 슬롯) 크기를 알 수 없으므로 전신으로 둔다 —
# 그런 자리는 AUTO 로 두지 말고 호출부가 BUST 를 명시하는 것이 맞다.
static func resolve_framing(framing: Framing, min_size: Vector2) -> Framing:
	if framing != Framing.AUTO:
		return framing
	var side := minf(min_size.x, min_size.y)
	return Framing.HEAD if side > 0.0 and side <= THUMB_MAX_SIDE else Framing.FULL


# 프레이밍에 맞게 잘라 낸 텍스처.
static func framed_texture(portrait: Texture2D, mode: Framing) -> Texture2D:
	match mode:
		Framing.HEAD:
			return head_texture(portrait)
		Framing.BUST:
			return bust_texture(portrait)
		_:
			return portrait


# 초상의 머리 쪽 정사각형만 잘라낸 텍스처.
#
# 왜 필요한가: 저작된 초상은 전신 일러스트다(세로가 가로의 3~4배).
# 작은 정사각 썸네일에 KEEP_ASPECT_COVERED 로 넣으면 가운데인 **몸통**이 잡혀서
# 누구인지 알아볼 수 없다. 얼굴이 보여야 초상을 쓰는 의미가 있다.
#
# 투명 여백을 뺀 실제 그림 범위(get_used_rect)의 위쪽 정사각형을 쓴다.
# 여백째로 자르면 그림이 작게 들어간 초상에서 머리가 또 빗나간다.
#
# 결과는 텍스처별로 캐시한다. get_image() 는 임포트된 텍스처를 CPU 로 내려받는
# 작업이라 줄을 다시 만들 때마다 하면 전투 중에 튄다.
static var _head_textures: Dictionary = {}
static var _trimmed_textures: Dictionary = {}


# 투명 여백을 잘라낸 텍스처.
#
# 저작된 초상은 캔버스 가운데에 인물이 작게 들어 있고 사방이 비어 있다.
# 그대로 자리에 맞추면 여백까지 자리를 차지해서 인물이 실제보다 작게 보인다
# (VN 무대에서 도형 인물보다 작아 보였다).
static func trimmed_texture(portrait: Texture2D) -> Texture2D:
	if portrait == null:
		return null

	var key := portrait.get_rid().get_id()
	if _trimmed_textures.has(key):
		return _trimmed_textures[key]

	var result: Texture2D = portrait
	var image := portrait.get_image()
	if image != null:
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0 and used.size != image.get_size():
			var atlas := AtlasTexture.new()
			atlas.atlas = portrait
			atlas.region = Rect2(used.position, used.size)
			result = atlas

	_trimmed_textures[key] = result
	return result

# 저작된 머리 범위(픽셀). 없으면 size.y == 0 인 빈 Rect2.
static func _head_rect_px(portrait: Texture2D) -> Rect2:
	if portrait == null:
		return Rect2()
	var ratio := PortraitSystem.get_head_rect(portrait)
	if ratio.size.y <= 0.0:
		return Rect2()

	var size := portrait.get_size()
	return Rect2(ratio.position.x * size.x, ratio.position.y * size.y,
		ratio.size.x * size.x, ratio.size.y * size.y)


# 지정한 영역을 잘라 낸 텍스처. 원본 밖으로 나가지 않게 가둔다.
static func _atlas_of(portrait: Texture2D, region: Rect2) -> Texture2D:
	var size := portrait.get_size()
	var clamped := region.intersection(Rect2(Vector2.ZERO, size))
	if clamped.size.x <= 0.0 or clamped.size.y <= 0.0:
		return portrait

	var atlas := AtlasTexture.new()
	atlas.atlas = portrait
	atlas.region = clamped
	return atlas


static func head_texture(portrait: Texture2D) -> Texture2D:
	if portrait == null:
		return null

	var key := portrait.get_rid().get_id()
	if _head_textures.has(key):
		return _head_textures[key]

	# 저작된 머리 범위가 있으면 그것을 쓴다. 얼굴 중심으로 정사각을 잡는다.
	var head := _head_rect_px(portrait)
	if head.size.y > 0.0:
		var side := head.size.y * HEAD_CROP_HEADS
		var center_x := head.get_center().x
		var center_y := head.position.y + head.size.y * HEAD_CROP_CENTER
		var result_head := _atlas_of(portrait,
			Rect2(center_x - side * 0.5, center_y - side * 0.5, side, side))
		_head_textures[key] = result_head
		return result_head

	var result: Texture2D = portrait
	var image := portrait.get_image()
	if image != null:
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var side: int = mini(used.size.x, used.size.y)
			var atlas := AtlasTexture.new()
			atlas.atlas = portrait
			# 가로는 그림 가운데, 세로는 그림 맨 위 = 머리.
			atlas.region = Rect2(
				used.position.x + (used.size.x - side) / 2.0,
				used.position.y,
				side, side)
			result = atlas

	_head_textures[key] = result
	return result


# 초상의 **상반신**만 잘라낸 텍스처.
#
# 왜 머리 크롭과 따로 필요한가:
#   파티 슬롯처럼 가로가 넓고 세로가 짧은 칸에 전신을 넣으면, 비율을 지키느라
#   인물이 칸 높이에 맞춰 줄어들고 양옆이 색 판으로 가득 찬다(인물은 손톱만 해진다).
#   반대로 머리만 자르면 얼굴은 크지만 어느 캐릭터가 무엇을 입었는지 알 수 없다.
#   그 사이가 상반신이다 — 얼굴이 충분히 크고, 칸도 채운다.
#
# 자르는 폭은 그림 전체 너비, 높이는 BUST_CROP_ASPECT 로 정한다. 그림 맨 위가 머리다.
# 반신(가슴 위) 구도로 저작된 초상은 잘라 낼 아래가 없는데, 그때는 min() 이 걸려
# 있는 만큼만 쓰므로 원본 그대로가 된다.
static var _bust_textures: Dictionary = {}

static func bust_texture(portrait: Texture2D) -> Texture2D:
	if portrait == null:
		return null

	var key := portrait.get_rid().get_id()
	if _bust_textures.has(key):
		return _bust_textures[key]

	# 저작된 머리 범위가 있으면 머리 크기로 자른다 — 인물마다 얼굴이 같은 크기로 선다.
	var head := _head_rect_px(portrait)
	if head.size.y > 0.0:
		var bust_height := head.size.y * BUST_CROP_HEADS
		var bust_width := bust_height * BUST_CROP_ASPECT
		var center_x := head.get_center().x
		var result_bust := _atlas_of(portrait, Rect2(
			center_x - bust_width * 0.5,
			head.position.y - head.size.y * BUST_TOP_MARGIN_HEADS,
			bust_width, bust_height))
		_bust_textures[key] = result_bust
		return result_bust

	var result: Texture2D = portrait
	var image := portrait.get_image()
	if image != null:
		var used := image.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			var height: float = minf(float(used.size.y), float(used.size.x) / BUST_CROP_ASPECT)
			var atlas := AtlasTexture.new()
			atlas.atlas = portrait
			atlas.region = Rect2(used.position.x, used.position.y, used.size.x, height)
			result = atlas

	_bust_textures[key] = result
	return result


# 반신 구도로 저작된 초상인지. 판정 근거는 BUST_ART_MIN_ASPECT 주석 참고.
# 여백을 뺀 **인물**의 비율로 본다 — 캔버스 비율은 전신·반신이 똑같이 맞춰져 있다.
static func is_bust_art(portrait: Texture2D) -> bool:
	if portrait == null:
		return false
	var trimmed := trimmed_texture(portrait)
	var size := trimmed.get_size()
	if size.y <= 0.0:
		return false
	return size.x / size.y >= BUST_ART_MIN_ASPECT


# 적 초상 자리. 전투 HUD 가 쓴다.
# EnemyData.tint 는 흰 도형 플레이스홀더를 칠하려고 고른 값이라 순색에 가깝다.
# portrait_frame 안의 muted() 가 팔레트 톤으로 당겨 준다(캐릭터 쪽과 같은 처리다).
static func enemy_portrait_block(enemy: EnemyData, min_size: Vector2) -> Control:
	if enemy == null:
		return portrait_frame(null, UITheme.STONE_GRAY, min_size)

	# 초상이 없으면 전장에서 쓰는 도형을 얹는다. 목록의 그림과 전장의 모양이 같아야
	# 어느 줄이 어느 적인지 이어진다(색만으로는 구별되지 않는다).
	# 도형 원본은 흰색이므로 잉크색으로 눌러야 밝은 색 판 위에서 읽힌다.
	# HUD 썸네일은 작다. 전신 초상을 그대로 넣으면 몸통만 잡히므로 머리 쪽을 쓴다.
	return portrait_frame(enemy.portrait, enemy.tint, min_size, Framing.HEAD,
		enemy.sprite_texture, _alpha(UITheme.INK, 0.55))


# 캐릭터의 역할 칩들을 한 줄로. 겸직이면 2개가 나온다.
static func role_chip_row(character: CharacterData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if character == null:
		return row
	for role in character.get_roles():
		row.add_child(role_chip(role))
	return row


# 재화 칩. 아이콘 + 수량.
#
# 상점·창고·우편·제조가 각자 같은 칩을 만들고 있었다(아이콘 크기와 여백이 화면마다
# 조금씩 달랐다). 아이콘 **이름** 규칙의 출처는 UITheme.currency_icon_name() 이다.
static func currency_chip(currency_type: String, amount_text: String, icon_size: int = 18) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip(inset_fill()))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)

	var icon := make_icon(UITheme.currency_icon_name(currency_type), icon_size)
	if icon != null:
		row.add_child(icon)

	row.add_child(label(amount_text, 13, text_1(), 700))
	return p


# 천 단위 구분. 창고에만 있던 것을 올려서 상점·우편도 같은 형식을 쓰게 한다.
static func comma(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i != 0:
			out = "," + out
	return ("-" + out) if value < 0 else out


# 목록이 비었을 때의 안내 패널. 오류가 아니라 정상 상태를 알리는 자리다.
# 다섯 화면이 같은 모양으로 만들던 것을 모은다.
static func empty_notice(title: String, hint: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel(16))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	p.add_child(box)
	box.add_child(label(title, 16, text_1(), 700))
	if not hint.is_empty():
		var l := label(hint, 13, text_2())
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	p.set_meta("body", box)
	return p


# 알림 점. "새 게 있다"만 알리는 가장 작은 표시다.
#
# 개수를 적지 않는 이유: 개수는 열어 보면 알 수 있는 정보이고, 목록 밖에서 필요한 것은
# 볼 것이 있는지 여부뿐이다. 숫자 배지는 앰버(주 액센트)를 써서 주 CTA 와 시선을
# 다투기도 했다. 점은 하락색(붉은 흙빛)이라 액센트와 겹치지 않는다.
static func new_dot(size: int = 8) -> Control:
	var dot := PanelContainer.new()
	dot.custom_minimum_size = Vector2(size, size)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# 테두리를 두르지 않는다. 이 크기에서는 테두리가 점의 절반을 먹어서
	# 붉은 점이 아니라 작은 회색 고리처럼 보인다.
	dot.add_theme_stylebox_override("panel",
		_box(UITheme.NEGATIVE, UITheme.NEGATIVE, 0, 0, RADIUS_CHIP))
	return dot


# 버튼·아이콘 위에 겹쳐 놓는 알림 점. 우상단 모서리에 붙는다.
#
# inset 은 버튼 테두리에서 안쪽으로 얼마나 들어갈지다. 아이콘 버튼은 내용 여백만큼
# 넣어 줘야 점이 버튼 모서리가 아니라 **아이콘 모서리**에 붙는다.
static func overlay_new_dot(size: int = 8, inset: float = 0.0) -> Control:
	var dot := new_dot(size)
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -inset - float(size)
	dot.offset_top = inset
	dot.offset_right = -inset
	dot.offset_bottom = inset + float(size)
	return dot


# 일반 태그 칩. 등급·상태 등 역할이 아닌 분류에 쓴다.
static func tag_chip(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip(color))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := label(text, 11, text_on_category(), 700)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


# 라벨(좌) + 값(우) 한 행. 정보 밀도의 기본 단위다.
static func stat_row(label_ko: String, label_en: String, value_text: String, bonus_text: String = "") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 30)

	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(label(label_ko, SIZE_BODY, text_2()))
	left.add_child(caption(label_en))
	row.add_child(left)

	row.add_child(label(value_text, 16, text_1(), 700))
	# 장비 보정분은 액센트로. (+320) 형태.
	if not bonus_text.is_empty():
		row.add_child(label(bonus_text, SIZE_BODY, accent_text(), 700))
	return row


# 증감 표시. 상승 ▲ 초록 / 하락 ▼ 빨강 / 0 은 회색.
static func delta(amount: int, suffix: String = "") -> Label:
	if amount > 0:
		return label("▲ +%d%s" % [amount, suffix], SIZE_BODY, up_color(), 700)
	if amount < 0:
		return label("▼ %d%s" % [amount, suffix], SIZE_BODY, down_color(), 700)
	return label("- 0%s" % suffix, SIZE_BODY, text_3())


# 패널 안 구분선.
static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = line()
	r.custom_minimum_size = Vector2(0, DIVIDER)
	return r


# 분위기용 더미 텍스트. 데이터가 없는 여백에 좌표·시리얼을 아주 흐리게 깐다.
# 장르 문법이며 정보가 아니다(읽으라고 두는 것이 아니다).
static func make_serial(text: String) -> Label:
	return label(text, SIZE_CAPTION, _alpha(UITheme.INK, 0.30))


# 아이콘 텍스처. Button.icon 처럼 노드가 아니라 Texture2D 를 받는 자리에서 쓴다.
# 없으면 null 이다 — 호출부는 그때 글자 등으로 떨어진다.
static func load_icon(icon_name: String) -> Texture2D:
	var path := UITheme.icon_path(icon_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D


# 메타 화면 배경(#287). 없으면 null 을 돌려주고, make_backdrop 이 단색으로 돌아간다.
# 아트가 아직 안 들어온 화면도 그냥 이 함수를 부르면 된다.
static func load_backdrop(backdrop_name: String) -> Texture2D:
	var path := UITheme.backdrop_path(backdrop_name)
	if path.is_empty():
		return null
	return load(path) as Texture2D


static func make_icon(icon_name: String, size: int) -> TextureRect:
	var texture := load_icon(icon_name)
	if texture == null:
		return null
	var rect := TextureRect.new()
	rect.texture = texture
	rect.custom_minimum_size = Vector2(size, size)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


# 주 CTA 버튼(우하단 하나). 크고 두껍게.
static func make_cta(text_ko: String, text_en: String) -> Button:
	var b := Button.new()
	b.text = "%s  %s" % [text_ko, text_en.to_upper()]
	b.custom_minimum_size = Vector2(210, 62)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_font_override("font", weight_font(0.6))
	b.add_theme_color_override("font_color", text_on_accent())
	b.add_theme_color_override("font_hover_color", text_on_accent())
	b.add_theme_color_override("font_pressed_color", text_on_accent())
	# 비활성일 때 면이 밝게 바뀐다. 기본 disabled 글자색은 그 위에서 거의 안 보인다.
	b.add_theme_color_override("font_disabled_color", text_3())
	b.add_theme_stylebox_override("normal", cta())
	b.add_theme_stylebox_override("hover", cta())
	b.add_theme_stylebox_override("pressed", cta_pressed())
	b.add_theme_stylebox_override("disabled", ghost())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hover_lift(b)
	return b


# 보조 버튼.
static func make_ghost(text_ko: String, min_width: int = 120, icon_name: String = "") -> Button:
	var b := Button.new()
	b.text = text_ko
	if not icon_name.is_empty():
		var icon := load_icon(icon_name)
		if icon != null:
			b.icon = icon
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 18)
			b.add_theme_constant_override("h_separation", 6)
	b.custom_minimum_size = Vector2(min_width, 50)
	b.add_theme_font_size_override("font_size", 14)
	b.add_theme_font_override("font", weight_font(0.35))
	b.add_theme_color_override("font_color", text_1())
	b.add_theme_color_override("font_hover_color", text_1())
	b.add_theme_color_override("font_pressed_color", text_1())
	b.add_theme_color_override("font_disabled_color", text_3())
	b.add_theme_stylebox_override("normal", ghost())
	b.add_theme_stylebox_override("hover", ghost_hover())
	b.add_theme_stylebox_override("pressed", ghost_pressed())
	b.add_theme_stylebox_override("disabled", ghost())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	hover_lift(b)
	return b


# 패널 하나. 제목(한/영)과 내용 칸을 함께 만든다.
# 반환값의 meta "body" 에 내용 컨테이너가 들어 있다.
# overlay = true 면 전장 위에 얹히는 반투명 패널이 된다(전투 HUD 용).
static func make_panel(title_ko: String, title_en: String, pad: int = 14,
		overlay: bool = false, icon_name: String = "") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_overlay(pad) if overlay else panel(pad))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)

	if not title_ko.is_empty():
		box.add_child(section(title_ko, title_en, UITheme.ACCENT, icon_name))
		box.add_child(rule())

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	p.set_meta("body", body)
	return p


# make_panel 이 만든 패널의 내용 칸.
static func body_of(panel_node: PanelContainer) -> VBoxContainer:
	return panel_node.get_meta("body") as VBoxContainer


# ===== 모션 (#127 -> #145) =====
#
# 남은 것은 **호버 반응 하나뿐이다.**
#
# #127 에서 진입 스태거와 수치 카운트업을 넣었다가 #145 에서 걷어냈다.
# 두 번에 걸쳐 시간을 줄여 봤지만(0.22/0.05 -> 0.14/0.03, 화면 열림 370ms -> 227ms)
# 여전히 답답하다는 피드백이 나왔고, 줄여서 해결될 문제가 아니었다.
#
# 메타 화면은 게임 중 수십 번 오가는 곳이다. 여기서 연출은 "분위기"가 아니라
# **정보와 조작 사이에 낀 지연**으로 느껴진다.
# 반대로 스토리 재생 화면은 **보는 것 자체가 목적**이라 같은 연출이 제 역할을 한다.
# 그쪽 연출(타이틀·페이드·인물 등퇴장·반응)은 그대로 두었다.
#
# 호버만 남긴 이유: 이건 **입력에 대한 즉각적인 반응**이지 대기 시간이 아니다.
# 없애면 버튼이 죽은 것처럼 느껴져서, 답답함을 줄이려다 반응이 없는 UI가 된다.
#
# 규칙(호버에도 그대로 적용): **컨테이너가 정한 position 과 size 는 건드리지 않는다.**
# VBox/HBox 안의 노드를 position 으로 움직이면 다음 레이아웃에서 곧바로 되돌아가
# 모션이 튄다. scale 만 쓴다 — 컨테이너가 관여하지 않는다.

const HOVER_SCALE := 1.03       # 호버 확대율
const HOVER_TIME := 0.09


# scale 의 기준점을 노드 가운데로 옮긴다.
#
# 왜 지연이 필요한가: _build() 직후에는 아직 레이아웃이 돌지 않아 size 가 0이다.
# 그때 pivot 을 잡으면 좌상단 기준이 되어 노드가 대각선으로 튄다.
static func _center_pivot(node: Control) -> void:
	if node.size == Vector2.ZERO:
		# 다음 레이아웃까지 기다렸다가 잡는다.
		# 같은 노드에 두 번 걸려도 값이 같아 문제되지 않으므로 중복 검사를 두지 않는다
		# (bind 로 만든 Callable 은 is_connected 로 비교가 되지 않는다).
		node.resized.connect(_on_pivot_resize.bind(node), CONNECT_ONE_SHOT)
		return
	node.pivot_offset = node.size * 0.5


static func _on_pivot_resize(node: Control) -> void:
	if is_instance_valid(node):
		node.pivot_offset = node.size * 0.5


# 호버하면 살짝 커진다.
#
# trigger 는 마우스를 실제로 받는 노드다. 카드는 클릭을 받으려고 전면에 투명 Button 을
# 얹는 구조라, 카드 자신은 마우스 신호를 받지 못한다. 그래서 신호는 버튼에서 듣고
# 크기는 카드에 준다.
static func hover_lift(target: Control, trigger: Control = null) -> void:
	if target == null:
		return
	var source: Control = trigger if trigger != null else target
	_center_pivot(target)

	source.mouse_entered.connect(func(): _scale_to(target, HOVER_SCALE))
	source.mouse_exited.connect(func(): _scale_to(target, 1.0))


static func _scale_to(node: Control, value: float) -> void:
	if not is_instance_valid(node):
		return
	_center_pivot(node)
	var tween := node.create_tween()
	tween.tween_property(node, "scale", Vector2(value, value), HOVER_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
