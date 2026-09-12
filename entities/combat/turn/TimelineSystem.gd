extends RefCounted
class_name TimelineSystem

# 행동 순서 시스템 — 턴제 전투의 **뼈대** (#450).
#
# 규칙은 한 줄이다: **행동값(AV)이 가장 낮은 유닛이 다음에 행동한다.**
#
#   AV = av_scale / SPD        (av_scale 기본 1000)
#
# 유닛이 행동하면 자기 AV를 `av_scale / SPD`로 리필하고, 그 사이 흐른 만큼을 전체
# 타임라인에서 차감한다. 그래서 **속도가 높을수록 AV 소모가 적어 자주 행동**한다.
# 속도 200 = AV 5, 속도 100 = AV 10 -> 정확히 2배 자주 행동한다.
#
# 여기가 무너지면 나머지 전부 무너진다. 그래서 이 클래스는 **연출을 모른다** —
# 노드도 신호도 없는 순수 계산기이고, 헤드리스에서 그대로 검증된다.
#
# 참고: docs/turn-combat-design.md §행동 순서

## 타임라인에 참여하는 유닛들. 전투가 소유하고 여기서는 참조만 한다.
var units: Array[TurnUnit] = []

## `unit_id` -> 남은 AV. 이 값이 낮은 유닛이 먼저 행동한다.
var _av: Dictionary = {}

## 전투 시작부터 흐른 누적 AV. 사이클 판정의 기준이다.
var elapsed_av: float = 0.0

## 추가 턴 대기열. AV를 소모하지 않고 즉시 한 번 더 행동하는 유닛들이다.
var _extra_queue: Array[StringName] = []

## 이번 턴에 행동 중인 유닛. 오의 상한(턴당 2개)과 추가 턴 캡의 기준이다.
var current_actor_id: StringName = &""

## **이번 턴이 추가 턴인가.** `advance_to_next()` 가 정한다.
##
## 왜 `is_pending_extra()` 로 물어보면 안 되는가: `advance_to_next()` 가 대기열에서
## id 를 **꺼내면서** 유닛을 돌려주므로, 돌려받은 뒤에 대기열을 조회하면 방금 꺼낸
## 그 턴은 이미 없다. 실제로 `TurnBattleManager` 가 그렇게 물어봐서 **추가 턴마다
## AV 가 리필되어 추가 턴이 정상 턴을 먹고 있었다**(#495).
var current_is_extra: bool = false


func _tuning() -> TurnCombatTuning:
	return PlayerStats.get_tuning_turn()


# ===== 초기화 (Setup) =====

# 전투 개시 시 초기 AV를 산정한다.
#
# 선공/피습은 `initial_offset`으로 표현한다 — 아군 전체의 AV를 깎으면 선공(아군 선제
# 이득), 늘리면 피습이다. 전투 밖 행동이 전투 안 유불리로 연결되는 접합부다.
func reset(battle_units: Array[TurnUnit], ally_offset_ratio: float = 0.0,
		enemy_offset_ratio: float = 0.0) -> void:
	units = battle_units
	_av.clear()
	_extra_queue.clear()
	elapsed_av = 0.0
	current_actor_id = &""
	current_is_extra = false

	for unit in units:
		var base := unit.get_action_value()
		var offset := ally_offset_ratio if unit.is_ally() else enemy_offset_ratio
		# 양수 offset = 지연(뒤로), 음수 = 앞당김(앞으로).
		_av[unit.unit_id] = maxf(base * (1.0 + offset), 0.0)


# 유닛을 타임라인에 추가한다 (소환체·증원).
#
# 초기 AV를 최대 AV의 절반으로 두는 이유: 0으로 두면 소환된 즉시 행동해 소환 스킬이
# 사실상 "추가 턴 + 유닛"이 되고, 최대치로 두면 소환이 한 사이클을 통째로 낭비한다.
func add_unit(unit: TurnUnit, initial_ratio: float = 0.5) -> void:
	if not units.has(unit):
		units.append(unit)
	_av[unit.unit_id] = unit.get_action_value() * clampf(initial_ratio, 0.0, 1.0)


# 유닛을 타임라인에서 뺀다 (사망·퇴장).
#
# **`units` 에서는 지우지 않는다.** 그 배열은 전투가 소유하고 여기서는 참조만 한다 —
# `reset()` 이 같은 객체를 받으므로 여기서 erase 하면 `TurnBattleManager.units` 가
# 그대로 깎인다. 실제로 그랬고, 그래서 **죽은 유닛이 전투 기록에서 통째로 사라져**
# 결과 화면의 딜량 표가 이름 대신 내부 id(`velociraptor_beastfolk#1`)를 띄웠다 (#497).
#
# `units` 는 "이 전투에 참여한 전원"이고, 여기서 빠져야 하는 것은 **행동 순서**뿐이다.
# `_active_units()` 가 `_av` 에 있는지로 거르므로 이것만으로 충분하다.
func remove_unit(unit: TurnUnit) -> void:
	_av.erase(unit.unit_id)
	_extra_queue = _extra_queue.filter(func(id): return id != unit.unit_id)


