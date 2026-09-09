extends Control
class_name TurnBattleHUD

# 턴제 전투 HUD (#450, 규율 개편 #478).
#
# **설계서 §14 — 확정된 UI 규율**을 지킨다. 흔한 모바일 RPG처럼 사각형 카드에 스탯을
# 담아 화면을 채우는 방식과 정반대다.
#
#   1. 중앙 개방 — 화면 중앙 60%에 UI를 두지 않는다. 캐릭터가 주인공이다
#   2. 가장자리 흡착 — 모든 UI가 화면 4변에 붙는다
#   3. 형태 언어 2종만 — 평행사변형(`skewX -12°`)과 막대. 원형·마름모·육각형 전부 금지
#   4. 텍스트 역기울기 — 글자는 `skewX +12°`로 되돌려 읽을 수 있게 한다
#   5. 요소 종류 상한 6종 — ①타임라인 칩 ②적 분절바+HP바 ③아군 초상+오의 스트립
#      ④아군 HP바+상태 점 ⑤공명 핍 ⑥액션 버튼. 넘으면 통합한다
#   6. 글자 라벨 금지 — "HP"·"인성치"·"SP" 같은 글자를 쓰지 않는다. **색과 위치가 라벨**
#   7. 색은 의미에만 — UI 크롬은 전부 무채색
#
# > 가장 중요한 교훈: 정보를 담을 공간이 부족해 보여도 **중앙을 침범하지 마라.**
#
# ## 통합 구조 (요소 6종을 지키는 방법)
#
# - **분절 인성치 바 하나**가 [인성치 + 약점 + 자물쇠] 3가지를 동시에 표현한다.
#   칸 개수 = 남은 자물쇠, 칸 색 = 요구 속성, 칸이 어두워짐 = 해제 완료.
#   예고가 없는 적은 같은 칸에 **약점 속성**을 칠하고 인성치 비율로 마스크한다.
#   그래서 약점 아이콘 줄이 따로 필요하지 않다.
# - **오의 게이지는 초상 프레임 좌측 변의 세로 스트립**이다. 별도 오의 버튼이 없다.
# - **상태이상은 아이콘이 아니라 색 점**(5×7 기울인 슬래시)이고, 아군·적이 같은 형태다.
# - 현재 웨이브는 타임라인 머리의 막대 핍(①에 흡수), 배속·자동·일시정지는 우상단
#   막대 토글(⑥에 흡수)이다.
#
# ## 2차 패널로 옮긴 정보 (삭제한 것이 아니다)
#
# - **스킬 목록** — 처음에는 액션 버튼 호버 시에만 펼쳤다("액션 입력 버튼 1개" 조항).
#   되돌렸다: 화면에 **누를 수 있는 것이 하나도 보이지 않았다.** 무엇을 쓸 수 있는지
#   알려면 포인터를 정확히 버튼 위에 올려야 했고, 그 전까지는 조작 가능한 UI 가
#   없는 화면으로 보였다. 지금은 **내 턴일 때만** 펼쳐 둔다 — 누를 수 있을 때만
#   보이므로 적 턴에는 여전히 버튼 1개다.
# - **적 행동 예고 문장** — 적 머리 위 상시 패널에서 **조준 중인 적 1체**에 한해
#   하단 밴드 우측 스트립으로. 예고의 요구 조건 자체는 분절 바가 항상 보여준다.
#
# ## 규격 해석
#
# 확정 규격표는 폭 656px 기준이지만 이 프로젝트의 뷰포트는 1280×720 이다.
# **환산(×1.95)하지 않고 1:1 로 적용한다.** 환산하면 적 클러스터가 100px → 195px 로
# 커져 적 간격 112px(`ENEMY_SLOT_STEP`)를 넘어 5체의 바가 서로 겹친다. 적 간격은
# 랭크 배치 = 전투 시스템의 소유이므로 UI 작업 범위에서 건드릴 수 없다.
#
# ## 화면 크기는 1280×720 이 아니다
#
# 프로젝트는 `canvas_items` + `expand` 스트레치를 쓴다. **창 비율이 16:9 가 아니면
# 캔버스가 기준 해상도보다 커진다** — 1920×1012 창에서 실측 캔버스는 1366×720 이었다.
# 그래서 우하단·우상단 UI 를 x 1160 처럼 절대 좌표로 두면 화면 오른쪽 끝에서 114px
# 안쪽에 떠 있게 되고, "가장자리 흡착"이 깨진다(녹화 영상에서 그렇게 보였다).
#
# 규칙: **크기는 상수, 위치는 변 기준 여백**이다. 오른쪽·아래에 붙는 것은 `size` 에서
# 빼고, 전장(적·아군 줄)은 캔버스 가로 중심에서 잰다. `size` 는 `_ready()` 의
# 전체 사각형 프리셋이 잡아 주므로 캔버스 크기와 같다.
#
# 왜 `_draw()`로 직접 그리는가: `Control`에는 skew 가 없어서 기울어진 평행사변형을
# 노드 조합으로 만들 수 없다. 문법의 핵심이 `skewX(-12°)`이므로 폴리곤을 직접 그린다.
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

# ===== 형태 언어 =====

const SKEW := -0.2126        # tan(-12°). 평행사변형의 기울기.
const MAX_SPEED := 3.0

## 터치 히트박스 최소 변. **시각 크기와 분리한다** — 오의 스트립은 4×36 이지만
## 판정은 56×56 이다. 기울기 없는 직사각형으로 판정한다.
const HIT_MIN := 56.0

# ===== 레이아웃 상수 (확정 규격, 1:1) =====

# --- 웨이브 핍 (타임라인 머리) ---
const WAVE_ORIGIN := Vector2(8.0, 70.0)
const WAVE_PIP := Vector2(14.0, 5.0)
const WAVE_GAP := 4.0

# --- 좌측 타임라인 ---
const TIMELINE_RAIL_W := 3.0     # 좌측 강조선 3px
const TIMELINE_X := 8.0
const TIMELINE_Y := 92.0
const TIMELINE_CHIP_W := 60.0
const TIMELINE_CHIP_H := 28.0
const TIMELINE_CHIP_H_NOW := 32.0  # 현재 칩만 32
const TIMELINE_GAP := 6.0
const TIMELINE_COUNT := 5          # 앞으로 5개 유닛
## 고스트는 칩 **옆에** 나란히 둔다. 칩 폭보다 작게 밀면 글자가 겹쳐 둘 다 못 읽는다.
const TIMELINE_GHOST_DX := TIMELINE_CHIP_W + TIMELINE_GAP
## 칩 안 초상 패치 폭. 강조선 3 + 26 + 문양 자리를 남긴다.
const CHIP_ART_W := 26.0

