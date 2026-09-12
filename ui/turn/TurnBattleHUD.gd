extends Control
class_name TurnBattleHUD

# 턴제 전투 HUD (#450, 규율 개편 #478, 시각 언어 통일 #489).
#
# **메타 화면(메인·편성·장비)과 같은 문법으로 그린다.** 출격 버튼을 누르고 넘어온 화면이
# 방금까지 보던 화면과 같은 재질이어야 한다.
#
#   1. 중앙 개방 — 화면 중앙 60%에 UI를 두지 않는다. 캐릭터가 주인공이다
#   2. 가장자리 흡착 — 모든 UI가 화면 4변에 붙는다. 여백은 메타 화면과 같은 14px
#   3. 부품은 `UITheme.overlay_*` — 둥근 반투명 판(BG 34% + 테두리 1px). 일러스트가 비친다
#   4. 색은 `UITheme` 팔레트에서만 — 아군 SAGE, 적 HOSTILE, 강조 AMBER, 글자 CREAM
#   5. 요소 종류 상한 6종 — ①행동 순서 카드 ②적 분절바+HP바 ③아군 초상+오의
#      ④아군 HP바+상태 점 ⑤공명 핍 ⑥액션 버튼. 넘으면 통합한다
#   6. 앰버 알약은 **하나뿐** — 메인 화면의 "출격만 알약 배경을 가진다"와 같은 규칙.
#      전투에서는 행동 확정 버튼이 그 자리다
#   7. 아이콘은 게임 것을 쓴다 — `UITheme.icon_path()` 로 `assets/sprites/ui/icons` 에서
#
# ## #478 에서 뒤집은 것 (#489)
#
# #478 은 이 화면을 평행사변형(`skewX -12°`) + 막대 2종으로만 그렸고, 어두운 네이비/시안
# 팔레트에 글자 라벨을 금지했다. 그 규율 자체는 일관됐지만 **게임에 시각 언어가 두 개**
# 생겼다 — 메타 화면은 둥근 흙 톤, 전투는 각진 네이비였다. 한쪽으로 모으기로 했고,
# 화면 수가 많은 메타 쪽을 기준으로 삼았다.
#
# 구체적으로 바뀐 것:
#   - 평행사변형 → 둥근 판(`draw_style_box`). `_skewed()` 와 텍스트 역기울기가 사라졌다
#   - 글자 라벨 금지 → 허용. 적 이름·"공명"·"열기"를 적는다. 메타 화면이 그렇게 한다
#   - 고채도 원소 7색 → 흙 톤. `UITheme.gd` 가 "형광색을 넣으면 아이콘과 어긋난다"를
#     명시하고 있어 팔레트 안으로 끌어왔다. 문양은 그대로 함께 둔다(색맹 대응)
#
# **바꾸지 않은 것**: 정보 구조(요소 6종)와 전장 좌표. 둘 다 전투 시스템 소유다.
#
# ## 통합 구조 (요소 6종을 지키는 방법)
#
# - **분절 인성치 바 하나**가 [인성치 + 약점 + 자물쇠] 3가지를 동시에 표현한다.
#   칸 개수 = 남은 자물쇠, 칸 색 = 요구 속성, 칸이 어두워짐 = 해제 완료.
# - **오의 게이지는 초상 카드 아래의 가는 게이지**이고, 만충이면 그 자리가 앰버 배지로
#   바뀐다. 별도 오의 버튼이 없다.
# - **상태이상은 아이콘이 아니라 색 점**이고, 아군·적이 같은 형태다.
# - 배속·자동·일시정지는 우상단 원형 버튼이다 — 메인 화면 상단 바와 같은 부품(⑥에 흡수).
#
# ## 규격 해석
#
# 확정 규격표는 폭 656px 기준이지만 이 프로젝트의 뷰포트는 1280×720 이다.
# **환산(×1.95)하지 않고 1:1 로 적용한다.**
#
# 적 정보 카드 폭은 `ENEMY_SLOT_STEP`(112)보다 좁아야 한다. 넓으면 적 5체가 나란히 설 때
# 카드가 서로 겹친다 — 재디자인 초안에서 116 으로 뒀다가 실제로 4px 겹쳤다.
#
# ## 화면 크기는 1280×720 이 아니다
#
# 프로젝트는 `canvas_items` + `expand` 스트레치를 쓴다. **창 비율이 16:9 가 아니면
# 캔버스가 기준 해상도보다 커진다** — 1920×1012 창에서 실측 캔버스는 1366×720 이었다.
#
# 규칙: **크기는 상수, 위치는 변 기준 여백**이다. 오른쪽·아래에 붙는 것은 `size` 에서
# 빼고, 전장(적·아군 줄)은 캔버스 가로 중심에서 잰다.
#
# 왜 `_draw()`로 직접 그리는가: 노드 기반으로 짜면 매 프레임 바뀌는 게이지·핍·조준
# 프레임 수십 개를 노드로 들고 있어야 한다. 판은 `StyleBoxFlat` 을 `draw_style_box()` 로
# 그리므로 메타 화면의 `UITheme.overlay_*` 와 같은 모양이 나온다.
#
# 참고: docs/turn-combat-design.md §14

# ===== 신호 =====

## 플레이어가 행동을 골랐다.
signal action_chosen(skill: SkillData, target: TurnUnit)
## 플레이어가 오의를 눌렀다. 턴 순서와 무관하게 언제든 나온다.
signal ultimate_requested(unit: TurnUnit)
## 배속이 바뀌었다 (1 / 2 / 3).
signal speed_changed(speed: float)
## 자동 전투가 켜지거나 꺼졌다.
signal auto_toggled(enabled: bool)
## 일시정지가 켜지거나 꺼졌다.
signal pause_toggled(enabled: bool)

# ===== 형태 언어 =====

const MAX_SPEED := 3.0

## 터치 히트박스 최소 변. **시각 크기와 분리한다** — 오의 배지는 68×18 이지만
## 판정은 56×56 이다.
const HIT_MIN := 56.0

## 메타 화면과 같은 화면 가장자리 여백(`main_screen.gd` 의 overlay margin).
const EDGE := 14.0

# 모서리 반경 — UITheme 과 같은 값을 쓴다.
const RADIUS_CARD := 13      # UITheme 카드 = HUDKit.RADIUS_CARD
const RADIUS_BOX := 14       # UITheme.RADIUS
const RADIUS_PILL := 22      # UITheme.RADIUS_PILL

const BORDER_THIN := 1       # UITheme.OVERLAY_BORDER_WIDTH
const BORDER_PICK := 2       # 고른 것 / 조준한 것

# 타이포 — HUDKit 의 단계를 따른다.
const SIZE_CTA := 18
const SIZE_LABEL := 13
const SIZE_SMALL := 11
const SIZE_TINY := 9

# ===== 레이아웃 상수 =====

# --- 상단 한 줄 (메인 화면 상단 바와 같은 자리) ---
const TOP := 6.0
const TOPBAR_H := 40.0
const TOPBAR_PAD := 8.0
const TOPBAR_ICON := 18.0
const TOGGLE_SIDE := 32.0
const TOGGLE_GAP := 6.0
const TOGGLE_TOP := 10.0
## 토글 3개 묶음의 왼쪽 끝 = 우측 여백에서 (32×3 + 6×2) 만큼 안쪽.
const TOGGLE_FROM_RIGHT := EDGE + TOGGLE_SIDE * 3.0 + TOGGLE_GAP * 2.0

# --- 좌측 행동 순서 카드 ---
const TIMELINE_X := EDGE
const TIMELINE_Y := 62.0
const TIMELINE_CARD := Vector2(76.0, 44.0)
const TIMELINE_GAP := 6.0
const TIMELINE_COUNT := 5
## 아군/적 구분은 카드 왼쪽의 이 막대 하나가 전부다.
const TIMELINE_RAIL := Vector2(6.0, 32.0)
const TIMELINE_ART := 32.0
const TIMELINE_BADGE := 20.0
## 고스트는 카드 **옆에** 나란히 둔다.
const TIMELINE_GHOST_DX := TIMELINE_CARD.x + TIMELINE_GAP