# ===== 조회 (Queries) =====

# 이 유닛의 남은 AV.
func get_av(unit: TurnUnit) -> float:
	return float(_av.get(unit.unit_id, unit.get_action_value()))


# 이 유닛의 리필 기준 AV (속도가 정하는 최대치).
func get_base_av(unit: TurnUnit) -> float:
	return unit.get_action_value()


# 전투 준비도(CR). 다음 행동까지 얼마나 찼는지 0~1.
#
# 왜 두 표현을 함께 두는가: 초보자는 "얼마나 찼는가"를 막대로 보는 게 이해하기 쉽고,
# 숙련자는 타임라인 칩으로 정밀하게 계획한다. 내부 계산은 AV 하나이고 CR은 그 표시다
# (설계서 §4.2.2 — 에픽세븐의 CR 시각화를 AV 위에 얹은 하이브리드).
func get_charge_ratio(unit: TurnUnit) -> float:
	var base := get_base_av(unit)
	if base <= 0.0:
		return 1.0
	return clampf(1.0 - get_av(unit) / base, 0.0, 1.0)


# 지금 몇 번째 사이클인가. 1부터 센다.
func current_cycle() -> int:
	return _tuning().cycle_at_av(elapsed_av)


# 이번 사이클이 끝나기까지 남은 AV.
func av_until_cycle_end() -> float:
	return maxf(_tuning().cycle_end_av(current_cycle()) - elapsed_av, 0.0)


# 살아 있고 타임라인에 있는 유닛들.
func _active_units() -> Array[TurnUnit]:
	var out: Array[TurnUnit] = []
	for unit in units:
		if unit.alive and _av.has(unit.unit_id):
			out.append(unit)
	return out


# ===== 진행 (Advance) =====

# 다음에 행동할 유닛을 확정하고 그 시점까지 시간을 흘린다.
#
# 추가 턴 대기열이 비어 있지 않으면 **AV를 흘리지 않고** 그 유닛을 돌려준다 —
# 추가 턴의 정의가 "AV 소모 없이 즉시 한 번 더"이기 때문이다.
#
# 반환: 행동할 유닛. 아무도 행동할 수 없으면 null.
func advance_to_next() -> TurnUnit:
	current_is_extra = false

	# 1) 추가 턴 우선.
	while not _extra_queue.is_empty():
		var id: StringName = _extra_queue.pop_front()
		var unit := _find_unit(id)
		if unit != null and unit.alive and unit.can_act():
			current_actor_id = id
			# 꺼내는 이 자리에서만 "추가 턴이다"를 알 수 있다. 호출자가 나중에
			# 대기열을 다시 보면 이미 꺼낸 뒤라 알 방법이 없다.
			current_is_extra = true
			return unit
		# 죽거나 행동 불가가 된 유닛의 추가 턴은 버린다.

	# 2) AV가 가장 낮은 유닛.
	var active := _active_units()
	if active.is_empty():
		return null

	var next_unit: TurnUnit = null
	var lowest := INF
	for unit in active:
		var av := get_av(unit)
		if av < lowest or (is_equal_approx(av, lowest) and _breaks_tie(unit, next_unit)):
			lowest = av
			next_unit = unit

	if next_unit == null:
		return null

	# 3) 그 시점까지 전체에서 차감한다.
	if lowest > 0.0:
		for unit in active:
			_av[unit.unit_id] = maxf(get_av(unit) - lowest, 0.0)
		elapsed_av += lowest

	current_actor_id = next_unit.unit_id
	return next_unit


# AV가 같을 때의 우선순위.
#
# 속도가 높은 쪽 -> 아군 -> 랭크가 앞인 쪽. **결정론적**이어야 한다 —
# 순서가 무작위면 같은 시드로 같은 전투가 재현되지 않고, 타임라인 프리뷰가 거짓말이 된다.
func _breaks_tie(candidate: TurnUnit, current: TurnUnit) -> bool:
	if current == null:
		return true
	if candidate.get_speed() != current.get_speed():
		return candidate.get_speed() > current.get_speed()
	if candidate.is_ally() != current.is_ally():
		return candidate.is_ally()
	return candidate.rank < current.rank


# 유닛이 턴을 마쳤다. 자기 AV를 리필한다.
#
# 추가 턴으로 행동한 경우에는 리필하지 않는다 — 그러면 추가 턴이 정상 턴을 소모해
# "추가"가 아니게 된다. 호출자가 `was_extra`로 알려 준다.
func on_turn_finished(unit: TurnUnit, was_extra: bool = false) -> void:
	if not was_extra:
		_av[unit.unit_id] = get_base_av(unit)
	# 연속 앞당김 카운터는 자기 턴을 마치면 끊긴다 — "연속"의 정의가 그렇다.
	unit.advance_streak = 0
	unit.extra_turns_used = 0
	current_actor_id = &""
	current_is_extra = false


