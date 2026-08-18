class_name UITheme
extends RefCounted

# 메타 화면(메인화면/편성/장비 등)의 색·StyleBox 단일 출처.
#
# 왜 코드로 두는가:
#   UI 아이콘(assets/sprites/ui/icons/*.svg)이 아래 색을 그대로 쓰고 있다.
#   같은 값을 .tres 테마와 아이콘에 따로 적어 두면 한쪽만 바뀔 때 톤이 어긋난다.
#   그래서 색의 출처를 여기 하나로 두고, 화면은 이 상수/헬퍼만 사용한다.
#
# 사용법:
#   panel.add_theme_stylebox_override("panel", UITheme.panel_box())
#   label.add_theme_color_override("font_color", UITheme.INK)
#
# 참고: SYSTEM_CONVENTIONS.md (단일 출처), assets/sprites/ui/icons/

# ===== 아이콘 경로 (Icon paths) =====
# 아이콘이 어디 있고 확장자가 무엇인지는 **여기만 안다.**
#
# 왜 모았는가: 화면 6개에 "res://assets/.../icon_xxx.svg" 가 39곳 흩어져 있었다.
# 아트를 PNG 로 교체할 때마다 그 39곳을 다 고쳐야 했고, 한 곳만 놓치면
# 아이콘이 조용히 사라졌다(_texture() 가 없는 파일에 null 을 돌려준다).
#
# 확장자를 화면이 알 필요가 없다. 새 아트는 PNG 로 들어오고 아직 교체되지 않은 것은
# SVG 이므로, 있는 쪽을 골라 준다. PNG 를 먼저 찾아 교체본이 우선하게 한다.
const ICON_DIR := "res://assets/sprites/ui/icons"
const ICON_EXTENSIONS := [".png", ".svg"]

# 아이콘 이름 -> 실제 경로 캐시. 같은 아이콘을 매 프레임 조회해도 파일을 다시 찾지 않는다.
static var _icon_paths: Dictionary = {}

# 아이콘 이름("icon_story")으로 실제 경로를 얻는다. 없으면 빈 문자열.
# 호출부는 확장자를 적지 않는다.
static func icon_path(icon_name: String) -> String:
	if _icon_paths.has(icon_name):
		return _icon_paths[icon_name]

	var found := ""
	for extension in ICON_EXTENSIONS:
		var candidate: String = ICON_DIR.path_join(icon_name + extension)
		if ResourceLoader.exists(candidate):
			found = candidate
			break

	_icon_paths[icon_name] = found
	return found


# 재화 아이콘 이름. "재화 id 로 아이콘 이름을 만든다"는 규칙이 이 한 곳에만 있다.
static func currency_icon_name(currency_type: String) -> String:
	return "icon_" + currency_type


# 역할 아이콘 이름. 위 재화와 같은 규약이다.
#
# 왜 여기인가: 화면 4곳(캐릭터/편성/메인/교단)이 같은 대응표를 각자 const 로
# 들고 있었다. 아이콘 파일 이름이 바뀌면 네 곳을 다 고쳐야 했고, 한 곳만 놓치면
# 그 화면에서만 아이콘이 조용히 사라진다(icon_path 가 빈 문자열을 돌려준다).
# 역할의 출처는 CharacterData.Role 이고, 그 역할이 어떤 그림을 쓰는지는 여기가 정한다.
static func role_icon_name(role: int) -> String:
	match role:
		CharacterData.Role.TANK:
			return "icon_role_tank"
		CharacterData.Role.RANGED_DEALER:
			return "icon_role_ranged_dealer"
		CharacterData.Role.BUFFER:
			return "icon_role_buffer"
		_:
			return ""


# ===== 팔레트 (아이콘과 동일한 값) =====
# 아이콘 SVG의 색과 1:1로 대응한다. 값을 바꾸면 아이콘도 함께 바꿔야 한다.
const OUTLINE := Color("6E6558")       # 진회갈 윤곽선
const OUTLINE_SOFT := Color("7A7060")  # 보조 윤곽선
const TAN := Color("DCCDAF")           # 기본 베이지
const TAN_DEEP := Color("C9B894")      # 진한 베이지(음영)
const CREAM := Color("F7F3EA")         # 밝은 면·하이라이트
const STONE_GRAY := Color("9A9691")
const STONE_DARK := Color("6E6A64")
const AMBER := Color("D9B26A")         # 금속·강조
const LILAC := Color("A78BC8")         # 보조 강조
const SAGE := Color("A8C07A")          # 보조 강조

