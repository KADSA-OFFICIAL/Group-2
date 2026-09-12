extends Node

# 턴제 전투 코어의 헤드리스 검증 (#450).
#
# 왜 필요한가: 이 시스템은 **수치 규칙의 묶음**이다. 화면에서 눈으로 보고 "맞는 것 같다"로는
# 검증되지 않는다. 버킷이 곱연산이 아니라 가산으로 붕괴하거나, 앞당김 감쇠가 빠져 무한
# 루프가 성립하거나, 약점이 아닌 공격이 인성치를 깎는 것은 전부 **전투가 정상으로 보이는
# 채로** 일어난다.
#
# 그래서 설계서의 수치를 그대로 재현해 본다. 특히 §5.3 의 "같은 버킷 25000 vs 분산 33750"은
# 시너지 설계 전체가 서 있는 수치이므로 그 두 숫자를 직접 확인한다.
#
# 실행:
#   godot --headless --path . res://tests/combat/VerifyTurnCombat.tscn

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await get_tree().process_frame

	_test_action_value()
	_test_cycles()
	_test_speed_breakpoints()
	_test_timeline_order()
	_test_advance_decay()
	_test_extra_turn_cap()
	_test_timeline_preview()
	_test_ranks()
	_test_movement()
	_test_aggro()
	_test_resonance()
	_test_energy_and_ultimate_cap()
	_test_heat()
	_test_damage_buckets()
	_test_defense_coefficient()
	_test_variance_and_crit_cap()
	_test_toughness_weakness_only()
	_test_physical_toughness_multipliers()
	_test_locks()
	_test_break()
	_test_break_resistance()
	_test_overbreak()
	_test_break_statuses_are_distinct()
	_test_pity()
	_test_element_colors()
	_test_presentation_specs()
	_test_authored_data()
	_test_enemy_baseline()
	_test_full_battle()
	_test_standard_encounter()
	_test_cycle_limit()

	if _failures.is_empty():
		print("PASS: 턴제 전투 코어 검증 %d개 통과" % _checks)
		get_tree().quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("FAIL: %d/%d 실패" % [_failures.size(), _checks])
		get_tree().quit(1)


# ===== 검증 헬퍼 =====

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("실패: " + message)


func _expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	_checks += 1
	if absf(actual - expected) > tolerance:
		_failures.append("실패: %s (기대 %.4f, 실제 %.4f)" % [message, expected, actual])


func _tuning() -> TurnCombatTuning:
	return TurnCombatConfig.tuning


# 합성 캐릭터. 저작 데이터에 의존하지 않는 순수 수치 검증에 쓴다.
func _make_character(id: String, speed: int, element: int, physical: int,
		strength: int = 100, defense: int = 100, hp: int = 1000) -> CharacterData:
	var data := CharacterData.new()
	data.character_id = StringName(id)
	data.display_name = id
	data.element = element
	data.physical_type = physical
	var stats := PlayerStats.new()
	stats.hp = hp
	stats.strength = strength
	stats.defense = defense
	stats.speed = speed
	stats.energy_max = 100
	stats.crit_rate = 0.0
	stats.crit_damage = 0.0
	data.stats = stats
	return data


func _make_unit(id: String, speed: int, element: int = TurnCombat.Element.IMPACT,
		physical: int = TurnCombat.PhysicalType.SLASH, rank: int = 1,
		strength: int = 100, defense: int = 100) -> TurnUnit:
	return TurnUnit.from_character(
		_make_character(id, speed, element, physical, strength, defense), rank)


func _make_enemy_unit(id: String, speed: int, toughness: int,
		weak_elements: Array[int], weak_physical: Array[int],
		rank: int = 1, tier: int = TurnCombat.EnemyTier.MINION) -> TurnUnit:
	var data := EnemyData.new()
	data.enemy_id = StringName(id)
	data.display_name = id
	data.tier = tier
	data.turn_level = 20
	data.toughness = toughness
	for e in weak_elements:
		data.weak_elements.append(e)
	for p in weak_physical:
		data.weak_physical.append(p)
	var stats := PlayerStats.new()
	stats.hp = 100000  # 검증 중에 죽지 않게 크게 잡는다.
	stats.strength = 100
	stats.defense = 0
	stats.speed = speed
	data.stats = stats
	return TurnUnit.from_enemy(data, rank)


# ===== 행동값 (AV) =====

func _test_action_value() -> void:
	var t := _tuning()
	_expect_near(t.action_value_for_speed(100.0), 10.0, 0.001,
		"AV = 1000 / SPD 이어야 한다 (SPD 100 -> AV 10)")
	_expect_near(t.action_value_for_speed(200.0), 5.0, 0.001,
		"SPD 200 = AV 5 (속도 2배 -> 2배 자주 행동)")

	# 속도 소프트캡: 220 초과분은 효율 절반.
	_expect_near(t.effective_speed(220.0), 220.0, 0.001, "소프트캡 이하 속도는 그대로여야 한다")
	_expect_near(t.effective_speed(320.0), 270.0, 0.001,
		"소프트캡 초과분(100)은 절반(50)만 반영되어야 한다")

	var unit := _make_unit("av", 100)
	_expect_near(unit.get_action_value(), 10.0, 0.001, "TurnUnit 이 AV 를 스텟에서 파생해야 한다")


func _test_cycles() -> void:
	var t := _tuning()
	# N사이클 종료 누적 AV = 15 + 10 x (N - 1)
	_expect_near(t.cycle_end_av(1), 15.0, 0.001, "1사이클 = 15 AV")
	_expect_near(t.cycle_end_av(2), 25.0, 0.001, "2사이클 = 25 AV")
	_expect_near(t.cycle_end_av(3), 35.0, 0.001, "3사이클 = 35 AV")

	_expect(t.cycle_at_av(0.0) == 1, "누적 0 AV 는 1사이클")
	_expect(t.cycle_at_av(14.9) == 1, "누적 14.9 AV 는 아직 1사이클")
	_expect(t.cycle_at_av(15.0) == 2, "누적 15 AV 부터 2사이클")
	_expect(t.cycle_at_av(25.0) == 3, "누적 25 AV 부터 3사이클")


func _test_speed_breakpoints() -> void:
	var t := _tuning()
	# 설계서 §4.2.3 속도 구간표: 3사이클(35 AV) 안의 행동 횟수.
	_expect(t.actions_in_window(90.0, 35.0) == 3, "SPD 90 은 3사이클에 3회 행동")
	_expect(t.actions_in_window(100.0, 35.0) == 3,
		"SPD 100 은 3사이클(35AV)에 3회 — AV 10 x 4 = 40 > 35")
	_expect(t.actions_in_window(120.0, 35.0) == 4, "SPD 120 은 4회")
	_expect(t.actions_in_window(143.0, 35.0) == 5, "SPD 143 은 5회 (설아의 구간)")
	_expect(t.actions_in_window(200.0, 35.0) == 7, "SPD 200 은 7회")

	# 다음 구간까지 필요한 속도가 실제로 행동 횟수를 1회 늘려야 한다.
	# 이 값이 UI에 표시되므로 틀리면 게임이 거짓말을 하게 된다.
	for speed in [90.0, 100.0, 120.0, 134.0, 143.0, 160.0]:
		var need := t.speed_to_next_breakpoint(speed, 3)
		var before := t.actions_in_window(speed, t.cycle_end_av(3))
		var after := t.actions_in_window(speed + float(need), t.cycle_end_av(3))
		_expect(after >= before + 1,
			"SPD %.0f + %d 이면 행동 횟수가 늘어야 한다 (%d -> %d)"
				% [speed, need, before, after])


# ===== 타임라인 =====

func _test_timeline_order() -> void:
	var fast := _make_unit("fast", 200)
	var slow := _make_unit("slow", 100)
	var units: Array[TurnUnit] = [fast, slow]

	var timeline := TimelineSystem.new()
	timeline.reset(units)

	# 속도 200(AV 5)이 속도 100(AV 10)보다 먼저, 그리고 2배 자주 행동한다.
	var order: Array[String] = []
	for _i in 6:
		var actor := timeline.advance_to_next()
		order.append(String(actor.unit_id))
		timeline.on_turn_finished(actor)

	_expect(order[0] == "fast", "AV 가 낮은 유닛이 먼저 행동해야 한다")
	var fast_count := order.count("fast")
	var slow_count := order.count("slow")
	_expect(fast_count == slow_count * 2,
		"속도 2배는 행동 횟수 2배여야 한다 (fast %d / slow %d)" % [fast_count, slow_count])

	# 행동 후 자기 AV 를 리필한다.
	_expect_near(timeline.get_av(fast), 5.0, 0.001, "행동 후 AV 가 기준값으로 리필되어야 한다")


func _test_advance_decay() -> void:
	var unit := _make_unit("adv", 100)
	var other := _make_unit("other", 100, TurnCombat.Element.IMPACT,
		TurnCombat.PhysicalType.SLASH, 2)
	var units: Array[TurnUnit] = [unit, other]

	var timeline := TimelineSystem.new()
	timeline.reset(units)

	# 1회차: 100% 효율. AV 10 에서 50% -> 5 감소.
	var first := timeline.advance_action(unit, 0.5)
	_expect_near(first, 5.0, 0.01, "1회차 앞당김 50% 는 기준AV 의 50% 를 깎아야 한다")

	# 2회차: 효율 50%. 남은 AV 5 에서 2.5 감소.
	var second := timeline.advance_action(unit, 0.5)
	_expect_near(second, 2.5, 0.01,
		"연속 2회차 앞당김은 효율 50% 여야 한다 (무한 턴 루프 방지)")

	# 3회차: 효율 25%.
	var third := timeline.advance_action(unit, 0.5)
	_expect_near(third, 1.25, 0.01, "연속 3회차 앞당김은 효율 25% 여야 한다")

	# 자기 턴을 마치면 연속 카운터가 끊긴다.
	timeline.on_turn_finished(unit)
	_expect(unit.advance_streak == 0, "턴을 마치면 연속 앞당김 카운터가 초기화되어야 한다")

	# 지연은 AV 를 늘린다.
	var before := timeline.get_av(other)
	timeline.delay_action(other, 0.3)
	_expect_near(timeline.get_av(other) - before, 3.0, 0.01, "지연 30% 는 기준AV 의 30% 를 더해야 한다")


func _test_extra_turn_cap() -> void:
	var unit := _make_unit("extra", 100)
	var units: Array[TurnUnit] = [unit]
	var timeline := TimelineSystem.new()
	timeline.reset(units)

	var cap := _tuning().extra_turn_cap
	var granted := 0
	for _i in cap + 3:
		if timeline.grant_extra_turn(unit):
			granted += 1
	_expect(granted == cap, "추가 턴은 턴당 %d회로 하드캡되어야 한다 (실제 %d)" % [cap, granted])

	# 추가 턴은 AV 를 소모하지 않는다.
	var before := timeline.get_av(unit)
	var actor := timeline.advance_to_next()
	_expect(actor == unit, "추가 턴 대기열이 최우선이어야 한다")
	_expect_near(timeline.get_av(unit), before, 0.001,
		"추가 턴은 AV 를 흘리지 않아야 한다")

	_test_extra_turn_does_not_refill()