# --- 적 정보 카드 ---
#
# `unit_position()` 은 전투 화면이 도형·연출을 놓는 좌표이기도 하다. **바꾸지 않는다.**
## #492 에서 452 → 440 으로 내렸다. 몸이 78 → 140 으로 커지면서 그 위의 정보 카드가
## 화면 천장(우상단 토글 y 10~42)을 밀어냈다. 적을 12px 내려 카드 자리를 만든다.
## 아군 머리(y 301)가 적 발밑(y 280)보다 아래인 것은 그대로다 — 여유 21px.
const ENEMY_ROW_FROM_BOTTOM := 440.0
const ENEMY_CENTER_DX := 60.0
## 몸이 112 폭이 되어(#492) 간격도 넓혔다. **1280 폭에서 적 5체가 들어가는 것이
## 상한을 정한다** — 5번 적의 카드 우단이 1263, 화면 끝까지 17px 남는다.
const ENEMY_SLOT_STEP := 126.0
## **`ENEMY_SLOT_STEP`(126) 보다 좁아야 한다.** 넓으면 적이 나란히 설 때 카드가 겹친다.
const CLUSTER_W := 118.0
const CLUSTER_H := 60.0
const CLUSTER_PAD := 10.0
const ENEMY_BODY_H := 140.0
## 카드 밑변을 적 도형 정수리에서 이만큼 더 띄운다.
##
## 전투 화면이 원소 문양 라벨을 발밑 -162 에 놓고 그 글자가 22px 라 발밑 -162 ~ -140 을
## 쓴다. 그 위로 넘기려면 정수리(-140)에서 22 이상 띄워야 한다. 4px 여유를 둔다.
##
## **몸 크기를 바꿀 때 이 셋이 함께 움직여야 한다** — 몸 높이 · 문양 위치 · 이 값.
## 하나만 두면 글자나 카드가 몸 안으로 들어가고, 셋을 다 올리면 이번처럼 카드가
## 화면 천장을 뚫는다. 세 번 겪었다.
const CLUSTER_GAP := 26.0
const SEG_SIZE := Vector2(20.0, 8.0)
const SEG_GAP := 4.0
const ENEMY_HP_SIZE := Vector2(84.0, 7.0)
const STATUS_DOT := 7.0
const STATUS_GAP := 4.0
const STATUS_MAX := 4
## 조준 고리 — 회전 크로스헤어 대신 발밑 타원 고리와 `icon_mark` 배지를 쓴다.
const AIM_RING := Vector2(118.0, 32.0)
const AIM_BORDER := 2.0
const AIM_DY := -6.0
const MARK_ICON := 24.0

# --- 아군 하단 밴드 (편성 화면의 초상 카드 문법) ---
const CARD_LEFT := EDGE
const CARD_SIZE := Vector2(68.0, 84.0)
const CARD_STEP := 78.0
const CARD_FROM_BOTTOM := 124.0
const CARD_BORDER := 3        # UITheme.BORDER_WIDTH — 편성 카드와 같은 두께
const ULT_GAUGE := Vector2(56.0, 5.0)
const ULT_BADGE_H := 18.0
const ALLY_HP_SIZE := Vector2(68.0, 6.0)
const ALLY_BADGE := 18.0

# --- 공명 / 열기 / 예고 (하단 가운데 왼쪽) ---
const PANEL_LEFT := 344.0
const INFO_SIZE := Vector2(236.0, 76.0)
const INFO_FROM_BOTTOM := 96.0
const RESONANCE_PIP := 14.0
const RESONANCE_GAP := 6.0
const HEAT_SIZE := Vector2(168.0, 8.0)
const INTENT_H := 40.0
const INTENT_FROM_BOTTOM := 150.0
const INTENT_MAX_W := 600.0
const INTENT_PAD := 12.0

# --- 액션 (우하단) ---
const ACTION_SIZE := Vector2(200.0, 54.0)
const ACTION_FROM_RIGHT := EDGE + ACTION_SIZE.x
const ACTION_FROM_BOTTOM := 58.0
const SKILL_SIZE := Vector2(200.0, 44.0)
## 세로 간격을 히트박스 최소 변에 맞춰 판정이 겹치지 않게 한다.
const SKILL_STEP := HIT_MIN
const SKILL_FROM_RIGHT := EDGE + SKILL_SIZE.x
const SKILL_FROM_BOTTOM := 110.0

# --- 아군 도형 위치 (전투 화면이 쓰는 좌표) ---
const ALLY_ROW_FROM_BOTTOM := 268.0
## 몸이 101 폭이 되어(#492) 간격을 넓혔다. 간격이 몸 폭과 같으면 정확히 맞닿는다.
## 1번 아군의 몸 우단(596)이 1번 적의 몸 좌단(644)보다 왼쪽이어야 한다.
const ALLY_CENTER_DX := -95.0
const ALLY_SLOT_STEP := -112.0

# ===== 상태 =====

var battle: TurnBattleManager = null

## 마우스가 올라간 행동. 여기가 바뀌면 타임라인 프리뷰가 갱신된다 (설계서 §4.2.5).
var hovered_action: int = -1
## 지금 고른 행동. **호버와 달리 마우스가 떠나도 남는다.**
var selected_action: int = 0
## 플레이어가 조준 중인 적.
var selected_target: TurnUnit = null
## 프리뷰 결과. `{"order": Array[TurnUnit], "expected": Dictionary, "locks": int}`
var preview: Dictionary = {}

var speed: float = 1.0
var auto: bool = false
## 일시정지 중인가. 켜져 있으면 행동 입력을 받지 않는다 —
## 멈춘 척만 하고 클릭이 통하면 그것은 일시정지가 아니다.
var paused: bool = false

## 오의 준비 배지의 발광 위상. 형태는 그대로 두고 밝기만 흔든다.
var _glow_phase: float = 0.0

var _font: Font = null
var _font_bold: Font = null
var _hit_zones: Array[Dictionary] = []
## 유닛별 머리 크롭 텍스처. `unit_id` -> Texture2D 또는 null(아트 없음).
var _head_art: Dictionary = {}
## 아이콘 이름 -> Texture2D. `_draw()` 가 매 프레임 돌므로 파일 조회를 반복하지 않는다.
var _icons: Dictionary = {}
## StyleBoxFlat 캐시. 매 프레임 새로 만들면 프레임마다 수십 개가 할당된다.
var _boxes: Dictionary = {}


func _ready() -> void:
	name = "TurnBattleHUD"
	# **`set_anchors_preset()` 만 부르면 안 된다.** 그쪽은 앵커를 바꾸면서 현재 사각형을
	# 유지하도록 오프셋을 다시 계산한다. 이 노드는 `CanvasLayer` 의 직속 자식이라 컨테이너가
	# 크기를 잡아 주지 않고, `_ready()` 시점 사각형이 0×0 이므로 오프셋이 0×0 에 고정된다.
	# 그러면 `_draw()` 는 정상으로 보이는데 **마우스 입력만 전부 사라진다.**
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font
	# 굵기는 파일을 늘리지 않고 HUDKit 과 같은 방법(embolden)으로 얻는다.
	_font_bold = HUDKit.weight_font(0.6)


func _process(delta: float) -> void:
	_glow_phase += delta * 3.0
	queue_redraw()


# ===== 좌표 (Layout) =====
#
# **크기는 상수, 위치는 변 기준**이다. 캔버스가 1280×720 보다 커질 수 있으므로
# 절대 좌표를 쓰지 않는다.

func enemy_position(rank: int) -> Vector2:
	return Vector2(size.x * 0.5 + ENEMY_CENTER_DX + ENEMY_SLOT_STEP * float(rank - 1),
		size.y - ENEMY_ROW_FROM_BOTTOM)


func ally_position(rank: int) -> Vector2:
	# 전투 화면이 도형을 놓는 좌표다. 하단 밴드의 카드 배치와는 별개다.
	return Vector2(size.x * 0.5 + ALLY_CENTER_DX + ALLY_SLOT_STEP * float(rank - 1),
		size.y - ALLY_ROW_FROM_BOTTOM)


# 적 정보 카드 좌상단. 적 도형 정수리보다 위다.
func cluster_origin(unit: TurnUnit) -> Vector2:
	return unit_position(unit) + Vector2(-CLUSTER_W * 0.5,
		-ENEMY_BODY_H - CLUSTER_GAP - CLUSTER_H)


func toggle_origin() -> Vector2:
	return Vector2(size.x - TOGGLE_FROM_RIGHT, TOGGLE_TOP)


func card_origin() -> Vector2:
	return Vector2(CARD_LEFT, size.y - CARD_FROM_BOTTOM)


func info_origin() -> Vector2:
	return Vector2(PANEL_LEFT, size.y - INFO_FROM_BOTTOM)


