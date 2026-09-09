extends Control
class_name TurnBattleHUD

# 턴제 전투 HUD (#450).
#
# **설계서 §4.9.0 — 스타레일 UI 의 진짜 문법**을 지킨다. 흔한 모바일 RPG처럼 사각형
# 카드에 스탯을 담아 화면을 채우는 방식과 정반대다.
#
#   1. 중앙 완전 개방 — 화면 중앙 60%에는 UI가 단 하나도 없다
#   2. 가장자리 흡착 — 모든 UI가 4변에 붙고, 일부는 **화면 밖으로 잘려 나간다**
#   3. 사각형 금지 — 패널·칩·버튼이 기울어진 평행사변형 또는 원형
#   4. 원형 = 중요도 — 오의·액션 버튼·조준환만 원형
#   5. 불규칙 배치 — 파티 카드가 일직선 그리드가 아니라 어긋난 사선
#   6. 반투명 유리 — 어두운 반투명 + 얇은 흰 외곽선
#   7. 라벨 최소화 — "HP", "인성치" 같은 글자를 쓰지 않는다. 색과 위치가 곧 라벨
#
# > 가장 중요한 교훈: 정보를 담을 공간이 부족해 보여도 **중앙을 침범하지 마라.**
#
# 왜 `_draw()`로 직접 그리는가: `Control`에는 skew 가 없어서 기울어진 평행사변형을
# 노드 조합으로 만들 수 없다. 문법의 핵심이 `skewX(-12°)`이므로 폴리곤을 직접 그린다.
#
# 참고: docs/turn-combat-design.md §UI

# ===== 신호 =====

## 플레이어가 행동을 골랐다.
signal action_chosen(skill: SkillData, target: TurnUnit)
## 플레이어가 오의를 눌렀다. 턴 순서와 무관하게 언제든 나온다.
signal ultimate_requested(unit: TurnUnit)
## 배속이 바뀌었다 (1 / 2 / 3).
signal speed_changed(speed: float)
## 자동 전투가 켜지거나 꺼졌다.
signal auto_toggled(enabled: bool)

# ===== 레이아웃 상수 =====
#
# 중앙 개방을 지키기 위해 좌우와 상하 가장자리에만 값을 둔다.

const SKEW := -0.2126        # tan(-12°). 설계서 §4.9.3 의 기울기 각도.
const TIMELINE_X := -18.0    # 음수 = 화면 밖으로 잘려 나간다 (문법 2번)
const TIMELINE_Y := 92.0
const TIMELINE_CHIP := Vector2(136.0, 40.0)
const TIMELINE_STEP := 46.0
const TIMELINE_INDENT := 7.0  # 아래로 갈수록 오른쪽으로 — 사선 계단을 만든다
const TIMELINE_DECAY := 0.94  # 크기 감쇠

const ENEMY_ROW_Y := 268.0
const ENEMY_SLOT_X := 716.0
const ENEMY_SLOT_STEP := 88.0

const ALLY_ROW_Y := 452.0
const ALLY_SLOT_X := 556.0
const ALLY_SLOT_STEP := -84.0

const CARD_ORIGIN := Vector2(56.0, 612.0)
const CARD_STEP := 148.0
## 카드마다 Y를 6~10px 어긋나게 둔다. **완벽한 정렬은 게임 UI를 죽인다.**
const CARD_JITTER: Array[float] = [0.0, -8.0, 4.0, -6.0]
const CARD_GAP_JITTER: Array[float] = [0.0, 6.0, -4.0, 8.0]

const RESONANCE_ORIGIN := Vector2(640.0, 664.0)
const HEAT_ORIGIN := Vector2(640.0, 692.0)

const ACTION_CENTER := Vector2(1188.0, 622.0)
const ACTION_RADIUS := 46.0
const SKILL_ROW := Vector2(1150.0, 470.0)
const SKILL_ROW_STEP := 40.0

# ===== 상태 =====

var battle: TurnBattleManager = null

## 마우스가 올라간 행동. 여기가 바뀌면 타임라인 프리뷰가 갱신된다 (설계서 §4.2.5).
var hovered_action: int = -1
## 플레이어가 조준 중인 적.
var selected_target: TurnUnit = null
## 프리뷰 결과. `{"order": Array[TurnUnit], "expected": Dictionary, "locks": int}`
var preview: Dictionary = {}

var speed: float = 1.0
var auto: bool = false