# 추가 턴을 마쳐도 AV 가 리필되면 안 된다 (#495 회귀 검사).
#
# 예전에는 `TurnBattleManager` 가 `advance_to_next()` **뒤에** `is_pending_extra()` 로
# 추가 턴 여부를 물었다. 그 함수는 대기열에서 id 를 이미 꺼낸 뒤라 항상 false 를
# 돌려줬고, 그래서 추가 턴마다 AV 가 리필되어 **추가 턴이 그 유닛의 정상 턴을 먹었다.**
# 전투는 정상으로 보이는데 추가 턴 스킬만 아무 이득이 없는, 눈으로 안 잡히는 버그다.
func _test_extra_turn_does_not_refill() -> void:
	var unit := _make_unit("extra_refill", 100)
	var units: Array[TurnUnit] = [unit]
	var timeline := TimelineSystem.new()
	timeline.reset(units)

	# 정상 턴을 한 번 소화해 기준 상태를 만든다.
	var normal := timeline.advance_to_next()
	_expect(normal == unit, "정상 턴이 진행되어야 한다")
	_expect(not timeline.current_is_extra, "정상 턴은 추가 턴으로 표시되면 안 된다")
	timeline.on_turn_finished(unit, timeline.current_is_extra)

	# AV 를 절반으로 낮춰 두면 리필 여부가 눈에 보인다.
	timeline.advance_action(unit, 0.5)
	var av_before := timeline.get_av(unit)
	_expect(av_before < timeline.get_base_av(unit) - 0.001,
		"앞당김으로 AV 가 기준치보다 낮아져 있어야 한다")

	timeline.grant_extra_turn(unit)
	var extra_actor := timeline.advance_to_next()
	_expect(extra_actor == unit, "추가 턴 대기열이 최우선이어야 한다")
	_expect(timeline.current_is_extra,
		"advance_to_next() 가 이번 턴이 추가 턴임을 기록해야 한다")

	timeline.on_turn_finished(unit, timeline.current_is_extra)
	_expect_near(timeline.get_av(unit), av_before, 0.001,
		"추가 턴을 마쳐도 AV 가 리필되면 안 된다 (#495)")


func _test_timeline_preview() -> void:
	var a := _make_unit("a", 120)
	var b := _make_unit("b", 100, TurnCombat.Element.IMPACT, TurnCombat.PhysicalType.SLASH, 2)
	var c := _make_unit("c", 90, TurnCombat.Element.IMPACT, TurnCombat.PhysicalType.SLASH, 3)
	var units: Array[TurnUnit] = [a, b, c]

	var timeline := TimelineSystem.new()
	timeline.reset(units)

	# 프리뷰는 8개 이상을 보여준다 (설계서 체크리스트 1번).
	var preview := timeline.preview()
	_expect(preview.size() >= 8, "타임라인 프리뷰는 8개 이상이어야 한다 (실제 %d)" % preview.size())

	# **프리뷰는 상태를 바꾸지 않는다.**
	var av_before := timeline.get_av(a)
	timeline.preview()
	timeline.preview_if_acted(a, {b.unit_id: -0.5}, false, true)
	_expect_near(timeline.get_av(a), av_before, 0.001, "프리뷰가 실제 AV 를 바꾸면 안 된다")

	# **프리뷰가 실제와 일치해야 한다.** 여기가 어긋나면 공개한 정보가 거짓말이 된다.
	var predicted := timeline.preview(4)
	var actual: Array[String] = []
	for _i in 4:
		var actor := timeline.advance_to_next()
		actual.append(String(actor.unit_id))
		timeline.on_turn_finished(actor)
	for i in 4:
		_expect(String(predicted[i].unit_id) == actual[i],
			"프리뷰 %d번째가 실제와 달라졌다 (예측 %s, 실제 %s)"
				% [i + 1, predicted[i].unit_id, actual[i]])

	# 오의는 턴을 소모하지 않으므로 순서를 바꾸지 않는다.
	var plain := timeline.preview(6)
	var after_ult := timeline.preview_if_acted(a, {}, false, false, 6)
	var same := true
	for i in 6:
		if plain[i] != after_ult[i]:
			same = false
	_expect(same, "오의(턴 미소모) 프리뷰는 순서를 바꾸지 않아야 한다")


# ===== 랭크 =====

func _test_ranks() -> void:
	var back := _make_unit("back", 100, TurnCombat.Element.CRYO,
		TurnCombat.PhysicalType.PIERCE, 4)
	var front := _make_unit("front", 100, TurnCombat.Element.PYRO,
		TurnCombat.PhysicalType.BLUNT, 1)
	var enemy1 := _make_enemy_unit("e1", 100, 60, [TurnCombat.Element.CRYO] as Array[int],
		[] as Array[int], 1)
	var enemy3 := _make_enemy_unit("e3", 100, 60, [TurnCombat.Element.CRYO] as Array[int],
		[] as Array[int], 3)
	var units: Array[TurnUnit] = [back, front, enemy1, enemy3]

	var ranks := RankSystem.new()
	ranks.place(units)

	_expect(ranks.at(TurnCombat.Side.ALLY, 1) == front, "A1 에 전열 유닛이 앉아야 한다")
	_expect(ranks.at(TurnCombat.Side.ALLY, 4) == back, "A4 에 후열 유닛이 앉아야 한다")
	_expect(ranks.at(TurnCombat.Side.ENEMY, 3) == enemy3, "E3 에 적이 앉아야 한다")

	# 후열 전용 스킬: 사용 랭크 A3~A4, 타격 랭크 E1~E2.
	var sniper := SkillData.new()
	sniper.skill_id = &"test_sniper"
	sniper.display_name = "관통 사격"
	sniper.turn_action = TurnCombat.ActionKind.BASIC
	sniper.usable_ranks = [3, 4]
	sniper.target_ranks = [1, 2]
	sniper.turn_targeting = TurnCombat.Targeting.SINGLE
	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0
	effect.toughness_damage = 20
	sniper.turn_effects = [effect]

	_expect(ranks.is_usable(back, sniper), "A4 에서 사용 랭크 A3~A4 스킬을 쓸 수 있어야 한다")
	_expect(not ranks.is_usable(front, sniper), "A1 에서는 사용 랭크 A3~A4 스킬을 쓸 수 없어야 한다")

	var reason := String(ranks.check_usable(front, sniper)["reason"])
	_expect(reason.contains("랭크"), "사용할 수 없는 이유에 랭크가 언급되어야 한다: " + reason)

	# 타격 랭크 밖의 적은 대상 목록에 오르지 않는다.
	var targets := ranks.valid_targets(back, sniper)
	_expect(targets.has(enemy1), "타격 랭크 안의 E1 은 대상이어야 한다")
	_expect(not targets.has(enemy3), "타격 랭크 밖의 E3 은 대상이 아니어야 한다")

	# 8칸 점 표기.
	_expect(sniper.format_usable_ranks() == "○ ○ ● ●",
		"사용 랭크 표기가 '○ ○ ● ●' 여야 한다 (실제 %s)" % sniper.format_usable_ranks())
	_expect(sniper.format_target_ranks() == "● ● ○ ○ ○",
		"타격 랭크 표기가 '● ● ○ ○ ○' 여야 한다 (실제 %s)" % sniper.format_target_ranks())

	# 확산은 인덱스 ±1 로 판정한다 (3D 거리가 아니다).
	var enemy2 := _make_enemy_unit("e2", 100, 60, [] as Array[int], [] as Array[int], 2)
	units.append(enemy2)
	ranks.place(units)
	var adjacent := ranks.adjacent(enemy2)
	_expect(adjacent.has(enemy1) and adjacent.has(enemy3),
		"E2 의 인접은 E1 과 E3 이어야 한다 (배열 인덱스 ±1)")


func _test_movement() -> void:
	var front := _make_unit("mover", 100, TurnCombat.Element.PYRO,
		TurnCombat.PhysicalType.BLUNT, 1)
	var second := _make_unit("second", 100, TurnCombat.Element.PYRO,
		TurnCombat.PhysicalType.BLUNT, 2)
	var units: Array[TurnUnit] = [front, second]
	var ranks := RankSystem.new()
	ranks.place(units)

	# 전열 전용 스킬.
	var melee := SkillData.new()
	melee.skill_id = &"test_melee"
	melee.display_name = "근접"
	melee.turn_action = TurnCombat.ActionKind.BASIC
	melee.usable_ranks = [1, 2]
	melee.turn_targeting = TurnCombat.Targeting.SINGLE
	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0
	melee.turn_effects = [effect]

	_expect(melee.can_use_from_rank(front.rank), "A1 에서 전열 스킬을 쓸 수 있어야 한다")

	# 밀치기로 A1 -> A3 으로 밀려나면 스킬 사용 조건이 실제로 깨진다.
	# **이것이 위치 조작 = 예방적 방어의 핵심이다.**
	ranks.push(front, 2)
	_expect(front.rank == 3, "2칸 밀치기로 A1 -> A3 이어야 한다 (실제 A%d)" % front.rank)
	_expect(not melee.can_use_from_rank(front.rank),
		"밀려난 뒤에는 전열 스킬을 쓸 수 없어야 한다 — 대형 붕괴가 무력화로 이어진다")
	# 1칸째에 A2 의 유닛과 자리를 맞바꿨고(second: A2 -> A1), 2칸째는 빈 A3 으로 갔다.
	# **적 대형이 실제로 어긋난다** — 밀린 쪽과 앞으로 나온 쪽 둘 다 조건이 바뀐다.
	_expect(second.rank == 1,
		"자리를 맞바꾼 유닛이 앞으로 나와야 한다 (실제 A%d)" % second.rank)

	# 끌어당기기로 복구.
	ranks.pull(front, 2)
	_expect(front.rank == 1, "2칸 끌어당기기로 A3 -> A1 이어야 한다")

	# 고정(Anchor)은 위치 이동에 면역이다.
	var anchor := TurnStatus.new(&"anchor", TurnStatus.Kind.ANCHOR, 3)
	front.statuses.append(anchor)
	ranks.push(front, 1)
	_expect(front.rank == 1, "고정 상태는 밀치기에 면역이어야 한다")

	# 랭크 밖으로는 나가지 않는다.
	front.statuses.clear()
	var moved := ranks.push(front, 99)
	_expect(front.rank <= TurnCombat.ALLY_RANK_COUNT,
		"밀치기가 랭크 범위를 넘어가면 안 된다 (실제 A%d)" % front.rank)
	_expect(moved <= TurnCombat.ALLY_RANK_COUNT - 1,
		"실제 이동 칸 수가 랭크 수를 넘으면 안 된다")