# --- 적 클러스터 ---
#
# `unit_position()` 은 전투 화면이 도형·연출을 놓는 좌표이기도 하다. **바꾸지 않는다.**
## 적 줄의 바닥에서 잰 높이. 지면선(아래에서 420)보다 위에 선다.
const ENEMY_ROW_FROM_BOTTOM := 452.0
## 적 줄의 가로 위치는 캔버스 **중심 기준**이다. 1280 기준 x 700 과 같은 값.
const ENEMY_CENTER_DX := 60.0
const ENEMY_SLOT_STEP := 112.0
const CLUSTER_W := 100.0
## 적 도형 높이(62×78). 클러스터를 이 위로 올려야 바가 몸통에 겹치지 않는다.
const ENEMY_BODY_H := 78.0
## 클러스터 밑변을 도형 정수리에서 이만큼 더 띄운다.
##
## -76 이었을 때 클러스터가 도형 상단 27px 를 덮었고, **적 HP 바(#E0473B)가 적 도형
## (#C8402F) 위에 얹혀 빨강 위 빨강이 되어 남은 체력을 읽을 수 없었다.**
##
## 값의 근거: 전투 화면이 원소 문양 라벨을 발밑 기준 -112 에 놓고 그 글자가 22px 라
## 발밑 -112 ~ -90 을 쓴다. 6px 만 띄웠을 때 클러스터 밑변(-84)이 그 문양과 겹쳤다.
## 문양 위로 넘기려면 정수리(-78)에서 46 이상 띄워야 한다.
const CLUSTER_GAP := 46.0
const SEG_SIZE := Vector2(22.0, 8.0)
const SEG_GAP := 4.0             # 22×4 + 4×3 = 100 — 클러스터 폭과 정확히 같다
const ENEMY_HP_SIZE := Vector2(100.0, 5.0)
const ENEMY_HP_DY := 12.0
const ENEMY_STATUS_DY := 21.0
const AIM_FRAME := Vector2(58.0, 54.0)
const AIM_BORDER := 2.0
## `unit_position()` 은 도형의 **발밑**이다 (전투 화면이 `body.position = -size * (0.5, 1)`
## 로 놓는다). 프레임을 그 위치에 그대로 씌우면 적의 다리 아래에 걸린다.
const AIM_DY := -39.0

# --- 아군 하단 밴드 ---
const BAND_H := 112.0            # 하단 밴드 높이 112
const CARD_LEFT := 40.0
const CARD_FROM_BOTTOM := 98.0
const CARD_STEP := 62.0          # 지터 없음. 확정 규격은 균일 간격이다
const ULT_STRIP := Vector2(4.0, 36.0)
const PORTRAIT := Vector2(42.0, 36.0)
const ALLY_HP_SIZE := Vector2(42.0, 4.0)
const ALLY_HP_GAP := 5.0         # 프레임 아래 5px
const STATUS_DOT := Vector2(5.0, 7.0)
const STATUS_GAP := 3.0
const STATUS_MAX := 4

# --- 공명 / 열기 / 예고 (하단 밴드 우측) ---
const RESONANCE_LEFT := 312.0
const RESONANCE_FROM_BOTTOM := 100.0
const RESONANCE_PIP := Vector2(7.0, 13.0)
const RESONANCE_GAP := 5.0
const HEAT_FROM_BOTTOM := 76.0
const HEAT_SIZE := Vector2(100.0, 4.0)
const INTENT_FROM_BOTTOM := 58.0
const INTENT_H := 24.0
const INTENT_MAX_W := 600.0

# --- 액션 버튼 (우하단) ---
const ACTION_SIZE := Vector2(92.0, 66.0)
const ACTION_BORDER := 3.0
const ACTION_FROM_RIGHT := 120.0
const ACTION_FROM_BOTTOM := 90.0
## 스킬 스트립. 세로 간격을 히트박스 최소 변(56)에 맞춰 판정이 겹치지 않게 한다.
const SKILL_SIZE := Vector2(124.0, 34.0)
const SKILL_STEP := HIT_MIN
const SKILL_FROM_RIGHT := 152.0
const SKILL_FROM_BOTTOM := 124.0

# --- 아군 도형 위치 (전투 화면이 쓰는 좌표) ---
const ALLY_ROW_FROM_BOTTOM := 268.0
const ALLY_CENTER_DX := -84.0
const ALLY_SLOT_STEP := -84.0

# --- 우상단 토글 3개 ---
const TOGGLE_TOP := 16.0
const TOGGLE_FROM_RIGHT := 176.0
const TOGGLE_SIZE := Vector2(40.0, 20.0)
const TOGGLE_STEP := HIT_MIN     # 판정이 서로 겹치지 않는 최소 간격

# ===== 상태 =====

var battle: TurnBattleManager = null

## 마우스가 올라간 행동. 여기가 바뀌면 타임라인 프리뷰가 갱신된다 (설계서 §4.2.5).
var hovered_action: int = -1
## 지금 고른 행동. **호버와 달리 마우스가 떠나도 남는다.**
## 호버만 있던 동안에는 스킬을 고르고 액션 버튼으로 손을 옮기는 순간 선택이 풀려서,
## 큰 버튼이 항상 첫 행동(일반공격)만 확정했다.
var selected_action: int = 0
## 플레이어가 조준 중인 적.
var selected_target: TurnUnit = null
## 프리뷰 결과. `{"order": Array[TurnUnit], "expected": Dictionary, "locks": int}`
var preview: Dictionary = {}

var speed: float = 1.0
var auto: bool = false

## 오의 준비 스트립의 발광 위상. 형태는 그대로 두고 밝기만 흔든다.
var _glow_phase: float = 0.0

var _font: Font = null
var _hit_zones: Array[Dictionary] = []
## 유닛별 머리 크롭 텍스처. `unit_id` -> Texture2D 또는 null(아트 없음).
## `_draw()` 가 매 프레임 돌므로 초상 조회를 프레임마다 반복하지 않는다.
var _head_art: Dictionary = {}


func _ready() -> void:
	name = "TurnBattleHUD"
	# **`set_anchors_preset()` 만 부르면 안 된다.** 그쪽은 앵커를 바꾸면서 현재 사각형을
	# 유지하도록 오프셋을 다시 계산한다. 이 노드는 `CanvasLayer` 의 직속 자식이라 컨테이너가
	# 크기를 잡아 주지 않고, `_ready()` 시점 사각형이 0×0 이므로 오프셋이 0×0 에 고정된다.
	# 그러면 `_draw()` 는 (사각형 밖으로도 그리므로) 정상으로 보이는데 **마우스 입력만
	# 전부 사라진다** — `gui_get_hovered_control()` 이 계속 null 이고 버튼이 하나도 눌리지
	# 않았다. 오프셋까지 함께 잡아야 한다.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_glow_phase += delta * 3.0
	queue_redraw()