# ===== 의미색 (Semantic) =====
# 위 팔레트를 용도에 매핑한다. 화면 코드는 가능하면 이쪽을 쓴다.
const BG := Color("3B342B")            # 화면 배경 (팔레트 톤에 맞춘 어두운 흙빛)
const SURFACE := TAN                   # 패널 면
const SURFACE_DEEP := TAN_DEEP         # 눌린/보조 패널 면
const INK := Color("2E2A24")           # 본문 글자 (밝은 패널 위)
const INK_DIM := OUTLINE               # 보조 글자
const INK_ON_DARK := CREAM             # 어두운 배경 위 글자
const ACCENT := AMBER                  # 주 강조 (출격 버튼 등)
const LINE := OUTLINE                  # 테두리

# 증감 표시용. 아이콘에는 쓰이지 않는 의미 전용 색이다.
# SAGE 원본은 밝은 베이지 면 위에서 너무 옅어 글자로 안 읽히므로 한 단계 낮춘다.
# 하락색은 팔레트에 대응하는 원본이 없어 여기서 정의한다(테라코타 계열, 베이지와 같은 흙 톤).
const POSITIVE := Color("6F8A46")      # 상승 ▲
const NEGATIVE := Color("B35C4C")      # 하락 ▼

# ===== 분류색 (Category) =====
# 역할·태그·등급처럼 **서로 구분되어야 하는** 항목에 쓴다.
#
# 왜 필요한가: 액센트가 앰버 하나뿐이면 탱커·딜러·버퍼가 전부 같은 색이 되어
# 목록에서 역할이 구분되지 않는다. 참고한 서브컬쳐 게임들은 액센트(주 동작)와
# 분류색(정보 구분)을 분리해서 쓴다. ACCENT 는 여전히 "주 동작 1개" 용이다.
#
# 흙 톤 팔레트에서 벗어나지 않도록 채도를 낮춰 둔다. 형광색을 넣으면 아이콘과 어긋난다.
const SKY := Color("6B8FA8")           # 탱커
const CORAL := Color("C4705C")         # 원거리 딜러
const LEAF := Color("7B9455")          # 버퍼

# ===== 그림자 =====
# 카드를 패널 위로 띄우는 데 쓴다. 검정이 아니라 잉크색이어야 흙 톤에서 탁해지지 않는다.
const SHADOW := Color(0.18, 0.16, 0.14, 0.22)
const SHADOW_STRONG := Color(0.18, 0.16, 0.14, 0.34)

# ===== 치수 (Metrics) =====
const RADIUS: int = 14                 # 패널 모서리
const RADIUS_PILL: int = 22            # 재화 표시줄 등 알약 모양
const BORDER_WIDTH: int = 3            # 아이콘 윤곽선 두께와 맞춘 값
const PAD: int = 12

# 아이콘 크기. 메타 화면이 제각각 정하면 화면마다 크기가 어긋나므로 여기서 고정한다.
# 서브컬쳐 게임 메인화면 기준: 재화·작은 버튼은 18~20, 하단 탭은 24~28.
const ICON_PILL: int = 18              # 재화 칩 안 아이콘
const ICON_NAV: int = 34               # 하단 탭 아이콘 (라벨이 아래 붙으므로 조금 크다)
const ICON_ROUND: int = 20             # 원형 아이콘 버튼 속 아이콘
const ICON_CTA: int = 26               # 출격 등 주요 버튼

# 캐릭터 일러스트 위에 UI를 얹을 때 쓰는 불투명도.
# 아이콘을 둘러싼 판이 진하면 아이콘보다 판이 먼저 보인다. 형태만 잡히는 정도로 옅게 둔다.
const OVERLAY_ALPHA: float = 0.34

# 오버레이 안쪽 여백. 아래 패널의 PAD(12)보다 훨씬 좁다.
# 여백이 넓으면 아이콘 20px 짜리 버튼도 판이 44px 로 부풀어 커 보인다.
# 아이콘에 바짝 붙여 판을 작게 만든다.
const OVERLAY_PAD: int = 4