## 조준환 회전 각도. 원형 크로스헤어가 천천히 돈다.
var _reticle_angle: float = 0.0
## 오의 준비 링의 발광 위상.
var _glow_phase: float = 0.0

var _font: Font = null
var _hit_zones: Array[Dictionary] = []


func _ready() -> void:
	name = "TurnBattleHUD"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	_reticle_angle += delta * 0.8
	_glow_phase += delta * 3.0
	queue_redraw()


# ===== 좌표 (Layout) =====

func enemy_position(rank: int) -> Vector2:
	return Vector2(ENEMY_SLOT_X + ENEMY_SLOT_STEP * float(rank - 1), ENEMY_ROW_Y)


func ally_position(rank: int) -> Vector2:
	return Vector2(ALLY_SLOT_X + ALLY_SLOT_STEP * float(rank - 1), ALLY_ROW_Y)


func unit_position(unit: TurnUnit) -> Vector2:
	return enemy_position(unit.rank) if unit.is_enemy() else ally_position(unit.rank)


# ===== 그리기 (Draw) =====

func _draw() -> void:
	_hit_zones.clear()
	if battle == null:
		return

	_draw_top_strip()
	_draw_timeline()
	_draw_enemy_clusters()
	_draw_party_cards()
	_draw_resonance()
	_draw_heat()
	_draw_actions()
	_draw_reticle()


# --- 상단 정보 띠 (설계서 §4.9.2 (G)) ---
#
# 좌: 사이클 카운터 / 중앙: 적 부대 이름 / 우: 배속·자동·일시정지 3개만.
# **그 이상 두지 않는다.**
func _draw_top_strip() -> void:
	var cycle := battle.timeline.current_cycle()
	_skewed_panel(Vector2(-10, 18), Vector2(120, 30), TurnCombat.COLOR_PANEL)
	_text(Vector2(22, 39), "%d 사이클" % cycle, TurnCombat.COLOR_TOUGHNESS, 15)

	# 중앙 배너 — 이름만. 중앙 개방 원칙 때문에 얇게 둔다.
	var label := "적 %d체" % battle.enemies().size()
	if battle.resources.heat_enabled() and not battle.resources.recommendation_label().is_empty():
		label = battle.resources.recommendation_label()
	var width := minf(float(label.length()) * 12.0 + 48.0, 520.0)
	_skewed_panel(Vector2(640.0 - width * 0.5, 18), Vector2(width, 28),
		TurnCombat.COLOR_PANEL)
	_text_centered(Vector2(640, 37), label, TurnCombat.COLOR_NEUTRAL, 14)

	# 우측 3개 토글.
	var speed_label := "▶▶ %dx" % int(speed)
	_toggle(Vector2(1064, 18), Vector2(76, 30), speed_label, speed > 1.0, "speed")
	_toggle(Vector2(1148, 18), Vector2(64, 30), "⋈ 자동", auto, "auto")
	_toggle(Vector2(1220, 18), Vector2(48, 30), "‖", false, "pause")