func intent_origin() -> Vector2:
	return Vector2(PANEL_LEFT, size.y - INTENT_FROM_BOTTOM)


func action_origin() -> Vector2:
	return Vector2(size.x - ACTION_FROM_RIGHT, size.y - ACTION_FROM_BOTTOM)


func skill_origin() -> Vector2:
	return Vector2(size.x - SKILL_FROM_RIGHT, size.y - SKILL_FROM_BOTTOM)


func unit_position(unit: TurnUnit) -> Vector2:
	return enemy_position(unit.rank) if unit.is_enemy() else ally_position(unit.rank)


# ===== 그리기 (Draw) =====

func _draw() -> void:
	_hit_zones.clear()
	if battle == null:
		return

	_draw_toggles()
	_draw_wave()
	_draw_timeline()
	_draw_enemy_clusters()
	_draw_expected_damage()
	_draw_party_band()
	_draw_resonance_panel()
	_draw_intent_strip()
	_draw_action()
	_draw_aim()


# --- 배속 · 자동 · 일시정지 (우상단) ---
#
# 메인 화면의 상점·우편·설정과 같은 원형 오버레이 버튼이다. 안의 표시는 형태만으로
# 구분한다 — 배속은 채운 핍 개수, 자동은 막대 하나의 점등, 일시정지는 막대 두 개.
func _draw_toggles() -> void:
	var origin := toggle_origin()

	var speed_pos := origin
	_pill(speed_pos, Vector2(TOGGLE_SIDE, TOGGLE_SIDE), _overlay_fill(), _overlay_line())
	for i in 3:
		var on := float(i) < speed
		_bar(speed_pos + Vector2(8.0 + float(i) * 6.0, 11.0), Vector2(4.0, 10.0),
			UITheme.CREAM if on else _gauge_empty())
	_register_hit(Rect2(speed_pos, Vector2(TOGGLE_SIDE, TOGGLE_SIDE)), "speed", {})

	var auto_pos := origin + Vector2(TOGGLE_SIDE + TOGGLE_GAP, 0.0)
	_pill(auto_pos, Vector2(TOGGLE_SIDE, TOGGLE_SIDE), _overlay_fill(),
		UITheme.ACCENT if auto else _overlay_line())
	_bar(auto_pos + Vector2(7.0, 14.0), Vector2(18.0, 4.0),
		UITheme.CREAM if auto else _gauge_empty())
	_register_hit(Rect2(auto_pos, Vector2(TOGGLE_SIDE, TOGGLE_SIDE)), "auto", {})

	var pause_pos := origin + Vector2((TOGGLE_SIDE + TOGGLE_GAP) * 2.0, 0.0)
	_pill(pause_pos, Vector2(TOGGLE_SIDE, TOGGLE_SIDE), _overlay_fill(),
		UITheme.ACCENT if paused else _overlay_line())
	for i in 2:
		_bar(pause_pos + Vector2(11.0 + float(i) * 7.0, 10.0), Vector2(4.0, 12.0),
			UITheme.CREAM if paused else UITheme.STONE_GRAY)
	_register_hit(Rect2(pause_pos, Vector2(TOGGLE_SIDE, TOGGLE_SIDE)), "pause", {})


# --- 현재 웨이브 (좌상단) ---
#
# 메인 화면의 재화 칩과 같은 알약이다. 핍을 세는 대신 글자로 적는다 —
# 메타 화면이 수치를 글자로 적으므로 여기서만 다른 문법을 쓸 이유가 없다.
func _draw_wave() -> void:
	var total := maxi(battle.wave_total, 1)
	var current := mini(battle.wave_index + 1, total)
	var label := "웨이브 %d" % current
	var tail := " / %d" % total

	var label_w := _width(label, SIZE_LABEL, true)
	var tail_w := _width(tail, SIZE_LABEL, false)
	var width := TOPBAR_PAD * 2.0 + TOPBAR_ICON + 6.0 + label_w + tail_w

	var pos := Vector2(EDGE, TOP)
	_pill(pos, Vector2(width, TOPBAR_H), _overlay_fill(), _overlay_line())
	_icon("icon_quest", pos + Vector2(TOPBAR_PAD, (TOPBAR_H - TOPBAR_ICON) * 0.5),
		TOPBAR_ICON)

	var text_x := pos.x + TOPBAR_PAD + TOPBAR_ICON + 6.0
	var baseline := pos.y + TOPBAR_H * 0.5 + float(SIZE_LABEL) * 0.36
	_text(Vector2(text_x, baseline), label, UITheme.ACCENT, SIZE_LABEL, true)
	_text(Vector2(text_x + label_w, baseline), tail, UITheme.CREAM, SIZE_LABEL)


# --- 행동 순서 (요소 ①) ---
#
# **이 요소 하나가 게임의 전략성을 결정한다.** 앞으로 5개 유닛을 보여주고, 스킬 호버
# 시 "이 행동 후의 순서"를 반투명 고스트로 겹쳐 그린다(FF10 식).
#
# 아군/적 구분은 카드 왼쪽 막대의 색이다. 사이클 경계는 카드 사이의 가는 선이다 —
# "N 사이클" 이라는 글자를 없애고 위치로 옮겼다.
func _draw_timeline() -> void:
	var entries := battle.timeline.preview_with_cycles()
	var ghost: Array[TurnUnit] = preview.get("order", [] as Array[TurnUnit])
	var count := mini(entries.size(), TIMELINE_COUNT)
	var y := TIMELINE_Y
	var last_cycle := -1

	for i in count:
		var entry: Dictionary = entries[i]
		var unit: TurnUnit = entry["unit"]
		var pos := Vector2(TIMELINE_X, y)
		var alpha := maxf(1.0 - float(i) * 0.09, 0.45)
		var cycle := int(entry["cycle"])

		# 사이클 경계. 여기서 다음 사이클이 시작된다.
		if last_cycle >= 0 and cycle != last_cycle:
			_bar(Vector2(TIMELINE_X + 12.0, y - TIMELINE_GAP * 0.5 - 1.0),
				Vector2(TIMELINE_CARD.x - 24.0, 2.0), _overlay_line())
		last_cycle = cycle

		# 지금 차례인 카드만 테두리를 크림으로 올리고 판을 조금 진하게 한다.
		var fill := _overlay_fill()
		var line := _overlay_line()
		if i == 0:
			fill = Color(UITheme.BG, 0.55)
			line = Color(UITheme.CREAM, 0.65)
		_plate(pos, TIMELINE_CARD, fill, line * Color(1, 1, 1, alpha), RADIUS_CARD,
			BORDER_PICK if i == 0 else BORDER_THIN)

		# 좌측 막대 — **아군/적 구분은 이 색 하나가 전부다.**
		var rail := TurnCombat.COLOR_ALLY_HP if unit.is_ally() else TurnCombat.COLOR_ENEMY_HP
		var rail_pos := pos + Vector2(6.0, (TIMELINE_CARD.y - TIMELINE_RAIL.y) * 0.5)
		_pill(rail_pos, TIMELINE_RAIL, rail * Color(1, 1, 1, alpha))
		# 소환체는 막대를 두 쪽으로 쪼갠다. 색을 늘리지 않고 형태로 구분한다.
		if unit.is_summon:
			_bar(rail_pos + Vector2(0.0, TIMELINE_RAIL.y * 0.5 - 1.0),
				Vector2(TIMELINE_RAIL.x, 2.0), UITheme.BG)

		# 초상 + 원소 배지. **얼굴이 있으면 이름 두 글자는 지운다** — 둘을 함께 넣으면
		# 작은 카드에서 둘 다 못 읽는다.
		var art_pos := pos + Vector2(16.0, (TIMELINE_CARD.y - TIMELINE_ART) * 0.5)
		var art := _portrait_of(unit)
		if art != null:
			_portrait_patch(art_pos, Vector2(TIMELINE_ART, TIMELINE_ART), art,
				Color(1, 1, 1, alpha), 0.46, 10.0)
		else:
			_plate(art_pos, Vector2(TIMELINE_ART, TIMELINE_ART), _gauge_empty(),
				_overlay_line(), 10, BORDER_THIN)
			_text_centered(art_pos + Vector2(TIMELINE_ART * 0.5, TIMELINE_ART * 0.5 + 4.0),
				unit.display_name.substr(0, 2),
				UITheme.CREAM * Color(1, 1, 1, alpha), SIZE_SMALL)

		_element_badge(pos + Vector2(TIMELINE_CARD.x - TIMELINE_BADGE - 6.0, 6.0),
			TIMELINE_BADGE, unit.element, alpha)

		# CR 게이지 — 초보자를 위한 두 번째 층위 (설계서 §4.2.2).
		var charge := battle.timeline.get_charge_ratio(unit)
		_gauge(pos + Vector2(TIMELINE_CARD.x - TIMELINE_BADGE - 6.0, TIMELINE_CARD.y - 11.0),
			Vector2(TIMELINE_BADGE, 5.0), charge, rail * Color(1, 1, 1, alpha))

		# 추가 행동은 카드 오른쪽 끝에 가는 막대를 덧댄다.
		if bool(entry["extra"]):
			_bar(pos + Vector2(TIMELINE_CARD.x - 4.0, 8.0),
				Vector2(2.0, TIMELINE_CARD.y - 16.0),
				UITheme.STONE_GRAY * Color(1, 1, 1, alpha))

		y += TIMELINE_CARD.y + TIMELINE_GAP

	# --- 프리뷰 고스트 ---
	#
	# **포인터를 올리고 있는 동안만** 그린다. 늘 그리면 타임라인이 두 줄로 보여
	# 어느 쪽이 실제 순서인지 읽을 수 없다.
	if ghost.is_empty() or hovered_action < 0:
		return
	var gy := TIMELINE_Y
	for i in mini(ghost.size(), count):
		var unit: TurnUnit = ghost[i]
		if unit != entries[i]["unit"]:
			var pos := Vector2(TIMELINE_X + TIMELINE_GHOST_DX, gy)
			_plate(pos, TIMELINE_CARD, Color(UITheme.CREAM, 0.14),
				Color(UITheme.CREAM, 0.7), RADIUS_CARD, BORDER_THIN)
			# 고스트도 실제 카드와 **같은 것**을 보여야 한다.
			var ghost_art := _portrait_of(unit)
			var art_pos := pos + Vector2(16.0, (TIMELINE_CARD.y - TIMELINE_ART) * 0.5)
			if ghost_art != null:
				_portrait_patch(art_pos, Vector2(TIMELINE_ART, TIMELINE_ART), ghost_art,
					Color(1, 1, 1, 0.85), 0.46, 10.0)
			else:
				_text_centered(art_pos + Vector2(TIMELINE_ART * 0.5, TIMELINE_ART * 0.5 + 4.0),
					unit.display_name.substr(0, 2), UITheme.CREAM, SIZE_SMALL)
		gy += TIMELINE_CARD.y + TIMELINE_GAP


