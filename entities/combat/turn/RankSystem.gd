extends RefCounted
class_name RankSystem

# 랭크(위치) 시스템 (#450).
#
#    [후열]                   [전열] │ [전열]                [후열]
#   A4   A3   A2   A1          │       E1   E2   E3   E4   E5
#
# HSR의 최대 약점은 **위치가 사실상 무의미**하다는 것이다. 2D 사이드뷰에서는 전열/후열을
# 자연스럽게 시각화할 수 있고, 다키스트 던전의 "랭크 + 위치 요구 스킬 + 밀치기/끌기"를
# 도입하면 전술 깊이가 한 단계 위가 된다 — 이것이 이 설계의 **차별화 핵심**이다.
#
# **핵심 루프**: 적 대형이 무너지면 적의 스킬 사용 조건이 깨져 적이 약한 대체 행동만
# 하게 된다. 즉 **위치 조작 = 예방적 방어**다. HSR에 없는 층위다.
#
# 참고: docs/turn-combat-design.md §랭크

## 진영별 랭크 배열. `_slots[side][rank - 1]` = 그 자리의 유닛(없으면 null).
var _slots: Dictionary = {}


func _tuning() -> TurnCombatTuning:
	return PlayerStats.get_tuning_turn()


func _init() -> void:
	_slots[TurnCombat.Side.ALLY] = _empty_slots(TurnCombat.ALLY_RANK_COUNT)
	_slots[TurnCombat.Side.ENEMY] = _empty_slots(TurnCombat.ENEMY_RANK_COUNT)


func _empty_slots(count: int) -> Array:
	var out: Array = []
	for _i in count:
		out.append(null)
	return out


# ===== 배치 (Placement) =====

# 유닛들을 각자의 `rank`에 앉힌다. 같은 자리가 겹치면 뒤쪽 빈 자리로 밀어 넣는다.
func place(units: Array[TurnUnit]) -> void:
	_slots[TurnCombat.Side.ALLY] = _empty_slots(TurnCombat.ALLY_RANK_COUNT)
	_slots[TurnCombat.Side.ENEMY] = _empty_slots(TurnCombat.ENEMY_RANK_COUNT)

	for unit in units:
		if not _seat(unit, unit.rank):
			# 원하는 자리가 찼으면 가장 앞쪽 빈 자리로.
			var free := first_free_rank(unit.side)
			if free > 0:
				_seat(unit, free)
			else:
				push_warning("RankSystem: %s 를 앉힐 자리가 없습니다(진영 %d)."
					% [unit.display_name, unit.side])


# 유닛을 지정한 랭크에 앉힌다. 이미 차 있으면 실패한다.
func _seat(unit: TurnUnit, rank: int) -> bool:
	var slots: Array = _slots[unit.side]
	if rank < 1 or rank > slots.size():
		return false
	if slots[rank - 1] != null:
		return false
	slots[rank - 1] = unit
	unit.rank = rank
	return true


func remove(unit: TurnUnit) -> void:
	var slots: Array = _slots.get(unit.side, [])
	for i in slots.size():
		if slots[i] == unit:
			slots[i] = null
			return


# ===== 조회 (Queries) =====

# 그 랭크에 있는 유닛. 없으면 null.
func at(side: int, rank: int) -> TurnUnit:
	var slots: Array = _slots.get(side, [])
	if rank < 1 or rank > slots.size():
		return null
	return slots[rank - 1]


# 그 진영에서 살아 있는 유닛들. 랭크 오름차순.
func living(side: int) -> Array[TurnUnit]:
	var out: Array[TurnUnit] = []
	for unit in _slots.get(side, []):
		if unit != null and unit.alive:
			out.append(unit)
	return out


# 가장 앞쪽 빈 랭크. 없으면 0.
func first_free_rank(side: int) -> int:
	var slots: Array = _slots.get(side, [])
	for i in slots.size():
		if slots[i] == null:
			return i + 1
	return 0


# 좌우 인접 유닛들 (확산 공격의 부수 대상).
#
# **3D 거리가 아니라 배열 인덱스 ±1이다.** 이 사실이 2D 이식을 무손실로 만든다.
func adjacent(unit: TurnUnit) -> Array[TurnUnit]:
	var out: Array[TurnUnit] = []
	for offset in [-1, 1]:
		var neighbor := at(unit.side, unit.rank + offset)
		if neighbor != null and neighbor.alive:
			out.append(neighbor)
	return out


# 대상 랭크에서 뒤쪽으로 순차 타격되는 유닛들 (관통).
func behind(unit: TurnUnit, count: int) -> Array[TurnUnit]:
	var out: Array[TurnUnit] = []
	var rank := unit.rank
	while out.size() < count:
		rank += 1
		var next := at(unit.side, rank)
		if next == null:
			if rank > TurnCombat.rank_count(unit.side):
				break
			continue  # 빈 자리는 건너뛴다(관통은 자리를 뚫는 게 아니라 유닛을 뚫는다).
		if next.alive:
			out.append(next)
	return out