# ===== 좌표 (Layout) =====
#
# **크기는 상수, 위치는 변 기준**이다. 캔버스가 1280×720 보다 커질 수 있으므로
# (헤더 "화면 크기는 1280×720 이 아니다" 참고) 절대 좌표를 쓰지 않는다.

func enemy_position(rank: int) -> Vector2:
	return Vector2(size.x * 0.5 + ENEMY_CENTER_DX + ENEMY_SLOT_STEP * float(rank - 1),
		size.y - ENEMY_ROW_FROM_BOTTOM)


func ally_position(rank: int) -> Vector2:
	# 전투 화면이 도형을 놓는 좌표다. 하단 밴드의 카드 배치와는 별개다.
	return Vector2(size.x * 0.5 + ALLY_CENTER_DX + ALLY_SLOT_STEP * float(rank - 1),
		size.y - ALLY_ROW_FROM_BOTTOM)


# 적 클러스터 밑변. 적 도형 정수리보다 위다.
func cluster_origin(unit: TurnUnit) -> Vector2:
	var cluster_h := SEG_SIZE.y + 4.0 + ENEMY_HP_SIZE.y + 3.0 + STATUS_DOT.y
	return unit_position(unit) + Vector2(-CLUSTER_W * 0.5,
		-ENEMY_BODY_H - CLUSTER_GAP - cluster_h)


func toggle_origin() -> Vector2:
	return Vector2(size.x - TOGGLE_FROM_RIGHT, TOGGLE_TOP)


func card_origin() -> Vector2:
	return Vector2(CARD_LEFT, size.y - CARD_FROM_BOTTOM)


func resonance_origin() -> Vector2:
	return Vector2(RESONANCE_LEFT, size.y - RESONANCE_FROM_BOTTOM)


func heat_origin() -> Vector2:
	return Vector2(RESONANCE_LEFT, size.y - HEAT_FROM_BOTTOM)


func intent_origin() -> Vector2:
	return Vector2(RESONANCE_LEFT, size.y - INTENT_FROM_BOTTOM)


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
	_draw_resonance()
	_draw_heat()
	_draw_intent_strip()
	_draw_action()
	_draw_aim_frames()


# --- 배속 · 자동 · 일시정지 (우상단) ---
#
# 글자 라벨을 쓰지 않는다. 배속은 채워진 막대 핍 개수, 자동은 막대 하나의 점등,
# 일시정지는 막대 두 개 — 형태만으로 구분된다.
func _draw_toggles() -> void:
	var origin := toggle_origin()
	var speed_pos := origin
	_skewed(speed_pos, TOGGLE_SIZE, TurnCombat.COLOR_PANEL, TurnCombat.COLOR_BORDER_IDLE)
	for i in 3:
		var on := float(i) < speed
		draw_rect(Rect2(speed_pos + Vector2(7.0 + float(i) * 9.0, 5.0), Vector2(4.0, 10.0)),
			TurnCombat.COLOR_TEXT_ACTIVE if on else TurnCombat.COLOR_GAUGE_EMPTY)
	_register_hit(Rect2(speed_pos, TOGGLE_SIZE), "speed", {})

	var auto_pos := origin + Vector2(TOGGLE_STEP, 0.0)
	_skewed(auto_pos, TOGGLE_SIZE, TurnCombat.COLOR_PANEL,
		TurnCombat.COLOR_AIM if auto else TurnCombat.COLOR_BORDER_IDLE)
	draw_rect(Rect2(auto_pos + Vector2(8.0, 8.0), Vector2(24.0, 4.0)),
		TurnCombat.COLOR_TEXT_ACTIVE if auto else TurnCombat.COLOR_GAUGE_EMPTY)
	_register_hit(Rect2(auto_pos, TOGGLE_SIZE), "auto", {})

	var pause_pos := origin + Vector2(TOGGLE_STEP * 2.0, 0.0)
	_skewed(pause_pos, TOGGLE_SIZE, TurnCombat.COLOR_PANEL, TurnCombat.COLOR_BORDER_IDLE)
	for i in 2:
		draw_rect(Rect2(pause_pos + Vector2(14.0 + float(i) * 9.0, 5.0), Vector2(4.0, 11.0)),
			TurnCombat.COLOR_TEXT_DIM)
	_register_hit(Rect2(pause_pos, TOGGLE_SIZE), "pause", {})


# --- 현재 웨이브 (필수 정보 5번) ---
#
# 타임라인 머리에 막대 핍으로 얹는다. 별도 요소를 만들지 않기 위해 ①에 흡수시켰다.
func _draw_wave() -> void:
	var total := maxi(battle.wave_total, 1)
	for i in total:
		var pos := WAVE_ORIGIN + Vector2(float(i) * (WAVE_PIP.x + WAVE_GAP), 0.0)
		var done := i <= battle.wave_index
		draw_rect(Rect2(pos, WAVE_PIP),
			TurnCombat.COLOR_TEXT_ACTIVE if done else TurnCombat.COLOR_GAUGE_EMPTY)