func _test_aggro() -> void:
	var a1 := _make_unit("a1", 100, TurnCombat.Element.PYRO, TurnCombat.PhysicalType.BLUNT, 1)
	var a4 := _make_unit("a4", 100, TurnCombat.Element.CRYO, TurnCombat.PhysicalType.PIERCE, 4)
	var enemy := _make_enemy_unit("aggro_e", 100, 40, [] as Array[int], [] as Array[int], 1)
	var units: Array[TurnUnit] = [a1, a4, enemy]
	var ranks := RankSystem.new()
	ranks.place(units)

	var t := _tuning()
	_expect_near(ranks.aggro_weight(a1), t.aggro_rank_weights[0], 0.001,
		"A1 의 어그로 가중치는 랭크 계수 1.5 여야 한다")
	_expect_near(ranks.aggro_weight(a4), t.aggro_rank_weights[3], 0.001,
		"A4 의 어그로 가중치는 랭크 계수 0.6 여야 한다")
	_expect(ranks.aggro_weight(a1) > ranks.aggro_weight(a4),
		"전열이 후열보다 어그로가 높아야 한다 — '탱커를 앞에 세운다'가 시스템으로 성립해야 한다")

	# 확률이 UI에 노출된다 (억울함을 줄이는 장치).
	var probabilities := ranks.aggro_probabilities()
	var total := 0.0
	for id in probabilities:
		total += float(probabilities[id])
	_expect_near(total, 1.0, 0.001, "어그로 확률의 합은 1이어야 한다")

	# 도발은 가중치를 무시하고 강제 지정한다.
	a4.statuses.append(TurnStatus.new(&"taunt", TurnStatus.Kind.TAUNT, 3))
	_expect_near(ranks.aggro_weight(a4), t.aggro_taunt_weight, 0.001,
		"도발 중인 유닛의 가중치는 도발 계수여야 한다")

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var forced := true
	for _i in 20:
		if ranks.pick_aggro_target(enemy, rng) != a4:
			forced = false
	_expect(forced, "도발은 대상을 강제 지정해야 한다")

	# 저HP 가중치.
	a4.statuses.clear()
	a1.current_hp = int(float(a1.get_max_hp()) * 0.2)
	_expect_near(ranks.aggro_weight(a1),
		t.aggro_rank_weights[0] * t.aggro_low_hp_weight, 0.001,
		"HP 30% 이하 아군에게 저HP 가중치가 곱해져야 한다")


# ===== 자원 =====

func _test_resonance() -> void:
	var resources := TurnResourceSystem.new()
	resources.reset()
	var t := _tuning()

	_expect(resources.resonance == t.resonance_start,
		"공명 초기값은 %d 여야 한다 (실제 %d)" % [t.resonance_start, resources.resonance])
	_expect(resources.resonance_max == t.resonance_max, "공명 최대치는 5여야 한다")

	_expect(resources.spend_resonance(1), "공명 1 소모가 성공해야 한다")
	_expect(resources.resonance == t.resonance_start - 1, "소모 후 값이 줄어야 한다")

	# 상한을 넘는 획득은 버려진다(저축되지 않는다).
	resources.gain_resonance(99)
	_expect(resources.resonance == resources.resonance_max, "공명은 상한을 넘지 않아야 한다")

	# 파산.
	resources.spend_resonance(resources.resonance_max)
	_expect(resources.is_resonance_bankrupt(), "공명 0 은 파산 상태여야 한다")
	_expect(not resources.spend_resonance(1), "공명이 없으면 소모가 실패해야 한다")

	# 편성 화면 RP 수지 예측 — 소비형만 모으면 마이너스가 나와야 한다.
	var spender := _make_character("spender", 100, TurnCombat.Element.PYRO,
		TurnCombat.PhysicalType.BLUNT)
	var basic := SkillData.new()
	basic.skill_id = &"fc_basic"
	basic.turn_action = TurnCombat.ActionKind.BASIC
	var basic_effect := TurnSkillEffect.new()
	basic_effect.kind = TurnSkillEffect.Kind.DAMAGE
	basic_effect.multiplier = 1.0
	basic.turn_effects = [basic_effect]
	var skill := SkillData.new()
	skill.skill_id = &"fc_skill"
	skill.turn_action = TurnCombat.ActionKind.SKILL
	skill.rp_cost = 1
	skill.turn_effects = [basic_effect]
	spender.turn_skills = [basic, skill]

	var party: Array[CharacterData] = [spender, spender, spender, spender]
	var balance := TurnResourceSystem.forecast_resonance_balance(party, 1)
	_expect(balance < 0.0,
		"공명 소비형 4명의 사이클당 수지는 마이너스여야 한다 (실제 %.2f)" % balance)
	_expect(TurnResourceSystem.forecast_label(balance).contains("위험"),
		"큰 마이너스 수지는 '위험'으로 경고해야 한다")


func _test_energy_and_ultimate_cap() -> void:
	var resources := TurnResourceSystem.new()
	resources.reset()
	var t := _tuning()

	var unit := _make_unit("ult", 100)
	unit.stats.energy_max = 100

	_expect(resources.gain_energy_for_action(unit, TurnCombat.ActionKind.BASIC)
		== t.energy_basic, "일반공격은 오의 게이지 +%d" % t.energy_basic)
	unit.energy = 0
	_expect(resources.gain_energy_for_action(unit, TurnCombat.ActionKind.SKILL)
		== t.energy_skill, "전투 스킬은 오의 게이지 +%d" % t.energy_skill)
	unit.energy = 0
	_expect(resources.gain_energy_on_damage_taken(unit) == t.energy_on_hit_taken,
		"피격은 오의 게이지 +%d" % t.energy_on_hit_taken)
	unit.energy = 0
	_expect(resources.gain_energy_on_break(unit) == t.energy_on_break,
		"격파 성공은 오의 게이지 +%d" % t.energy_on_break)

	# 오의 회복 효율이 곱연산으로 걸린다.
	unit.energy = 0
	unit.stats.energy_recharge = 0.5
	_expect(resources.gain_energy_for_action(unit, TurnCombat.ActionKind.BASIC)
		== int(round(float(t.energy_basic) * 1.5)),
		"오의 회복 효율 +50% 는 획득량에 곱연산되어야 한다")
	unit.stats.energy_recharge = 0.0

	# 오의 상한: 한 유닛 턴 사이에 최대 2회.
	var ultimate := SkillData.new()
	ultimate.skill_id = &"test_ult"
	ultimate.turn_action = TurnCombat.ActionKind.ULTIMATE
	ultimate.energy_cost = 10
	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0
	ultimate.turn_effects = [effect]

	unit.energy = 100
	var used := 0
	for _i in t.ultimate_per_turn_cap + 3:
		if resources.spend_ultimate(unit, ultimate):
			used += 1
			unit.energy = 100  # 게이지가 아니라 상한에 막히는지를 본다.
	_expect(used == t.ultimate_per_turn_cap,
		"오의는 턴당 %d회로 막혀야 한다 (실제 %d) — 연쇄 오의 폭주 방지"
			% [t.ultimate_per_turn_cap, used])
	_expect(resources.ultimate_blocked_reason(unit, ultimate).contains("상한"),
		"막힌 이유가 상한임을 알려야 한다")

	resources.on_turn_start(unit)
	_expect(resources.ultimates_this_turn == 0, "턴이 시작되면 오의 카운터가 초기화되어야 한다")


func _test_heat() -> void:
	var resources := TurnResourceSystem.new()
	resources.reset()
	var t := _tuning()
	if not t.heat_enabled:
		return

	resources.heat = 20.0
	_expect(resources.heat_zone() == -1, "20 은 냉각 구간이어야 한다")
	_expect_near(resources.heat_damage_modifier(), t.heat_cold_damage, 0.001,
		"냉각 구간은 피해 -10%")

	resources.heat = 55.0
	_expect(resources.heat_zone() == 0, "55 는 최적 구간이어야 한다")
	_expect_near(resources.heat_damage_modifier(), t.heat_optimal_damage, 0.001,
		"최적 구간은 피해 +15%")
	_expect_near(resources.heat_damage_taken_modifier(), t.heat_optimal_damage_taken, 0.001,
		"최적 구간은 받는 피해 -10%")

	resources.heat = 85.0
	_expect(resources.heat_zone() == 1, "85 는 과열 구간이어야 한다")
	_expect_near(resources.heat_damage_modifier(), t.heat_overheat_damage, 0.001,
		"과열 구간은 피해 -20%")
	_expect_near(resources.heat_damage_taken_modifier(), t.heat_overheat_damage_taken, 0.001,
		"과열 구간은 받는 피해 +25%")

	# 스킬 남발은 열기를 올리고, 일반공격은 내린다 — 스킬 스팸 억제 장치다.
	resources.heat = 50.0
	resources.add_heat_for_action(TurnCombat.ActionKind.SKILL)
	_expect(resources.heat > 50.0, "스킬 사용은 열기를 올려야 한다")
	resources.heat = 50.0
	resources.add_heat_for_action(TurnCombat.ActionKind.BASIC)
	_expect(resources.heat < 50.0, "일반공격은 열기를 내려야 한다")

	# 매 턴 권장 행동이 제시되고, 수행하면 열기가 크게 내려간다.
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	resources.roll_recommendation(rng)
	_expect(not resources.recommendation.is_empty(), "권장 행동이 제시되어야 한다")
	_expect(not resources.recommendation_label().is_empty(), "권장 행동에 설명 문구가 있어야 한다")

	# 열기는 0~최대 사이로 클램프된다.
	resources.heat = 0.0
	resources.add_heat(-999.0)
	_expect_near(resources.heat, 0.0, 0.001, "열기는 0 아래로 내려가지 않아야 한다")
	resources.add_heat(999.0)
	_expect_near(resources.heat, t.heat_max, 0.001, "열기는 최대치를 넘지 않아야 한다")


# ===== 데미지 =====