# --- 행동 순서 타임라인 (설계서 §4.9.2 (A)) ---
#
# **이 요소 하나가 게임의 전략성을 결정한다.** 최소 8개 앞을 보여주고,
# 스킬 호버 시 "이 행동 후의 순서"를 반투명 고스트로 겹쳐 그린다(FF10 식).
func _draw_timeline() -> void:
	var entries := battle.timeline.preview_with_cycles()
	var ghost: Array[TurnUnit] = preview.get("order", [] as Array[TurnUnit])

	for i in entries.size():
		var entry: Dictionary = entries[i]
		var unit: TurnUnit = entry["unit"]
		var scale := pow(TIMELINE_DECAY, float(i))
		var size := TIMELINE_CHIP * scale
		var pos := Vector2(TIMELINE_X + TIMELINE_INDENT * float(i),
			TIMELINE_Y + TIMELINE_STEP * float(i))
		var alpha := maxf(1.0 - float(i) * 0.07, 0.35)

		# 아군 = 백청색 / 적 = 주황적색 / 소환체 = 금색 점선.
		var border := TurnCombat.COLOR_ALLY_HP if unit.is_ally() else Color("E87A3B")
		if unit.is_summon:
			border = Color("FFD54F")  # 소환체는 금색 — 실질 5인 파티임을 알린다.

		var fill := TurnCombat.COLOR_PANEL
		fill.a *= alpha
		_skewed_panel(pos, size, fill, border * Color(1, 1, 1, alpha))

		# 특성/추가 행동은 패턴 배경으로 구분한다.
		if bool(entry["extra"]):
			_skewed_panel(pos + Vector2(4, 4), size - Vector2(8, 8),
				Color(1, 1, 1, 0.10 * alpha))

		# 원소 문양 + 이름. 라벨은 쓰지 않는다 — 색과 위치가 라벨이다.
		var text_color := Color(1, 1, 1, alpha)
		_text(pos + Vector2(14, size.y * 0.68),
			"%s %s" % [TurnCombat.element_glyph(unit.element), unit.display_name],
			text_color, int(15.0 * scale))
		_text(pos + Vector2(size.x - 34, size.y * 0.68),
			"C%d" % int(entry["cycle"]), TurnCombat.COLOR_NEUTRAL * Color(1, 1, 1, alpha),
			int(11.0 * scale))

		# 아군 칩의 "행동 가능" 마커.
		if unit == battle.active_unit:
			_text(pos + Vector2(size.x - 12, size.y * 0.7), "▶",
				TurnCombat.COLOR_ULT_READY, int(14.0 * scale))

		# CR 막대 — 초보자를 위한 두 번째 층위 (설계서 §4.2.2).
		var charge := battle.timeline.get_charge_ratio(unit)
		var bar_pos := pos + Vector2(10, size.y - 5)
		draw_rect(Rect2(bar_pos, Vector2(size.x - 20, 2.0)),
			Color(1, 1, 1, 0.15 * alpha))
		draw_rect(Rect2(bar_pos, Vector2((size.x - 20) * charge, 2.0)),
			border * Color(1, 1, 1, alpha * 0.8))

	# --- 프리뷰 고스트 ---
	#
	# 앞당김/지연이 포함된 스킬이면 칩이 이동하는 것을 반투명으로 겹쳐 보여준다.
	# **HSR에도 없는 기능이고, 설계서가 최우선 UX로 꼽은 것이다.**
	if ghost.is_empty():
		return
	for i in mini(ghost.size(), entries.size()):
		var unit: TurnUnit = ghost[i]
		if unit == entries[i]["unit"]:
			continue  # 순서가 그대로면 고스트를 그릴 필요가 없다.
		var scale := pow(TIMELINE_DECAY, float(i))
		var size := TIMELINE_CHIP * scale
		var pos := Vector2(TIMELINE_X + TIMELINE_INDENT * float(i) + 26.0,
			TIMELINE_Y + TIMELINE_STEP * float(i))
		_skewed_panel(pos, size, Color(0.2, 0.9, 0.6, 0.20), Color(0.23, 0.88, 0.48, 0.75))
		_text(pos + Vector2(14, size.y * 0.68),
			"%s %s" % [TurnCombat.element_glyph(unit.element), unit.display_name],
			Color(1, 1, 1, 0.85), int(14.0 * scale))