# --- 행동 순서 타임라인 (요소 ①) ---
#
# **이 요소 하나가 게임의 전략성을 결정한다.** 앞으로 5개 유닛을 보여주고, 스킬 호버
# 시 "이 행동 후의 순서"를 반투명 고스트로 겹쳐 그린다(FF10 식).
#
# 아군/적 구분은 칩 좌측 강조선 3px 의 색이다. 사이클 경계는 칩 사이의 막대다 —
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
		var height := TIMELINE_CHIP_H_NOW if i == 0 else TIMELINE_CHIP_H
		var size := Vector2(TIMELINE_CHIP_W, height)
		var pos := Vector2(TIMELINE_X, y)
		var alpha := maxf(1.0 - float(i) * 0.09, 0.45)
		var cycle := int(entry["cycle"])

		# 사이클 경계 막대. 여기서 다음 사이클이 시작된다.
		if last_cycle >= 0 and cycle != last_cycle:
			draw_rect(Rect2(Vector2(TIMELINE_X, y - TIMELINE_GAP * 0.5 - 1.0),
				Vector2(TIMELINE_CHIP_W, 2.0)), TurnCombat.COLOR_BORDER_IDLE)
		last_cycle = cycle

		var fill := TurnCombat.COLOR_PANEL
		fill.a *= alpha
		var border := TurnCombat.COLOR_PANEL_LINE if i == 0 else TurnCombat.COLOR_BORDER_IDLE
		_skewed(pos, size, fill, border * Color(1, 1, 1, alpha))

		# 좌측 강조선 — **아군/적 구분은 이 색 하나가 전부다.**
		var rail := TurnCombat.COLOR_ALLY_HP if unit.is_ally() else TurnCombat.COLOR_ENEMY_HP
		draw_rect(Rect2(pos + Vector2(0.0, 2.0),
			Vector2(TIMELINE_RAIL_W, size.y - 4.0)), rail * Color(1, 1, 1, alpha))
		# 소환체는 강조선을 두 줄로 쪼갠다. 색을 늘리지 않고 형태로 구분한다.
		if unit.is_summon:
			draw_rect(Rect2(pos + Vector2(0.0, size.y * 0.5 - 1.0),
				Vector2(TIMELINE_RAIL_W, 2.0)), TurnCombat.COLOR_BACKDROP)

		# 추가 행동은 칩 안에 얇은 막대를 덧댄다 (패턴 배경 대신).
		if bool(entry["extra"]):
			draw_rect(Rect2(pos + Vector2(size.x - 6.0, 3.0), Vector2(2.0, size.y - 6.0)),
				TurnCombat.COLOR_TEXT_DIM * Color(1, 1, 1, alpha))

		# 초상 + 원소 문양. **얼굴이 있으면 이름 두 글자는 지운다** — 42px 생존 규칙의
		# 요지가 "머리색·실루엣·눈 위치로 알아본다"이고, 60×32 칩에 얼굴과 글자를 함께
		# 넣으면 둘 다 못 읽는다.
		var ink := TurnCombat.COLOR_TEXT_ACTIVE * Color(1, 1, 1, alpha)
		var art := _portrait_of(unit)
		var text_x := 24.0
		if art != null:
			_skewed_texture(pos + Vector2(TIMELINE_RAIL_W + 1.0, 1.0),
				Vector2(CHIP_ART_W, size.y - 2.0), art, Color(1, 1, 1, alpha))
			text_x = TIMELINE_RAIL_W + CHIP_ART_W + 4.0
		_text(pos + Vector2(text_x, size.y * 0.5 + 4.0),
			TurnCombat.element_glyph(unit.element),
			TurnCombat.element_color(unit.element) * Color(1, 1, 1, alpha), 12)
		if art == null:
			_text(pos + Vector2(text_x + 16.0, size.y * 0.5 + 4.0),
				unit.display_name.substr(0, 2), ink, 12)

		# CR 막대 — 초보자를 위한 두 번째 층위 (설계서 §4.2.2).
		var charge := battle.timeline.get_charge_ratio(unit)
		var bar := pos + Vector2(6.0, size.y - 4.0)
		draw_rect(Rect2(bar, Vector2(size.x - 12.0, 2.0)),
			TurnCombat.COLOR_GAUGE_EMPTY * Color(1, 1, 1, alpha))
		draw_rect(Rect2(bar, Vector2((size.x - 12.0) * charge, 2.0)),
			rail * Color(1, 1, 1, alpha * 0.8))

		y += size.y + TIMELINE_GAP

	# --- 프리뷰 고스트 ---
	#
	# 앞당김/지연이 포함된 스킬이면 칩이 이동하는 것을 반투명으로 겹쳐 보여준다.
	# 조준·선택을 뜻하는 백색을 쓴다 — 지금 고른 행동의 결과이기 때문이다.
	#
	# **포인터를 올리고 있는 동안만** 그린다. 선택이 유지되도록 바꾼 뒤로는 프리뷰가 항상
	# 살아 있어서, 고스트를 늘 그리면 타임라인이 두 줄로 보여 어느 쪽이 실제 순서인지
	# 읽을 수 없었다.
	if ghost.is_empty() or hovered_action < 0:
		return
	var gy := TIMELINE_Y
	for i in mini(ghost.size(), count):
		var height := TIMELINE_CHIP_H_NOW if i == 0 else TIMELINE_CHIP_H
		var unit: TurnUnit = ghost[i]
		if unit != entries[i]["unit"]:
			var pos := Vector2(TIMELINE_X + TIMELINE_GHOST_DX, gy)
			var chip := Vector2(TIMELINE_CHIP_W, height)
			_skewed(pos, chip, Color(1, 1, 1, 0.14), Color(1, 1, 1, 0.7))
			# 고스트도 실제 칩과 **같은 것**을 보여야 한다. 한쪽은 얼굴, 다른 쪽은
			# 글자였더니 바뀐 순서를 두 칸씩 눈으로 짝지어야 읽을 수 있었다.
			var ghost_art := _portrait_of(unit)
			if ghost_art != null:
				_skewed_texture(pos + Vector2(TIMELINE_RAIL_W + 1.0, 1.0),
					Vector2(CHIP_ART_W, chip.y - 2.0), ghost_art, Color(1, 1, 1, 0.85))
			else:
				_text(pos + Vector2(8.0, chip.y * 0.5 + 4.0),
					unit.display_name.substr(0, 2), TurnCombat.COLOR_AIM, 12)
		gy += height + TIMELINE_GAP


# --- 적 정보 클러스터 (요소 ②) ---
#
# 적 머리 위 부유. **라벨 텍스트를 전혀 쓰지 않는다.** 3층 구조:
#   1층: 분절 인성치 바 — 칸 개수 = 남은 자물쇠, 칸 색 = 요구 속성, 어두움 = 해제 완료
#   2층: HP 바 100×5 (적색)
#   3층: 상태이상 색 점 (5×7 기울인 슬래시)
func _draw_enemy_clusters() -> void:
	for unit in battle.enemies():
		var base := cluster_origin(unit)

		# 클러스터가 도형에서 46px 위로 떨어져 있으므로 **어느 적의 것인지 잇는다.**
		# 5체가 나란히 서면 어느 바가 누구 것인지 위치만으로는 확신할 수 없다.
		var foot := unit_position(unit)
		var tick_top := base.y + ENEMY_STATUS_DY + STATUS_DOT.y + 2.0
		draw_rect(Rect2(Vector2(foot.x - 0.5, tick_top),
			Vector2(1.0, foot.y - ENEMY_BODY_H - tick_top - 2.0)),
			TurnCombat.COLOR_BORDER_IDLE)

		_draw_segment_bar(unit, base)

		# --- 2층: HP 바 ---
		var hp_pos := base + Vector2(0.0, ENEMY_HP_DY)
		draw_rect(Rect2(hp_pos, ENEMY_HP_SIZE), TurnCombat.COLOR_GAUGE_EMPTY)
		draw_rect(Rect2(hp_pos, Vector2(ENEMY_HP_SIZE.x * unit.get_hp_ratio(),
			ENEMY_HP_SIZE.y)), TurnCombat.COLOR_ENEMY_HP)

		# --- 3층: 상태이상 색 점 ---
		_draw_status_dots(unit, base + Vector2(0.0, ENEMY_STATUS_DY))