# **설계서 §5.3 의 수치를 그대로 재현한다.**
#
# 기본 데미지 10000 에 +50% 버프 3개를 줄 때:
#   (가) 같은 버킷 3중첩  -> 25000
#   (나) 서로 다른 버킷   -> 33750   (35% 차이)
#
# 이 두 숫자가 시너지 설계 전체가 서 있는 근거다. 버킷이 곱연산이 아니라 가산으로
# 붕괴하면 전투는 정상으로 보이는 채로 팀 빌딩의 재미가 사라진다.
func _test_damage_buckets() -> void:
	var coefficient := PlayerStats.get_tuning().strength_to_phys_atk
	var strength := int(round(10000.0 / coefficient))

	# --- (가) 같은 버킷에 3개 몰빵: 공격력 +150% -> x2.5 ---
	var ctx_a := _bucket_context(strength)
	ctx_a.source.stats.buff_physical_attack_percent = 1.5
	DamagePipeline.new(null, null).compute(ctx_a)
	_expect_near(ctx_a.damage, 25000.0, 250.0,
		"같은 버킷 3중첩(공격력 +150%)은 25000 이어야 한다 (설계서 §5.3 (가))")

	# --- (나) 서로 다른 버킷에 분산: 공격력 +50% x 피해증가 +50% x 받는피해 +50% ---
	var ctx_b := _bucket_context(strength)
	ctx_b.source.stats.buff_physical_attack_percent = 0.5
	ctx_b.source.stats.buff_damage_bonus = 0.5
	ctx_b.target.stats.buff_vulnerability = 0.5
	DamagePipeline.new(null, null).compute(ctx_b)
	_expect_near(ctx_b.damage, 33750.0, 340.0,
		"서로 다른 버킷 분산은 33750 이어야 한다 (설계서 §5.3 (나))")

	_expect(ctx_b.damage > ctx_a.damage * 1.3,
		"버킷 분산이 같은 버킷 몰빵보다 30% 이상 강해야 한다 — 역할 분업이 곧 데미지다")

	# 계산 내역이 남는다 -> 그대로 플레이어용 전투 로그가 된다.
	_expect(ctx_b.log.size() >= 9,
		"파이프라인 각 단계가 계산 내역을 남겨야 한다 (실제 %d줄)" % ctx_b.log.size())
	_expect(ctx_b.detail().contains("버킷A"), "전투 로그에 버킷별 내역이 보여야 한다")


# 버킷 검증용 컨텍스트. 방어·저항·치명타·열기·변동을 모두 껐다.
func _bucket_context(strength: int) -> DamageContext:
	var source := _make_unit("bucket_src", 100, TurnCombat.Element.IMPACT,
		TurnCombat.PhysicalType.SLASH, 1, strength, 0)
	var target := _make_unit("bucket_tgt", 100, TurnCombat.Element.IMPACT,
		TurnCombat.PhysicalType.SLASH, 2, 0, 0)
	target.stats.strength = 0
	target.stats.defense = 0

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0
	effect.scaling = TurnCombat.Scaling.ATTACK

	var ctx := DamageContext.new()
	ctx.source = source
	ctx.target = target
	ctx.effect = effect
	ctx.preview_mode = true  # 변동과 치명타 굴림을 끈다.
	return ctx


func _test_defense_coefficient() -> void:
	var t := _tuning()
	var source := _make_unit("def_src", 100, TurnCombat.Element.IMPACT,
		TurnCombat.PhysicalType.SLASH, 1, 500, 0)
	# 방어력을 정확히 알기 위해 근력 기여를 0으로 두고 defense 만 쓴다.
	var target := _make_unit("def_tgt", 100, TurnCombat.Element.IMPACT,
		TurnCombat.PhysicalType.SLASH, 2, 0, 0)
	target.stats.strength = 0
	target.stats.defense = 200

	var expected_def := float(target.get_defense())
	var expected_coefficient := expected_def \
		/ (expected_def + t.defense_constant + t.defense_level_coefficient * float(source.level))

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0

	var ctx := DamageContext.new()
	ctx.source = source
	ctx.target = target
	ctx.effect = effect
	ctx.preview_mode = true
	DamagePipeline.new(null, null).compute(ctx)

	_expect_near(ctx.defense_coefficient, expected_coefficient, 0.001,
		"방어계수 = DEF / (DEF + %.0f + %.0f x 레벨) 이어야 한다"
			% [t.defense_constant, t.defense_level_coefficient])

	# 방어력 감소는 이 곡선에서 곱연산에 가까운 큰 이득을 준다.
	target.stats.buff_defense_reduction = 0.4
	var ctx2 := DamageContext.new()
	ctx2.source = source
	ctx2.target = target
	ctx2.effect = effect
	ctx2.preview_mode = true
	DamagePipeline.new(null, null).compute(ctx2)
	_expect(ctx2.damage > ctx.damage,
		"방어력 40%% 감소는 피해를 늘려야 한다 (%.0f -> %.0f)" % [ctx.damage, ctx2.damage])
	target.stats.buff_defense_reduction = 0.0


func _test_variance_and_crit_cap() -> void:
	var t := _tuning()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	# 랜덤 변동이 ±3% 안에 있어야 한다. "계산 가능한 게임"이 설계 3원칙의 첫 줄이다.
	var lowest := INF
	var highest := -INF
	for _i in 200:
		var ctx := _bucket_context(500)
		ctx.preview_mode = false
		ctx.source.stats.crit_rate = 0.0
		DamagePipeline.new(rng, null).compute(ctx)
		lowest = minf(lowest, ctx.damage)
		highest = maxf(highest, ctx.damage)

	var baseline := _bucket_context(500)
	DamagePipeline.new(null, null).compute(baseline)
	var spread := (highest - lowest) / baseline.damage
	_expect(spread <= t.damage_variance * 2.0 + 0.005,
		"랜덤 변동 폭이 ±%.0f%% 를 넘으면 안 된다 (실제 폭 %.1f%%)"
			% [t.damage_variance * 100.0, spread * 100.0])

	# 치명타 확률 상한 초과분은 치명타 피해로 일부 전환된다.
	var over := _bucket_context(500)
	over.source.stats.crit_rate = 1.5   # 상한 100% 를 50%p 초과
	over.source.stats.crit_damage = 0.5
	DamagePipeline.new(null, null).compute(over)
	var expected_multiplier := 1.0 + 1.0 * (0.5 + 0.5 * t.crit_overflow_to_damage)
	_expect_near(over.crit_multiplier, expected_multiplier, 0.01,
		"치명타 확률 초과분(50%%p)의 %.0f%% 가 치명타 피해로 전환되어야 한다"
			% (t.crit_overflow_to_damage * 100.0))

	# 지속 피해와 추가 피해는 치명타가 나지 않는다.
	var dot := _bucket_context(500)
	dot.preview_mode = false
	dot.is_dot = true
	dot.source.stats.crit_rate = 1.0
	DamagePipeline.new(rng, null).compute(dot)
	_expect(not dot.is_crit and is_equal_approx(dot.crit_multiplier, 1.0),
		"지속 피해는 치명타가 나지 않아야 한다 — DoT 팀이 치명타 축을 통째로 버리는 근거다")


# ===== 인성치와 격파 =====

func _test_toughness_weakness_only() -> void:
	var attacker := _make_unit("weak_src", 100, TurnCombat.Element.CRYO,
		TurnCombat.PhysicalType.PIERCE, 1, 200, 0)
	var target := _make_enemy_unit("weak_tgt", 100, 100,
		[TurnCombat.Element.CRYO] as Array[int], [] as Array[int], 1)

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0
	effect.toughness_damage = 30

	# 약점 공격은 인성치를 깎는다.
	var hit := DamageContext.new()
	hit.source = attacker
	hit.target = target
	hit.effect = effect
	hit.element = TurnCombat.Element.CRYO
	hit.physical_type = TurnCombat.PhysicalType.PIERCE
	hit.preview_mode = true
	DamagePipeline.new(null, null).compute(hit)
	_expect(hit.hits_weakness, "한기 약점 적에게 한기 공격은 약점 판정이어야 한다")
	_expect(hit.toughness_damage > 0, "약점 공격은 인성치를 깎아야 한다")

	# **비약점 공격은 HP만 깎고 인성치는 그대로다.**
	var miss := DamageContext.new()
	miss.source = attacker
	miss.target = target
	miss.effect = effect
	miss.element = TurnCombat.Element.PYRO
	miss.physical_type = TurnCombat.PhysicalType.SLASH
	miss.preview_mode = true
	DamagePipeline.new(null, null).compute(miss)
	_expect(not miss.hits_weakness, "화염은 이 적의 약점이 아니어야 한다")
	_expect(miss.toughness_damage == 0,
		"비약점 공격은 인성치를 깎지 않아야 한다 — 속성은 배율이 아니라 잠금 해제 키다")

	# 인성치가 남아 있는 적은 받는 피해가 10% 감소한다 (격파 = 딜 증폭).
	var t := _tuning()
	_expect_near(miss.get_bucket(TurnCombat.Bucket.VULNERABILITY),
		-t.unbroken_damage_reduction, 0.001,
		"인성치가 남은 적은 받는 피해 -%.0f%% 여야 한다"
			% (t.unbroken_damage_reduction * 100.0))


func _test_physical_toughness_multipliers() -> void:
	# 강타는 인성치 피해 x1.3, 관통은 x0.85 (대신 다단 히트로 자물쇠를 여러 개 연다).
	_expect_near(TurnCombat.physical_toughness_multiplier(TurnCombat.PhysicalType.BLUNT),
		1.3, 0.001, "강타의 인성치 배율은 1.3 이어야 한다")
	_expect_near(TurnCombat.physical_toughness_multiplier(TurnCombat.PhysicalType.PIERCE),
		0.85, 0.001, "관통의 인성치 배율은 0.85 이어야 한다")
	_expect_near(TurnCombat.physical_toughness_multiplier(TurnCombat.PhysicalType.SLASH),
		1.0, 0.001, "참격의 인성치 배율은 1.0 이어야 한다")

	var blunt := _make_unit("blunt", 100, TurnCombat.Element.PYRO,
		TurnCombat.PhysicalType.BLUNT, 1, 200, 0)
	var target := _make_enemy_unit("bt", 100, 200,
		[TurnCombat.Element.PYRO] as Array[int], [] as Array[int], 1)

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0
	effect.toughness_damage = 30

	var ctx := DamageContext.new()
	ctx.source = blunt
	ctx.target = target
	ctx.effect = effect
	ctx.element = TurnCombat.Element.PYRO
	ctx.physical_type = TurnCombat.PhysicalType.BLUNT
	ctx.preview_mode = true
	DamagePipeline.new(null, null).compute(ctx)
	_expect(ctx.toughness_damage == 39,
		"강타의 인성치 피해는 30 x 1.3 = 39 여야 한다 (실제 %d)" % ctx.toughness_damage)