# 오버레이 테두리. 상단 칩·원형 버튼처럼 일러스트 위에 얹히는 것들에 쓴다.
#
# 아래 패널(panel_box 등)의 BORDER_WIDTH(3)보다 얇고 옅다.
# 굵은 테두리는 아이콘 자체의 윤곽선과 겹쳐 답답해 보이고, 작은 칩에서는
# 테두리가 내용보다 눈에 띈다. 형태만 겨우 잡히는 정도로 둔다.
const OVERLAY_BORDER_WIDTH: int = 1
const OVERLAY_LINE_ALPHA: float = 0.28


# ===== StyleBox 빌더 =====

# 일반 패널. 두들 아이콘과 같은 굵은 테두리 + 둥근 모서리.
static func panel_box(radius: int = RADIUS) -> StyleBoxFlat:
	return _box(SURFACE, LINE, radius, BORDER_WIDTH)


# 눌린/보조 패널. 본문보다 한 톤 어둡다.
static func panel_box_deep(radius: int = RADIUS) -> StyleBoxFlat:
	return _box(SURFACE_DEEP, LINE, radius, BORDER_WIDTH)


# 알약 모양. 재화 표시줄처럼 가로로 긴 칩에 쓴다.
static func pill_box(fill: Color = SURFACE) -> StyleBoxFlat:
	return _box(fill, LINE, RADIUS_PILL, BORDER_WIDTH)


# 강조 버튼(출격 등).
static func accent_box(radius: int = RADIUS) -> StyleBoxFlat:
	return _box(ACCENT, LINE, radius, BORDER_WIDTH)


# 배경처럼 테두리 없이 면만 필요한 경우.
static func flat_box(fill: Color, radius: int = RADIUS) -> StyleBoxFlat:
	return _box(fill, fill, radius, 0)


# ===== 오버레이용 (캐릭터 일러스트 위에 얹는 UI) =====
# 메인화면은 일러스트가 화면을 꽉 채우므로, 그 위의 UI는 그림이 비쳐 보여야 한다.
# 불투명 패널을 쓰면 애써 넣은 그림을 가린다.

# 반투명 패널. 상·하단 바처럼 넓은 면에 쓴다.
static func overlay_box(radius: int = RADIUS) -> StyleBoxFlat:
	return _box(_alpha(BG, OVERLAY_ALPHA), _overlay_line(), radius, OVERLAY_BORDER_WIDTH, OVERLAY_PAD)


# 반투명 알약. 재화 칩·작은 버튼에 쓴다.
static func overlay_pill(fill: Color = BG) -> StyleBoxFlat:
	return _box(_alpha(fill, OVERLAY_ALPHA), _overlay_line(), RADIUS_PILL, OVERLAY_BORDER_WIDTH, OVERLAY_PAD)


# 글자가 들어가는 반투명 알약(프로필·재화·길라잡이).
# 아이콘 버튼보다 여백이 조금 넓어야 글자가 테두리에 붙지 않는다.
static func overlay_text_pill(fill: Color = BG) -> StyleBoxFlat:
	return _box(_alpha(fill, OVERLAY_ALPHA), _overlay_line(), RADIUS_PILL, OVERLAY_BORDER_WIDTH, OVERLAY_PAD + 4)


# 강조 알약(출격 CTA). 주요 동작이므로 오버레이 중 유일하게 불투명에 가깝다.
# 테두리는 다른 오버레이와 같은 두께로 얇게 둔다. 굵으면 아이콘 윤곽선과 겹쳐 뭉개진다.
static func overlay_accent(radius: int = RADIUS) -> StyleBoxFlat:
	return _box(_alpha(ACCENT, 0.92), _alpha(LINE, 0.45), radius, OVERLAY_BORDER_WIDTH, OVERLAY_PAD + 4)


# 오버레이용 테두리색. 얇게 + 옅게가 이 한 곳에서 정해진다.
static func _overlay_line() -> Color:
	return _alpha(LINE, OVERLAY_LINE_ALPHA)


static func _alpha(color: Color, a: float) -> Color:
	return Color(color.r, color.g, color.b, a)


# 화면 전체를 덮는 배경 노드. 각 화면이 맨 아래에 깔아 쓴다.
# 배경 이미지가 없어도 팔레트 톤이 유지되도록 단색으로 칠한다.
static func make_background() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Background"
	rect.color = BG
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 배경이 버튼 클릭을 가로채지 않게 한다.
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func _box(fill: Color, border: Color, radius: int, border_width: int, pad: int = PAD) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border_width)
	box.border_color = border
	box.set_content_margin_all(pad)
	return box