# --- 적 정보 클러스터 (설계서 §4.9.2 (B)) ---
#
# 적 머리 위 부유. **라벨 텍스트를 전혀 쓰지 않는다.** 3층 구조:
#   1층: 인성치 바(백색, 자물쇠 분절) + 약점 아이콘 인라인 우측
#   2층: HP 바(적색) + 좌측 원형 순번 배지
#   3층: 디버프 아이콘
func _draw_enemy_clusters() -> void:
	var order := _threat_order()

	for unit in battle.enemies():
		var base := unit_position(unit) + Vector2(-58, -86)
		var width := 116.0

		# --- 1층: 인성치 바 + 자물쇠 분절 ---
		#
		# **인성치 바를 HP 바보다 짧고 얇게**, 색은 백색 계열.
		# 자물쇠를 분절 칸으로 표현하는 것이 중앙 개방과의 절충안이다 (§4.9.5).
		var tough_size := Vector2(width * 0.78, 6.0)
		draw_rect(Rect2(base, tough_size), Color(0, 0, 0, 0.55))
		if unit.is_broken:
			# 격파 상태 — 바가 깨진 것을 색으로 알린다.
			draw_rect(Rect2(base, tough_size), Color(0.9, 0.3, 0.2, 0.35))
		else:
			draw_rect(Rect2(base, Vector2(tough_size.x * unit.get_toughness_ratio(),
				tough_size.y)), TurnCombat.COLOR_TOUGHNESS)

		var segments := battle.toughness.toughness_segments(unit)
		if not segments.is_empty():
			var seg_width := tough_size.x / float(segments.size())
			for i in segments.size():
				var seg: Dictionary = segments[i]
				var lock: TurnLock = seg["lock"]
				var seg_pos := base + Vector2(seg_width * float(i), 0)
				# 분절 경계선.
				if i > 0:
					draw_line(seg_pos, seg_pos + Vector2(0, tough_size.y),
						Color(0, 0, 0, 0.8), 1.0)
				# 자물쇠 아이콘을 **초소형으로 인라인** 표시.
				var glyph_color := lock.color()
				if lock.cleared:
					glyph_color = Color(glyph_color.r, glyph_color.g, glyph_color.b, 0.25)
				_text(seg_pos + Vector2(seg_width * 0.5 - 4, -4), lock.glyph(), glyph_color, 12)

		# 약점 아이콘을 **바 우측에 인라인**으로. 별도 줄을 만들지 않는다.
		var weak_x := base.x + tough_size.x + 5.0
		for e in unit.weak_elements:
			_text(Vector2(weak_x, base.y + 7), TurnCombat.element_glyph(e),
				TurnCombat.element_color(e), 12)
			weak_x += 12.0
		for p in unit.weak_physical:
			_text(Vector2(weak_x, base.y + 7), TurnCombat.physical_glyph(p),
				TurnCombat.COLOR_NEUTRAL, 12)
			weak_x += 12.0

		# --- 2층: HP 바 + 순번 배지 ---
		var hp_pos := base + Vector2(14, 10)
		var hp_size := Vector2(width - 14.0, 8.0)
		draw_rect(Rect2(hp_pos, hp_size), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(hp_pos, Vector2(hp_size.x * unit.get_hp_ratio(), hp_size.y)),
			TurnCombat.COLOR_ENEMY_HP)

		# 순번 배지 — **타임라인을 보지 않아도 위협 순서를 안다.**
		var badge_center := base + Vector2(6, 14)
		var threat := int(order.get(unit.unit_id, 0))
		draw_circle(badge_center, 8.0, Color(0.05, 0.07, 0.12, 0.9))
		draw_arc(badge_center, 8.0, 0, TAU, 20, TurnCombat.COLOR_ENEMY_HP, 1.5)
		if threat > 0:
			_text_centered(badge_center + Vector2(0, 4), str(threat),
				TurnCombat.COLOR_TOUGHNESS, 11)

		# --- 3층: 상태이상 아이콘 (지속 턴 수를 숫자로) ---
		var status_x := base.x + 14.0
		for status in unit.statuses:
			_text(Vector2(status_x, base.y + 32), status.format_badge(), status.color(), 11)
			status_x += float(status.format_badge().length()) * 7.0 + 6.0

		# --- 행동 예고 ---
		#
		# 완전 정보 공개. 정보 표시 단계에 따라 얼마나 보여줄지 정한다.
		if unit.intent != null:
			var detail := TurnCombatConfig.info_detail
			var text := unit.intent.describe(detail)
			var panel_width := float(text.length()) * 8.0 + 24.0
			_skewed_panel(base + Vector2(0, -30), Vector2(panel_width, 24),
				Color(0.35, 0.08, 0.06, 0.78), Color(1, 0.5, 0.4, 0.5))
			_text(base + Vector2(12, -13), "⚠ " + text, Color(1, 0.86, 0.8), 12)

			if detail != TurnCombat.InfoDetail.CHALLENGE and unit.intent.total_locks() > 0:
				_text(base + Vector2(12, -36),
					"🔒 " + unit.intent.format_locks(), TurnCombat.COLOR_WARN, 13)

		# --- 예상 피해 프리뷰 (호버 중인 스킬 기준) ---
		var expected: Dictionary = preview.get("expected", {})
		if expected.has(unit.unit_id):
			_text(base + Vector2(width + 16, 18),
				"-%d" % int(expected[unit.unit_id]), TurnCombat.COLOR_WARN, 15)


# 적의 위협 순서 (타임라인 등장 순). `unit_id` -> 1부터의 순번.
func _threat_order() -> Dictionary:
	var out: Dictionary = {}
	var index := 1
	for unit in battle.timeline.preview(12):
		if unit.is_enemy() and not out.has(unit.unit_id):
			out[unit.unit_id] = index
			index += 1
	return out


