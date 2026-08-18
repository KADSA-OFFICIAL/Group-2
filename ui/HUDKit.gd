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
static func make_backdrop() -> Control:
	var root := Control.new()
	root.name = "Backdrop"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base := ColorRect.new()
	base.color = ground_bg()
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(base)

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
static func section(title_ko: String, title_en: String, bar_color: Color = UITheme.ACCENT) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(accent_bar(bar_color, 5, 26))

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


# 역할 칩. 색 + 한글 이름. 이름의 출처는 CharacterData 다.
static func role_chip(role: int, icon_name: String = "") -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", chip(role_color(role)))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(row)

	if not icon_name.is_empty():
		var icon := make_icon(icon_name, 14)
		if icon != null:
			row.add_child(icon)

	row.add_child(label(CharacterData.role_to_name(role), 11, text_on_category(), 700))
	return p


# 캐릭터 초상 자리.
#
# portrait 가 있으면 그것을 채우고, 없으면 tint 색 판을 둔다(docs §0: 아트 확정 전 플레이스홀더).
# 여섯 화면이 각자 ColorRect 로 만들던 것을 여기로 모은다 — 모서리 반경과 채도가
# 화면마다 달랐다.
static func portrait_block(character: CharacterData, min_size: Vector2) -> Control:
	var p := PanelContainer.new()
	var tint: Color = character.tint if character != null else UITheme.STONE_GRAY
	p.add_theme_stylebox_override("panel", _box(muted(tint), line(), 2, 0, RADIUS_CARD))
	p.custom_minimum_size = min_size
	p.clip_contents = true
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if character != null and character.portrait != null:
		var t := TextureRect.new()
		t.texture = character.portrait
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(t)
	return p


# 캐릭터의 역할 칩들을 한 줄로. 겸직이면 2개가 나온다.
static func role_chip_row(character: CharacterData, icon_names: Dictionary = {}) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if character == null:
		return row
	for role in character.get_roles():
		row.add_child(role_chip(role, icon_names.get(role, "")))
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
static func make_ghost(text_ko: String, min_width: int = 120) -> Button:
	var b := Button.new()
	b.text = text_ko
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
		overlay: bool = false) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_overlay(pad) if overlay else panel(pad))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	p.add_child(box)

	if not title_ko.is_empty():
		box.add_child(section(title_ko, title_en))
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