# ===== 행동 조작 (Manipulation) =====

# 행동 앞당김. 현재 AV를 `기준AV x percent`만큼 즉시 줄인다.
#
# **함정(의도된 것)**: 이미 AV가 낮은(곧 행동할) 유닛에게 쓰면 낭비된다. 이 미묘함이
# 고수와 초보를 가르는 지점이다.
#
# **가드레일**: 같은 대상에게 연속으로 걸면 2회차부터 효율이 절반이 된다. 이것이 없으면
# 앞당김 100%를 서로 주고받아 무한 턴 루프가 성립한다(설계서 §4.13).
#
# 반환: 실제로 줄어든 AV.
func advance_action(unit: TurnUnit, percent: float) -> float:
	var t := _tuning()
	var efficiency := 1.0
	if unit.advance_streak > 0:
		efficiency = pow(t.advance_repeat_efficiency, float(unit.advance_streak))
	unit.advance_streak += 1

	var effective := clampf(percent, 0.0, 1.0) * efficiency
	var reduction := get_base_av(unit) * effective
	var before := get_av(unit)
	_av[unit.unit_id] = maxf(before - reduction, 0.0)
	return before - get_av(unit)


# 행동 지연. 현재 AV를 `기준AV x percent`만큼 늘린다.
#
# 효과 저항이 아니라 **격파 저항**을 쓰지 않는 이유: 지연은 상태이상이 아니라 타임라인
# 조작이다. 보스는 `delay_resistance`(효과 저항으로 대체)로 버틴다.
func delay_action(unit: TurnUnit, percent: float) -> float:
	var resist := unit.stats.get_effect_res() if unit.is_enemy() else 0.0
	var effective := maxf(percent, 0.0) * (1.0 - resist)
	var addition := get_base_av(unit) * effective
	var before := get_av(unit)
	_av[unit.unit_id] = before + addition
	return get_av(unit) - before


# 추가 턴을 준다. 하드캡(기본 2회/턴)을 넘으면 무시한다.
#
# 반환: 실제로 부여되었는가.
func grant_extra_turn(unit: TurnUnit) -> bool:
	var cap := _tuning().extra_turn_cap
	if unit.extra_turns_used >= cap:
		return false
	unit.extra_turns_used += 1
	_extra_queue.append(unit.unit_id)
	return true


func has_pending_extra_turn() -> bool:
	return not _extra_queue.is_empty()


func is_pending_extra(unit: TurnUnit) -> bool:
	return _extra_queue.has(unit.unit_id)


# ===== 프리뷰 (Preview) =====
#
# 타임라인 UI가 읽는다. **상태를 바꾸지 않는다** — 스냅샷을 떠서 앞으로 시뮬레이션한다.

# 앞으로의 행동 순서. 반환은 유닛 배열이고, 같은 유닛이 여러 번 나올 수 있다.
func preview(count: int = -1) -> Array[TurnUnit]:
	var limit := count if count > 0 else _tuning().timeline_preview_count
	return _simulate(_snapshot(), _extra_queue.duplicate(), limit)


# **이 유닛이 이 행동을 하면 순서가 어떻게 바뀌는가** (설계서 §4.2.5).
#
# HSR에도 없는 기능이고, 설계서가 "이 기능 하나가 전략성 체감을 2배로 만든다"고 꼽은
# 최우선 UX다. 스킬 버튼에 커서를 올리면 좌측 타임라인에 반투명 고스트로 겹쳐 그린다.
#
# `av_changes`: `unit_id` -> 앞당김/지연 비율. 양수 = 지연, 음수 = 앞당김.
#               스킬이 걸 행동 조작을 미리 반영하기 위한 것이다.
# `grants_extra`: 이 행동이 시전자에게 추가 턴을 주는가.
# `consumes_turn`: 턴을 소모하는가. 오의는 false다 — 오의를 써도 순서가 바뀌지 않는 것이
#                  "턴 밖 발동"의 의미이고, 프리뷰가 그것을 그대로 보여 줘야 한다.
func preview_if_acted(actor: TurnUnit, av_changes: Dictionary = {},
		grants_extra: bool = false, consumes_turn: bool = true,
		count: int = -1) -> Array[TurnUnit]:
	var limit := count if count > 0 else _tuning().timeline_preview_count
	var snapshot := _snapshot()
	var extras := _extra_queue.duplicate()

	if consumes_turn and snapshot.has(actor.unit_id):
		snapshot[actor.unit_id] = get_base_av(actor)

	for id in av_changes:
		if not snapshot.has(id):
			continue
		var unit := _find_unit(id)
		if unit == null:
			continue
		var ratio := float(av_changes[id])
		var delta := get_base_av(unit) * ratio
		# 앞당김(음수)에는 연속 적용 감쇠를 반영한다 — 프리뷰가 실제와 달라지면
		# 공개된 정보가 거짓말이 되고, 이 기능의 값어치가 사라진다.
		if ratio < 0.0 and unit.advance_streak > 0:
			delta *= pow(_tuning().advance_repeat_efficiency, float(unit.advance_streak))
		snapshot[id] = maxf(float(snapshot[id]) + delta, 0.0)

	if grants_extra and actor.extra_turns_used < _tuning().extra_turn_cap:
		extras.append(actor.unit_id)

	return _simulate(snapshot, extras, limit)