# --- 파티 카드 (설계서 §4.9.2 (D)) ---
#
# 사각형 카드가 아니다. **원형 초상 + 원형 오의 버튼의 쌍**이다.
# 4개 카드의 Y좌표를 6~10px씩 어긋나게 배치한다.
func _draw_party_cards() -> void:
	var allies := battle.allies()
	for i in allies.size():
		var unit: TurnUnit = allies[i]
		var jitter := CARD_JITTER[i % CARD_JITTER.size()]
		var gap := CARD_GAP_JITTER[i % CARD_GAP_JITTER.size()]
		var origin := CARD_ORIGIN + Vector2(CARD_STEP * float(i) + gap, jitter)

		# 원형 초상 (48px, 얇은 백색 링).
		var portrait := origin + Vector2(24, 24)
		var tint := unit.character.tint if unit.character != null else Color.WHITE
		draw_circle(portrait, 24.0, tint * Color(1, 1, 1, 0.55))
		draw_arc(portrait, 24.0, 0, TAU, 32, TurnCombat.COLOR_PANEL_LINE, 2.0)

		# 행동 중인 유닛을 강조한다.
		if unit == battle.active_unit:
			draw_arc(portrait, 29.0, 0, TAU, 32, TurnCombat.COLOR_ULT_READY, 2.0)

		_text_centered(portrait + Vector2(0, 5), unit.display_name.substr(0, 2),
			Color.WHITE, 15)

		# 원소 문양 — 색맹 대응으로 색과 형태를 함께 쓴다.
		_text(portrait + Vector2(-30, -14), TurnCombat.element_glyph(unit.element),
			TurnCombat.element_color(unit.element), 13)
		# 랭크 표시. 위치가 전술이므로 항상 보여야 한다.
		_text(portrait + Vector2(-32, 18), "A%d" % unit.rank, TurnCombat.COLOR_NEUTRAL, 11)

		# 원형 오의 엠블럼 (40px) — 초상과 살짝 겹쳐 배치.
		var ult_center := origin + Vector2(58, 30)
		var ratio := unit.get_energy_ratio()
		var ready := ratio >= 1.0
		draw_circle(ult_center, 20.0, Color(0.05, 0.07, 0.12, 0.85))
		draw_arc(ult_center, 20.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 28,
			TurnCombat.COLOR_ULT_READY if ready else TurnCombat.COLOR_BUFF, 3.0)
		if ready:
			# 만충 시 링 발광 + 회전 + 채도 상승. 이 "준비 완료" 피드백이 강렬해야
			# 플레이어가 오의 타이밍을 인식한다.
			var pulse := 0.5 + 0.5 * sin(_glow_phase)
			draw_arc(ult_center, 24.0 + pulse * 3.0, _reticle_angle,
				_reticle_angle + TAU * 0.75, 24,
				TurnCombat.COLOR_ULT_READY * Color(1, 1, 1, 0.5 + pulse * 0.4), 2.0)
			_text_centered(ult_center + Vector2(0, 5), "◉", TurnCombat.COLOR_ULT_READY, 18)
			_register_hit(Rect2(ult_center - Vector2(20, 20), Vector2(40, 40)),
				"ultimate", {"unit": unit})
		else:
			_text_centered(ult_center + Vector2(0, 4), "%d" % unit.energy,
				TurnCombat.COLOR_NEUTRAL, 12)

		# HP 수치(우측 정렬) + HP 바 (시안). 라벨 없음.
		_text(origin + Vector2(0, 60), str(unit.current_hp), Color.WHITE, 14)
		var hp_pos := origin + Vector2(0, 66)
		draw_rect(Rect2(hp_pos, Vector2(84, 5)), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(hp_pos, Vector2(84.0 * unit.get_hp_ratio(), 5)),
			TurnCombat.COLOR_ALLY_HP)

		# 보호막은 HP 바 위에 겹쳐 그린다.
		var shield := unit.get_shield_total()
		if shield > 0:
			var shield_ratio := clampf(float(shield) / float(unit.get_max_hp()), 0.0, 1.0)
			draw_rect(Rect2(hp_pos + Vector2(0, -3), Vector2(84.0 * shield_ratio, 3)),
				TurnCombat.COLOR_BUFF)

		# 버프/디버프 아이콘 행 (작은 사선 사각형).
		var badge_x := origin.x
		for status in unit.statuses:
			_skewed_panel(Vector2(badge_x, origin.y + 74), Vector2(11, 11),
				status.color() * Color(1, 1, 1, 0.75))
			badge_x += 14.0

		if not unit.alive:
			_text(origin + Vector2(0, 96), "전투 불능", TurnCombat.COLOR_DANGER, 12)