func _test_locks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 999
	var pipeline := DamagePipeline.new(rng, null)
	var statuses := TurnStatusSystem.new(rng, pipeline)
	var toughness := ToughnessSystem.new(rng, pipeline, statuses)

	var enemy := _make_enemy_unit("lock_e", 100, 120,
		[TurnCombat.Element.CRYO, TurnCombat.Element.VOLT] as Array[int],
		[TurnCombat.PhysicalType.BLUNT] as Array[int],
		1, TurnCombat.EnemyTier.ELITE)

	var locks := toughness.generate_locks(enemy)
	var lock_range := enemy.enemy.get_lock_count_range()
	_expect(locks.size() >= lock_range.x and locks.size() <= lock_range.y,
		"정예의 자물쇠 개수는 %d~%d 여야 한다 (실제 %d)"
			% [lock_range.x, lock_range.y, locks.size()])

	# 자물쇠 타입은 **약점 목록에서만** 뽑아야 한다. 아니면 자물쇠를 다 열어도
	# 인성치가 남아 격파가 나지 않는다.
	for lock in locks:
		if lock.is_element:
			_expect(enemy.weak_elements.has(lock.value),
				"원소 자물쇠는 약점 원소여야 한다: %s" % lock.type_name())
		else:
			_expect(enemy.weak_physical.has(lock.value),
				"물리 자물쇠는 약점 타입이어야 한다: %s" % lock.type_name())

	# 후보가 2종 이상이면 최소 2종이 섞여야 한다 (한 캐릭터가 혼자 다 열지 못하게).
	if locks.size() >= 2:
		var kinds := {}
		for lock in locks:
			kinds["%s%d" % ["e" if lock.is_element else "p", lock.value]] = true
		_expect(kinds.size() >= 2,
			"자물쇠 조합에 최소 2종이 섞여야 한다 (실제 %d종)" % kinds.size())

	# --- 부분 해제 -> 위력 비율 ---
	var intent := TurnIntent.new()
	intent.locks = [
		TurnLock.new(true, TurnCombat.Element.CRYO),
		TurnLock.new(true, TurnCombat.Element.CRYO),
		TurnLock.new(true, TurnCombat.Element.VOLT),
		TurnLock.new(false, TurnCombat.PhysicalType.BLUNT),
	]
	intent.recalculate_power()
	_expect_near(intent.power_ratio, 1.0, 0.001, "자물쇠를 하나도 열지 않으면 위력 100%")

	intent.locks[0].cleared = true
	intent.locks[1].cleared = true
	intent.locks[2].cleared = true
	intent.recalculate_power()
	_expect_near(intent.power_ratio, 0.25, 0.001,
		"4개 중 3개 해제 = 위력 25% 여야 한다 (설계서 §4.4.2 규칙 4)")
	_expect(not intent.nullified, "일부 해제는 무산이 아니어야 한다")

	intent.locks[3].cleared = true
	intent.recalculate_power()
	_expect(intent.nullified and is_equal_approx(intent.power_ratio, 0.0),
		"전부 해제는 무산(위력 0)이어야 한다")

	# --- 자물쇠 해제 판정: 타입이 맞아야 열린다 ---
	var fresh := TurnIntent.new()
	fresh.locks = [
		TurnLock.new(true, TurnCombat.Element.CRYO),
		TurnLock.new(false, TurnCombat.PhysicalType.BLUNT),
	]
	fresh.recalculate_power()
	_expect(fresh.find_matching_lock(TurnCombat.Element.PYRO,
		TurnCombat.PhysicalType.SLASH) == null,
		"타입이 맞지 않는 공격은 자물쇠를 열지 못해야 한다")
	var opened := fresh.find_matching_lock(TurnCombat.Element.CRYO,
		TurnCombat.PhysicalType.SLASH)
	_expect(opened != null and opened.is_element,
		"한기 공격은 한기 자물쇠를 열어야 한다")

	# --- 전부 해제 -> 무산 + 즉시 격파 ---
	enemy.intent = TurnIntent.new()
	enemy.intent.locks = [TurnLock.new(true, TurnCombat.Element.CRYO)]
	enemy.intent.recalculate_power()
	enemy.toughness = enemy.max_toughness

	var attacker := _make_unit("lock_src", 100, TurnCombat.Element.CRYO,
		TurnCombat.PhysicalType.PIERCE, 1, 200, 0)
	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0
	effect.toughness_damage = 5   # 인성치만으로는 격파되지 않는 작은 값

	var ctx := DamageContext.new()
	ctx.source = attacker
	ctx.target = enemy
	ctx.effect = effect
	ctx.element = TurnCombat.Element.CRYO
	ctx.physical_type = TurnCombat.PhysicalType.PIERCE
	pipeline.compute(ctx)
	var result := toughness.on_hit(ctx)

	_expect(result["lock_cleared"] != null, "타입이 맞는 공격은 자물쇠를 열어야 한다")
	_expect(bool(result["nullified"]),
		"자물쇠를 전부 열면 적 행동이 무산되어야 한다")
	_expect(bool(result["broke"]),
		"자물쇠 전부 해제는 즉시 격파여야 한다 (설계서 §4.4.2 규칙 3)")


func _test_break() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31337
	var pipeline := DamagePipeline.new(rng, null)
	var statuses := TurnStatusSystem.new(rng, pipeline)
	var toughness := ToughnessSystem.new(rng, pipeline, statuses)
	var t := _tuning()

	var attacker := _make_unit("brk_src", 100, TurnCombat.Element.CRYO,
		TurnCombat.PhysicalType.BLUNT, 1, 300, 0)
	var enemy := _make_enemy_unit("brk_e", 100, 60,
		[TurnCombat.Element.CRYO] as Array[int], [] as Array[int], 1)

	var break_ctx := toughness.trigger_break(attacker, enemy, TurnCombat.Element.CRYO)

	_expect(enemy.is_broken, "격파 후 격파 상태여야 한다")
	_expect(enemy.toughness == 0, "격파 시 인성치가 0이어야 한다")
	_expect(enemy.break_stun_left == t.break_stun_turns,
		"격파는 이번 턴 + 다음 턴 완전 행동 불가여야 한다 (%d턴, 실제 %d)"
			% [t.break_stun_turns, enemy.break_stun_left])
	_expect(not enemy.can_act(), "격파 상태에서는 행동할 수 없어야 한다")
	_expect(enemy.blocked_reason().contains("격파"), "행동 불가 이유가 격파여야 한다")

	# 원소별 상태이상이 붙는다.
	var status := enemy.find_break_status(TurnCombat.BreakStatus.FREEZE)
	_expect(status != null, "한기 격파는 [동결]을 부여해야 한다")

	# 격파 데미지가 원소 배율을 쓴다.
	_expect(break_ctx != null and break_ctx.is_break_damage, "격파 데미지가 발생해야 한다")
	_expect(break_ctx.final_damage() > 0, "격파 데미지가 0이 아니어야 한다")

	# 격파 중에는 받는 피해 +25%, 방어력 -30%.
	var probe := DamageContext.new()
	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0
	probe.source = attacker
	probe.target = enemy
	probe.effect = effect
	probe.preview_mode = true
	pipeline.compute(probe)
	_expect(probe.get_bucket(TurnCombat.Bucket.VULNERABILITY) >= t.broken_vulnerability,
		"격파 중에는 받는 피해 +%.0f%% 여야 한다" % (t.broken_vulnerability * 100.0))
	_expect_near(probe.get_bucket(TurnCombat.Bucket.DEFENSE), t.broken_defense_reduction,
		0.001, "격파 중에는 방어력 -%.0f%% 여야 한다" % (t.broken_defense_reduction * 100.0))

	# 격파 해제 시 인성치 전량 회복.
	var guard := 0
	while enemy.is_broken and guard < 10:
		toughness.tick_turn_start(enemy)
		guard += 1
	_expect(not enemy.is_broken, "격파가 몇 턴 뒤에 풀려야 한다")
	_expect(enemy.toughness == enemy.max_toughness,
		"격파 해제 시 인성치가 전량 회복되어야 한다 (%d/%d)"
			% [enemy.toughness, enemy.max_toughness])

	# 원소 배율 표 (트레이드오프: 격파 데미지가 낮은 원소는 상태이상이 강하다).
	_expect_near(TurnCombat.element_break_multiplier(TurnCombat.Element.IMPACT), 2.0,
		0.001, "충격의 격파 배율은 2.0")
	_expect_near(TurnCombat.element_break_multiplier(TurnCombat.Element.PYRO), 2.0,
		0.001, "화염의 격파 배율은 2.0")
	_expect_near(TurnCombat.element_break_multiplier(TurnCombat.Element.GALE), 1.5,
		0.001, "풍압의 격파 배율은 1.5")
	_expect_near(TurnCombat.element_break_multiplier(TurnCombat.Element.CRYO), 1.0,
		0.001, "한기의 격파 배율은 1.0")
	_expect_near(TurnCombat.element_break_multiplier(TurnCombat.Element.CORROSION), 0.5,
		0.001, "침식의 격파 배율은 0.5 (대신 속박이 강력하다)")
	_expect_near(TurnCombat.element_break_multiplier(TurnCombat.Element.LUMEN), 0.5,
		0.001, "광휘의 격파 배율은 0.5 (대신 각인이 강력하다)")


func _test_break_resistance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var pipeline := DamagePipeline.new(rng, null)
	var statuses := TurnStatusSystem.new(rng, pipeline)
	var toughness := ToughnessSystem.new(rng, pipeline, statuses)

	var attacker := _make_unit("res_src", 100, TurnCombat.Element.PYRO,
		TurnCombat.PhysicalType.BLUNT, 1, 300, 0)
	var boss := _make_enemy_unit("boss", 100, 200,
		[TurnCombat.Element.PYRO] as Array[int], [] as Array[int], 1,
		TurnCombat.EnemyTier.BOSS)
	boss.break_resistance = 0.5

	toughness.trigger_break(attacker, boss, TurnCombat.Element.PYRO)
	_expect(boss.break_stun_left < _tuning().break_stun_turns,
		"격파 저항은 행동 불가 턴을 줄여야 한다 (실제 %d턴)" % boss.break_stun_left)
	_expect(boss.break_stun_left >= 1,
		"격파 저항이 있어도 최소 1턴은 보장되어야 한다 — 0턴이면 격파 축이 죽는다")


func _test_overbreak() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	var pipeline := DamagePipeline.new(rng, null)
	var statuses := TurnStatusSystem.new(rng, pipeline)
	var toughness := ToughnessSystem.new(rng, pipeline, statuses)

	var attacker := _make_unit("ob_src", 100, TurnCombat.Element.CRYO,
		TurnCombat.PhysicalType.PIERCE, 1, 300, 0)
	var enemy := _make_enemy_unit("ob_e", 100, 60,
		[TurnCombat.Element.CRYO] as Array[int], [] as Array[int], 1)

	# 격파 상태로 만든 뒤 추가 인성치 피해를 넣는다.
	toughness.trigger_break(attacker, enemy, TurnCombat.Element.CRYO)

	var effect := TurnSkillEffect.new()
	effect.kind = TurnSkillEffect.Kind.DAMAGE
	effect.multiplier = 1.0
	effect.toughness_damage = 30

	var ctx := DamageContext.new()
	ctx.source = attacker
	ctx.target = enemy
	ctx.effect = effect
	ctx.element = TurnCombat.Element.CRYO
	ctx.physical_type = TurnCombat.PhysicalType.PIERCE
	# 격파 상태에서는 파이프라인이 인성치 피해를 0으로 두지 않는다 — `on_hit` 이 전환한다.
	ctx.toughness_damage = 30

	var result := toughness.on_hit(ctx)
	var over = result["overbreak_context"]
	_expect(over != null,
		"격파 상태의 적에게 넣은 인성치 피해는 초격파 피해로 전환되어야 한다")
	if over != null:
		_expect(over.is_overbreak and over.final_damage() > 0,
			"초격파 피해가 0이 아니어야 한다 (실제 %d)" % over.final_damage())
	_expect(not bool(result["broke"]), "이미 격파된 적을 다시 격파하지 않아야 한다")


