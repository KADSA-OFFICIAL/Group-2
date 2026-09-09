extends RefCounted
class_name ToughnessSystem

# 인성치 · 자물쇠 · 약점 격파 (#450).
#
# 이 게임의 **핵심 발명**이 여기 있다. HSR은 적에게 고정된 약점 목록이 있고 인성치를
# 계속 깎기만 한다. 본 설계는 **적이 행동을 예고할 때 그 행동에 맞는 봉인 조건(Lock)이
# 함께 표시**된다.
#
#   ⚠ 다음 행동: 「멸절의 낙뢰」  전체 피해 1,240
#   🔒 봉인 조건:  🔨  ❄  ❄  ⚡     (강타 1 + 한기 2 + 전격 1)
#
# 규칙:
#   1. 자물쇠 하나 해제 = 해당 타입 공격 1회 적중
#   2. 자물쇠 하나 해제 = 인성치도 함께 감소
#   3. **전부 해제 → 행동 무산 + 즉시 격파 + 격파 데미지 폭발**
#   4. **일부 해제 → 그 비율만큼 적 행동 위력 감소** (4개 중 3개 = 위력 25%)
#   5. 자물쇠는 적 행동이 끝나거나 무산되면 **다음 행동마다 다른 조합**으로 갱신
#
# 왜 좋은가: 매 턴 화면에 명확한 미니 퍼즐이 생기고, 팀 편성이 자동으로 의미를 가지며,
# 부분 성공에도 보상이 있어 좌절이 적다. "무지성 약점 속성 연타"보다 판단 밀도가 훨씬 높다.
#
# 참고: docs/turn-combat-design.md §인성치와 격파

var rng: RandomNumberGenerator = null
var pipeline: DamagePipeline = null
var statuses: TurnStatusSystem = null

## 격파가 일어났을 때. `func(unit: TurnUnit, element: int, ctx: DamageContext) -> void`.
var on_break: Callable = Callable()
## 자물쇠가 해제됐을 때. `func(unit: TurnUnit, lock: TurnLock, index: int, total: int) -> void`.
## 해제음을 **상승 음계**로 설계하기 위해 몇 번째 해제인지 함께 넘긴다(설계서 §4.10.9).
var on_lock_cleared: Callable = Callable()
## 적 행동이 무산됐을 때. `func(unit: TurnUnit) -> void`.
var on_nullified: Callable = Callable()


func _init(random: RandomNumberGenerator = null, damage_pipeline: DamagePipeline = null,
		status_system: TurnStatusSystem = null) -> void:
	rng = random if random != null else RandomNumberGenerator.new()
	pipeline = damage_pipeline
	statuses = status_system


func _tuning() -> TurnCombatTuning:
	return PlayerStats.get_tuning_turn()


# ===== 자물쇠 생성 (Lock generation) =====

# 적의 예고에 붙일 자물쇠 조합을 만든다.
#
# 개수는 등급이 정하고(잡몹 1~2 / 정예 3~4 / 보스 4~6), 타입은 **약점 목록에서만** 뽑는다.
# 약점이 아닌 타입을 넣으면 그 칸은 인성치를 깎지 못하는 채로 열려야 하고,
# "자물쇠 해제 = 인성치 감소"라는 규칙이 깨진다.
#
# 같은 타입이 여러 번 나올 수 있다(❄ ❄ = 한기 2회). 그래야 "한기 딜러 한 명으로 두 칸을
# 여는" 판단과 "두 원소를 나눠 여는" 판단이 갈린다.
func generate_locks(unit: TurnUnit) -> Array[TurnLock]:
	var out: Array[TurnLock] = []
	if unit.enemy == null:
		return out

	var candidates := unit.enemy.get_lock_candidates()
	if candidates.is_empty():
		return out

	var range_i := unit.enemy.get_lock_count_range()
	var count := rng.randi_range(mini(range_i.x, range_i.y), maxi(range_i.x, range_i.y))
	count = maxi(count, 1)

	# 후보가 2종 이상이면 **최소 2종을 섞는다.** 한 종류로만 채우면 그 원소 캐릭터
	# 하나가 매 턴 자물쇠를 혼자 다 열어, 팀 편성 퍼즐이 사라진다.
	if candidates.size() >= 2 and count >= 2:
		var first: Array = candidates[rng.randi_range(0, candidates.size() - 1)]
		var second: Array = first
		var guard := 0
		while second == first and guard < 8:
			second = candidates[rng.randi_range(0, candidates.size() - 1)]
			guard += 1
		out.append(TurnLock.new(bool(first[0]), int(first[1])))
		out.append(TurnLock.new(bool(second[0]), int(second[1])))

	while out.size() < count:
		var pick: Array = candidates[rng.randi_range(0, candidates.size() - 1)]
		out.append(TurnLock.new(bool(pick[0]), int(pick[1])))

	# 표시 순서를 안정화한다 — 같은 조합이 매번 다른 순서로 그려지면 눈에 익지 않는다.
	out.sort_custom(func(a: TurnLock, b: TurnLock) -> bool:
		if a.is_element != b.is_element:
			return a.is_element
		return a.value < b.value)

	return out