# --- 공명 포인트 (설계서 §4.9.2 (E)) ---
#
# 큰 숫자 + 마름모 핍 5개를 **오른쪽 위로 올라가는 사선**으로 배치한다.
# 정확히 수평 정렬하지 않는다.
func _draw_resonance() -> void:
	var resources := battle.resources
	var bankrupt := resources.is_resonance_bankrupt()

	var color := TurnCombat.COLOR_DANGER if bankrupt else TurnCombat.COLOR_TOUGHNESS
	_text(RESONANCE_ORIGIN + Vector2(-34, 8), str(resources.resonance), color, 24)

	for i in resources.resonance_max:
		# 오른쪽 위로 올라가는 사선.
		var center := RESONANCE_ORIGIN + Vector2(float(i) * 21.0, -float(i) * 2.6)
		var filled := i < resources.resonance
		_diamond(center, 7.0,
			TurnCombat.COLOR_TOUGHNESS if filled else Color(1, 1, 1, 0.16))

	if bankrupt:
		# 0개일 때 **경고 색상**으로 전환 — 파산 위험을 시각적으로 경고한다.
		_text(RESONANCE_ORIGIN + Vector2(-34, 26), "공명 파산",
			TurnCombat.COLOR_DANGER, 11)


# --- 열기 게이지 ---
#
# 냉각 / 최적 / 과열 3구간. 같은 스킬 반복 스팸을 억제하는 축이다.
func _draw_heat() -> void:
	var resources := battle.resources
	if not resources.heat_enabled():
		return

	var t := TurnCombatConfig.tuning
	var size := Vector2(180, 6)
	var pos := HEAT_ORIGIN + Vector2(-34, 0)
	draw_rect(Rect2(pos, size), Color(0, 0, 0, 0.6))

	# 최적 구간을 배경으로 표시한다 — 어디를 노려야 하는지 보여야 한다.
	var optimal_start := size.x * t.heat_optimal_min / t.heat_max
	var optimal_end := size.x * t.heat_optimal_max / t.heat_max
	draw_rect(Rect2(pos + Vector2(optimal_start, 0),
		Vector2(optimal_end - optimal_start, size.y)), Color(0.23, 0.88, 0.48, 0.22))

	var zone := resources.heat_zone()
	var heat_color := TurnCombat.COLOR_ULT_READY
	if zone < 0:
		heat_color = TurnCombat.COLOR_BUFF
	elif zone > 0:
		heat_color = TurnCombat.COLOR_DANGER
	draw_rect(Rect2(pos, Vector2(size.x * resources.heat / t.heat_max, size.y)), heat_color)
	_text(pos + Vector2(size.x + 8, 6), resources.heat_zone_name(), heat_color, 11)