# 분절 인성치 바. **[인성치 + 약점 + 자물쇠]를 한 요소로 표현한다.**
#
# 예고가 있으면 칸 = 자물쇠다. 칸 색이 요구 속성이고, 해제된 칸은 어두워진다.
# 예고가 없으면 칸 = 약점 속성이고, 남은 인성치 비율만큼만 칸이 켜진다.
# 둘 다 없으면 무채색 막대 하나로 인성치만 보여준다.
#
# 이렇게 묶어야 약점 아이콘 줄을 따로 만들지 않고도 "무엇을 넣어야 하는가"가 보인다.
func _draw_segment_bar(unit: TurnUnit, base: Vector2) -> void:
	# 격파 상태는 클러스터 폭만큼 빈 게이지를 둔다 — 빈 칸이 곧 "인성치가 없다"다.
	if unit.is_broken:
		draw_rect(Rect2(base, Vector2(CLUSTER_W, SEG_SIZE.y)),
			TurnCombat.COLOR_GAUGE_EMPTY)
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
			# 약점도 예고도 없으면 남은 인성치 비율만 막대로 보여준다.
			draw_rect(Rect2(base, Vector2(CLUSTER_W, SEG_SIZE.y)),
				TurnCombat.COLOR_GAUGE_EMPTY)
			draw_rect(Rect2(base, Vector2(CLUSTER_W * ratio, SEG_SIZE.y)),
				TurnCombat.COLOR_TOUGHNESS)
			return
		var lit := int(ceilf(float(weak.size()) * ratio))
		for i in weak.size():
			weak[i]["off"] = i >= lit
		cells = weak

	# **칸 폭은 22 로 고정한다.** 폭을 클러스터에 맞춰 나누면 자물쇠 1개짜리 적이
	# 100px 짜리 통짜 바로 보여서 "인성치가 가득하다"로 읽힌다 — 여기서 정보는
	# **칸의 개수**다. 칸이 4개를 넘어 폭을 넘길 때만 줄인다.
	var count := cells.size()
	var seg_w := minf(SEG_SIZE.x,
		(CLUSTER_W - SEG_GAP * float(count - 1)) / float(count))
	for i in count:
		var cell: Dictionary = cells[i]
		var pos := base + Vector2((seg_w + SEG_GAP) * float(i), 0.0)
		draw_rect(Rect2(pos, Vector2(seg_w, SEG_SIZE.y)), TurnCombat.COLOR_GAUGE_EMPTY)
		var color: Color = cell["color"]
		if bool(cell["off"]):
			# 어두워짐 = 해제 완료 / 이미 깎인 칸. 색상은 남겨 무엇이었는지 읽히게 한다.
			color = color.darkened(0.74)
		draw_rect(Rect2(pos, Vector2(seg_w, SEG_SIZE.y)), color)
		# 색맹 대응 — 칸 안에 요구 타입의 고유 문양을 어두운 잉크로 찍는다.
		if not bool(cell["off"]) and seg_w >= 14.0:
			_text_centered(pos + Vector2(seg_w * 0.5, SEG_SIZE.y - 1.0),
				String(cell["glyph"]), TurnCombat.COLOR_BACKDROP, 9)


# 상태이상 색 점. **아이콘도 텍스트도 쓰지 않는다** — 5×7 기울인 슬래시 최대 4개다.
# 아군과 적이 같은 형태를 쓴다.
func _draw_status_dots(unit: TurnUnit, origin: Vector2) -> void:
	var shown := 0
	for status in unit.statuses:
		if shown >= STATUS_MAX:
			break
		var pos := origin + Vector2(float(shown) * (STATUS_DOT.x + STATUS_GAP), 0.0)
		_skewed(pos, STATUS_DOT, status.color())
		shown += 1
	# 4개를 넘으면 마지막 자리에 무채색 점을 하나 더 찍어 "더 있다"만 알린다.
	if unit.statuses.size() > STATUS_MAX:
		_skewed(origin + Vector2(float(STATUS_MAX) * (STATUS_DOT.x + STATUS_GAP), 0.0),
			STATUS_DOT, TurnCombat.COLOR_TEXT_DIM)


# 호버 중인 스킬의 예상 피해를 모든 대상 위에 표시한다.
#
# 예고 스트립과 달리 이것은 **전부 보여야 한다** — 확산·전체 공격이 누구에게 얼마나
# 들어가는지가 판단의 핵심이고, 숫자 하나는 겹칠 만큼 크지 않다.
func _draw_expected_damage() -> void:
	var expected: Dictionary = preview.get("expected", {})
	if expected.is_empty():
		return
	for unit in battle.enemies():
		if not expected.has(unit.unit_id):
			continue
		var pos := cluster_origin(unit) + Vector2(CLUSTER_W + 6.0, ENEMY_HP_DY + 6.0)
		_text(pos, "-%d" % int(expected[unit.unit_id]), TurnCombat.COLOR_ENEMY_HP, 15)