# --- 적 정보 카드 (요소 ②) ---
#
# 적 머리 위에 뜨는 오버레이 카드. 3층 구조:
#   1층: 이름 — 메타 화면이 이름을 적으므로 여기서도 적는다
#   2층: 분절 인성치 바 + HP 바
#   3층: 상태이상 색 점
func _draw_enemy_clusters() -> void:
	for unit in battle.enemies():
		var base := cluster_origin(unit)
		var aimed := unit == selected_target

		# 카드가 도형에서 떨어져 있으므로 **어느 적의 것인지 잇는다.**
		var foot := unit_position(unit)
		_bar(Vector2(foot.x - 0.5, base.y + CLUSTER_H),
			Vector2(1.0, foot.y - ENEMY_BODY_H - base.y - CLUSTER_H - 2.0),
			_overlay_line())

		# 조준 중이면 테두리를 앰버로 올린다. 메타의 강조색이 곧 "지금 고른 것"이다.
		_plate(base, Vector2(CLUSTER_W, CLUSTER_H), _overlay_fill(),
			UITheme.ACCENT if aimed else _overlay_line(), RADIUS_BOX,
			BORDER_PICK if aimed else BORDER_THIN)
		if aimed:
			_icon("icon_mark", base + Vector2(-MARK_ICON * 0.5, -MARK_ICON * 0.4), MARK_ICON)

		var inner := base + Vector2(CLUSTER_PAD, 0.0)
		# 이름은 카드 안쪽 폭에 맞춰 줄인다. 카드 폭은 `ENEMY_SLOT_STEP` 에 묶여 있어
		# 늘릴 수 없고, 그대로 두면 "벨로시랩터 수인 2" 가 옆 카드 위로 흘러나간다.
		_text(inner + Vector2(0.0, 16.0),
			_elide(unit.display_name, CLUSTER_W - CLUSTER_PAD * 2.0, SIZE_SMALL),
			UITheme.CREAM, SIZE_SMALL)

		_draw_segment_bar(unit, inner + Vector2(0.0, 22.0))

		_gauge(inner + Vector2(0.0, 36.0), ENEMY_HP_SIZE, unit.get_hp_ratio(),
			TurnCombat.COLOR_ENEMY_HP)

		_draw_status_dots(unit, inner + Vector2(0.0, 47.0))


# 분절 인성치 바. **[인성치 + 약점 + 자물쇠]를 한 요소로 표현한다.**
#
# 예고가 있으면 칸 = 자물쇠다. 칸 색이 요구 속성이고, 해제된 칸은 어두워진다.
# 예고가 없으면 칸 = 약점 속성이고, 남은 인성치 비율만큼만 칸이 켜진다.
# 둘 다 없으면 무채색 게이지 하나로 인성치만 보여준다.
func _draw_segment_bar(unit: TurnUnit, base: Vector2) -> void:
	# 격파 상태는 빈 게이지를 둔다 — 빈 칸이 곧 "인성치가 없다"다.
	if unit.is_broken:
		_gauge(base, Vector2(ENEMY_HP_SIZE.x, SEG_SIZE.y), 0.0, TurnCombat.COLOR_TOUGHNESS)
		return

	var cells: Array[Dictionary] = []
	for seg in battle.toughness.toughness_segments(unit):
		var lock: TurnLock = seg["lock"]
		cells.append({"color": lock.color(), "glyph": lock.glyph(), "off": lock.cleared})

	var ratio := unit.get_toughness_ratio()
	if cells.is_empty():
		# 예고 없음 — 칸은 약점 속성이고, 인성치 비율이 몇 칸까지 켜지는지를 정한다.
		var weak: Array[Dictionary] = []
		for e in unit.weak_elements:
			weak.append({"color": TurnCombat.element_color(e),
				"glyph": TurnCombat.element_glyph(e), "off": false})
		for p in unit.weak_physical:
			weak.append({"color": TurnCombat.COLOR_TOUGHNESS,
				"glyph": TurnCombat.physical_glyph(p), "off": false})
		if weak.is_empty():
			# 약점도 예고도 없으면 남은 인성치 비율만 게이지로 보여준다.
			_gauge(base, Vector2(ENEMY_HP_SIZE.x, SEG_SIZE.y), ratio,
				TurnCombat.COLOR_TOUGHNESS)
			return
		var lit := int(ceilf(float(weak.size()) * ratio))
		for i in weak.size():
			weak[i]["off"] = i >= lit
		cells = weak

	# **칸 폭은 고정한다.** 폭을 카드에 맞춰 나누면 자물쇠 1개짜리 적이 통짜 바로 보여
	# "인성치가 가득하다"로 읽힌다 — 여기서 정보는 **칸의 개수**다.
	var count := cells.size()
	var seg_w := minf(SEG_SIZE.x,
		(ENEMY_HP_SIZE.x - SEG_GAP * float(count - 1)) / float(count))
	for i in count:
		var cell: Dictionary = cells[i]
		var pos := base + Vector2((seg_w + SEG_GAP) * float(i), 0.0)
		var color: Color = cell["color"]
		if bool(cell["off"]):
			# 어두워짐 = 해제 완료. 색상은 남겨 무엇이었는지 읽히게 한다.
			color = color.darkened(0.55)
		_plate(pos, Vector2(seg_w, SEG_SIZE.y), color, _overlay_line(), 4, BORDER_THIN)
		# 색맹 대응 — 칸 안에 요구 타입의 고유 문양을 어두운 잉크로 찍는다.
		if not bool(cell["off"]) and seg_w >= 14.0:
			_text_centered(pos + Vector2(seg_w * 0.5, SEG_SIZE.y - 1.0),
				String(cell["glyph"]), UITheme.INK, SIZE_TINY)