# --- 액션 버튼 (설계서 §4.9.2 (F)) ---
#
# 우하단 **대형 원형**. 가장 큰 단일 UI 요소이며 엄지 도달 범위의 정중앙이다.
# 그 위에 스킬 목록을 사선 알약으로 쌓는다.
func _draw_actions() -> void:
	if battle.phase != TurnBattleManager.Phase.AWAITING_INPUT:
		# 입력 대기가 아니면 액션을 그리지 않는다 — 누를 수 없는 버튼은 거짓말이다.
		var label: String = "적 행동 중"
		if battle.active_unit == null or battle.active_unit.is_ally():
			label = String(TurnBattleManager.Phase.keys()[battle.phase])
		_text(ACTION_CENTER + Vector2(-56, 76), label, TurnCombat.COLOR_NEUTRAL, 13)
		return

	var actions := battle.available_actions()
	if actions.is_empty():
		return

	# 스킬 목록 — 위로 쌓는다. 자물쇠 개수와 코스트를 함께 띄운다.
	for i in actions.size():
		var entry: Dictionary = actions[i]
		var skill: SkillData = entry["skill"]
		var ok := bool(entry["ok"])
		var pos := SKILL_ROW + Vector2(-float(i) * 6.0, -float(i) * SKILL_ROW_STEP)
		var size := Vector2(124, 34)

		var fill := TurnCombat.COLOR_PANEL
		var border := TurnCombat.COLOR_PANEL_LINE
		if not ok:
			# **회색 처리 + 이유 표시.** 왜 못 쓰는지 보여야 위치 전술이 전술이 된다.
			fill = Color(0.08, 0.08, 0.10, 0.72)
			border = Color(1, 0.4, 0.35, 0.45)
		if i == hovered_action:
			border = TurnCombat.COLOR_ULT_READY

		_skewed_panel(pos, size, fill, border)
		var name_color := Color.WHITE if ok else Color(1, 1, 1, 0.4)
		_text(pos + Vector2(12, 15), skill.display_name, name_color, 13)

		# 코스트 — 오의는 게이지, 스킬은 공명.
		var cost := ""
		if skill.is_turn_ultimate():
			cost = "오의"
		elif skill.rp_cost > 0:
			cost = "◆%d" % skill.rp_cost
		elif skill.is_turn_basic():
			cost = "+◆1"
		_text(pos + Vector2(size.x - 34, 15), cost, TurnCombat.COLOR_NEUTRAL, 11)

		# 자물쇠 개수 — 매 턴의 미니 퍼즐을 계산기 없이 풀 수 있게 한다.
		if int(entry["locks"]) > 0:
			_text(pos + Vector2(12, 29), "🔒 x%d" % int(entry["locks"]),
				TurnCombat.COLOR_WARN, 11)
		elif not ok:
			_text(pos + Vector2(12, 29), String(entry["reason"]),
				Color(1, 0.55, 0.5, 0.85), 10)
		else:
			_text(pos + Vector2(12, 29), skill.format_usable_ranks(),
				TurnCombat.COLOR_NEUTRAL, 10)

		if ok:
			_register_hit(Rect2(pos, size), "action", {"index": i, "skill": skill})

	# 대형 원형 버튼 — 지금 고른(호버 중인) 행동을 확정한다.
	var chosen := hovered_action if hovered_action >= 0 else 0
	var chosen_entry: Dictionary = actions[clampi(chosen, 0, actions.size() - 1)]
	var chosen_skill: SkillData = chosen_entry["skill"]
	var usable := bool(chosen_entry["ok"])

	draw_circle(ACTION_CENTER, ACTION_RADIUS,
		Color(0.06, 0.09, 0.14, 0.9) if usable else Color(0.10, 0.06, 0.06, 0.9))
	draw_arc(ACTION_CENTER, ACTION_RADIUS, 0, TAU, 48,
		TurnCombat.COLOR_ULT_READY if usable else TurnCombat.COLOR_DANGER, 3.0)
	_text_centered(ACTION_CENTER + Vector2(0, -2),
		TurnCombat.element_glyph(battle.active_unit.element), Color.WHITE, 26)
	_text_centered(ACTION_CENTER + Vector2(0, 22),
		TurnCombat.targeting_name(chosen_skill.turn_targeting), Color.WHITE, 12)
	if usable:
		_register_hit(Rect2(ACTION_CENTER - Vector2(ACTION_RADIUS, ACTION_RADIUS),
			Vector2(ACTION_RADIUS * 2, ACTION_RADIUS * 2)),
			"confirm", {"skill": chosen_skill})


# --- 타겟 조준환 (설계서 §4.9.2 (C)) ---
#
# **회전하는 원형 크로스헤어.** 삼각 마커 3개가 원 둘레를 천천히 돈다.
# 확산/광역 스킬 선택 시 부수 대상에는 작고 흐린 조준환을 표시한다.
func _draw_reticle() -> void:
	if battle.phase != TurnBattleManager.Phase.AWAITING_INPUT:
		return

	# 적을 클릭할 수 있게 히트존을 등록한다.
	for unit in battle.enemies():
		var center := unit_position(unit)
		_register_hit(Rect2(center - Vector2(38, 48), Vector2(76, 96)),
			"target", {"unit": unit})

	if selected_target == null:
		return

	_reticle_at(unit_position(selected_target), 34.0, 1.0)

	# 부수 대상 (확산/전체).
	var actions := battle.available_actions()
	if hovered_action < 0 or hovered_action >= actions.size():
		return
	var skill: SkillData = actions[hovered_action]["skill"]
	for entry in battle.ranks.expand_targets(battle.active_unit, skill, selected_target, null):
		var unit: TurnUnit = entry[0]
		if unit == selected_target or unit == null or unit.is_ally():
			continue
		_reticle_at(unit_position(unit), 22.0, 0.45)