func _test_break_statuses_are_distinct() -> void:
	# **격파 상태이상 7종이 전부 다르게 동작해야 한다.** "그냥 다 도트뎀"이 되면
	# 약점 속성 맞추기가 단순 최적화가 되고 전략 선택이 사라진다.
	_expect(TurnStatusSystem.BREAK_SPEC.size() == 7,
		"격파 상태이상 규격이 7종이어야 한다 (실제 %d)" % TurnStatusSystem.BREAK_SPEC.size())

	# 원소 -> 상태이상 대응이 1:1 이어야 한다.
	var mapped := {}
	for element in TurnCombat.ELEMENT_NAME:
		var status := TurnCombat.element_break_status(element)
		_expect(not mapped.has(status),
			"두 원소가 같은 격파 상태이상을 쓰면 안 된다: %s" % TurnCombat.break_status_name(status))
		mapped[status] = element
	_expect(mapped.size() == 7, "7원소가 7개의 서로 다른 상태이상을 써야 한다")

	# CC 계열과 데미지 계열이 섞여 있어야 한다.
	var stun_count := 0
	var dot_count := 0
	var stat_count := 0
	for status in TurnStatusSystem.BREAK_SPEC:
		var spec: Dictionary = TurnStatusSystem.BREAK_SPEC[status]
		if bool(spec.get("stun", false)):
			stun_count += 1
		if float(spec.get("multiplier", 0.0)) > 0.0:
			dot_count += 1
		if spec.has("speed_percent") or spec.has("vulnerability") \
				or spec.has("vulnerability_per_stack") or spec.has("delay"):
			stat_count += 1

	_expect(stun_count >= 1, "행동 봉인(CC) 계열이 최소 1종 있어야 한다 (동결)")
	_expect(dot_count >= 3, "지속 피해 계열이 최소 3종 있어야 한다 (실제 %d)" % dot_count)
	_expect(stat_count >= 2, "스탯/지연 계열이 최소 2종 있어야 한다 (속박·각인)")

	# 열상은 **대상의** 최대 HP 를 기준으로 한다 (건 쪽의 공격력이 아니다).
	var bleed: Dictionary = TurnStatusSystem.BREAK_SPEC[TurnCombat.BreakStatus.BLEED]
	_expect(bool(bleed.get("from_target", false)),
		"열상은 대상 최대HP 비례여야 한다")
	_expect(int(bleed.get("scaling", -1)) == TurnCombat.Scaling.MAX_HP,
		"열상의 기준 스탯은 최대HP 여야 한다")

	# 균열은 중첩형, 연소는 3중첩.
	_expect(int(TurnStatusSystem.BREAK_SPEC[TurnCombat.BreakStatus.FRACTURE]["max_stacks"]) == 5,
		"균열은 최대 5중첩이어야 한다")
	_expect(int(TurnStatusSystem.BREAK_SPEC[TurnCombat.BreakStatus.BURN]["max_stacks"]) == 3,
		"연소는 최대 3중첩이어야 한다")

	# 각인은 스탯 변화가 두 개다 — 상태 하나가 여러 스탯을 건드릴 수 있어야 한다.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var statuses := TurnStatusSystem.new(rng, DamagePipeline.new(rng, null))
	var source := _make_unit("sigil_src", 100)
	var sigil := statuses.build_break_status(source, TurnCombat.BreakStatus.SIGIL,
		TurnCombat.Element.LUMEN)
	_expect(sigil.all_mods().size() >= 2,
		"각인은 속도 감소 + 받는 피해 증가를 함께 걸어야 한다 (실제 %d개)"
			% sigil.all_mods().size())

	# 속박과 각인은 부여와 동시에 행동 지연을 요구한다.
	_expect(statuses.break_delay_ratio(TurnCombat.BreakStatus.BIND) > 0.0,
		"속박은 행동 지연을 걸어야 한다")
	_expect(statuses.break_delay_ratio(TurnCombat.BreakStatus.SIGIL) > 0.0,
		"각인은 행동 지연을 걸어야 한다")

	# 각인이 실제로 속도를 떨어뜨리는지 (스탯 채널까지 이어지는지) 확인한다.
	var victim := _make_unit("sigil_tgt", 100)
	var before_speed := victim.get_speed()
	statuses.apply(source, victim, sigil)
	_expect(victim.get_speed() < before_speed,
		"각인이 걸리면 실제 속도가 떨어져야 한다 (%d -> %d)"
			% [before_speed, victim.get_speed()])

	# 정화하면 원래대로 돌아온다.
	statuses.cleanse(victim, 0)
	_expect(victim.get_speed() == before_speed,
		"정화 후 속도가 원래대로 돌아와야 한다 (%d -> %d)"
			% [before_speed, victim.get_speed()])


func _test_pity() -> void:
	var t := _tuning()
	var rng := RandomNumberGenerator.new()
	rng.seed = 8080
	var statuses := TurnStatusSystem.new(rng, DamagePipeline.new(rng, null))

	var source := _make_unit("pity_src", 100)
	var target := _make_unit("pity_tgt", 100)

	# 확률 0 이면 계속 실패한다. `debuff_pity_after_failures` 회 실패한 뒤에는 확정 성공.
	var successes := 0
	for _i in t.debuff_pity_after_failures:
		if statuses.roll_debuff(source, target, 0.0):
			successes += 1
	_expect(successes == 0, "확률 0 은 Pity 도달 전까지 실패해야 한다")
	_expect(target.debuff_failures == t.debuff_pity_after_failures,
		"연속 실패 횟수가 누적되어야 한다 (실제 %d)" % target.debuff_failures)
	_expect(statuses.roll_debuff(source, target, 0.0),
		"%d회 연속 실패 후 %d회차는 확정 성공이어야 한다 (억울함 방지)"
			% [t.debuff_pity_after_failures, t.debuff_pity_after_failures + 1])
	_expect(target.debuff_failures == 0, "확정 성공 후 카운터가 초기화되어야 한다")

	# 효과 저항 상한.
	target.stats.effect_res = 5.0
	_expect_near(target.stats.get_effect_res(), t.effect_res_cap, 0.001,
		"효과 저항은 %.0f%% 로 상한이 걸려야 한다" % (t.effect_res_cap * 100.0))


# ===== 어휘 =====

func _test_element_colors() -> void:
	# 설계서 §4.10.10 의 색상 코드와 정확히 일치해야 한다.
	# 색이 곧 라벨이므로 여기가 어긋나면 전 게임의 색 언어가 깨진다.
	var expected := {
		TurnCombat.Element.IMPACT: "e8e8e8",
		TurnCombat.Element.PYRO: "ff6b35",
		TurnCombat.Element.CRYO: "4fc3f7",
		TurnCombat.Element.VOLT: "b388ff",
		TurnCombat.Element.GALE: "66d9a6",
		TurnCombat.Element.CORROSION: "7c4dff",
		TurnCombat.Element.LUMEN: "ffd54f",
	}
	for element in expected:
		var actual := TurnCombat.element_color(element).to_html(false).to_lower()
		_expect(actual == expected[element],
			"%s 의 색상 코드는 #%s 여야 한다 (실제 #%s)"
				% [TurnCombat.element_name(element), expected[element], actual])

	# 색맹 대응: 원소마다 **고유 형태** 아이콘이 병기되어야 한다.
	var glyphs := {}
	for element in TurnCombat.ELEMENT_NAME:
		var glyph := TurnCombat.element_glyph(element)
		_expect(not glyph.is_empty() and glyph != "?",
			"%s 에 고유 형태 문양이 있어야 한다" % TurnCombat.element_name(element))
		_expect(not glyphs.has(glyph),
			"두 원소가 같은 문양을 쓰면 안 된다: %s" % glyph)
		glyphs[glyph] = true

	# 물리 타입도 같은 규칙.
	var physical_glyphs := {}
	for physical in TurnCombat.PHYSICAL_NAME:
		var glyph := TurnCombat.physical_glyph(physical)
		_expect(not physical_glyphs.has(glyph),
			"두 물리 타입이 같은 문양을 쓰면 안 된다: %s" % glyph)
		physical_glyphs[glyph] = true

	# 10개 상성 축 (원소 7 + 물리 3).
	_expect(TurnCombat.ELEMENT_NAME.size() + TurnCombat.PHYSICAL_NAME.size() == 10,
		"상성 축은 원소 7 + 물리 3 = 10개여야 한다")

	# 8역할.
	_expect(TurnCombat.CLASS_NAME.size() == 8, "역할은 8종이어야 한다")


