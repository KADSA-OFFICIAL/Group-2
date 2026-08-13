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

# ===== 치수 (Metrics) =====
const RADIUS: int = 14                 # 패널 모서리
const RADIUS_PILL: int = 22            # 재화 표시줄 등 알약 모양
const BORDER_WIDTH: int = 3            # 아이콘 윤곽선 두께와 맞춘 값
const PAD: int = 12

# 아이콘 크기. 메타 화면이 제각각 정하면 화면마다 크기가 어긋나므로 여기서 고정한다.
# 서브컬쳐 게임 메인화면 기준: 재화·작은 버튼은 18~20, 하단 탭은 24~28.
const ICON_PILL: int = 18              # 재화 칩 안 아이콘
const ICON_NAV: int = 24               # 하단 탭 아이콘
const ICON_ROUND: int = 20             # 원형 아이콘 버튼 속 아이콘
const ICON_CTA: int = 26               # 출격 등 주요 버튼

# 캐릭터 일러스트 위에 UI를 얹을 때 쓰는 불투명도.
# 완전히 불투명하면 그림을 가리고, 너무 옅으면 글자가 안 읽힌다.
const OVERLAY_ALPHA: float = 0.62


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
	return _box(_alpha(BG, OVERLAY_ALPHA), _alpha(LINE, 0.55), radius, 2)


# 반투명 알약. 재화 칩·작은 버튼에 쓴다.
static func overlay_pill(fill: Color = BG) -> StyleBoxFlat:
	return _box(_alpha(fill, OVERLAY_ALPHA), _alpha(LINE, 0.55), RADIUS_PILL, 2)


# 강조 알약(출격 CTA). 주요 동작이므로 오버레이 중 유일하게 불투명에 가깝다.
static func overlay_accent(radius: int = RADIUS) -> StyleBoxFlat:
	return _box(_alpha(ACCENT, 0.92), LINE, radius, BORDER_WIDTH)


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


static func _box(fill: Color, border: Color, radius: int, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border_width)
	box.border_color = border
	box.set_content_margin_all(PAD)
	return box