# --- 아군 하단 밴드 (요소 ③ + ④) ---
#
# 사각형 카드가 아니다. **기울인 초상 프레임 + 좌측 변의 오의 스트립**이다.
# 카드 순서가 곧 랭크다 — "A1" 같은 글자를 쓰지 않는다.
func _draw_party_band() -> void:
	# **카드 슬롯은 랭크가 정한다** (루프 순서가 아니다). 누가 쓰러져도 남은 카드가
	# 왼쪽으로 밀리지 않아야 "위치 = 랭크"가 라벨 역할을 계속 한다.
	for unit in battle.allies():
		var origin := card_origin() + Vector2(CARD_STEP * float(unit.rank - 1), 0.0)
		var alive := unit.alive

		# --- 오의 스트립 (요소 ③) — 초상 프레임 좌측 변, 아래에서 위로 찬다 ---
		var strip_pos := origin
		var ratio := unit.get_energy_ratio()
		var ready := ratio >= 1.0 and alive
		draw_rect(Rect2(strip_pos, ULT_STRIP), TurnCombat.COLOR_GAUGE_EMPTY)
		var fill_h := ULT_STRIP.y * clampf(ratio, 0.0, 1.0)
		var strip_color := TurnCombat.COLOR_TEXT_DIM
		if ready:
			# 만충 시 밝기를 흔든다. **형태는 바꾸지 않는다** — 색만이 라벨이다.
			var pulse := 0.72 + 0.28 * sin(_glow_phase)
			strip_color = TurnCombat.COLOR_ULT_READY * Color(pulse, pulse, pulse, 1.0)
		draw_rect(Rect2(strip_pos + Vector2(0.0, ULT_STRIP.y - fill_h),
			Vector2(ULT_STRIP.x, fill_h)), strip_color)
		if ready:
			_register_hit(Rect2(strip_pos, ULT_STRIP), "ultimate", {"unit": unit})

		# --- 초상 프레임 (요소 ③) ---
		var frame := origin + Vector2(ULT_STRIP.x + 2.0, 0.0)
		var tint := unit.character.tint if unit.character != null else Color.WHITE
		var frame_fill := tint * Color(1, 1, 1, 0.5) if alive \
			else TurnCombat.COLOR_GAUGE_EMPTY
		var frame_line := TurnCombat.COLOR_PANEL_LINE
		if not alive:
			frame_line = TurnCombat.COLOR_BORDER_IDLE
		elif unit == battle.active_unit:
			frame_line = TurnCombat.COLOR_AIM  # 백색 = 지금 선택된 유닛
		# 색 판을 먼저 깔고 그 위에 얼굴을 얹는다. 초상에 투명 여백이 있어도 칸이 비지 않는다.
		_skewed(frame, PORTRAIT, frame_fill)
		var art := _portrait_of(unit)
		if art != null:
			_skewed_texture(frame, PORTRAIT, art,
				Color(1, 1, 1, 1) if alive else Color(0.45, 0.5, 0.6, 0.8))
		# 테두리는 얼굴 위에 그린다 — 어두운 UI 배경에서 인물을 떼어 내는 림 라이트다.
		_skewed(frame, PORTRAIT, Color(0, 0, 0, 0), frame_line)

		var ink := TurnCombat.COLOR_TEXT_ACTIVE if alive else TurnCombat.COLOR_TEXT_DIM
		if art == null:
			_text_centered(frame + Vector2(PORTRAIT.x * 0.5, PORTRAIT.y * 0.5 + 6.0),
				unit.display_name.substr(0, 2), ink, 15)
		_text(frame + Vector2(4.0, 11.0), TurnCombat.element_glyph(unit.element),
			TurnCombat.element_color(unit.element) if alive else TurnCombat.COLOR_TEXT_DIM, 11)

		# --- HP 바 (요소 ④) — 프레임 아래 5px ---
		var hp_pos := frame + Vector2(0.0, PORTRAIT.y + ALLY_HP_GAP)
		draw_rect(Rect2(hp_pos, ALLY_HP_SIZE), TurnCombat.COLOR_GAUGE_EMPTY)
		if alive:
			draw_rect(Rect2(hp_pos, Vector2(ALLY_HP_SIZE.x * unit.get_hp_ratio(),
				ALLY_HP_SIZE.y)), TurnCombat.COLOR_ALLY_HP)
			# 보호막은 HP 바 위에 겹치는 얇은 막대다.
			var shield := unit.get_shield_total()
			if shield > 0:
				var s := clampf(float(shield) / float(unit.get_max_hp()), 0.0, 1.0)
				draw_rect(Rect2(hp_pos + Vector2(0.0, -3.0),
					Vector2(ALLY_HP_SIZE.x * s, 2.0)), TurnCombat.COLOR_TEXT_ACTIVE)

		# --- 상태이상 색 점 (요소 ④) ---
		_draw_status_dots(unit, hp_pos + Vector2(0.0, ALLY_HP_SIZE.y + 4.0))


# --- 공명 포인트 (요소 ⑤) ---
#
# 핍 5개. 개수가 곧 숫자이므로 큰 숫자를 따로 쓰지 않는다.
# 0개일 때는 핍 테두리 자리를 적색으로 바꿔 파산을 경고한다 — "공명 파산" 글자를 없앴다.
func _draw_resonance() -> void:
	var resources := battle.resources
	var bankrupt := resources.is_resonance_bankrupt()
	var empty := TurnCombat.COLOR_ENEMY_HP if bankrupt else TurnCombat.COLOR_GAUGE_EMPTY

	for i in resources.resonance_max:
		var pos := resonance_origin() \
			+ Vector2(float(i) * (RESONANCE_PIP.x + RESONANCE_GAP), 0.0)
		var filled := i < resources.resonance
		_skewed(pos, RESONANCE_PIP, TurnCombat.COLOR_TOUGHNESS if filled else empty)


# --- 열기 게이지 (⑤에 흡수) ---
#
# 냉각 / 최적 / 과열 3구간. 막대 색과 최적 구간 배경이 구간명을 대신한다.
func _draw_heat() -> void:
	var resources := battle.resources
	if not resources.heat_enabled():
		return

	var t := TurnCombatConfig.tuning
	var origin := heat_origin()
	draw_rect(Rect2(origin, HEAT_SIZE), TurnCombat.COLOR_GAUGE_EMPTY)

	# 최적 구간을 배경으로 표시한다 — 어디를 노려야 하는지 보여야 한다.
	var lo := HEAT_SIZE.x * t.heat_optimal_min / t.heat_max
	var hi := HEAT_SIZE.x * t.heat_optimal_max / t.heat_max
	draw_rect(Rect2(origin + Vector2(lo, 0.0), Vector2(hi - lo, HEAT_SIZE.y)),
		TurnCombat.COLOR_ULT_READY * Color(1, 1, 1, 0.28))

	var zone := resources.heat_zone()
	var color := TurnCombat.COLOR_TOUGHNESS
	if zone < 0:
		color = TurnCombat.COLOR_TEXT_DIM      # 냉각 — 무채색
	elif zone > 0:
		color = TurnCombat.COLOR_ENEMY_HP      # 과열 — 경고
	draw_rect(Rect2(origin,
		Vector2(HEAT_SIZE.x * resources.heat / t.heat_max, HEAT_SIZE.y)), color)


# --- 적 행동 예고 (2차 패널) ---
#
# 예고의 **요구 조건**은 분절 바가 항상 보여주므로, 문장은 조준 중인 적 1체에 한해
# 하단 밴드에 붙인다. 적 머리 위에 상시로 띄우면 5체의 패널이 서로를 덮는다 —
# 처음 그렸을 때 실제로 그렇게 됐다.
func _draw_intent_strip() -> void:
	if selected_target == null or selected_target.intent == null:
		return
	var text := selected_target.intent.describe(TurnCombatConfig.info_detail)
	if text.is_empty():
		return
	var width := minf(float(text.length()) * 8.4 + 24.0, INTENT_MAX_W)
	var origin := intent_origin()
	_skewed(origin, Vector2(width, INTENT_H), TurnCombat.COLOR_PANEL,
		TurnCombat.COLOR_ENEMY_HP)
	_text(origin + Vector2(12.0, INTENT_H - 8.0), text,
		TurnCombat.COLOR_TEXT_ACTIVE, 12)