# ===== 타격 처리 (On hit) =====

# 공격 한 번이 인성치와 자물쇠에 미치는 영향을 처리한다.
#
# 반환:
# ```
# {
#   "lock_cleared": TurnLock | null,
#   "nullified": bool,           # 자물쇠 전부 해제로 적 행동이 무산됐다
#   "broke": bool,               # 이 타격으로 격파됐다
#   "break_context": DamageContext | null,
#   "overbreak_context": DamageContext | null,
#   "toughness_applied": int,
# }
# ```
func on_hit(ctx: DamageContext) -> Dictionary:
	var result := {
		"lock_cleared": null,
		"nullified": false,
		"broke": false,
		"break_context": null,
		"overbreak_context": null,
		"toughness_applied": 0,
	}

	var target := ctx.target
	if target == null or target.max_toughness <= 0:
		return result

	# --- 이미 격파된 적: 인성치 피해가 초격파 피해로 전환된다 ---
	if target.is_broken:
		if ctx.toughness_damage > 0 and pipeline != null:
			var over := pipeline.build_overbreak_context(
				ctx.source, target, ctx.element, ctx.toughness_damage)
			pipeline.resolve(over)
			result["overbreak_context"] = over
		return result

	# --- 자물쇠 해제 (약점 여부와 무관하게 타입이 맞으면 열린다) ---
	#
	# 자물쇠 타입은 약점에서만 뽑았으므로 "타입이 맞으면 약점"이 성립한다. 그래도
	# 인성치 감소는 아래에서 `hits_weakness`로 다시 확인한다 — 자물쇠가 없는 적
	# (예고 전)에도 약점 규칙이 똑같이 적용되어야 한다.
	if target.intent != null:
		var lock := target.intent.find_matching_lock(ctx.element, ctx.physical_type)
		if lock != null:
			lock.cleared = true
			result["lock_cleared"] = lock
			target.intent.recalculate_power()

			if on_lock_cleared.is_valid():
				on_lock_cleared.call(target, lock,
					target.intent.cleared_locks(), target.intent.total_locks())

			# 자물쇠 해제는 인성치도 함께 깎는다. 몫은 "최대 인성치 / 자물쇠 개수"다 —
			# 그래야 자물쇠를 다 열면 인성치도 0이 되어 두 규칙이 어긋나지 않는다.
			var share := float(target.max_toughness) \
				/ float(maxi(target.intent.total_locks(), 1))
			var lock_toughness := int(round(share * _tuning().lock_toughness_share))
			result["toughness_applied"] = int(result["toughness_applied"]) \
				+ _reduce_toughness(target, lock_toughness)

			if target.intent.nullified:
				result["nullified"] = true
				if on_nullified.is_valid():
					on_nullified.call(target)

	# --- 스킬 자체의 인성치 피해 (약점 공격만) ---
	if ctx.toughness_damage > 0:
		result["toughness_applied"] = int(result["toughness_applied"]) \
			+ _reduce_toughness(target, ctx.toughness_damage)

	# --- 격파 판정 ---
	# 자물쇠 전부 해제도 즉시 격파다(설계서 §4.4.2 규칙 3).
	if target.toughness <= 0 or bool(result["nullified"]):
		var break_ctx := trigger_break(ctx.source, target, ctx.element)
		result["broke"] = true
		result["break_context"] = break_ctx

	return result


func _reduce_toughness(target: TurnUnit, amount: int) -> int:
	if amount <= 0:
		return 0
	var before := target.toughness
	target.toughness = maxi(target.toughness - amount, 0)
	return before - target.toughness


# ===== 격파 (Break) =====