# 상태이상 색 점. **아이콘도 텍스트도 쓰지 않는다** — 둥근 점 최대 4개다.
# 아군과 적이 같은 형태를 쓴다.
func _draw_status_dots(unit: TurnUnit, origin: Vector2) -> void:
	var shown := 0
	for status in unit.statuses:
		if shown >= STATUS_MAX:
			break
		var pos := origin + Vector2(float(shown) * (STATUS_DOT + STATUS_GAP), 0.0)
		_plate(pos, Vector2(STATUS_DOT, STATUS_DOT), status.color(), _overlay_line(),
			int(STATUS_DOT * 0.5), BORDER_THIN)
		shown += 1
	# 4개를 넘으면 마지막 자리에 무채색 점을 하나 더 찍어 "더 있다"만 알린다.
	if unit.statuses.size() > STATUS_MAX:
		_plate(origin + Vector2(float(STATUS_MAX) * (STATUS_DOT + STATUS_GAP), 0.0),
			Vector2(STATUS_DOT, STATUS_DOT), UITheme.STONE_GRAY, _overlay_line(),
			int(STATUS_DOT * 0.5), BORDER_THIN)


# 호버 중인 스킬의 예상 피해를 모든 대상 위에 표시한다.
#
# 예고와 달리 이것은 **전부 보여야 한다** — 확산·전체 공격이 누구에게 얼마나 들어가는지가
# 판단의 핵심이다.
func _draw_expected_damage() -> void:
	var expected: Dictionary = preview.get("expected", {})
	if expected.is_empty():
		return
	for unit in battle.enemies():
		if not expected.has(unit.unit_id):
			continue
		# **카드 옆이 아니라 위에** 올린다. 카드 사이 간격이 8px(112 - 104)뿐이라
		# 옆에 두면 숫자가 통째로 이웃 카드의 HP 바를 덮는다.
		var base := cluster_origin(unit)
		_text_centered_outlined(base + Vector2(CLUSTER_W * 0.5, -6.0),
			"-%d" % int(expected[unit.unit_id]), TurnCombat.COLOR_ENEMY_HP, SIZE_LABEL)


# --- 아군 하단 밴드 (요소 ③ + ④) ---
#
# 편성 화면의 초상 카드와 같은 문법이다: 둥근 모서리 13, 테두리 3,
# `HUDKit.muted(tint)` 면색. 카드 순서가 곧 랭크다 — "A1" 같은 글자를 쓰지 않는다.
func _draw_party_band() -> void:
	# **카드 슬롯은 랭크가 정한다** (루프 순서가 아니다). 누가 쓰러져도 남은 카드가
	# 왼쪽으로 밀리지 않아야 "위치 = 랭크"가 라벨 역할을 계속 한다.
	for unit in battle.allies():
		var origin := card_origin() + Vector2(CARD_STEP * float(unit.rank - 1), 0.0)
		var alive := unit.alive

		# --- 초상 카드 (요소 ③) ---
		var tint := unit.character.tint if unit.character != null else Color.WHITE
		var fill := HUDKit.muted(tint) if alive else _gauge_empty()
		var line := Color(UITheme.LINE, 0.7)
		if not alive:
			line = _overlay_line()
		elif unit == battle.active_unit:
			line = UITheme.CREAM   # 크림 = 지금 행동할 유닛
		# 색 판을 먼저 깔고 그 위에 얼굴을 얹는다. 초상에 투명 여백이 있어도 칸이 비지 않는다.
		_plate(origin, CARD_SIZE, fill, Color(0, 0, 0, 0), RADIUS_CARD, 0)
		var art := _portrait_of(unit)
		if art != null:
			_portrait_patch(origin, CARD_SIZE, art,
				Color(1, 1, 1, 1) if alive else Color(0.45, 0.45, 0.45, 0.8),
				0.42, float(RADIUS_CARD))
		else:
			_text_centered(origin + Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y * 0.5 + 6.0),
				unit.display_name.substr(0, 2),
				UITheme.INK if alive else UITheme.STONE_GRAY, SIZE_CTA)
		# 테두리는 얼굴 위에 그린다 — 어두운 배경에서 인물을 떼어 내는 림 라이트다.
		_plate(origin, CARD_SIZE, Color(0, 0, 0, 0), line, RADIUS_CARD, CARD_BORDER)

		_element_badge(origin + Vector2(CARD_SIZE.x - ALLY_BADGE + 4.0, 4.0),
			ALLY_BADGE, unit.element, 1.0 if alive else 0.45)

		# --- 오의 (요소 ③) — 카드 아래쪽. 만충이면 게이지가 앰버 배지로 바뀐다 ---
		var ratio := unit.get_energy_ratio()
		var ready := ratio >= 1.0 and alive
		if ready:
			# 만충 시 밝기를 흔든다. **형태는 바꾸지 않는다** — 색만이 라벨이다.
			var pulse := 0.72 + 0.28 * sin(_glow_phase)
			var badge_pos := origin + Vector2(0.0, CARD_SIZE.y - ULT_BADGE_H)
			_pill(badge_pos, Vector2(CARD_SIZE.x, ULT_BADGE_H),
				Color(UITheme.ACCENT, 0.92) * Color(pulse, pulse, pulse, 1.0),
				Color(UITheme.LINE, 0.45))
			_text_centered(badge_pos + Vector2(CARD_SIZE.x * 0.5, ULT_BADGE_H - 5.0),
				"오의", UITheme.INK, 10)
			if not paused:
				_register_hit(Rect2(badge_pos, Vector2(CARD_SIZE.x, ULT_BADGE_H)),
					"ultimate", {"unit": unit})
		elif alive:
			_gauge(origin + Vector2((CARD_SIZE.x - ULT_GAUGE.x) * 0.5,
				CARD_SIZE.y - ULT_GAUGE.y - 6.0), ULT_GAUGE, ratio, UITheme.ACCENT)

		# --- HP (요소 ④) — 카드 아래 ---
		var hp_pos := origin + Vector2(0.0, CARD_SIZE.y + 4.0)
		# 보호막은 HP 게이지 위에 겹치는 얇은 막대다.
		if alive:
			var shield := unit.get_shield_total()
			if shield > 0:
				var s := clampf(float(shield) / float(unit.get_max_hp()), 0.0, 1.0)
				_pill(hp_pos - Vector2(0.0, 4.0), Vector2(ALLY_HP_SIZE.x * s, 3.0),
					UITheme.CREAM)
		_gauge(hp_pos, ALLY_HP_SIZE, unit.get_hp_ratio() if alive else 0.0,
			TurnCombat.COLOR_ALLY_HP)

		# --- 상태이상 (요소 ④) ---
		_draw_status_dots(unit, hp_pos + Vector2(0.0, ALLY_HP_SIZE.y + 4.0))

		# 이름 — 그림 위에 바로 얹히므로 메타 화면 탭과 같은 외곽선을 넣는다.
		_text_centered_outlined(
			Vector2(origin.x + CARD_SIZE.x * 0.5, size.y - 5.0),
			unit.display_name, UITheme.CREAM if alive else UITheme.STONE_GRAY, SIZE_SMALL)


# --- 공명 + 열기 (요소 ⑤) ---
#
# 한 판에 묶는다. 메타 화면이 관련 수치를 한 알약에 모으는 것과 같다.
# 공명은 핍 개수가 곧 숫자이고, 0개일 때는 핍 자리가 적색으로 바뀌어 파산을 경고한다.
func _draw_resonance_panel() -> void:
	var resources := battle.resources
	var origin := info_origin()
	_plate(origin, INFO_SIZE, _overlay_fill(), _overlay_line(), RADIUS_BOX, BORDER_THIN)

	var bankrupt := resources.is_resonance_bankrupt()
	var empty := TurnCombat.COLOR_ENEMY_HP if bankrupt else _gauge_empty()

	_text(origin + Vector2(14.0, 26.0), "공명", Color(UITheme.CREAM, 0.75), SIZE_SMALL)
	for i in resources.resonance_max:
		var pos := origin + Vector2(52.0 + float(i) * (RESONANCE_PIP + RESONANCE_GAP), 12.0)
		var filled := i < resources.resonance
		_plate(pos, Vector2(RESONANCE_PIP, RESONANCE_PIP),
			TurnCombat.COLOR_TOUGHNESS if filled else empty,
			_overlay_line(), int(RESONANCE_PIP * 0.5), BORDER_THIN)

	if not resources.heat_enabled():
		return

	# 열기 — 냉각 / 최적 / 과열 3구간. 게이지 색과 최적 구간 배경이 구간명을 대신한다.
	var t := TurnCombatConfig.tuning
	var heat_pos := origin + Vector2(52.0, 44.0)
	_text(origin + Vector2(14.0, 52.0), "열기", Color(UITheme.CREAM, 0.75), SIZE_SMALL)

	var radius := int(HEAT_SIZE.y * 0.5)
	_plate(heat_pos, HEAT_SIZE, _gauge_empty(), _overlay_line(), radius, BORDER_THIN)
	# 최적 구간을 배경으로 표시한다 — 어디를 노려야 하는지 보여야 한다.
	var lo := HEAT_SIZE.x * t.heat_optimal_min / t.heat_max
	var hi := HEAT_SIZE.x * t.heat_optimal_max / t.heat_max
	_bar(heat_pos + Vector2(lo, 0.0), Vector2(hi - lo, HEAT_SIZE.y),
		Color(UITheme.SAGE, 0.35))

	var zone := resources.heat_zone()
	var color := TurnCombat.COLOR_TOUGHNESS
	if zone < 0:
		color = UITheme.STONE_GRAY               # 냉각 — 무채색
	elif zone > 0:
		color = TurnCombat.COLOR_ENEMY_HP        # 과열 — 경고
	var filled_w := HEAT_SIZE.x * clampf(resources.heat / t.heat_max, 0.0, 1.0)
	if filled_w > 1.0:
		_plate(heat_pos, Vector2(filled_w, HEAT_SIZE.y), color, Color(0, 0, 0, 0), radius, 0)