# ===== 스킬 사용 판정 (Usability) =====

# 이 유닛이 이 스킬을 지금 쓸 수 있는가. 못 쓰면 이유를 함께 돌려준다.
#
# 이유를 문자열로 함께 주는 이유: 회색 버튼만 보여 주면 플레이어가 왜 못 쓰는지 몰라
# 랭크 시스템 자체를 이해하지 못한다. 위치 전술은 **왜 막혔는지 보일 때만** 전술이 된다.
#
# 반환: `{"ok": bool, "reason": String}`
func check_usable(unit: TurnUnit, skill: SkillData) -> Dictionary:
	if skill == null:
		return {"ok": false, "reason": "스킬이 없습니다"}
	if not unit.can_act() and skill.consumes_turn():
		return {"ok": false, "reason": unit.blocked_reason()}
	if not skill.can_use_from_rank(unit.rank):
		return {
			"ok": false,
			"reason": "이 랭크에서 쓸 수 없습니다 (사용 %s)" % skill.format_usable_ranks(),
		}
	if skill.turn_deals_damage() and not skill.targets_allies():
		if valid_targets(unit, skill).is_empty():
			return {
				"ok": false,
				"reason": "타격할 수 있는 대상이 없습니다 (타격 %s)" % skill.format_target_ranks(),
			}
	return {"ok": true, "reason": ""}


func is_usable(unit: TurnUnit, skill: SkillData) -> bool:
	return bool(check_usable(unit, skill)["ok"])


# 이 스킬로 고를 수 있는 대상들.
func valid_targets(unit: TurnUnit, skill: SkillData) -> Array[TurnUnit]:
	if skill == null:
		return []

	var out: Array[TurnUnit] = []

	if skill.turn_targeting == TurnCombat.Targeting.SELF:
		out.append(unit)
		return out

	if skill.targets_allies():
		for ally in living(unit.side):
			out.append(ally)
		return out

	var enemy_side := TurnCombat.Side.ENEMY if unit.is_ally() else TurnCombat.Side.ALLY
	for target in living(enemy_side):
		if skill.can_target_rank(target.rank):
			out.append(target)
	return out


# 고른 대상에서 실제로 맞는 유닛들을 펼친다 (확산·전체·관통·튕김).
#
# 반환: `[[unit, ratio], ...]` — ratio는 주 대상 대비 배율(확산 인접은 0.5 등).
func expand_targets(unit: TurnUnit, skill: SkillData, primary: TurnUnit,
		rng: RandomNumberGenerator = null) -> Array:
	var out: Array = []

	match skill.turn_targeting:
		TurnCombat.Targeting.SELF:
			out.append([unit, 1.0])

		TurnCombat.Targeting.ALLY_ALL:
			for ally in living(unit.side):
				out.append([ally, 1.0])

		TurnCombat.Targeting.ALLY_SINGLE:
			if primary != null:
				out.append([primary, 1.0])

		TurnCombat.Targeting.ALL_ENEMIES:
			var enemy_side := TurnCombat.Side.ENEMY if unit.is_ally() else TurnCombat.Side.ALLY
			for target in living(enemy_side):
				out.append([target, 1.0])

		TurnCombat.Targeting.BLAST:
			if primary != null:
				out.append([primary, 1.0])
				var ratio := _tuning().blast_adjacent_ratio
				for neighbor in adjacent(primary):
					out.append([neighbor, ratio])

		TurnCombat.Targeting.LINE:
			if primary != null:
				out.append([primary, 1.0])
				var ratio := _tuning().blast_adjacent_ratio
				for target in behind(primary, maxi(skill.bounce_count, 1)):
					out.append([target, ratio])

		TurnCombat.Targeting.BOUNCE:
			var enemy_side2 := TurnCombat.Side.ENEMY if unit.is_ally() else TurnCombat.Side.ALLY
			var pool := living(enemy_side2)
			if not pool.is_empty():
				var bounces := maxi(skill.bounce_count, 1)
				for i in bounces:
					# 결정론이 필요하면 호출자가 시드된 rng 를 넘긴다.
					var index := 0
					if rng != null:
						index = rng.randi_range(0, pool.size() - 1)
					else:
						index = i % pool.size()
					out.append([pool[index], 1.0])

		_:  # SINGLE
			if primary != null:
				out.append([primary, 1.0])

	return out


# ===== 위치 조작 (Movement) =====

# 유닛을 뒤쪽 랭크로 밀친다. 반환: 실제로 이동한 칸 수.
#
# 왜 "빈 자리로만" 옮기지 않고 자리를 맞바꾸는가: 대형이 촘촘한 상태에서 밀치기가
# 아무 일도 하지 않으면 위치 조작 스킬이 상황 의존적으로 죽는다. 자리를 맞바꾸면
# 밀린 유닛과 앞으로 나온 유닛이 **둘 다** 조건이 바뀌어 대형 붕괴가 실제로 일어난다.
func push(unit: TurnUnit, distance: int = 1) -> int:
	return _move(unit, absi(distance))