# --- 액션 버튼 (요소 ⑥) ---
#
# 우하단 평행사변형 하나. **기본 상태의 액션 입력 요소는 이것뿐이다.**
# 포인터가 올라가면 위로 스킬 2차 패널이 펼쳐진다.
func _draw_action() -> void:
	var awaiting := battle.phase == TurnBattleManager.Phase.AWAITING_INPUT
	var actions: Array[Dictionary] = []
	if awaiting:
		actions = battle.available_actions()

	# 입력 대기가 아니거나 쓸 행동이 없으면 **비활성 테두리**로 둔다.
	# "적 행동 중" 같은 글자를 쓰지 않는다 — 누를 수 없음은 무채색이 말한다.
	var origin := action_origin()
	if actions.is_empty():
		_skewed(origin, ACTION_SIZE, TurnCombat.COLOR_PANEL,
			TurnCombat.COLOR_BORDER_IDLE, ACTION_BORDER)
		return

	# 내 턴이면 스킬 목록을 펼쳐 둔다. 누를 수 있는 것이 보여야 조작 가능한 화면이다.
	_draw_skill_panel(actions)

	var chosen := clampi(hovered_action if hovered_action >= 0 else selected_action,
		0, actions.size() - 1)
	var entry: Dictionary = actions[chosen]
	var skill: SkillData = entry["skill"]
	var usable := bool(entry["ok"])

	_skewed(origin, ACTION_SIZE, TurnCombat.COLOR_PANEL,
		TurnCombat.COLOR_ULT_READY if usable else TurnCombat.COLOR_BORDER_IDLE,
		ACTION_BORDER)

	# 고른 행동의 원소 문양. 대상 범위는 조준 프레임이 실물로 보여주므로 글자가 필요없다.
	var element := skill.resolve_element(battle.active_unit.element)
	_text_centered(origin + Vector2(ACTION_SIZE.x * 0.5, 38.0),
		TurnCombat.element_glyph(element),
		TurnCombat.element_color(element) if usable else TurnCombat.COLOR_TEXT_DIM, 26)

	# 코스트 핍 — 공명 몇 칸을 쓰는지(또는 버는지)를 막대 개수로만 알린다.
	var gain := skill.is_turn_basic() and skill.rp_cost <= 0
	var cost := 1 if gain else skill.rp_cost
	for i in mini(cost, 6):
		draw_rect(Rect2(origin + Vector2(14.0 + float(i) * 8.0, 50.0),
			Vector2(5.0, 3.0)),
			TurnCombat.COLOR_ULT_READY if gain else TurnCombat.COLOR_TOUGHNESS)

	if usable:
		_register_hit(Rect2(origin, ACTION_SIZE), "confirm", {"skill": skill})


# 스킬 2차 패널. 액션 버튼 위로 쌓는다. 세로 간격이 히트박스 최소 변과 같아 판정이
# 겹치지 않는다 — 시각 높이 34 에 판정 56 을 쓰면서 겹침을 피하는 유일한 방법이다.
#
# 여기는 2차 패널이므로 스킬 이름·사용 불가 이유·사용 가능 랭크를 글자로 적는다.
# 금지된 것은 "HP"·"인성치" 같은 **카테고리 라벨**이고, 이 문장들은 내용이다.
func _draw_skill_panel(actions: Array[Dictionary]) -> void:
	for i in actions.size():
		var entry: Dictionary = actions[i]
		var skill: SkillData = entry["skill"]
		var ok := bool(entry["ok"])
		var pos := skill_origin() - Vector2(0.0, SKILL_STEP * float(i))
		var border := TurnCombat.COLOR_BORDER_IDLE
		if i == hovered_action or (hovered_action < 0 and i == selected_action):
			border = TurnCombat.COLOR_AIM   # 백색 = 지금 고른 것
		elif ok:
			border = TurnCombat.COLOR_PANEL_LINE
		_skewed(pos, SKILL_SIZE, TurnCombat.COLOR_PANEL, border)

		var ink := TurnCombat.COLOR_TEXT_ACTIVE if ok else TurnCombat.COLOR_TEXT_DIM
		_text(pos + Vector2(10.0, 15.0), skill.display_name, ink, 13)
		# 왜 못 쓰는지 / 어느 랭크에서 쓰는지. 위치 전술이 전술이 되려면 보여야 한다.
		var note := String(entry["reason"]) if not ok else skill.format_usable_ranks()
		_text(pos + Vector2(10.0, 29.0), note, TurnCombat.COLOR_TEXT_DIM, 9)

		# 남은 자물쇠 개수를 막대 핍으로. 매 턴의 미니 퍼즐을 계산 없이 읽게 한다.
		var locks := int(entry["locks"])
		for k in mini(locks, 6):
			draw_rect(Rect2(pos + Vector2(SKILL_SIZE.x - 12.0 - float(k) * 6.0, 5.0),
				Vector2(3.0, 10.0)), TurnCombat.COLOR_TOUGHNESS)

		# 코스트 핍 — 공명 소모는 백색, 기본공격의 회수는 녹색.
		var gain := skill.is_turn_basic() and skill.rp_cost <= 0
		var cost := 1 if gain else skill.rp_cost
		for k in mini(cost, 6):
			draw_rect(Rect2(pos + Vector2(SKILL_SIZE.x - 12.0 - float(k) * 6.0, 22.0),
				Vector2(4.0, 4.0)),
				TurnCombat.COLOR_ULT_READY if gain else TurnCombat.COLOR_TOUGHNESS)

		# **스트립 자체가 버튼이다.** 고르는 것과 확정하는 것을 나누면 두 번 눌러야 하고,
		# 큰 버튼만 누를 수 있는 화면에서는 스킬 목록이 장식으로 보였다.
		_register_hit(Rect2(pos + Vector2(0.0, (SKILL_SIZE.y - SKILL_STEP) * 0.5),
			Vector2(SKILL_SIZE.x, SKILL_STEP)), "action",
			{"index": i, "skill": skill, "ok": ok})