func _test_presentation_specs() -> void:
	# 약점 격파 9단계가 전부 있어야 한다 — 게임의 첫인상을 결정하는 연출이다.
	for element in TurnCombat.ELEMENT_NAME:
		var steps := PresentationQueue.break_steps(element)
		_expect(steps.size() == 9,
			"%s 의 격파 연출은 9단계여야 한다 (실제 %d)"
				% [TurnCombat.element_name(element), steps.size()])
		# 원소마다 전용 대형 이펙트가 달라야 한다.
		_expect(not PresentationQueue.element_break_effect(element).is_empty(),
			"%s 에 전용 격파 이펙트 설명이 있어야 한다" % TurnCombat.element_name(element))

	# 타격 피드백 규격표 (설계서 §4.10.5).
	var basic: Dictionary = PresentationQueue.FEEDBACK["basic"]
	var skill: Dictionary = PresentationQueue.FEEDBACK["skill"]
	var ultimate: Dictionary = PresentationQueue.FEEDBACK["ultimate"]
	var break_fb: Dictionary = PresentationQueue.FEEDBACK["break"]

	_expect(int(basic["hitstop_frames"]) == 2, "일반공격 히트스톱은 2프레임")
	_expect(int(skill["hitstop_frames"]) == 4, "스킬 히트스톱은 4프레임")
	_expect(int(ultimate["hitstop_frames"]) == 8, "오의 히트스톱은 8프레임")
	_expect(int(break_fb["hitstop_frames"]) == 12, "약점 격파 히트스톱은 12프레임")

	_expect_near(float(break_fb["shake_px"]), 20.0, 0.001, "격파 흔들림 진폭은 20px")
	_expect_near(float(break_fb["slowmo_scale"]), 0.15, 0.001, "격파 슬로모션은 0.15배속")
	_expect_near(float(break_fb["flash"]), 0.70, 0.001, "격파 플래시는 70%")

	# 무게 순서: 일반공격 < 스킬 < 오의 < 격파. 이 순서가 뒤집히면 연출이 거짓말을 한다.
	_expect(int(basic["hitstop_frames"]) < int(skill["hitstop_frames"])
		and int(skill["hitstop_frames"]) < int(ultimate["hitstop_frames"])
		and int(ultimate["hitstop_frames"]) < int(break_fb["hitstop_frames"]),
		"히트스톱은 일반공격 < 스킬 < 오의 < 격파 순이어야 한다")

	# 데미지 숫자 규격 (설계서 §4.10.6).
	_expect_near(float(PresentationQueue.NUMBER_STYLE["crit"]["scale"]), 1.6, 0.001,
		"치명타 숫자는 1.6배")
	_expect_near(float(PresentationQueue.NUMBER_STYLE["break"]["scale"]), 2.0, 0.001,
		"격파 숫자는 2.0배")
	_expect(String(PresentationQueue.NUMBER_STYLE["crit"]["label"]) == "CRITICAL",
		"치명타에 CRITICAL 라벨이 있어야 한다")

	# 자물쇠 해제음은 **상승 음계**여야 한다. 연속 해제가 음악이 되게 하려는 것이다.
	var pitches: Array[float] = []
	for i in range(1, 4):
		pitches.append(PresentationQueue.lock_pitch(i, 4))
	_expect(pitches[0] < pitches[1] and pitches[1] < pitches[2],
		"자물쇠 해제음의 음정이 올라가야 한다 (%s)" % str(pitches))
	_expect(PresentationQueue.lock_pitch(4, 4) > pitches[2],
		"전부 해제는 가장 높은 음(화음 폭발)이어야 한다")

	# 오의 컷인 8단계 (3D 컷씬의 2D 대체안).
	var unit := _make_unit("cutin", 100)
	var ult_skill := SkillData.new()
	ult_skill.display_name = "테스트 오의"
	var cutin := PresentationQueue.ultimate_cutin_steps(unit, ult_skill)
	_expect(cutin.size() == 8, "오의 컷인은 8단계여야 한다 (실제 %d)" % cutin.size())
	var has_typography := false
	for step in cutin:
		if step.has("text"):
			has_typography = true
	_expect(has_typography,
		"오의 컷인에 키네틱 타이포그래피 단계가 있어야 한다 — 글자 자체가 연출이다")

	# 연출을 끄면 큐가 비어 있어야 한다 (헤드리스 테스트 · 연출 감소 모드).
	var off := PresentationQueue.new(false, 1.0)
	off.push_log("무시되어야 한다")
	_expect(off.is_empty(), "연출을 끄면 큐에 아무것도 쌓이지 않아야 한다")

	# 배속은 재생 시간만 나눈다 (로직을 건드리지 않는다).
	var fast := PresentationQueue.new(true, 3.0)
	_expect_near(fast.scaled(0.9), 0.3, 0.001, "3배속은 재생 시간을 1/3로 만들어야 한다")


# ===== 저작 데이터 =====

func _test_authored_data() -> void:
	# 로스터 6인이 턴제 유닛으로 변환되고, 검증을 통과해야 한다.
	var ids := CharacterDatabase.get_playable_ids()
	_expect(ids.size() == 6, "로스터는 6인이어야 한다 (실제 %d)" % ids.size())

	var elements := {}
	var physicals := {}
	var classes := {}

	for id in ids:
		var character: CharacterData = CharacterDatabase.get_character(id)
		_expect(character != null, "%s 를 조회할 수 있어야 한다" % id)
		if character == null:
			continue

		var problems := character.validate_turn()
		_expect(problems.is_empty(),
			"%s 의 턴제 저작이 유효해야 한다: %s" % [id, ", ".join(problems)])

		_expect(character.is_turn_ready(),
			"%s 에 턴제 일반공격이 저작되어야 한다" % id)
		_expect(character.get_turn_ultimate() != null,
			"%s 에 턴제 오의가 저작되어야 한다" % id)
		_expect(character.get_stats().get_energy_max() > 0,
			"%s 의 오의 게이지 최대치가 0보다 커야 한다" % id)
		_expect(character.get_stats().get_speed() > 0,
			"%s 의 속도가 0보다 커야 한다" % id)
		_expect(not character.preferred_ranks.is_empty(),
			"%s 의 선호 랭크가 저작되어야 한다" % id)

		elements[character.element] = true
		physicals[character.physical_type] = true
		classes[character.battle_class] = true

		# 유닛으로 변환된다.
		var unit := TurnUnit.from_character(character, character.preferred_ranks[0])
		_expect(unit.get_max_hp() > 0, "%s 의 최대 HP 가 0보다 커야 한다" % id)
		_expect(unit.get_action_value() > 0.0, "%s 의 AV 가 0보다 커야 한다" % id)

		# **스텟은 복제되어야 한다.** 원본을 쓰면 전투 중 버프가 저작 데이터를 오염시킨다.
		_expect(unit.stats != character.get_stats(),
			"%s 의 스텟은 저작 리소스의 복제본이어야 한다" % id)

	# 원소·물리 타입이 충분히 흩어져야 자물쇠 퍼즐이 성립한다.
	_expect(elements.size() >= 5,
		"로스터의 원소가 5종 이상이어야 자물쇠 조합을 풀 수 있다 (실제 %d종)" % elements.size())
	_expect(physicals.size() == 3,
		"로스터가 물리 타입 3종을 모두 커버해야 한다 (실제 %d종)" % physicals.size())
	_expect(classes.size() >= 5,
		"로스터의 턴제 역할이 5종 이상이어야 한다 (실제 %d종)" % classes.size())

	# 적 6종.
	var enemy_ids := EnemyDatabase.get_all_ids()
	_expect(enemy_ids.size() >= 6, "적이 6종 이상 저작되어야 한다 (실제 %d)" % enemy_ids.size())

	for id in enemy_ids:
		var enemy: EnemyData = EnemyDatabase.get_enemy(id)
		if enemy == null:
			continue
		var problems := enemy.validate_turn()
		_expect(problems.is_empty(),
			"%s 의 턴제 저작이 유효해야 한다: %s" % [id, ", ".join(problems)])
		_expect(not enemy.turn_skills.is_empty(),
			"%s 에 턴제 행동표가 저작되어야 한다" % id)
		_expect(enemy.get_effective_toughness() > 0,
			"%s 의 인성치가 0보다 커야 한다" % id)
		_expect(not enemy.get_lock_candidates().is_empty(),
			"%s 에 자물쇠 후보(약점)가 있어야 한다 — 없으면 영원히 격파되지 않는다" % id)

		var unit := TurnUnit.from_enemy(enemy, 1)
		_expect(unit.max_toughness > 0, "%s 유닛의 인성치가 설정되어야 한다" % id)
		# 밸런스 배수가 복제본에만 적용되어야 한다.
		_expect(enemy.get_stats().hp > 0, "%s 저작 리소스의 HP 가 오염되면 안 된다" % id)

	# 로스터의 원소가 어딘가에서 반드시 약점이어야 한다 — 쓸모없는 캐릭터를 만들지 않는다.
	var weak_pool := {}
	for id in enemy_ids:
		var enemy: EnemyData = EnemyDatabase.get_enemy(id)
		if enemy == null:
			continue
		for e in enemy.weak_elements:
			weak_pool[int(e)] = true
	for element in elements:
		_expect(weak_pool.has(element),
			"%s 원소가 어떤 적의 약점도 아니다 — 그 캐릭터는 인성치를 깎을 수 없다"
				% TurnCombat.element_name(element))


# ===== 전체 전투 =====

func _test_full_battle() -> void:
	var party: Array[CharacterData] = []
	for id in [&"mina", &"harang", &"seola", &"gangji"]:
		var character: CharacterData = CharacterDatabase.get_character(id)
		if character != null:
			party.append(character)
	_expect(party.size() == 4, "4인 파티를 구성할 수 있어야 한다")

	var enemies: Array[EnemyData] = []
	for id in [&"velociraptor_beastfolk", &"velociraptor_beastfolk_2",
			&"mammoth_beastfolk", &"seoa", &"mammoth_boss"]:
		var enemy: EnemyData = EnemyDatabase.get_enemy(id)
		if enemy != null:
			enemies.append(enemy)
	_expect(enemies.size() == 5, "적 5마리를 구성할 수 있어야 한다 (최대 랭크)")

	var battle := TurnBattleManager.new()
	battle.auto_battle = true
	battle.start(party, enemies, 0, 20260909)

	_expect(battle.units.size() == 9, "4 vs 5 = 9유닛이어야 한다 (실제 %d)" % battle.units.size())
	_expect(battle.allies().size() == 4, "아군 4명이 배치되어야 한다")
	_expect(battle.enemies().size() == 5, "적 5마리가 배치되어야 한다")

	# 랭크가 겹치지 않아야 한다.
	var ally_ranks := {}
	for unit in battle.allies():
		_expect(not ally_ranks.has(unit.rank),
			"아군 랭크가 겹쳤다: A%d" % unit.rank)
		ally_ranks[unit.rank] = true

	# 모든 적이 예고와 자물쇠를 갖는다 — 완전 정보 공개.
	for unit in battle.enemies():
		_expect(unit.intent != null, "%s 에 행동 예고가 있어야 한다" % unit.display_name)
		if unit.intent == null:
			continue
		_expect(unit.intent.skill != null, "%s 의 예고에 스킬이 있어야 한다" % unit.display_name)
		_expect(unit.intent.total_locks() > 0,
			"%s 의 예고에 자물쇠가 있어야 한다" % unit.display_name)
		# 예상 피해가 공개된다.
		_expect(not unit.intent.expected_damage.is_empty(),
			"%s 의 예상 피해가 계산되어야 한다" % unit.display_name)
		_expect(unit.intent.describe().contains("다음 행동"),
			"예고 문구에 다음 행동이 보여야 한다")

	# 정보 표시 3단계.
	var sample := battle.enemies()[0]
	_expect(sample.intent.describe(TurnCombat.InfoDetail.CHALLENGE).contains("???"),
		"도전 난이도에서는 정보를 감춰야 한다")
	_expect(sample.intent.describe(TurnCombat.InfoDetail.VERBOSE).contains("예상 피해")
			or sample.intent.total_expected_damage() == 0,
		"상세 난이도에서는 예상 피해 수치를 보여야 한다")

	# 준비 페이즈.
	_expect(battle.phase == TurnBattleManager.Phase.PREP, "전투는 준비 페이즈에서 시작한다")
	var prep_before := battle.prep_points
	_expect(battle.use_prep("energy"), "준비 포인트를 쓸 수 있어야 한다")
	_expect(battle.prep_points == prep_before - 1, "준비 포인트가 소모되어야 한다")
	var charged := false
	for unit in battle.allies():
		if unit.energy > 0:
			charged = true
	_expect(charged, "준비(오의 게이지 50%)가 실제로 게이지를 채워야 한다")

	battle.begin_battle()

	# 자동 전투로 끝까지 굴린다. 무한 루프면 여기서 걸린다.
	var guard := 0
	while not battle.is_over() and guard < 4000:
		guard += 1
		if battle.phase == TurnBattleManager.Phase.AWAITING_INPUT:
			# 자동 전투이므로 여기 오지 않아야 한다.
			battle.auto_battle = true
			battle.advance()
		elif battle.phase == TurnBattleManager.Phase.TURN_END \
				or battle.phase == TurnBattleManager.Phase.TURN_START:
			battle.advance()
		else:
			break

	_expect(battle.is_over(),
		"전투가 끝나야 한다 (%d회 진행 후 상태 %s)"
			% [guard, TurnBattleManager.Phase.keys()[battle.phase]])
	_expect(guard < 4000, "전투가 무한 루프에 빠지면 안 된다 (진행 %d회)" % guard)

	var summary := battle.result_summary()
	_expect(int(summary["turns"]) > 0, "턴이 진행되어야 한다")
	_expect(int(summary["cycles"]) >= 1, "사이클이 1 이상이어야 한다")
	_expect(not battle.battle_log.is_empty(), "전투 로그가 남아야 한다")
	_expect(summary.has("damage") and not summary["damage"].is_empty(),
		"캐릭터별 딜량이 집계되어야 한다")

	print("  전투 결과: %s / %d 사이클 / %d턴 / 격파 %d회 / 자물쇠 %d개 해제 / 무산 %d회"
		% ["승리" if bool(summary["victory"]) else "패배",
			int(summary["cycles"]), int(summary["turns"]), int(summary["breaks"]),
			int(summary["locks_cleared"]), int(summary["nullified"])])

	# 자물쇠와 격파가 실제로 굴러갔는지 — 시스템이 배선만 되고 죽어 있지 않은지 본다.
	_expect(int(summary["locks_cleared"]) > 0,
		"전투 중 자물쇠가 한 번도 해제되지 않았다 — 자물쇠 시스템이 죽어 있다")
	_expect(int(summary["breaks"]) > 0,
		"전투 중 격파가 한 번도 나지 않았다 — 격파 시스템이 죽어 있다")

	# 같은 시드는 같은 전투를 재현해야 한다 (리플레이 · 버그 재현).
	var replay := TurnBattleManager.new()
	replay.auto_battle = true
	replay.start(party, enemies, 0, 20260909)
	replay.use_prep("energy")
	replay.begin_battle()
	var replay_guard := 0
	while not replay.is_over() and replay_guard < 4000:
		replay_guard += 1
		if replay.phase == TurnBattleManager.Phase.TURN_END \
				or replay.phase == TurnBattleManager.Phase.TURN_START \
				or replay.phase == TurnBattleManager.Phase.AWAITING_INPUT:
			replay.advance()
		else:
			break

	var replay_summary := replay.result_summary()
	_expect(int(replay_summary["turns"]) == int(summary["turns"])
			and int(replay_summary["breaks"]) == int(summary["breaks"]),
		"같은 시드는 같은 전투를 재현해야 한다 (턴 %d/%d, 격파 %d/%d)"
			% [int(summary["turns"]), int(replay_summary["turns"]),
				int(summary["breaks"]), int(replay_summary["breaks"])])