# 유닛을 앞쪽 랭크로 끌어당긴다.
func pull(unit: TurnUnit, distance: int = 1) -> int:
	return _move(unit, -absi(distance))


# 시전자가 스스로 이동한다 (자리바꿈). 방향은 부호로.
func shift(unit: TurnUnit, distance: int) -> int:
	return _move(unit, distance)


func _move(unit: TurnUnit, delta: int) -> int:
	if delta == 0:
		return 0
	if unit.is_anchored():
		return 0

	var slots: Array = _slots.get(unit.side, [])
	var limit := slots.size()
	var moved := 0
	var step := 1 if delta > 0 else -1

	for _i in absi(delta):
		var from := unit.rank
		var to := from + step
		if to < 1 or to > limit:
			break

		var other: TurnUnit = slots[to - 1]
		if other != null and other.is_anchored():
			break  # 고정된 유닛과는 자리를 맞바꿀 수 없다.

		slots[from - 1] = other
		slots[to - 1] = unit
		unit.rank = to
		if other != null:
			other.rank = from
		moved += 1

	return moved


# ===== 어그로 (Aggro) =====

# 적이 노릴 아군을 가중치 랜덤으로 고른다.
#
# **완전 랜덤도 확정도 아니다**: 확정이면 퍼즐이 되고, 완전 랜덤이면 억울해진다.
# 랭크 계수(A1:1.5 ~ A4:0.6)가 "탱커를 앞에 세운다"는 직관을 시스템으로 성립시킨다.
#
# `rng`를 받는 이유: 결정론적 RNG여야 리플레이·버그 재현·헤드리스 테스트가 된다.
func pick_aggro_target(attacker: TurnUnit, rng: RandomNumberGenerator,
		allowed_ranks: Array[int] = []) -> TurnUnit:
	var target_side := TurnCombat.Side.ALLY if attacker.is_enemy() else TurnCombat.Side.ENEMY
	var candidates := living(target_side)
	if candidates.is_empty():
		return null

	if not allowed_ranks.is_empty():
		var filtered: Array[TurnUnit] = []
		for unit in candidates:
			if allowed_ranks.has(unit.rank):
				filtered.append(unit)
		# 조건을 만족하는 대상이 없으면 조건을 버린다 — 적이 아무것도 못 하고 서 있는
		# 것보다 약한 대체 행동을 하는 편이 낫다(대형 붕괴의 보상은 위력 감소로 준다).
		if not filtered.is_empty():
			candidates = filtered

	var weights: Array[float] = []
	var total := 0.0
	for unit in candidates:
		var w := aggro_weight(unit)
		weights.append(w)
		total += w

	if total <= 0.0:
		return candidates[0]

	var roll := rng.randf() * total
	var accum := 0.0
	for i in candidates.size():
		accum += weights[i]
		if roll <= accum:
			return candidates[i]
	return candidates[candidates.size() - 1]


# 이 유닛의 어그로 가중치.
func aggro_weight(unit: TurnUnit) -> float:
	var t := _tuning()

	if unit.is_taunting():
		return t.aggro_taunt_weight

	var weight := 1.0
	if unit.is_ally():
		var weights := t.aggro_rank_weights
		var index := clampi(unit.rank - 1, 0, weights.size() - 1)
		weight *= weights[index]

	if unit.get_hp_ratio() <= t.aggro_low_hp_threshold:
		weight *= t.aggro_low_hp_weight

	return maxf(weight, 0.0)


# 각 아군이 노려질 확률(0~1). UI가 초상화 위에 작게 표시한다 (옵션).
#
# 다키스트 던전이 "적중률·회피율 미표기"로 겪은 불만을 피하는 장치다.
func aggro_probabilities(target_side: int = TurnCombat.Side.ALLY) -> Dictionary:
	var out: Dictionary = {}
	var candidates := living(target_side)
	var total := 0.0
	for unit in candidates:
		total += aggro_weight(unit)
	if total <= 0.0:
		return out
	for unit in candidates:
		out[unit.unit_id] = aggro_weight(unit) / total
	return out


# ===== 디버그 (Debug) =====

func describe() -> String:
	var lines: Array[String] = []
	for side in [TurnCombat.Side.ALLY, TurnCombat.Side.ENEMY]:
		var tag := "아군" if side == TurnCombat.Side.ALLY else "적"
		var parts: Array[String] = []
		var slots: Array = _slots[side]
		for i in slots.size():
			var unit: TurnUnit = slots[i]
			parts.append("%d:%s" % [i + 1, unit.display_name if unit != null else "-"])
		lines.append("%s  %s" % [tag, "  ".join(parts)])
	return "\n".join(lines)