# --- 조준 프레임 (요소 ⑥에 포함) ---
#
# 회전 원형 크로스헤어를 없애고 **58×54 백색 사각 프레임 4변**으로 바꿨다.
# 확산/광역 스킬 선택 시 부수 대상에는 흐린 같은 프레임을 표시한다.
func _draw_aim_frames() -> void:
	if battle.phase != TurnBattleManager.Phase.AWAITING_INPUT:
		return

	# 적을 클릭할 수 있게 히트존을 등록한다.
	for unit in battle.enemies():
		_register_hit(Rect2(_aim_center(unit) - AIM_FRAME * 0.5, AIM_FRAME),
			"target", {"unit": unit})

	if selected_target == null:
		return
	_aim_at(_aim_center(selected_target), 1.0)

	var actions := battle.available_actions()
	var index := hovered_action if hovered_action >= 0 else selected_action
	if index < 0 or index >= actions.size():
		return
	var skill: SkillData = actions[index]["skill"]
	for entry in battle.ranks.expand_targets(battle.active_unit, skill, selected_target, null):
		var unit: TurnUnit = entry[0]
		if unit == selected_target or unit == null or unit.is_ally():
			continue
		_aim_at(_aim_center(unit), 0.45)


# 프레임을 막대 4개로 그린다. `draw_rect` 외곽선은 축 정렬 직사각형이므로 형태 언어의
# "막대"에 속한다.
func _aim_center(unit: TurnUnit) -> Vector2:
	return unit_position(unit) + Vector2(0.0, AIM_DY)


func _aim_at(center: Vector2, alpha: float) -> void:
	draw_rect(Rect2(center - AIM_FRAME * 0.5, AIM_FRAME),
		TurnCombat.COLOR_AIM * Color(1, 1, 1, alpha), false, AIM_BORDER)


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
			pass


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
#
# 액션 버튼이나 스킬 패널 위에 있으면 패널을 펼친 상태로 유지한다. 기본 상태에서
# 액션 입력 요소를 버튼 1개로 유지하려면 이 호버가 유일한 펼침 조건이다.
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
# 기울어진 폴리곤을 직접 그리므로 노드 기반 버튼을 쓸 수 없다. `_draw()` 가 그리면서
# 클릭 영역을 등록하고, 입력은 그 목록을 역순으로(위에 그린 것 우선) 찾는다.
#
# **판정은 시각 크기와 분리한다.** 최소 56×56, 기울기 없는 직사각형이다. 오의 스트립은
# 4×36 으로 보이지만 판정은 56×56 이고, 그래서 카드 간격(62)이 그 하한을 정한다.

func _register_hit(rect: Rect2, kind: String, data: Dictionary) -> void:
	var size := Vector2(maxf(rect.size.x, HIT_MIN), maxf(rect.size.y, HIT_MIN))
	_hit_zones.append({
		"rect": Rect2(rect.get_center() - size * 0.5, size),
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

# 기울어진 평행사변형. **형태 언어 2종** 중 하나이며, 패널·칩·버튼·핍·상태 점이
# 모두 이 도형이다. 나머지 하나는 축 정렬 막대(`draw_rect`)다.
func _skewed(pos: Vector2, size: Vector2, fill: Color,
		border: Color = Color(0, 0, 0, 0), width: float = 1.0) -> void:
	var offset := size.y * SKEW
	var points := PackedVector2Array([
		pos + Vector2(-offset, 0.0),
		pos + Vector2(size.x - offset, 0.0),
		pos + Vector2(size.x, size.y),
		pos + Vector2(0.0, size.y),
	])
	draw_colored_polygon(points, fill)
	if border.a > 0.0:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, border, width)


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


# 초상을 기울어진 칸에 채운다. **늘리지 않는다.**
#
# 머리 크롭은 정사각이고 칸은 42×36 이나 26×30 이다. 텍스처를 칸 비율로 늘리면 얼굴이
# 찌그러지므로(가이드 §3.4), 칸 비율과 같은 창을 UV 로 잘라 낸다. 세로 중심을 살짝
# 위로 두는 것은 정가운데로 자르면 턱이 먼저 잘려 나가기 때문이다.
func _skewed_texture(pos: Vector2, size: Vector2, texture: Texture2D,
		tint: Color = Color.WHITE, center_v: float = 0.46) -> void:
	if texture == null:
		return
	var offset := size.y * SKEW
	var points := PackedVector2Array([
		pos + Vector2(-offset, 0.0),
		pos + Vector2(size.x - offset, 0.0),
		pos + Vector2(size.x, size.y),
		pos + Vector2(0.0, size.y),
	])

	# `HUDKit.head_texture()` 는 `AtlasTexture` 를 돌려준다. **UV 는 아틀라스 원본 기준이라
	# 잘라 둔 영역을 자동으로 따르지 않는다** — 그대로 0~1 을 쓰면 머리가 아니라 전신이
	# 들어온다(실제로 칩과 카드에 통짜 전신이 찍혔다). 영역을 직접 원본 좌표로 환산한다.
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
	var quad_aspect := size.x / size.y
	var win := region.size
	if win.x / win.y > quad_aspect:
		win.x = win.y * quad_aspect
	else:
		win.y = win.x / quad_aspect
	# 창의 세로 중심을 영역의 `center_v` 지점에 둔다. 0.5(정가운데)로 두면 잘라 둔 머리
	# 영역에서도 어깨가 절반을 차지해 얼굴이 아래로 밀린다.
	var win_pos := Vector2(
		region.position.x + (region.size.x - win.x) * 0.5,
		clampf(region.position.y + region.size.y * center_v - win.y * 0.5,
			region.position.y, region.position.y + region.size.y - win.y))

	var u0 := win_pos / sheet
	var u1 := (win_pos + win) / sheet
	var uvs := PackedVector2Array([
		Vector2(u0.x, u0.y),
		Vector2(u1.x, u0.y),
		Vector2(u1.x, u1.y),
		Vector2(u0.x, u1.y),
	])
	draw_colored_polygon(points, tint, uvs, base)


# 텍스트는 패널과 **반대로** `skewX +12°` 기울인다. 그래야 기울인 판 위에서 글자가
# 똑바로 서 보인다. `draw_string` 에는 기울기가 없으므로 변환 행렬을 직접 건다.
func _text(pos: Vector2, text: String, color: Color, size: int) -> void:
	if _font == null:
		return
	draw_set_transform_matrix(Transform2D(Vector2(1.0, 0.0), Vector2(-SKEW, 1.0), pos))
	draw_string(_font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _text_centered(pos: Vector2, text: String, color: Color, size: int) -> void:
	if _font == null:
		return
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_text(pos - Vector2(width * 0.5, 0.0), text, color, size)


# 전투가 진행되면 화면을 갱신한다. 전투 화면이 부른다.
func refresh() -> void:
	_refresh_preview()
	queue_redraw()