# --- 적 행동 예고 ---
#
# 예고의 **요구 조건**은 분절 바가 항상 보여주므로, 문장은 조준 중인 적 1체에 한해
# 하단에 붙인다. 적 머리 위에 상시로 띄우면 5체의 패널이 서로를 덮는다.
func _draw_intent_strip() -> void:
	if selected_target == null or selected_target.intent == null:
		return
	var text := selected_target.intent.describe(TurnCombatConfig.info_detail)
	if text.is_empty():
		return

	var origin := intent_origin()
	var width := minf(INTENT_PAD * 2.0 + TOPBAR_ICON + 8.0 + _width(text, SIZE_LABEL, false),
		INTENT_MAX_W)
	_pill(origin, Vector2(width, INTENT_H), _overlay_fill(),
		Color(TurnCombat.COLOR_ENEMY_HP, 0.75), BORDER_PICK)
	_icon("icon_capture", origin + Vector2(INTENT_PAD, (INTENT_H - TOPBAR_ICON) * 0.5),
		TOPBAR_ICON)
	_text(origin + Vector2(INTENT_PAD + TOPBAR_ICON + 8.0,
		INTENT_H * 0.5 + float(SIZE_LABEL) * 0.36), text, UITheme.CREAM, SIZE_LABEL)


# --- 액션 (요소 ⑥) ---
#
# 우하단 앰버 알약 하나. **메인 화면의 "출격" 과 같은 자리, 같은 부품이다** —
# 화면에서 주요 동작은 언제나 하나이고 그것만 불투명한 앰버다.
# 내 턴이면 위로 스킬 알약이 펼쳐진다.
func _draw_action() -> void:
	var awaiting := battle.phase == TurnBattleManager.Phase.AWAITING_INPUT and not paused
	var actions: Array[Dictionary] = []
	if awaiting:
		actions = battle.available_actions()

	var origin := action_origin()

	# 입력 대기가 아니거나 쓸 행동이 없으면 보통 오버레이로 내린다.
	# 앰버는 **누를 수 있을 때만** 쓴다.
	if actions.is_empty():
		_pill(origin, ACTION_SIZE, _overlay_fill(), _overlay_line())
		_text_centered(origin + Vector2(ACTION_SIZE.x * 0.5, ACTION_SIZE.y * 0.5 + 6.0),
			"적 행동 중", Color(UITheme.CREAM, 0.6), SIZE_LABEL)
		return

	# 내 턴이면 스킬 목록을 펼쳐 둔다. 누를 수 있는 것이 보여야 조작 가능한 화면이다.
	_draw_skill_panel(actions)

	var chosen := clampi(hovered_action if hovered_action >= 0 else selected_action,
		0, actions.size() - 1)
	var entry: Dictionary = actions[chosen]
	var skill: SkillData = entry["skill"]
	var usable := bool(entry["ok"])

	if usable:
		_pill(origin, ACTION_SIZE, Color(UITheme.ACCENT, 0.92), Color(UITheme.LINE, 0.45))
	else:
		_pill(origin, ACTION_SIZE, _overlay_fill(), _overlay_line())

	var ink := UITheme.INK if usable else Color(UITheme.CREAM, 0.6)
	var label := skill.display_name
	var label_w := _width(label, SIZE_CTA, true)
	var icon_side := 26.0
	var content_x := origin.x + (ACTION_SIZE.x - icon_side - 8.0 - label_w) * 0.5
	_icon("icon_battle", Vector2(content_x, origin.y + (ACTION_SIZE.y - icon_side) * 0.5),
		icon_side, Color(1, 1, 1, 1.0 if usable else 0.45))
	_text(Vector2(content_x + icon_side + 8.0,
		origin.y + ACTION_SIZE.y * 0.5 + float(SIZE_CTA) * 0.36), label, ink, SIZE_CTA, true)

	if usable:
		_register_hit(Rect2(origin, ACTION_SIZE), "confirm", {"skill": skill})


# 스킬 알약. 액션 버튼 위로 쌓는다. 세로 간격이 히트박스 최소 변과 같아 판정이
# 겹치지 않는다 — 시각 높이 44 에 판정 56 을 쓰면서 겹침을 피하는 유일한 방법이다.
#
# 여기는 2차 패널이므로 스킬 이름·사용 불가 이유·사용 가능 랭크를 글자로 적는다.
func _draw_skill_panel(actions: Array[Dictionary]) -> void:
	for i in actions.size():
		var entry: Dictionary = actions[i]
		var skill: SkillData = entry["skill"]
		var ok := bool(entry["ok"])
		var pos := skill_origin() - Vector2(0.0, SKILL_STEP * float(i))

		var picked := i == hovered_action or (hovered_action < 0 and i == selected_action)
		var fill := _overlay_fill()
		var line := _overlay_line()
		if picked:
			fill = Color(UITheme.BG, 0.55)
			line = Color(UITheme.CREAM, 0.65)   # 크림 = 지금 고른 것
		_pill(pos, SKILL_SIZE, fill, line, BORDER_PICK if picked else BORDER_THIN)

		var ink := UITheme.CREAM if ok else UITheme.STONE_GRAY
		_text(pos + Vector2(14.0, 20.0), skill.display_name, ink, SIZE_LABEL, picked)
		# 왜 못 쓰는지 / 어느 랭크에서 쓰는지. 위치 전술이 전술이 되려면 보여야 한다.
		var note := String(entry["reason"]) if not ok else skill.format_usable_ranks()
		_text(pos + Vector2(14.0, 34.0), note, Color(UITheme.CREAM, 0.6), SIZE_TINY)

		# 코스트 핍 — 공명 소모는 크림, 기본공격의 회수는 세이지.
		var gain := skill.is_turn_basic() and skill.rp_cost <= 0
		var cost := 1 if gain else skill.rp_cost
		for k in mini(cost, 6):
			var dot := pos + Vector2(SKILL_SIZE.x - 18.0 - float(k) * 12.0,
				SKILL_SIZE.y * 0.5 - 4.0)
			_plate(dot, Vector2(8.0, 8.0),
				UITheme.SAGE if gain else UITheme.CREAM, _overlay_line(), 4, BORDER_THIN)

		# 남은 자물쇠 개수를 작은 막대로. 매 턴의 미니 퍼즐을 계산 없이 읽게 한다.
		var locks := int(entry["locks"])
		for k in mini(locks, 6):
			_bar(pos + Vector2(SKILL_SIZE.x - 16.0 - float(k) * 5.0, 8.0),
				Vector2(3.0, 8.0), TurnCombat.COLOR_TOUGHNESS)

		# **알약 자체가 버튼이다.** 고르는 것과 확정하는 것을 나누면 두 번 눌러야 한다.
		_register_hit(Rect2(pos + Vector2(0.0, (SKILL_SIZE.y - SKILL_STEP) * 0.5),
			Vector2(SKILL_SIZE.x, SKILL_STEP)), "action",
			{"index": i, "skill": skill, "ok": ok})


