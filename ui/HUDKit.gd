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
# 아트 디렉션(#118 에서 전환):
#   킷의 A(테크니컬 다크 HUD)를 따르던 것을 **밝고 아기자기한 톤**으로 되돌렸다.
#   메인화면이 UITheme 의 밝은 베이지 문법을 쓰는데 서브 화면만 다크라서 톤이 갈렸고,
#   이미 저작된 아이콘 26종도 베이지/스톤 톤이라 밝은 쪽이 원래 이 게임의 색이다.
#
#   바뀐 것 = 색(밝은 면 + 잉크 글자)과 형태(둥근 모서리, 두꺼운 두들 테두리, 스캔라인 제거).
#   유지한 것 = 위 1~7번 레이아웃 문법 전부. 톤만 갈아끼운 것이지 구조는 #104 그대로다.
#
#   액센트는 여전히 앰버 1색이다. "액센트는 정확히 1개" 규칙은 그대로 지킨다.
#
# 색은 전부 UITheme 상수에서 파생한다. 이 파일에 리터럴 색을 만들지 않는다.

# ===== 치수 =====
# 모서리·테두리는 UITheme 을 따른다. 여기서 따로 정하면 메인화면과 또 어긋난다.
const RADIUS: int = UITheme.RADIUS          # 패널 모서리 (둥글게)
const RADIUS_SMALL: int = 10                # 카드·버튼처럼 작은 요소
const BORDER: int = UITheme.BORDER_WIDTH    # 두들 아이콘 윤곽선과 같은 두께
const DIVIDER: int = 2                      # 패널 안 구분선 두께
const BRACKET_LEN: int = 10                 # 선택 표시 L자 브래킷 길이
const BRACKET_WIDTH: int = 3

const RAIL_WIDTH: int = 300      # 좌측 리스트 폭
const DETAIL_WIDTH: int = 380    # 우측 상세 폭

# ===== 색 (UITheme 팔레트를 이 문법에 매핑) =====
# 값의 출처는 UITheme 이다. 여기서 새 색을 만들지 않는다.
#
# 밝은 톤에서는 명도 순서가 다크와 반대다.
#   바닥(진한 베이지) < 카드(기본 베이지) < 패널(크림)
# 패널이 바닥보다 밝아야 위로 떠 보인다. 다크에서 하던 대로 패널을 어둡게 하면
# 밝은 바닥에 구멍이 뚫린 것처럼 보인다.

# 화면 바닥. 패널보다 한 단계 진해야 패널이 떠 보인다.
static func ground_bg() -> Color:
	return UITheme.TAN_DEEP


static func panel_fill() -> Color:
	return UITheme.CREAM


static func card_fill() -> Color:
	return UITheme.TAN


static func line() -> Color:
	return _alpha(UITheme.LINE, 0.55)


static func line_hi() -> Color:
	return UITheme.LINE


# 밝은 면 위 글자. UITheme.INK 계열이며 CREAM 이 아니다.
static func text_1() -> Color:
	return UITheme.INK


static func text_2() -> Color:
	return UITheme.INK_DIM


static func text_3() -> Color:
	return _alpha(UITheme.INK_DIM, 0.70)


# 밝은 면 위 액센트 **글자**.
# ACCENT 원본(앰버)은 크림/베이지 위에서 거의 안 읽힌다. 면을 칠할 때는 ACCENT 를
# 그대로 쓰되, 글자에는 이 값을 쓴다. 다크에서는 이 구분이 필요 없었다.
static func accent_text() -> Color:
	return UITheme.ACCENT.darkened(0.45)


static func up_color() -> Color:
	return UITheme.POSITIVE


static func down_color() -> Color:
	return UITheme.NEGATIVE


static func _alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


# ===== StyleBox =====
# 모서리를 둥글리고 테두리를 두들 아이콘과 같은 두께로 굵게 그린다.
# 다크 시절의 각진 모서리 + 1px 헤어라인은 밝은 면 위에서 차갑게 읽힌다.

static func panel(pad: int = 12) -> StyleBoxFlat:
	return _box(panel_fill(), line_hi(), BORDER, pad, RADIUS)


static func card(selected: bool = false) -> StyleBoxFlat:
	# 선택 카드는 앰버로 면을 채운다. 밝은 면 위에서는 다크 때처럼 알파 0.16 으로
	# 깔면 배경과 구분이 안 된다. 테두리도 옅게 두지 않고 윤곽선 색을 그대로 쓴다.
	if selected:
		return _box(_alpha(UITheme.ACCENT, 0.75), line_hi(), BORDER, 8, RADIUS_SMALL)
	return _box(card_fill(), line(), BORDER, 8, RADIUS_SMALL)


# 패널 안에 파인 칸. 패널(크림)보다 한 단계 진하게 해서 눌려 보이게 한다.
static func inset(pad: int = 8) -> StyleBoxFlat:
	return _box(UITheme.SURFACE_DEEP, line(), BORDER, pad, RADIUS_SMALL)


# 주 CTA. 액센트로 꽉 채운다. 화면당 하나만 쓴다.
static func cta() -> StyleBoxFlat:
	return _box(UITheme.ACCENT, line_hi(), BORDER, 12, RADIUS)


# 보조 버튼. 밝은 면 + 윤곽선.
static func ghost() -> StyleBoxFlat:
	return _box(UITheme.SURFACE, line_hi(), BORDER, 10, RADIUS_SMALL)


static func ghost_hover() -> StyleBoxFlat:
	return _box(_alpha(UITheme.ACCENT, 0.45), line_hi(), BORDER, 10, RADIUS_SMALL)


static func _box(fill: Color, border: Color, width: int, pad: int, radius: int = RADIUS) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(width)
	box.border_color = border
	box.set_content_margin_all(pad)
	return box


# ===== 화면 뼈대 =====

# 화면 바닥.
#
# 다크 시절에는 여기에 4px 간격 스캔라인 셰이더를 깔았다. 밝은 베이지 바닥에서는
# 같은 줄무늬가 질감이 아니라 얼룩으로 읽혀서 걷어냈다. 단색 한 장이면 충분하다.
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
		row.add_child(label(bonus_text, 12, accent_text(), 700))
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
			# 밝은 면 위에서는 앰버 브래킷이 배경에 묻는다. 윤곽선 색으로 그린다.
			bar.color = UITheme.LINE
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
	var l := label(text, 10, _alpha(UITheme.INK_DIM, 0.35))
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
	# 비활성일 때 면이 밝은 베이지로 바뀐다. Godot 기본 disabled 글자색은 그 위에서
	# 거의 안 보이므로 명시한다("재료 부족" 같은 안내가 CTA 안에 들어간다).
	b.add_theme_color_override("font_disabled_color", text_2())
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
	# hover 면이 앰버로 차므로 글자를 앰버로 두면 겹쳐서 안 읽힌다. 잉크로 유지한다.
	b.add_theme_color_override("font_hover_color", text_1())
	b.add_theme_color_override("font_disabled_color", text_3())
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
		rule.custom_minimum_size = Vector2(0, DIVIDER)
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