# 약점 격파를 발동한다.
#
# 순서(설계서 §4.4.3):
#   1. 즉시 격파 데미지 (원소 배율 적용)
#   2. 원소별 상태이상 부여
#   3. **적은 이번 턴 + 다음 턴 완전 행동 불가** (옥토패스식)
#   4. 격파 지속 중 받는 피해 +25%, 방어력 -30%  ← `DamagePipeline`이 적용
#   5. 격파 해제 시 인성치 전량 회복
#
# HSR의 "25% 지연"보다 훨씬 강한 보상이다. 대신 인성치 총량을 높여 격파 난이도를 올린다.
func trigger_break(source: TurnUnit, target: TurnUnit, element: int) -> DamageContext:
	if target.is_broken:
		return null

	target.is_broken = true
	target.toughness = 0

	# 격파 저항이 행동 불가 턴을 줄인다. 보스가 격파 팀을 완전히 봉쇄하지는 못하도록
	# 최소 1턴은 보장한다 — 0턴이면 격파의 보상이 사라져 격파 축 자체가 죽는다.
	var t := _tuning()
	var stun := int(round(float(t.break_stun_turns) * (1.0 - target.break_resistance)))
	target.break_stun_left = maxi(stun, 1)

	var recover := t.break_recover_turns
	if target.enemy != null:
		recover = target.enemy.get_break_recover_turns()
	target.break_recover_left = maxi(
		int(round(float(recover) * (1.0 - target.break_resistance))), 1)

	# 1) 격파 데미지.
	var ctx: DamageContext = null
	if pipeline != null and source != null:
		ctx = pipeline.build_break_context(source, target, element)
		pipeline.resolve(ctx)

	# 2) 원소별 상태이상.
	if statuses != null:
		statuses.apply_break_status(source, target, element)

	# 자물쇠가 남아 있으면 무산 처리한다 — 격파된 적은 그 행동을 하지 못한다.
	if target.intent != null and not target.intent.nullified:
		for lock in target.intent.locks:
			lock.cleared = true
		target.intent.recalculate_power()

	if on_break.is_valid():
		on_break.call(target, element, ctx)

	return ctx


# ===== 턴 진행 (Tick) =====

# 유닛의 턴이 시작됐다. 격파 기절과 인성치 회복을 진행한다.
#
# 반환: `{"acted_blocked": bool, "recovered": bool}`
func tick_turn_start(unit: TurnUnit) -> Dictionary:
	var out := {"acted_blocked": false, "recovered": false}
	if unit.max_toughness <= 0:
		return out

	if unit.break_stun_left > 0:
		unit.break_stun_left -= 1
		out["acted_blocked"] = true

	if unit.is_broken:
		unit.break_recover_left -= 1
		if unit.break_recover_left <= 0 and unit.break_stun_left <= 0:
			# 격파 해제: 인성치 전량 회복.
			unit.is_broken = false
			unit.toughness = unit.max_toughness
			out["recovered"] = true

	return out


# ===== 예고 갱신 (Intent refresh) =====

# 적의 예고를 새 자물쇠 조합으로 교체한다. 행동이 끝나거나 무산된 뒤에 부른다.
func refresh_locks(unit: TurnUnit) -> void:
	if unit.intent == null:
		return
	unit.intent.locks = generate_locks(unit)
	unit.intent.recalculate_power()


# ===== 조회 (Queries) =====

# 이 스킬이 지금 이 적의 자물쇠를 몇 개 열 수 있는가.
#
# UI가 스킬 버튼 옆에 "🔒 x2"로 띄운다. 매 턴의 미니 퍼즐을 풀기 위해 플레이어가
# 계산기를 두드리게 만들지 않으려는 것이다.
func count_openable_locks(attacker: TurnUnit, skill: SkillData, target: TurnUnit) -> int:
	if target.intent == null or skill == null:
		return 0

	var element := skill.resolve_element(attacker.element)
	var physical := skill.resolve_physical_type(attacker.physical_type)
	var hits := maxi(skill.turn_hits, 1)

	# 히트 1회당 자물쇠 1개다. 남은 자물쇠 중 타입이 맞는 것의 개수와 히트 수 중 작은 쪽.
	var matching := 0
	for lock in target.intent.locks:
		if lock.matches(element, physical):
			matching += 1

	return mini(matching, hits)


# 인성치 바를 자물쇠 개수만큼 **분절(segment)**로 그리기 위한 값.
#
# 설계서 §4.9.2(B)의 절충안이다: 자물쇠 조합을 상시 노출하면 명확하지만 중앙 개방
# 원칙과 충돌하므로, 인성치 바의 분절 칸에 아이콘을 초소형으로 인라인 표시한다.
#
# 반환: `[{"lock": TurnLock, "filled": bool}, ...]`
func toughness_segments(unit: TurnUnit) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if unit.intent == null or unit.intent.locks.is_empty():
		return out
	for lock in unit.intent.locks:
		out.append({"lock": lock, "filled": not lock.cleared})
	return out