# 현재 AV 상태의 복사본.
func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for unit in _active_units():
		out[unit.unit_id] = get_av(unit)
	return out


# 스냅샷을 앞으로 굴려 순서를 뽑는다. 원본을 건드리지 않는다.
func _simulate(snapshot: Dictionary, extras: Array, limit: int) -> Array[TurnUnit]:
	var out: Array[TurnUnit] = []
	var extra_queue: Array = extras.duplicate()

	# 시뮬레이션 안에서 쓸 임시 추가턴 카운터. 실제 유닛 상태를 건드리지 않는다.
	var guard := 0
	while out.size() < limit and guard < limit * 8:
		guard += 1

		if not extra_queue.is_empty():
			var extra_id: StringName = extra_queue.pop_front()
			var extra_unit := _find_unit(extra_id)
			if extra_unit != null and extra_unit.alive:
				out.append(extra_unit)
			continue

		var next_id: StringName = &""
		var next_unit: TurnUnit = null
		var lowest := INF
		for id in snapshot:
			var unit := _find_unit(id)
			if unit == null or not unit.alive:
				continue
			var av := float(snapshot[id])
			if av < lowest or (is_equal_approx(av, lowest) and _breaks_tie(unit, next_unit)):
				lowest = av
				next_id = id
				next_unit = unit

		if next_unit == null:
			break

		# 그 시점까지 흘린 뒤 행동자를 기록하고 AV를 리필한다.
		for id in snapshot:
			snapshot[id] = maxf(float(snapshot[id]) - lowest, 0.0)
		out.append(next_unit)
		snapshot[next_id] = get_base_av(next_unit)

	return out


# 프리뷰 칩마다 "이 행동이 몇 번째 사이클인가"를 함께 알려 준다.
# 사이클 제한 콘텐츠에서 플레이어가 남은 예산을 셀 수 있어야 한다.
func preview_with_cycles(count: int = -1) -> Array[Dictionary]:
	var limit := count if count > 0 else _tuning().timeline_preview_count
	var snapshot := _snapshot()
	var extra_queue: Array = _extra_queue.duplicate()
	var out: Array[Dictionary] = []
	var t := _tuning()
	var clock := elapsed_av
	var guard := 0

	while out.size() < limit and guard < limit * 8:
		guard += 1

		if not extra_queue.is_empty():
			var extra_id: StringName = extra_queue.pop_front()
			var extra_unit := _find_unit(extra_id)
			if extra_unit != null and extra_unit.alive:
				out.append({"unit": extra_unit, "cycle": t.cycle_at_av(clock), "extra": true})
			continue

		var next_id: StringName = &""
		var next_unit: TurnUnit = null
		var lowest := INF
		for id in snapshot:
			var unit := _find_unit(id)
			if unit == null or not unit.alive:
				continue
			var av := float(snapshot[id])
			if av < lowest or (is_equal_approx(av, lowest) and _breaks_tie(unit, next_unit)):
				lowest = av
				next_id = id
				next_unit = unit

		if next_unit == null:
			break

		for id in snapshot:
			snapshot[id] = maxf(float(snapshot[id]) - lowest, 0.0)
		clock += lowest
		out.append({"unit": next_unit, "cycle": t.cycle_at_av(clock), "extra": false})
		snapshot[next_id] = get_base_av(next_unit)

	return out


func _find_unit(id: StringName) -> TurnUnit:
	for unit in units:
		if unit.unit_id == id:
			return unit
	return null


# ===== 디버그 (Debug) =====

func describe() -> String:
	var lines: Array[String] = []
	lines.append("사이클 %d (누적 AV %.2f)" % [current_cycle(), elapsed_av])
	var index := 1
	for entry in preview_with_cycles():
		var unit: TurnUnit = entry["unit"]
		lines.append("  %d. %s (AV %.2f, C%d%s)"
			% [index, unit.display_name, get_av(unit), int(entry["cycle"]),
				" 추가턴" if entry["extra"] else ""])
		index += 1
	return "\n".join(lines)