func _reticle_at(center: Vector2, radius: float, alpha: float) -> void:
	var color := Color(1, 0.62, 0.28, alpha)
	draw_arc(center, radius, 0, TAU, 40, color, 2.0)
	for i in 3:
		var angle := _reticle_angle + TAU * float(i) / 3.0
		var tip := center + Vector2.RIGHT.rotated(angle) * (radius + 8.0)
		var left := center + Vector2.RIGHT.rotated(angle + 0.12) * radius
		var right := center + Vector2.RIGHT.rotated(angle - 0.12) * radius
		draw_colored_polygon([tip, left, right], color)


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
			hovered_action = int(zone["data"]["index"])
			_refresh_preview()

		"confirm":
			var skill: SkillData = zone["data"]["skill"]
			_emit_action(skill)

		"target":
			selected_target = zone["data"]["unit"]
			_refresh_preview()

		"ultimate":
			# **턴 순서와 무관하게 언제든 발동한다.** 이 게임의 심장이다.
			ultimate_requested.emit(zone["data"]["unit"])

		"speed":
			speed = 1.0 if speed >= 3.0 else speed + 1.0
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
	preview = {}


# 마우스가 올라간 행동이 바뀌면 **타임라인 프리뷰를 갱신한다** (설계서 §4.2.5).
func _update_hover(position: Vector2) -> void:
	var zone := _zone_at(position)
	var index := -1
	if not zone.is_empty() and String(zone["kind"]) == "action":
		index = int(zone["data"]["index"])
	if index != hovered_action:
		hovered_action = index
		_refresh_preview()


func _refresh_preview() -> void:
	preview = {}
	if battle == null or battle.phase != TurnBattleManager.Phase.AWAITING_INPUT:
		return
	var actions := battle.available_actions()
	if hovered_action < 0 or hovered_action >= actions.size():
		return
	var skill: SkillData = actions[hovered_action]["skill"]
	preview = battle.preview_action(skill, selected_target)


# ===== 히트존 (Hit zones) =====
#
# 기울어진 폴리곤을 직접 그리므로 노드 기반 버튼을 쓸 수 없다. `_draw()` 가 그리면서
# 클릭 영역을 등록하고, 입력은 그 목록을 역순으로(위에 그린 것 우선) 찾는다.

func _register_hit(rect: Rect2, kind: String, data: Dictionary) -> void:
	_hit_zones.append({"rect": rect, "kind": kind, "data": data})


func _zone_at(position: Vector2) -> Dictionary:
	for i in range(_hit_zones.size() - 1, -1, -1):
		var zone: Dictionary = _hit_zones[i]
		if (zone["rect"] as Rect2).has_point(position):
			return zone
	return {}


# ===== 그리기 헬퍼 (Draw helpers) =====

# 기울어진 평행사변형 패널. **사각형 금지** 문법(§4.9.0 3번)을 지키는 기본 도형이다.
func _skewed_panel(pos: Vector2, size: Vector2, fill: Color,
		border: Color = Color(0, 0, 0, 0)) -> void:
	var offset := size.y * SKEW
	var points := PackedVector2Array([
		pos + Vector2(-offset, 0),
		pos + Vector2(size.x - offset, 0),
		pos + Vector2(size.x, size.y),
		pos + Vector2(0, size.y),
	])
	draw_colored_polygon(points, fill)
	if border.a > 0.0:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, border, 1.0)


# 상단 토글 버튼. 사선 알약 하나에 라벨과 켜짐 상태만 담는다.
func _toggle(pos: Vector2, size: Vector2, label: String, on: bool, kind: String) -> void:
	var fill := TurnCombat.COLOR_PANEL
	var border := TurnCombat.COLOR_PANEL_LINE
	if on:
		fill = Color(0.06, 0.24, 0.16, 0.82)
		border = TurnCombat.COLOR_ULT_READY
	_skewed_panel(pos, size, fill, border)
	_text_centered(pos + Vector2(size.x * 0.5, size.y * 0.68), label,
		TurnCombat.COLOR_ULT_READY if on else TurnCombat.COLOR_NEUTRAL, 13)
	_register_hit(Rect2(pos, size), kind, {})


# 마름모. 공명 포인트 핍이 이 형태다.
func _diamond(center: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius * 0.75, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius * 0.75, 0),
	]), color)


func _text(pos: Vector2, text: String, color: Color, size: int) -> void:
	if _font == null:
		return
	draw_string(_font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_centered(pos: Vector2, text: String, color: Color, size: int) -> void:
	if _font == null:
		return
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(_font, pos - Vector2(width * 0.5, 0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


# 전투가 진행되면 화면을 갱신한다. 전투 화면이 부른다.
func refresh() -> void:
	_refresh_preview()
	queue_redraw()