# ===== 적 기준 스탯 =====

func _test_enemy_baseline() -> void:
	var t := _tuning()

	# 설계서 §4.15 의 레벨별 표를 근사한다. 표에 없는 레벨에서 값이 튀지 않아야 한다.
	_expect_near(float(t.enemy_base_hp(20, TurnCombat.EnemyTier.MINION)), 1800.0, 260.0,
		"Lv20 잡몹의 기준 HP 는 설계서 표(1,800)에 가까워야 한다")
	_expect_near(float(t.enemy_base_attack(20, TurnCombat.EnemyTier.MINION)), 240.0, 40.0,
		"Lv20 잡몹의 기준 공격력은 설계서 표(240)에 가까워야 한다")
	_expect_near(float(t.enemy_base_defense(20)), 320.0, 50.0,
		"Lv20 적의 기준 방어력은 설계서 표(320)에 가까워야 한다")

	# 등급이 올라가면 단조 증가해야 한다.
	_expect(t.enemy_base_hp(20, TurnCombat.EnemyTier.ELITE)
			> t.enemy_base_hp(20, TurnCombat.EnemyTier.MINION),
		"정예의 기준 HP 가 잡몹보다 커야 한다")
	_expect(t.enemy_base_hp(20, TurnCombat.EnemyTier.BOSS)
			> t.enemy_base_hp(20, TurnCombat.EnemyTier.ELITE),
		"보스의 기준 HP 가 정예보다 커야 한다")

	# 레벨이 올라가면 단조 증가해야 한다.
	_expect(t.enemy_base_hp(40, TurnCombat.EnemyTier.MINION)
			> t.enemy_base_hp(20, TurnCombat.EnemyTier.MINION),
		"레벨이 올라가면 기준 HP 가 커져야 한다")

	# **실시간 배수를 쓰지 않는다.** 실시간 HP 는 연속 DPS 기준이라 턴제에서 수백 턴이 된다.
	var boss: EnemyData = EnemyDatabase.get_enemy(&"mammoth_boss")
	if boss != null:
		var unit := TurnUnit.from_enemy(boss, 1)
		var realtime_hp := int(round(float(boss.get_stats().hp) * boss.hp_multiplier))
		_expect(unit.get_max_hp() != realtime_hp,
			"턴제 HP 가 실시간 HP x hp_multiplier(%d)를 그대로 쓰면 안 된다" % realtime_hp)
		_expect(unit.get_max_hp() == boss.get_turn_hp(),
			"턴제 유닛의 HP 는 EnemyData.get_turn_hp() 와 같아야 한다 (%d vs %d)"
				% [unit.get_max_hp(), boss.get_turn_hp()])

		# 파생 규칙의 소유자는 PlayerStats 다 — 역산한 기초 스텟이 목표 파생값을 만들어야 한다.
		_expect(absi(unit.get_attack() - boss.get_turn_attack()) <= 2,
			"역산한 근력이 목표 공격력을 만들어야 한다 (%d vs %d)"
				% [unit.get_attack(), boss.get_turn_attack()])
		_expect(absi(unit.get_defense() - boss.get_turn_defense()) <= 2,
			"역산한 방어력이 목표 방어력을 만들어야 한다 (%d vs %d)"
				% [unit.get_defense(), boss.get_turn_defense()])

		# 같은 정의로 유닛을 두 번 만들어도 스텟이 커지지 않아야 한다.
		var again := TurnUnit.from_enemy(boss, 1)
		_expect(again.get_max_hp() == unit.get_max_hp(),
			"같은 정의로 만든 두 유닛의 HP 가 같아야 한다 (저작 리소스 오염 없음)")


# ===== 표준 조우 =====
#
# **이 검사가 잡는 것**: 자동 전투 정책이 회복 스킬을 후보에서 빼먹는 회귀다.
# 처음에 대상 목록을 적으로만 걸렀더니 치유자가 평타만 쳐서 정예전 승률이 0/5 였다.
# 밸런스처럼 보이지만 원인은 필터 한 줄이었다 — 눈으로는 구분되지 않는다.
func _test_standard_encounter() -> void:
	var party: Array[CharacterData] = []
	for id in [&"mina", &"harang", &"seola", &"gangji"]:
		var character: CharacterData = CharacterDatabase.get_character(id)
		if character != null:
			party.append(character)

	var enemies: Array[EnemyData] = []
	for id in [&"mammoth_beastfolk", &"velociraptor_beastfolk",
			&"velociraptor_beastfolk_2"]:
		var enemy: EnemyData = EnemyDatabase.get_enemy(id)
		if enemy != null:
			enemies.append(enemy)

	var wins := 0
	var cycles := 0
	var breaks := 0
	var trials := 4

	for i in trials:
		var battle := TurnBattleManager.new()
		battle.auto_battle = true
		battle.cycle_limit = 40
		battle.start(party, enemies, 0, 700 + i * 53)
		battle.presentation.enabled = false
		battle.begin_battle()

		var guard := 0
		while not battle.is_over() and guard < 3000:
			guard += 1
			battle.advance()

		if battle.phase == TurnBattleManager.Phase.VICTORY:
			wins += 1
		cycles += battle.timeline.current_cycle()
		breaks += int(battle.stats["breaks"])

	print("  표준 조우(정예1+잡몹2) 자동 전투: 승 %d/%d, 평균 %d사이클, 평균 격파 %.1f회"
		% [wins, trials, cycles / trials, float(breaks) / float(trials)])

	_expect(wins == trials,
		"표준 조우는 자동 전투로 확실히 이겨야 한다 (승 %d/%d) — 지면 자동 전투 정책이나 밸런스가 깨진 것이다"
			% [wins, trials])
	_expect(cycles / trials <= 25,
		"표준 조우가 25사이클을 넘으면 안 된다 (평균 %d사이클) — 적 HP 가 턴제 스케일을 벗어났다"
			% (cycles / trials))
	_expect(float(breaks) / float(trials) >= 2.0,
		"표준 조우에서 평균 2회 이상 격파가 나야 한다 (실제 %.1f회) — 격파가 주 루프여야 한다"
			% (float(breaks) / float(trials)))


# ===== 사이클 제한 =====

func _test_cycle_limit() -> void:
	# 사이클 제한은 교착을 잡는 가드레일이다. 힐러가 있는 파티와 고HP 보스가 만나면
	# 양쪽이 서로를 죽이지 못해 수천 턴이 흐르고, 그것은 "아주 긴 전투"로 보여서
	# 버그로 인식되지 않는다.
	var party: Array[CharacterData] = []
	var character: CharacterData = CharacterDatabase.get_character(&"gangji")
	if character != null:
		party.append(character)

	var enemies: Array[EnemyData] = []
	var boss: EnemyData = EnemyDatabase.get_enemy(&"mammoth_boss")
	if boss != null:
		enemies.append(boss)

	if party.is_empty() or enemies.is_empty():
		return

	var battle := TurnBattleManager.new()
	battle.auto_battle = true
	battle.cycle_limit = 3
	battle.start(party, enemies, 0, 4242)
	battle.presentation.enabled = false
	battle.begin_battle()

	var guard := 0
	while not battle.is_over() and guard < 2000:
		guard += 1
		battle.advance()

	_expect(battle.is_over(), "사이클 제한이 걸린 전투는 반드시 끝나야 한다")
	_expect(battle.timeline.current_cycle() <= battle.cycle_limit + 1,
		"사이클 제한 %d 를 크게 넘기지 않아야 한다 (실제 %d사이클)"
			% [battle.cycle_limit, battle.timeline.current_cycle()])

	# 제한이 0이면 제한 없음이어야 한다 (기존 동작 보존).
	var unlimited := TurnBattleManager.new()
	_expect(unlimited.cycle_limit == 0, "사이클 제한의 기본값은 0(제한 없음)이어야 한다")