# --- 조준 (요소 ⑥에 포함) ---
#
# 사각 프레임을 없애고 **발밑 앰버 고리 + 적 카드 테두리**로 바꿨다. 메타 화면에 사각
# 조준 프레임과 같은 부품이 없고, 앰버가 이미 "지금 고른 것"을 뜻한다.
# 확산/광역 스킬 선택 시 부수 대상에는 흐린 같은 고리를 표시한다.
func _draw_aim() -> void:
	if paused or battle.phase != TurnBattleManager.Phase.AWAITING_INPUT:
		return

	# 적을 클릭할 수 있게 히트존을 등록한다.
	for unit in battle.enemies():
		var foot := unit_position(unit)
		_register_hit(Rect2(foot - Vector2(AIM_RING.x * 0.5, ENEMY_BODY_H),
			Vector2(AIM_RING.x, ENEMY_BODY_H)), "target", {"unit": unit})

	if selected_target == null:
		return
	_aim_ring(unit_position(selected_target), 1.0)

	var actions := battle.available_actions()
	var index := hovered_action if hovered_action >= 0 else selected_action
	if index < 0 or index >= actions.size():
		return
	var skill: SkillData = actions[index]["skill"]
	for entry in battle.ranks.expand_targets(battle.active_unit, skill, selected_target, null):
		var unit: TurnUnit = entry[0]
		if unit == selected_target or unit == null or unit.is_ally():
			continue
		_aim_ring(unit_position(unit), 0.45)


# 발밑 타원 고리. `draw_arc` 는 정원만 그리므로 변환으로 눌러 타원을 만든다.
func _aim_ring(foot: Vector2, alpha: float) -> void:
	var center := foot + Vector2(0.0, AIM_DY)
	var squash := AIM_RING.y / AIM_RING.x
	draw_set_transform(center, 0.0, Vector2(1.0, squash))
	draw_arc(Vector2.ZERO, AIM_RING.x * 0.5, 0.0, TAU, 32,
		Color(UITheme.ACCENT, alpha), AIM_BORDER / squash)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ===== 입력 (Input) =====

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_update_hover(event.position)
		return

	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	var zone := _zone_at(event.position)
	if zone.is_empty():
		return

	match String(zone["kind"]):
		"action":
			# 쓸 수 있으면 바로 실행한다. 못 쓰면 고르기만 해서 이유가 읽히게 둔다.
			selected_action = int(zone["data"]["index"])
			hovered_action = selected_action
			if bool(zone["data"].get("ok", false)):
				_emit_action(zone["data"]["skill"])
			else:
				_refresh_preview()

		"confirm":
			_emit_action(zone["data"]["skill"])

		"target":
			selected_target = zone["data"]["unit"]
			_refresh_preview()

		"ultimate":
			# **턴 순서와 무관하게 언제든 발동한다.** 이 게임의 심장이다.
			ultimate_requested.emit(zone["data"]["unit"])

		"speed":
			speed = 1.0 if speed >= MAX_SPEED else speed + 1.0
			speed_changed.emit(speed)

		"auto":
			auto = not auto
			auto_toggled.emit(auto)

		"pause":
			# **실제로 멈춘다.** 예전에는 `pass` 라 눌러도 아무 일이 없었다.
			paused = not paused
			pause_toggled.emit(paused)


func _emit_action(skill: SkillData) -> void:
	if skill == null or battle == null:
		return

	var target := selected_target
	if skill.needs_target_pick():
		var candidates := battle.ranks.valid_targets(battle.active_unit, skill)
		if target == null or not candidates.has(target):
			target = candidates[0] if not candidates.is_empty() else null

	action_chosen.emit(skill, target)
	selected_target = null
	hovered_action = -1
	selected_action = 0
	preview = {}


# 마우스가 올라간 행동이 바뀌면 **타임라인 프리뷰를 갱신한다** (설계서 §4.2.5).
func _update_hover(position: Vector2) -> void:
	var zone := _zone_at(position)
	var kind := String(zone["kind"]) if not zone.is_empty() else ""
	var index := int(zone["data"]["index"]) if kind == "action" else -1
	# 스킬 위를 지나가면 그것이 **고른 것으로 남는다.** 마우스가 떠나면 프리뷰만 걷힌다.
	if index >= 0:
		selected_action = index
	if index != hovered_action:
		hovered_action = index
		_refresh_preview()


func _refresh_preview() -> void:
	preview = {}
	if battle == null or battle.phase != TurnBattleManager.Phase.AWAITING_INPUT:
		return
	var actions := battle.available_actions()
	var index := hovered_action if hovered_action >= 0 else selected_action
	if index < 0 or index >= actions.size():
		return
	var skill: SkillData = actions[index]["skill"]
	preview = battle.preview_action(skill, selected_target)


# ===== 히트존 (Hit zones) =====
#
# `_draw()` 가 그리면서 클릭 영역을 등록하고, 입력은 그 목록을 역순으로(위에 그린 것
# 우선) 찾는다.
#
# **판정은 시각 크기와 분리한다.** 최소 56×56 이다.

func _register_hit(rect: Rect2, kind: String, data: Dictionary) -> void:
	var hit := Vector2(maxf(rect.size.x, HIT_MIN), maxf(rect.size.y, HIT_MIN))
	_hit_zones.append({
		"rect": Rect2(rect.get_center() - hit * 0.5, hit),
		"kind": kind,
		"data": data,
	})


func _zone_at(position: Vector2) -> Dictionary:
	for i in range(_hit_zones.size() - 1, -1, -1):
		var zone: Dictionary = _hit_zones[i]
		if (zone["rect"] as Rect2).has_point(position):
			return zone
	return {}


# ===== 그리기 헬퍼 (Draw helpers) =====
#
# 판은 전부 `StyleBoxFlat` 이다. 메타 화면이 `UITheme.overlay_*` 로 만드는 것과 같은
# 모양(둥근 모서리 + 얇은 테두리)을 `_draw()` 안에서 내는 유일한 방법이다.

# 색 값은 `TurnCombat` 이 소유한다. 여기서 다시 정의하지 않는다 —
# 전투 화면(`TurnBattle.gd`)과 이 HUD 가 각자 같은 색을 계산하면 한쪽만 고쳐진다.

## 오버레이 판의 면색. `UITheme.overlay_box()` 와 같은 값이다.
func _overlay_fill() -> Color:
	return TurnCombat.panel_fill()


## 오버레이 판의 테두리색.
func _overlay_line() -> Color:
	return TurnCombat.panel_line()


## 빈 게이지 바닥. 어두운 전장 위에서 트랙이 보이도록 잉크를 옅게 깐다.
func _gauge_empty() -> Color:
	return TurnCombat.gauge_empty()


func _box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var key := "%s|%s|%d|%d" % [fill.to_html(true), border.to_html(true), radius, width]
	if _boxes.has(key):
		return _boxes[key]
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = fill.a > 0.0
	box.set_corner_radius_all(radius)
	box.set_border_width_all(width)
	box.border_color = border
	_boxes[key] = box
	return box


## 둥근 판 하나.
func _plate(pos: Vector2, plate_size: Vector2, fill: Color,
		border: Color = Color(0, 0, 0, 0), radius: int = RADIUS_BOX,
		width: int = BORDER_THIN) -> void:
	draw_style_box(_box(fill, border, radius, width), Rect2(pos, plate_size))


## 알약(모서리를 완전히 둥글린 판).
func _pill(pos: Vector2, pill_size: Vector2, fill: Color,
		border: Color = Color(0, 0, 0, 0), width: int = BORDER_THIN) -> void:
	var radius := int(minf(pill_size.x, pill_size.y) * 0.5)
	draw_style_box(_box(fill, border, radius, width if border.a > 0.0 else 0),
		Rect2(pos, pill_size))


## 축 정렬 막대. 모서리를 둥글리지 않는 자리(구분선·작은 눈금)에만 쓴다.
func _bar(pos: Vector2, bar_size: Vector2, color: Color) -> void:
	draw_rect(Rect2(pos, bar_size), color)


## 게이지 — 트랙과 채움이 모두 알약이다.
func _gauge(pos: Vector2, gauge_size: Vector2, ratio: float, color: Color) -> void:
	var radius := int(gauge_size.y * 0.5)
	_plate(pos, gauge_size, _gauge_empty(), _overlay_line(), radius, BORDER_THIN)
	var filled := gauge_size.x * clampf(ratio, 0.0, 1.0)
	if filled > 1.0:
		_plate(pos, Vector2(filled, gauge_size.y), color, Color(0, 0, 0, 0), radius, 0)


## 원소 배지 — 재화 칩과 같은 문법의 작은 알약. 색과 문양이 함께 간다(색맹 대응).
func _element_badge(pos: Vector2, side: float, element: int, alpha: float) -> void:
	var color := TurnCombat.element_color(element) * Color(1, 1, 1, alpha)
	_plate(pos, Vector2(side, side), color, Color(UITheme.LINE, alpha * 0.6),
		int(side * 0.5), BORDER_THIN)
	_text_centered(pos + Vector2(side * 0.5, side * 0.5 + 4.0),
		TurnCombat.element_glyph(element), Color(UITheme.INK, alpha), SIZE_SMALL)


func _icon(icon_name: String, pos: Vector2, side: float,
		modulate: Color = Color.WHITE) -> void:
	var tex := _icon_texture(icon_name)
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(pos, Vector2(side, side)), false, modulate)


func _icon_texture(icon_name: String) -> Texture2D:
	if _icons.has(icon_name):
		return _icons[icon_name]
	# 어느 확장자인지는 UITheme 만 안다. 여기서 경로를 조립하지 않는다.
	var path := UITheme.icon_path(icon_name)
	var tex: Texture2D = null
	if not path.is_empty():
		tex = load(path) as Texture2D
	_icons[icon_name] = tex
	return tex


func _font_for(bold: bool) -> Font:
	return _font_bold if bold and _font_bold != null else _font


func _width(text: String, font_size: int, bold: bool = false) -> float:
	var f := _font_for(bold)
	if f == null:
		return 0.0
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


func _text(pos: Vector2, text: String, color: Color, font_size: int,
		bold: bool = false) -> void:
	var f := _font_for(bold)
	if f == null:
		return
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_centered(pos: Vector2, text: String, color: Color, font_size: int,
		bold: bool = false) -> void:
	_text(pos - Vector2(_width(text, font_size, bold) * 0.5, 0.0), text, color,
		font_size, bold)


# 그림 위에 바로 얹히는 라벨. 메타 화면의 하단 탭과 같이 외곽선을 넣어 어떤 배경에서도
# 읽히게 한다 (`main_screen.gd` 의 `outline_size 4` + `OUTLINE` 색).
func _text_outlined(pos: Vector2, text: String, color: Color, font_size: int) -> void:
	if _font == null:
		return
	draw_string_outline(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4,
		UITheme.OUTLINE)
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _text_centered_outlined(pos: Vector2, text: String, color: Color,
		font_size: int) -> void:
	_text_outlined(pos - Vector2(_width(text, font_size) * 0.5, 0.0), text, color, font_size)


# 폭에 맞게 글자를 줄인다. 칸 폭이 전투 시스템 상수(`ENEMY_SLOT_STEP` 등)에 묶여 있어
# 늘릴 수 없는 자리에서 쓴다.
func _elide(text: String, max_width: float, font_size: int, bold: bool = false) -> String:
	if _width(text, font_size, bold) <= max_width:
		return text
	var ellipsis := "…"
	var budget := max_width - _width(ellipsis, font_size, bold)
	var cut := text
	while cut.length() > 1 and _width(cut, font_size, bold) > budget:
		cut = cut.substr(0, cut.length() - 1)
	return cut + ellipsis


# ===== 초상 (Portraits) =====

# 이 유닛의 머리 크롭 텍스처. 없으면 null.
#
# 어떤 그림을 쓸지는 `PortraitSystem` 이 정하고(화면에서 고른 선택 > 저작 기본값),
# 어떻게 자를지는 `HUDKit` 이 정한다(저작된 머리 범위 `data/portraits/portrait_meta.tres`).
# **여기서 `character.portrait` 를 직접 읽거나 크롭을 다시 계산하지 않는다** — 그러면
# 전투 화면만 다른 그림·다른 크롭이 뜬다.
func _portrait_of(unit: TurnUnit) -> Texture2D:
	if _head_art.has(unit.unit_id):
		return _head_art[unit.unit_id]

	var source: Texture2D = null
	if unit.character != null:
		source = PortraitSystem.get_portrait(unit.character)
	elif unit.enemy != null:
		source = unit.enemy.portrait

	var cropped: Texture2D = null
	if source != null:
		cropped = HUDKit.head_texture(source)
	_head_art[unit.unit_id] = cropped
	return cropped


# 초상을 칸에 채운다. **늘리지 않는다.**
#
# 머리 크롭은 정사각이고 칸은 68×84 이나 32×32 이다. 텍스처를 칸 비율로 늘리면 얼굴이
# 찌그러지므로(가이드 §3.4), 칸 비율과 같은 창을 UV 로 잘라 낸다. 세로 중심을 살짝 위로
# 두는 것은 정가운데로 자르면 턱이 먼저 잘려 나가기 때문이다.
#
# 모서리를 둥글리는 이유: 판이 전부 둥근 모서리인데 그림만 각지면 카드 네 귀퉁이에서
# 그림이 판 밖으로 삐져나온다. `draw_colored_polygon` 에 둥근 사각형 정점을 넘기고
# UV 도 같은 비율로 만든다.
func _portrait_patch(pos: Vector2, patch_size: Vector2, texture: Texture2D,
		tint: Color = Color.WHITE, center_v: float = 0.46,
		radius: float = 0.0) -> void:
	if texture == null:
		return

	# `HUDKit.head_texture()` 는 `AtlasTexture` 를 돌려준다. **UV 는 아틀라스 원본 기준이라
	# 잘라 둔 영역을 자동으로 따르지 않는다** — 그대로 0~1 을 쓰면 머리가 아니라 전신이
	# 들어온다. 영역을 직접 원본 좌표로 환산한다.
	var base := texture
	var region := Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		var atlas := texture as AtlasTexture
		if atlas.atlas != null:
			base = atlas.atlas
			region = atlas.region

	var sheet := base.get_size()
	if sheet.x <= 0.0 or sheet.y <= 0.0 or region.size.y <= 0.0:
		return

	# 칸 비율과 같은 창을 영역 안에서 잘라 낸다. 늘리면 얼굴이 찌그러진다.
	var quad_aspect := patch_size.x / patch_size.y
	var win := region.size
	if win.x / win.y > quad_aspect:
		win.x = win.y * quad_aspect
	else:
		win.y = win.x / quad_aspect
	var win_pos := Vector2(
		region.position.x + (region.size.x - win.x) * 0.5,
		clampf(region.position.y + region.size.y * center_v - win.y * 0.5,
			region.position.y, region.position.y + region.size.y - win.y))

	var u0 := win_pos / sheet
	var u1 := (win_pos + win) / sheet

	var points := _rounded_points(pos, patch_size, radius)
	var uvs := PackedVector2Array()
	uvs.resize(points.size())
	for i in points.size():
		# 판 안에서의 상대 위치를 그대로 UV 창에 사상한다.
		var local := (points[i] - pos) / patch_size
		uvs[i] = Vector2(lerpf(u0.x, u1.x, local.x), lerpf(u0.y, u1.y, local.y))
	draw_colored_polygon(points, tint, uvs, base)


# 둥근 사각형의 정점. 반경이 0 이면 네 귀퉁이만 돌려준다.
func _rounded_points(pos: Vector2, rect_size: Vector2, radius: float) -> PackedVector2Array:
	var r := minf(radius, minf(rect_size.x, rect_size.y) * 0.5)
	if r <= 0.5:
		return PackedVector2Array([
			pos,
			pos + Vector2(rect_size.x, 0.0),
			pos + rect_size,
			pos + Vector2(0.0, rect_size.y),
		])

	var steps := 5
	var points := PackedVector2Array()
	# 좌상 -> 우상 -> 우하 -> 좌하 순서로 각 귀퉁이 호를 잇는다.
	var corners := [
		{"c": pos + Vector2(r, r), "from": PI, "to": PI * 1.5},
		{"c": pos + Vector2(rect_size.x - r, r), "from": PI * 1.5, "to": TAU},
		{"c": pos + Vector2(rect_size.x - r, rect_size.y - r), "from": 0.0, "to": PI * 0.5},
		{"c": pos + Vector2(r, rect_size.y - r), "from": PI * 0.5, "to": PI},
	]
	for corner in corners:
		var center: Vector2 = corner["c"]
		var from: float = corner["from"]
		var to: float = corner["to"]
		for s in steps + 1:
			var a := lerpf(from, to, float(s) / float(steps))
			points.append(center + Vector2(cos(a), sin(a)) * r)
	return points


# 전투가 진행되면 화면을 갱신한다. 전투 화면이 부른다.
func refresh() -> void:
	_refresh_preview()
	queue_redraw()
